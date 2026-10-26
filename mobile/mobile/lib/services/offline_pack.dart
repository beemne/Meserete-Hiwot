import 'dart:async';
import 'dart:convert';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/providers.dart';
import '../features/auth/session.dart';
import '../models/json.dart';
import '../repositories/providers.dart';
import 'download_service.dart';
import 'preferences_service.dart';
import 'sync_service.dart';

/// Offline copies kept in the phone's SQLite database, refreshed from the server whenever the phone
/// is online (sign-in, coming back online, every 30 minutes) and used when it is not:
///  - everyone: their own member card + QR (so the QR shows without a connection) and the featured
///    Mezmurs (saved like a download);
///  - attendance takers / borrowing staff: the member directory (QR id, name, photo, member ID,
///    type), the programs they may take attendance for with their sessions and recorded marks, the
///    lendable items. A QR scan, the eligibility check and "already recorded" then work offline;
///    marks / borrowings wait in the sync queue and the server checks them again when they are sent.
class OfflinePackService {
  OfflinePackService(this._ref);
  final Ref _ref;
  Timer? _timer;
  Future<void>? _running;

  Database get _db => _ref.read(localDbProvider).db;

  void start() => _timer ??= Timer.periodic(const Duration(minutes: 30), (_) => unawaited(refresh()));

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Download everything again (concurrent callers share one run). Silent on failure.
  Future<void> refresh() {
    if (_running != null) return _running!;
    if (_ref.read(sessionProvider) is! SignedIn || !_ref.read(isOnlineProvider)) return Future.value();
    return _running = _refresh().whenComplete(() => _running = null);
  }

  Future<void> _refresh() async {
    final local = _ref.read(localDbProvider);
    try {
      final card = await _ref.read(orgRepositoryProvider).myCard();
      await local.putCache('pack:my_card', card);
      final avatar = asStr(card['avatar_url']);
      if (avatar != null) unawaited(_prefetch([avatar]));
    } catch (e) {
      debugPrint('offline pack: card failed: $e');
    }
    try {
      final pack = await _ref.read(apiClientProvider).get<Json>('/offline/pack', parse: asJson);
      await _store(pack);
    } catch (e) {
      debugPrint('offline pack failed: $e');
    }
    unawaited(_featured());
  }

  Future<void> _store(Json pack) async {
    final local = _ref.read(localDbProvider);
    final members = asJsonList(pack['members']);
    await _db.transaction((tx) async {
      await tx.delete('directory');
      final batch = tx.batch();
      for (final m in members) {
        batch.insert('directory', {
          'id': asIntOr(m['id']),
          'uuid': asStr(m['uuid']) ?? '',
          'full_name': asStr(m['full_name']) ?? '',
          'member_id': asStr(m['member_id']),
          'member_group': asStr(m['member_group']),
          'json': jsonEncode(m),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    await local.putCache('pack:programs', pack['programs'] ?? const []);
    await local.putCache('pack:marks', pack['marks'] ?? const []);
    await local.putCache('pack:items', pack['items'] ?? const []);
    await local.putCache('pack:meta', {'generated_at': pack['generated_at'], 'signature_policy': pack['signature_policy'], 'roles': pack['roles'], 'me': pack['me']});
    // Photos for checking faces offline (already cached ones are skipped by the cache manager).
    unawaited(_prefetch([for (final m in members) ?asStr(m['avatar_url'])]));
  }

  Future<void> _prefetch(List<String> urls) async {
    final cache = DefaultCacheManager();
    for (final u in urls) {
      if (!_ref.read(isOnlineProvider)) return;
      try {
        if (await cache.getFileFromCache(u) == null) await cache.downloadFile(u);
      } catch (_) {
        // a missing photo only means the initials are shown
      }
    }
  }

  /// Featured Mezmurs are kept on the phone like downloads (audio per the "download audio" /
  /// "Wi-Fi only" settings).
  Future<void> _featured() async {
    try {
      final page = await _ref.read(contentRepositoryProvider).mezmurs(featured: true);
      await _ref.read(downloadsProvider.notifier).downloadAll(page.items, withAudio: _ref.read(preferencesProvider).downloadAudio);
    } catch (e) {
      debugPrint('offline featured: $e');
    }
  }

  // ---------------------------------------------------------------- reads (offline-safe)
  Future<Json?> myCard() async {
    final c = await _ref.read(localDbProvider).getCache('pack:my_card');
    return c is Map ? asJson(c) : null;
  }

  Future<Json?> memberByUuid(String uuid) async {
    final rows = await _db.query('directory', where: 'uuid = ?', whereArgs: [uuid.toLowerCase()], limit: 1);
    return rows.isEmpty ? null : asJson(jsonDecode(rows.first['json'] as String));
  }

  Future<Json?> memberById(int id) async {
    final rows = await _db.query('directory', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : asJson(jsonDecode(rows.first['json'] as String));
  }

  /// Name / member ID search in the offline directory.
  Future<List<Json>> searchMembers(String q, {int limit = 50}) async {
    final t = q.trim();
    final rows = await _db.query(
      'directory',
      where: t.isEmpty ? null : 'full_name LIKE ? OR member_id LIKE ?',
      whereArgs: t.isEmpty ? null : ['%$t%', '%$t%'],
      orderBy: 'full_name',
      limit: limit,
    );
    return [for (final r in rows) asJson(jsonDecode(r['json'] as String))];
  }

  Future<int> memberCount() async => Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM directory')) ?? 0;

  Future<List<Json>> programs() async => asJsonList(await _ref.read(localDbProvider).getCache('pack:programs'));
  Future<List<Json>> items() async => asJsonList(await _ref.read(localDbProvider).getCache('pack:items'));

  Future<Json?> program(int id) async {
    for (final p in await programs()) {
      if (asIntOr(p['id']) == id) return p;
    }
    return null;
  }

  /// When the pack was made (null = never downloaded on this phone).
  Future<String?> generatedAt() async => asStr(asJson(await _ref.read(localDbProvider).getCache('pack:meta'))['generated_at']);

  Future<Json> _meta() async => asJson(await _ref.read(localDbProvider).getCache('pack:meta'));

  /// HR assigned this account to take attendance (or it holds attendance control) — from the last pack.
  Future<bool> takesAttendance() async => asJson((await _meta())['roles'])['attendance'] == true;

  /// Member groups HR exempted from signing attendance (from the last pack).
  Future<List<String>> signatureExemptGroups() async => asValues(asJson((await _meta())['signature_policy'])['exempt_groups'], (e) => '$e');

  // ---------------------------------------------------------------- attendance sessions offline
  // The pack carries each occurrence's session as the server knew it. Start / End pressed on this
  // phone while offline are kept here (and queued) so the phone keeps working; the server applies
  // them at their capture time when they sync, or hands them to HR if it cannot.

  Future<Json?> localSession(int programId, String date) async {
    final v = await _ref.read(localDbProvider).getCache('att_session:$programId:$date');
    return v is Map && v.isNotEmpty ? asJson(v) : null;
  }

  Future<void> saveLocalSession(int programId, String date, Json session) =>
      _ref.read(localDbProvider).putCache('att_session:$programId:$date', session);

  /// The server has the phone's offline Start / End now: its own copy is enough.
  Future<void> clearLocalSession(int programId, String date) => _ref.read(localDbProvider).putCache('att_session:$programId:$date', const <String, dynamic>{});

  /// The occurrence's session as this phone knows it: the pack's copy with this phone's own offline
  /// Start / End on top.
  Future<Json?> session(int programId, String date) async {
    final p = await program(programId);
    final occ = asJsonList(p?['occurrences']).where((o) => o['date'] == date).firstOrNull;
    return mergeSession(occ == null ? null : asJson(occ['session']), await localSession(programId, date));
  }

  /// The same answer as GET /programs/{id}/attendance/check, from the offline copies: who the member
  /// is and whether they may be recorded now. [myId] = the taker (nobody records themselves).
  Future<Json> check({required int programId, required String? date, String? uuid, int? userId, required int myId, DateTime? now}) async {
    now ??= DateTime.now();
    final member = uuid != null ? await memberByUuid(uuid) : (userId != null ? await memberById(userId) : null);
    final p = await program(programId);
    final sync = _ref.read(syncServiceProvider);
    final pending = [...await sync.pending(SyncOp.attendanceRecord), ...await sync.pending(SyncOp.attendanceSet)];
    final marks = asJsonList(await _ref.read(localDbProvider).getCache('pack:marks'));
    final d = date ?? pickOccurrenceDate(p, now);
    final local = d == null ? null : await localSession(programId, d);
    return offlineAttendanceCheck(
      program: p,
      member: member,
      date: d,
      myId: myId,
      now: now,
      marks: marks,
      pending: pending,
      localSession: local,
      exemptGroups: await signatureExemptGroups(),
    );
  }
}

/// The occurrence a check without a date is about: today's (or the latest past one).
String? pickOccurrenceDate(Json? program, DateTime now) {
  final occurrences = asJsonList(program?['occurrences']);
  final today = _iso(now);
  final past = occurrences.where((o) => (asStr(o['date']) ?? '').compareTo(today) <= 0).toList();
  return asStr((past.isNotEmpty ? past.last : occurrences.firstOrNull)?['date']);
}

/// The server's session with this phone's offline Start / End applied on top (the phone's own
/// actions are newer than the pack it downloaded).
Json? mergeSession(Json? server, Json? local) {
  if (local == null) return server;
  final s = {...?server};
  final rank = {'scheduled': 0, 'active': 1, 'ended': 2, 'cancelled': 3};
  if ((rank[local['status']] ?? 0) > (rank[s['status']] ?? 0)) {
    s['status'] = local['status'];
    if (s['started_at'] == null && local['started_at'] != null) {
      s['started_at'] = local['started_at'];
      s['start_source'] = 'offline';
    }
    if (local['ended_at'] != null) s['ended_at'] = local['ended_at'];
  }
  s['client_uuid'] ??= local['client_uuid'];
  s['local'] = true;
  return s;
}

/// Pure eligibility rules for an offline check (mirrors the server's identify step): only the
/// session's assigned taker records, only after Start and before End / the scheduled end.
Json offlineAttendanceCheck({
  required Json? program,
  required Json? member,
  required String? date,
  required int myId,
  required DateTime now,
  required List<Json> marks,
  required List<Json> pending,
  Json? localSession,
  List<String> exemptGroups = const [],
}) {
  if (member == null) return {'eligible': false, 'reason': 'MEMBER_NOT_FOUND', 'offline': true};
  if (program == null) return {'member': member, 'eligible': false, 'reason': 'PROGRAM_NOT_FOUND', 'offline': true};
  final uid = asIntOr(member['id']);
  final occurrences = asJsonList(program['occurrences']);
  final today = _iso(now);
  final d = date ?? pickOccurrenceDate(program, now) ?? today;
  final occ = occurrences.where((o) => o['date'] == d).firstOrNull;
  final session = mergeSession(occ == null ? null : asJson(occ['session']), localSession);
  final ends = DateTime.tryParse(asStr(occ?['ends_at']) ?? '');
  final closedAt = DateTime.tryParse(asStr(occ?['closed_at']) ?? '');
  final endedAt = DateTime.tryParse(asStr(session?['ended_at']) ?? '');
  final closed = (ends != null && !ends.isAfter(now)) ||
      (closedAt != null && !closedAt.isAfter(now)) ||
      (endedAt != null && !endedAt.isAfter(now)) ||
      session?['status'] == 'ended';
  final groups = asValues(program['member_groups'], (e) => '$e');
  final participants = program['participant_ids'] == null ? null : asValues(program['participant_ids'], (e) => asIntOr(e));
  final recorded = [
    ...marks.where((m) => asIntOr(m['program_id']) == asIntOr(program['id']) && m['date'] == d && asIntOr(m['user_id']) == uid),
    ...pending.where((m) => asIntOr(m['program_id']) == asIntOr(program['id']) && m['date'] == d && asIntOr(m['user_id']) == uid).map((m) => {...m, 'pending': true}),
  ];
  final existing = recorded.where((m) => m['status'] == 'present' || m['status'] == 'late').firstOrNull;
  final takerId = session?['taker_id'] == null ? null : asIntOr(session!['taker_id']);
  String? reason;
  if (occ == null || occ['cancelled'] == true) {
    reason = 'ATTENDANCE_NOT_ACTIVE';
  } else if (takerId == null) {
    reason = 'NO_ATTENDANCE_TAKERS_ASSIGNED';
  } else if (takerId != myId) {
    reason = 'NOT_SESSION_TAKER';
  } else if (closed) {
    reason = 'ATTENDANCE_CLOSED';
  } else if (session?['started_at'] == null) {
    reason = 'SESSION_NOT_STARTED';
  } else if (uid == myId) {
    reason = 'SELF_ATTENDANCE_NOT_ALLOWED';
  } else if (groups.isNotEmpty && !groups.contains(member['member_group'])) {
    reason = 'MEMBER_NOT_IN_GROUP';
  } else if ((member['membership_status'] ?? 'active') != 'active' ||
      (participants != null && !participants.contains(uid)) ||
      (participants == null && (asStr(member['joined_on']) ?? '').compareTo(d) > 0)) {
    reason = 'MEMBER_NOT_EXPECTED';
  } else if (existing != null) {
    reason = 'ATTENDANCE_ALREADY_RECORDED';
  }
  return {
    'member': member,
    'program': {'id': program['id'], 'title': program['title'], 'member_groups': groups},
    'occurrence': {'date': d, 'starts_at': occ?['starts_at'], 'ends_at': occ?['ends_at'], 'closed': closed},
    'session': session,
    'eligible': reason == null,
    'reason': reason,
    'attendance': existing == null ? null : {...existing, 'status': existing['status'] == 'late' ? 'present' : existing['status']},
    'would_record': reason == null ? 'present' : null,
    'signature_required': !exemptGroups.contains(member['member_group']),
    'offline': true,
  };
}

String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Shows the "Take attendance" entry to assigned takers who have no admin panel.
final takesAttendanceProvider = FutureProvider.autoDispose<bool>((ref) => ref.watch(offlinePackProvider).takesAttendance());

final offlinePackProvider = Provider<OfflinePackService>((ref) {
  final s = OfflinePackService(ref);
  ref.onDispose(s.stop);
  return s;
});
