import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/network/api_exception.dart';
import '../core/providers.dart';
import '../models/activity.dart';
import '../models/json.dart';
import 'local_notifications.dart';
import 'sync_service.dart';

/// Personal reminders: stored locally, scheduled as device notifications (work offline),
/// and synchronised with the server through the sync queue.
class ReminderController extends Notifier<List<Reminder>> {
  String channelName = 'Reminders';

  @override
  List<Reminder> build() {
    final sync = ref.read(syncServiceProvider);
    // Server copy wins on conflict: replace the local reminder and reschedule it.
    sync.onConflict(SyncOp.reminderUpdate, (payload, server) async {
      if (server is Map) await _applyServer(asJson(server));
    });
    unawaited(_load());
    return const [];
  }

  Database get _db => ref.read(localDbProvider).db;
  LocalNotifications get _notifier => ref.read(localNotificationsProvider);

  Future<void> _load() async {
    final rows = await _db.query('reminders', where: 'deleted = 0', orderBy: 'remind_at');
    state = rows.map(Reminder.fromRow).toList();
  }

  Future<void> _save(Reminder r) async {
    await _db.insert('reminders', r.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _notifier.schedule(r, channelName: channelName);
    await _load();
  }

  Reminder? forProgram(int programId) => state.where((r) => r.programId == programId).firstOrNull;

  Future<Reminder> create({required String title, String? note, required DateTime remindAt, String repeat = 'none', int? programId, int? borrowingId}) async {
    final r = Reminder(
      clientUuid: const Uuid().v4(),
      programId: programId,
      borrowingId: borrowingId,
      title: title,
      note: note,
      remindAt: DateTime.fromMillisecondsSinceEpoch(remindAt.millisecondsSinceEpoch ~/ 1000 * 1000),
      repeat: repeat,
      notificationId: Random().nextInt(1 << 30),
      updatedAt: DateTime.now(),
    );
    await _save(r);
    await ref.read(syncServiceProvider).enqueue(SyncOp.reminderCreate, r.toApi());
    return r;
  }

  Future<void> update(Reminder r, {String? title, String? note, DateTime? remindAt, String? repeat, bool? isEnabled}) async {
    final base = r.updatedAt;
    final next = r.copyWith(title: title, note: note, remindAt: remindAt, repeat: repeat, isEnabled: isEnabled, updatedAt: DateTime.now());
    await _save(next);
    await ref.read(syncServiceProvider).enqueue(SyncOp.reminderUpdate, {
      'client_uuid': r.clientUuid,
      'title': next.title,
      'note': next.note,
      'remind_at': next.remindAt.toUtc().toIso8601String(),
      'repeat': next.repeat,
      'is_enabled': next.isEnabled,
      if (base != null) 'base_updated_at': base.toUtc().toIso8601String(),
    });
  }

  Future<void> delete(Reminder r) async {
    await _notifier.cancel(r.notificationId);
    await _db.update('reminders', {'deleted': 1}, where: 'client_uuid = ?', whereArgs: [r.clientUuid]);
    await _load();
    await ref.read(syncServiceProvider).enqueue(SyncOp.reminderDelete, {'client_uuid': r.clientUuid});
  }

  Future<void> _applyServer(Json s) async {
    final uuid = s['client_uuid'] as String;
    final existing = await _db.query('reminders', where: 'client_uuid = ?', whereArgs: [uuid], limit: 1);
    final notificationId = existing.isNotEmpty ? existing.first['notification_id'] as int : Random().nextInt(1 << 30);
    final r = Reminder(
      clientUuid: uuid,
      serverId: asInt(s['id']),
      programId: asInt(s['program_id']),
      borrowingId: asInt(s['borrowing_id']),
      title: asStr(s['title']) ?? '',
      note: asStr(s['note']),
      remindAt: asDate(s['remind_at']) ?? DateTime.now(),
      repeat: asStr(s['repeat']) ?? 'none',
      isEnabled: asBool(s['is_enabled']),
      updatedAt: asDate(s['updated_at']),
      deleted: asBool(s['deleted']),
      notificationId: notificationId,
    );
    if (r.deleted) {
      await _notifier.cancel(notificationId);
      await _db.delete('reminders', where: 'client_uuid = ?', whereArgs: [uuid]);
      await _load();
    } else {
      await _save(r);
    }
  }

  /// Pull server-side changes (other installs, conflicts) since the last sync.
  Future<void> pull() async {
    final prefs = ref.read(localPrefsProvider);
    final pending = await _db.query('sync_queue', where: 'type LIKE ?', whereArgs: ['reminder.%'], limit: 1);
    if (pending.isNotEmpty) return; // push first; pull after the queue drains
    try {
      final since = prefs.remindersSyncedAt;
      final list = await ref.read(apiClientProvider).get<List<dynamic>>('/reminders', query: {'since': since?.toUtc().toIso8601String()});
      for (final s in list) {
        await _applyServer(asJson(s));
      }
      await prefs.setRemindersSyncedAt(DateTime.now());
    } on ApiException {
      // offline — keep local state
    }
  }

  /// Re-arm every local notification (after reboot/app update/sign-in).
  Future<void> rescheduleAll() async {
    // Read the stored reminders first: right after start-up [state] may not be loaded yet.
    await _load();
    for (final r in state) {
      // Old personal reminders for programs are replaced by the program's own reminders
      // (2 days / 1 day / 6 hours / 1 hour, chosen on each program): they no longer ring.
      if (r.programId != null) {
        await _notifier.cancel(r.notificationId);
        continue;
      }
      await _notifier.schedule(r, channelName: channelName);
    }
  }
}

final remindersProvider = NotifierProvider<ReminderController, List<Reminder>>(ReminderController.new);
