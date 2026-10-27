import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/error_text.dart';
import '../core/l10n/l10n.dart';
import '../core/network/api_exception.dart';
import '../core/providers.dart';
import '../features/auth/session.dart';
import '../models/json.dart';
import '../repositories/providers.dart';
import '../repositories/sinksar_repository.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/favorites_service.dart';
import '../services/local_notifications.dart';
import '../services/offline_pack.dart';
import '../services/program_alarms.dart';
import '../services/push_service.dart';
import '../services/reminder_service.dart';
import '../services/sinksar_widget_service.dart';
import '../services/sync_service.dart';
import '../services/unread_service.dart';
import '../services/update_service.dart';
import 'deep_links.dart';
import 'notification_gate.dart';
import 'router.dart';

/// Wires long-lived services to the session and app lifecycle:
///  sign-in  → register FCM token, flush + pull sync data, refresh offline copies, re-arm reminders
///  sign-out → unregister push, stop sync, cancel local reminders, stop audio
///  online / resume → flush the offline queue
///  notification taps → deep links
class AppServicesHost extends ConsumerStatefulWidget {
  const AppServicesHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppServicesHost> createState() => _AppServicesHostState();
}

class _AppServicesHostState extends ConsumerState<AppServicesHost> with WidgetsBindingObserver {
  final _subs = <StreamSubscription<dynamic>>[];
  String? _pendingPayload;
  DateTime? _lastTapTime;
  String? _lastPayload;

  static String _pushDataToPayload(Map<String, dynamic> data) {
    final nid = data['notification_id'] ?? data['id'] ?? '';
    if (data['route'] != null && '${data['route']}'.isNotEmpty) {
      return 'n:$nid|route:${data['route']}';
    }
    final rawEntityType = data['entity_type']?.toString();
    final rawType = data['type']?.toString();
    // Prioritize specific entity_type over generic broad module types like 'education', 'system', 'broadcast'
    final effectiveType = (rawEntityType != null && rawEntityType.isNotEmpty && rawEntityType != 'education' && rawEntityType != 'system')
        ? rawEntityType
        : (rawType ?? rawEntityType ?? '');

    if (effectiveType == 'sinksar' || effectiveType == 'holy_day') {
      return 'n:$nid|sinksar:${data['date'] ?? ''}';
    }
    if (effectiveType == 'alarm' || effectiveType == 'program_alarm') {
      return 'n:$nid|alarm:${data['entity_id'] ?? data['id'] ?? ''}';
    }

    final entityId = data['entity_id'] ?? data['quiz_id'] ?? data['lesson_id'] ?? data['class_id'] ?? data['id'] ?? '';
    final buffer = StringBuffer('n:$nid|$effectiveType:$entityId');
    if (data['attempt_id'] != null && '${data['attempt_id']}'.isNotEmpty) {
      buffer.write('|attempt_id:${data['attempt_id']}');
    }
    if (data['lesson_id'] != null && '${data['lesson_id']}'.isNotEmpty) {
      buffer.write('|lesson_id:${data['lesson_id']}');
    }
    if (data['quiz_id'] != null && '${data['quiz_id']}'.isNotEmpty) {
      buffer.write('|quiz_id:${data['quiz_id']}');
    }
    if (data['class_id'] != null && '${data['class_id']}'.isNotEmpty) {
      buffer.write('|class_id:${data['class_id']}');
    }
    if (data['date'] != null && '${data['date']}'.isNotEmpty) {
      buffer.write('|date:${data['date']}');
    }
    return buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
  }

  Future<void> _init() async {
    final l = lookupAppLocalizations(ref.read(appSettingsProvider).locale);
    final local = ref.read(localNotificationsProvider);
    // Each start-up step is isolated: a failure in local notifications must never stop push
    // registration, sign-in hooks or deep links from being set up.
    try {
      await local.init(channelName: l.notifications, remindersName: l.reminders, programsName: l.programs, borrowingName: l.borrowings, chatName: l.chatTitle);
    } catch (e) {
      debugPrint('local notifications init failed: $e');
    }
    ref.read(remindersProvider.notifier).channelName = l.reminders;

    final push = ref.read(pushServiceProvider);
    try {
      await push.init();
    } catch (e) {
      debugPrint('push init failed: $e');
    }

    // Handle home-screen widget taps directing to Sinksar
    try {
      ref.read(sinksarWidgetServiceProvider).initWidgetLaunchHandler(_openPayload);
    } catch (e) {
      debugPrint('sinksar widget launch handler init failed: $e');
    }

    final session = ref.read(sessionProvider.notifier);
    session.addSignInHook((user) async {
      final sync = ref.read(syncServiceProvider)..start();
      await sync.flush();
      unawaited(push.registerForUser());
      unawaited(ref.read(favoritesProvider.notifier).pull().catchError((_) {}));
      await ref.read(remindersProvider.notifier).pull();
      await ref.read(remindersProvider.notifier).rescheduleAll();
      unawaited(ref.read(downloadsProvider.notifier).refreshStale().then((_) => ref.read(downloadsProvider.notifier).syncAllLyrics()));
      unawaited(ref.read(unreadCountProvider.notifier).refresh());
      unawaited(_syncProgramAlarms());
      unawaited(_syncDailySinksar());
      unawaited(_syncPreferences());
      // Re-trigger pending payload if tapped while unauthenticated or cold-starting
      if (_pendingPayload != null) {
        final p = _pendingPayload!;
        _pendingPayload = null;
        Future.delayed(const Duration(milliseconds: 300), () => _openPayload(p));
      }
      // Own QR card, featured Mezmurs and (staff) the member directory / programs / items for offline work.
      ref.read(offlinePackProvider).start();
      unawaited(ref.read(offlinePackProvider).refresh());
    });
    session.addSignOutHook((_) async {
      await ref.read(syncServiceProvider).flush();
      ref.read(syncServiceProvider).stop();
      ref.read(offlinePackProvider).stop();
      await push.unregister();
      await local.cancelAll();
      await ref.read(audioProvider.notifier).stop();
    });

    // A task changed offline that someone else changed meanwhile: the server copy wins; say so.
    ref.read(syncServiceProvider).onConflict(SyncOp.projectTaskUpdate, (payload, server) async {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(duration: const Duration(seconds: 6), content: Text(ctx.l10n.pmSyncConflict)));
    });

    _subs
      ..add(local.taps.listen(_openPayload))
      ..add(push.taps.listen((data) => _openPayload(_pushDataToPayload(data))))
      ..add(push.received.listen((_) => unawaited(ref.read(unreadCountProvider.notifier).refresh())))
      ..add(ref.read(syncServiceProvider).onFlushed.listen((_) => unawaited(ref.read(remindersProvider.notifier).pull())))
      // An offline change (attendance, borrowing…) the server refused when it was finally sent.
      ..add(ref.read(syncServiceProvider).onRejected.listen((r) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        final l = ctx.l10n;
        final what = switch (r.type) {
          SyncOp.attendanceSet ||
          SyncOp.attendanceRecord ||
          SyncOp.attendanceSessionStart ||
          SyncOp.attendanceSessionEnd ||
          SyncOp.attendanceClear ||
          SyncOp.attendanceBulk =>
            l.syncWhatAttendance,
          SyncOp.eduAttendanceSet || SyncOp.eduAttendanceScan => l.syncWhatClassAttendance,
          SyncOp.borrowingCreate => l.syncWhatBorrowing,
          SyncOp.borrowingReturn => l.syncWhatReturn,
          SyncOp.projectTaskUpdate => l.syncWhatTask,
          _ => l.syncWhatReminder,
        };
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(l.offlineChangeRejected(what, errorText(l, ApiException(code: r.code ?? ApiException.unknown)))),
        ));
      }))
      // Offline attendance the server could not apply as captured: kept for HR, never dropped.
      ..add(ref.read(syncServiceProvider).onHeldForReview.listen((r) {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(duration: const Duration(seconds: 6), content: Text(ctx.l10n.syncHeldForReview(ctx.l10n.syncWhatAttendance))));
      }));

    ref.listenManual(connectivityProvider, (prev, next) {
      if (next.value == true && prev?.value == false) {
        unawaited(ref.read(syncServiceProvider).flush().then((_) => ref.read(offlinePackProvider).refresh()));
        unawaited(_syncProgramAlarms());
        unawaited(ref.read(downloadsProvider.notifier).retryFailed());
        unawaited(ref.read(downloadsProvider.notifier).refreshStale().then((_) => ref.read(downloadsProvider.notifier).syncAllLyrics()));
      }
    });

    await _checkForUpdate();

    final launch = local.takeLaunchPayload();
    if (launch != null) Future.delayed(const Duration(milliseconds: 800), () => _openPayload(launch));
  }

  /// Alarms before every upcoming program visible to this user, at the program's reminder times
  /// or the member's own choice (general programs and the special events they are invited to).
  Future<void> _syncProgramAlarms() => ref.read(programAlarmSyncProvider).run();

  /// Version check: forced updates redirect (router); optional ones are offered once per version.
  Future<void> _checkForUpdate() async {
    final info = await ref.read(updateProvider.notifier).check();
    if (info == null || info.force || !info.available || info.latestCode == null) return;
    final prefs = ref.read(localPrefsProvider);
    if (prefs.dismissedUpdateCode >= info.latestCode!) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final l = ctx.l10n;
    final update = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text(l.updateAvailableTitle),
        content: Text([l.updateAvailableBody(info.latestName ?? ''), if (info.notes != null) info.notes!].join('\n\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.later)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.updateNow)),
        ],
      ),
    );
    if (update == true) {
      await ref.read(updateProvider.notifier).openDownloadPage();
    } else {
      await prefs.setDismissedUpdateCode(info.latestCode!);
    }
  }

  /// Apply account preferences that also have a device-level effect (language, theme).
  Future<void> _syncPreferences() async {
    try {
      final prefs = await ref.read(accountRepositoryProvider).preferences();
      final settings = ref.read(appSettingsProvider.notifier);
      if (prefs.language != ref.read(appSettingsProvider).locale.languageCode) await settings.setLocale(prefs.language);
      if (prefs.theme != 'system') await settings.setDark(prefs.theme == 'dark');
    } catch (_) {}
  }

  Future<void> _syncDailySinksar() async {
    try {
      final prefs = await ref.read(accountRepositoryProvider).notificationPreferences();
      final topics = asJsonList(prefs['topics']);
      final sinksarTopic = topics.firstWhere(
        (t) => t['topic'] == 'sinksar',
        orElse: () => const {'push': true},
      );
      final enabled = prefs['enabled'] != false && sinksarTopic['push'] == true;

      final today = await ref.read(sinksarRepositoryProvider).today();
      final feastTitle = today.featuredTitle.isNotEmpty ? today.featuredTitle : 'የዕለቱ ስንክሳር';
      final feastBody = today.formattedFull;

      await ref.read(localNotificationsProvider).scheduleDailySinksarNotification(
        enabled: enabled,
        title: feastTitle,
        body: 'የዕለቱ ስንክሳር እና መታሰቢያ: $feastBody',
        payload: 'sinksar:${today.gregorianDate}',
      );
    } catch (e) {
      debugPrint('Sync daily sinksar failed: $e');
    }
  }

  void _openPayload(String payload) {
    if (payload.trim().isEmpty) return;

    // Prevent duplicate navigation when same notification is tapped repeatedly or dispatched twice
    final now = DateTime.now();
    if (_lastPayload == payload &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 1200) {
      return;
    }
    _lastPayload = payload;
    _lastTapTime = now;

    if (ref.read(sessionProvider) is! SignedIn) {
      _pendingPayload = payload;
      return;
    }
    final target = parsePayload(payload);
    if (target.notificationId != null) {
      unawaited(ref.read(localNotificationsProvider).dismissMessage(target.notificationId!));
      unawaited(ref.read(notificationRepositoryProvider).markRead(target.notificationId!).then((_) => ref.read(unreadCountProvider.notifier).refresh()).catchError((_) {}));
    }
    try {
      ref.read(routerProvider).push(target.route);
    } catch (_) {
      ref.read(routerProvider).go(target.route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(updateProvider.notifier).check());
      // Returning from Telegram after linking: refresh the profile to show the new status.
      if (ref.read(sessionProvider) is SignedIn) unawaited(ref.read(sessionProvider.notifier).refreshUser());
      unawaited(ref.read(syncServiceProvider).flush());
      unawaited(ref.read(unreadCountProvider.notifier).refresh());
      if (ref.read(sessionProvider) is SignedIn) unawaited(_syncProgramAlarms());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationGate(child: widget.child);
}
