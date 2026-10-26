import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/local_notifications.dart';
import '../widgets/brand.dart';

/// Notifications are required: program alarms, attendance and approvals all arrive that way.
/// Until the phone allows them, the app shows only this request.
class NotificationGate extends ConsumerStatefulWidget {
  const NotificationGate({super.key, required this.child});
  final Widget child;

  static const _channel = MethodChannel('mezmur/settings');

  /// Opens this app's notification settings (Android), for when the permission was refused for good.
  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } catch (_) {}
  }

  @override
  ConsumerState<NotificationGate> createState() => _NotificationGateState();
}

class _NotificationGateState extends ConsumerState<NotificationGate> with WidgetsBindingObserver {
  bool? _allowed; // null = not checked yet (show the app meanwhile)
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check(ask: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system settings: re-check.
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check({bool ask = false}) async {
    if (!Platform.isAndroid && !Platform.isIOS) return setState(() => _allowed = true);
    final local = ref.read(localNotificationsProvider);
    var ok = await local.notificationsEnabled();
    if (!ok && ask && !_asked) {
      _asked = true;
      ok = await local.requestPermission();
    }
    if (mounted) setState(() => _allowed = ok);
  }

  Future<void> _allow() async {
    final ok = await ref.read(localNotificationsProvider).requestPermission();
    if (ok) {
      if (mounted) setState(() => _allowed = true);
      return;
    }
    // Refused before ("don't ask again"): only the system settings can turn them on.
    await NotificationGate.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed != false) return widget.child;
    final l = context.l10n;
    final p = context.palette;
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const AppLogo(size: 84),
                const SizedBox(height: 24),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_active_rounded, size: 40, color: AppColors.maroon),
                ),
                const SizedBox(height: 20),
                Text(l.notifGateTitle, textAlign: TextAlign.center, style: context.serif(22)),
                const SizedBox(height: 10),
                Text(l.notifGateBody, textAlign: TextAlign.center, style: context.sans(14, color: p.muted, height: 1.6)),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(onPressed: _allow, icon: const Icon(Icons.notifications_rounded), label: Text(l.notifGateAllow)),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: NotificationGate.openSettings, child: Text(l.notifGateOpenSettings)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
