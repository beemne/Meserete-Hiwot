import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/network/api_exception.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/local_db.dart';
import 'package:mezmur_zelideta/core/storage/local_prefs.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

class _MemoryCache implements ResponseCache {
  final data = <String, Object?>{};
  @override
  Future<Object?> get(String key) async => data[key];
  @override
  Future<void> put(String key, Object? body) async => data[key] = body;
}

class _TestSession extends SessionController {
  _TestSession(this._user);
  final AppUser _user;
  @override
  SessionState build() => SignedIn(_user);
}

final _online = StateProvider<bool>((_) => true);

DioException _drop(RequestOptions r) => DioException(requestOptions: r, type: DioExceptionType.connectionError);

Future<(ApiClient, FakeAdapter)> _api(Map<String, dynamic>? Function(RequestOptions r) handler) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  final adapter = FakeAdapter((r) {
    final b = handler(r);
    if (b == null) throw _drop(r);
    return (status: 200, body: b);
  });
  final api = ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter)
    ..cache = _MemoryCache()
    ..retryDelays = const [Duration.zero, Duration.zero];
  return (api, adapter);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('flaky connection', () {
    test('a dropped connection is retried instead of failing', () async {
      var calls = 0;
      final (api, adapter) = await _api((r) => ++calls < 2 ? null : ok({'n': 1}));
      expect(await api.get<Map<String, dynamic>>('/programs/1', parse: (d) => (d as Map).cast()), {'n': 1});
      expect(adapter.requests, hasLength(2));
    });

    test('offline: the last good copy is shown, not a timeout error', () async {
      var down = false;
      final (api, _) = await _api((r) => down ? null : ok([
            {'id': 1, 'title': 'ሰንበት'},
          ]));
      final fresh = await api.getPage('/borrowings/me', (j) => j);
      expect(fresh.meta['offline'], isNull);
      down = true;
      final cached = await api.getPage('/borrowings/me', (j) => j);
      expect(cached.items.single['title'], 'ሰንበት');
      expect(cached.meta['offline'], isTrue);
    });

    test('with nothing cached the network error is still reported', () async {
      final (api, _) = await _api((r) => null);
      expect(() => api.get<Object?>('/programs/5'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)));
    });

    test('delta endpoints (?since=) are never answered from an old copy', () async {
      var down = false;
      final (api, _) = await _api((r) => down ? null : ok(<Object>[]));
      await api.get<Object?>('/reminders', query: {'since': 'x'});
      down = true;
      expect(() => api.get<Object?>('/reminders', query: {'since': 'x'}), throwsA(isA<ApiException>()));
    });
  });

  group('staff work offline (sync queue)', () {
    Future<ProviderContainer> container(FakeAdapter adapter, {required bool online, AppUser? user, LocalDb? existingDb}) async {
      FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1', 'token_scope': 'app', 'device_id': 'd'});
      SharedPreferences.setMockInitialValues({});
      final store = SecureStore();
      await store.load();
      final db = existingDb ?? await LocalDb.open(path: inMemoryDatabasePath);
      if (existingDb == null) {
        await db.db.delete('sync_queue');
      }
      final prefs = await LocalPrefs.load();
      final api = ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
      final testUser = user ?? const AppUser(id: 9, fullName: 'Admin', phone: '+251911000000', accountType: 'admin');
      return ProviderContainer(overrides: [
        secureStoreProvider.overrideWithValue(store),
        localDbProvider.overrideWithValue(db),
        localPrefsProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
        _online.overrideWith((_) => online),
        isOnlineProvider.overrideWith((ref) => ref.watch(_online)),
        sessionProvider.overrideWith(() => _TestSession(testUser)),
      ]);
    }

    Map<String, dynamic> results(RequestOptions r, String status, {String? code}) => ok({
          'results': [
            for (final op in (body(r)['operations'] as List)) {'op_id': (op as Map)['op_id'], 'status': status, 'code': ?code, 'server': {'id': 44}},
          ],
        });

    test('online: an attendance mark is applied at once', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'applied')));
      final c = await container(adapter, online: true);
      final sync = c.read(syncServiceProvider);
      final out = await sync.submit(SyncOp.attendanceSet, {'program_id': 1, 'user_id': 2, 'status': 'present', 'date': '2026-09-28'});
      expect(out.applied, isTrue);
      expect(await sync.pendingCount(), 0);
    });

    test('offline: the mark is kept on the phone and sent when back online', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'applied')));
      final c = await container(adapter, online: false);
      final sync = c.read(syncServiceProvider);
      final out = await sync.submit(SyncOp.borrowingCreate, {'user_id': 2, 'item_id': 3, 'quantity': 1});
      expect(out.queued, isTrue);
      expect(await sync.pending(SyncOp.borrowingCreate), hasLength(1));
      expect(adapter.requests, isEmpty);
      c.read(_online.notifier).state = true;
      await sync.flush();
      expect(await sync.pendingCount(), 0);
      expect(adapter.requests.single.path, '/sync');
    });

    test('only changes the person made are reported when refused later; background ops stay silent', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'rejected', code: 'MEZMUR_NOT_FOUND')));
      final c = await container(adapter, online: false);
      final sync = c.read(syncServiceProvider);
      final seen = <String>[];
      final sub = sync.onRejected.listen((r) => seen.add(r.type));
      await sync.enqueue(SyncOp.activity, {'action': 'audio_play'});
      await sync.enqueue(SyncOp.favoriteAdd, {'mezmur_id': 9});
      await sync.enqueue(SyncOp.attendanceSet, {'program_id': 1, 'user_id': 2, 'status': 'present', 'date': '2026-09-28'});
      c.read(_online.notifier).state = true;
      await sync.flush();
      await Future<void>.delayed(Duration.zero);
      expect(seen, [SyncOp.attendanceSet]);
      expect(await sync.pendingCount(), 0);
      await sub.cancel();
    });

    test('a signed offline attendance record is kept encrypted on the phone and sent with the phone clock', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'applied')));
      final c = await container(adapter, online: false);
      final sync = c.read(syncServiceProvider);
      const sig = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
      await sync.submit(SyncOp.attendanceSessionStart, {'program_id': 1, 'date': '2026-10-05', 'session_uuid': '6f1c2b8e-4a39-4c0e-9c64-1b2f3e4d5a6b'});
      final out = await sync.submit(SyncOp.attendanceRecord, {'program_id': 1, 'user_id': 2, 'status': 'present', 'date': '2026-10-05', 'via': 'qr', 'signature': sig});
      expect(out.queued, isTrue);
      // At rest: no signature (or member) readable in the queue table…
      final raw = (await c.read(localDbProvider).db.query('sync_queue', where: 'type = ?', whereArgs: [SyncOp.attendanceRecord])).single['payload'] as String;
      expect(raw, isNot(contains('data:image')));
      expect(raw, contains('_sealed'));
      // …but the app reads it back (roster / offline check) and the server gets it whole.
      expect((await sync.pending(SyncOp.attendanceRecord)).single['signature'], sig);
      c.read(_online.notifier).state = true;
      await sync.flush();
      final sent = body(adapter.requests.single);
      expect(sent['client_now'], isA<String>());
      final ops = (sent['operations'] as List).cast<Map>();
      expect(ops.map((o) => o['type']), [SyncOp.attendanceSessionStart, SyncOp.attendanceRecord]);
      expect((ops[1]['payload'] as Map)['signature'], sig);
      expect(ops[1]['client_ts'], isA<String>());
      expect(await sync.pendingCount(), 0);
    });

    test('offline attendance the server cannot apply is reported as sent to HR (not as lost)', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'conflict')));
      final c = await container(adapter, online: false);
      final sync = c.read(syncServiceProvider);
      final held = <String>[];
      final rejected = <String>[];
      final s1 = sync.onHeldForReview.listen((h) => held.add(h.type));
      final s2 = sync.onRejected.listen((r) => rejected.add(r.type));
      await sync.enqueue(SyncOp.attendanceRecord, {'program_id': 1, 'user_id': 2, 'status': 'present', 'date': '2026-10-05'});
      c.read(_online.notifier).state = true;
      await sync.flush();
      await Future<void>.delayed(Duration.zero);
      expect(held, [SyncOp.attendanceRecord]);
      expect(rejected, isEmpty);
      await s1.cancel();
      await s2.cancel();
    });

    test('a refused op is reported, not retried forever', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'rejected', code: 'ATTENDANCE_NOT_ACTIVE')));
      final c = await container(adapter, online: true);
      final out = await c.read(syncServiceProvider).submit(SyncOp.attendanceSet, {'program_id': 1, 'user_id': 2, 'status': 'late', 'date': '2026-09-28'});
      expect(out.rejected, isTrue);
      expect(out.code, 'ATTENDANCE_NOT_ACTIVE');
      expect(await c.read(syncServiceProvider).pendingCount(), 0);
    });

    test('F0a: queued offline records are tagged with user_id and survive normal logout and expire', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'applied')));
      final c = await container(adapter, online: false, user: const AppUser(id: 42, fullName: 'Taker', phone: '+251911111111', accountType: 'staff'));
      final sync = c.read(syncServiceProvider);
      final db = c.read(localDbProvider);

      await sync.submit(SyncOp.attendanceRecord, {'program_id': 1, 'user_id': 2, 'status': 'present', 'date': '2026-10-16'});
      expect(await sync.pendingCount(), 1);

      // Verify row in SQLite is tagged with user_id = 42
      final raw = await db.db.query('sync_queue');
      expect(raw.single['user_id'], 42);

      // Logout without discard preserves the queue
      await c.read(sessionProvider.notifier).logout(discard: false);
      expect((await db.db.query('sync_queue')).length, 1);

      // Expire preserves the queue
      await c.read(sessionProvider.notifier).expire();
      expect((await db.db.query('sync_queue')).length, 1);
    });

    test('F0a: explicit discard deletes only the leaving user rows and keeps other users rows', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'applied')));
      final c = await container(adapter, online: false, user: const AppUser(id: 42, fullName: 'Taker', phone: '+251911111111', accountType: 'staff'));
      final sync = c.read(syncServiceProvider);
      final db = c.read(localDbProvider);

      await sync.submit(SyncOp.attendanceRecord, {'program_id': 1, 'user_id': 2, 'status': 'present', 'date': '2026-10-16'});

      // Another user's row already in the queue
      await db.db.insert('sync_queue', {
        'op_id': 'other-user-op-1',
        'user_id': 99,
        'type': SyncOp.attendanceRecord,
        'payload': '{"test": true}',
        'client_ts': DateTime.now().toUtc().toIso8601String(),
      });
      expect(await sync.pendingCount(userId: 42), 1);
      expect((await db.db.query('sync_queue')).length, 2);

      // Logout with discard = true deletes only user 42's rows
      await c.read(sessionProvider.notifier).logout(discard: true);
      final remaining = await db.db.query('sync_queue');
      expect(remaining.length, 1);
      expect(remaining.single['user_id'], 99);
    });

    test('F0a: a different user sign-in never sends or shows the first user pending queue', () async {
      final adapter = FakeAdapter((r) => (status: 200, body: results(r, 'applied')));
      final localDb = await LocalDb.open(path: inMemoryDatabasePath);
      await localDb.db.delete('sync_queue');

      // Taker 42 queues an offline attendance record
      final c1 = await container(adapter, online: false, user: const AppUser(id: 42, fullName: 'Taker 42', phone: '+251911111111', accountType: 'staff'), existingDb: localDb);
      await c1.read(syncServiceProvider).submit(SyncOp.attendanceRecord, {'program_id': 1, 'user_id': 2, 'status': 'present', 'date': '2026-10-16'});
      expect(await c1.read(syncServiceProvider).pendingCount(), 1);
      await c1.read(sessionProvider.notifier).logout(discard: false);

      // Different user 84 signs in on the same phone
      final c2 = await container(adapter, online: true, user: const AppUser(id: 84, fullName: 'User 84', phone: '+251922222222', accountType: 'member'), existingDb: localDb);
      final sync2 = c2.read(syncServiceProvider);

      // User 84 sees 0 pending operations
      expect(await sync2.pendingCount(), 0);
      expect(await sync2.pending(SyncOp.attendanceRecord), isEmpty);

      // Flush while User 84 is active sends nothing to /sync
      adapter.requests.clear();
      await sync2.flush();
      expect(adapter.requests, isEmpty);

      // Original user 42 signs in again and flushes
      final c3 = await container(adapter, online: true, user: const AppUser(id: 42, fullName: 'Taker 42', phone: '+251911111111', accountType: 'staff'), existingDb: localDb);
      final sync3 = c3.read(syncServiceProvider);
      expect(await sync3.pendingCount(), 1);
      await sync3.flush();
      expect(adapter.requests.where((r) => r.path == '/sync'), hasLength(1));
      expect(await sync3.pendingCount(), 0);
    });
  });
}
