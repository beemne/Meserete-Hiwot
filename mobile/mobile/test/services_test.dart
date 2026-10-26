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
import 'package:mezmur_zelideta/models/content.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/services/favorites_service.dart';
import 'package:mezmur_zelideta/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

class _SignedInSession extends SessionController {
  @override
  SessionState build() => const SignedIn(AppUser(id: 1, fullName: 'ሙከራ', phone: '+251911223344'));
}

/// Test-controlled connectivity.
final _online = StateProvider<bool>((_) => true);

Future<ProviderContainer> _container(FakeAdapter adapter, {bool online = true}) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1', 'token_scope': 'app', 'device_id': 'android-test-device'});
  SharedPreferences.setMockInitialValues({});
  final store = SecureStore();
  await store.load();
  final db = await LocalDb.open(path: inMemoryDatabasePath);
  final prefs = await LocalPrefs.load();
  final api = ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
  return ProviderContainer(overrides: [
    secureStoreProvider.overrideWithValue(store),
    localDbProvider.overrideWithValue(db),
    localPrefsProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(api),
    _online.overrideWith((_) => online),
    isOnlineProvider.overrideWith((ref) => ref.watch(_online)),
    sessionProvider.overrideWith(_SignedInSession.new),
  ]);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ApiClient', () {
    test('refreshes an expired access token once and retries the request', () async {
      var calls = 0;
      final adapter = FakeAdapter((r) {
        if (r.path == '/auth/refresh') return (status: 200, body: ok({'access_token': 'a2', 'refresh_token': 'r2'}));
        calls++;
        if (r.headers['Authorization'] == 'Bearer a1') return (status: 401, body: failBody('TOKEN_EXPIRED'));
        return (status: 200, body: ok({'hello': 'ok'}));
      });
      final c = await _container(adapter);
      final res = await c.read(apiClientProvider).get<Map<String, dynamic>>('/me', parse: (d) => (d as Map).cast());
      expect(res['hello'], 'ok');
      expect(calls, 2);
      expect(c.read(secureStoreProvider).accessToken, 'a2');
      expect(c.read(secureStoreProvider).refreshToken, 'r2');
    });

    test('maps validation errors to field codes', () async {
      final adapter = FakeAdapter((_) => (status: 422, body: failBody('VALIDATION_ERROR', [{'field': 'phone', 'code': 'INVALID_PHONE', 'message': 'INVALID_PHONE'}])));
      final c = await _container(adapter);
      expect(
        () => c.read(apiClientProvider).post<void>('/auth/register'),
        throwsA(isA<ApiException>().having((e) => e.fieldError('phone'), 'phone', 'INVALID_PHONE').having((e) => e.status, 'status', 422)),
      );
    });

    test('signals session expiry when the server revoked the session', () async {
      final adapter = FakeAdapter((_) => (status: 401, body: failBody('SESSION_REVOKED')));
      final c = await _container(adapter);
      var expired = false;
      c.read(apiClientProvider).onSessionExpired = () => expired = true;
      await expectLater(c.read(apiClientProvider).get<void>('/me'), throwsA(isA<ApiException>()));
      expect(expired, isTrue);
    });
  });

  group('offline sync', () {
    test('favorites are queued offline and flushed once online, without duplicates', () async {
      final sent = <List<dynamic>>[];
      final adapter = FakeAdapter((r) {
        if (r.path == '/sync') {
          final ops = body(r)['operations'] as List;
          sent.add(ops);
          return (status: 200, body: ok({'results': [for (final o in ops) {'op_id': o['op_id'], 'status': 'applied'}]}));
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });
      final offline = await _container(adapter, online: false);
      final favs = offline.read(favoritesProvider.notifier);
      await favs.toggle(const MezmurSummary(id: 7, title: 'ቅዱስ'));
      expect(offline.read(favoritesProvider), contains(7));
      expect(await offline.read(syncServiceProvider).pendingCount(), 1);
      expect(sent, isEmpty); // nothing sent while offline

      // Connection comes back.
      offline.read(_online.notifier).state = true;
      final sync = offline.read(syncServiceProvider);
      await sync.flush();
      expect(sent, hasLength(1));
      expect(sent.first.single['type'], 'favorite.add');
      expect(await sync.pendingCount(), 0);
      await sync.flush();
      expect(sent, hasLength(1)); // nothing re-sent
    });

    test('a conflict applies the server copy instead of overwriting it', () async {
      Object? applied;
      final adapter = FakeAdapter((r) {
        final ops = body(r)['operations'] as List;
        return (
          status: 200,
          body: ok({
            'results': [
              for (final o in ops) {'op_id': o['op_id'], 'status': 'conflict', 'server': {'title': 'server wins'}},
            ],
          }),
        );
      });
      final c = await _container(adapter);
      final sync = c.read(syncServiceProvider)..onConflict(SyncOp.reminderUpdate, (_, server) async => applied = server);
      await sync.enqueue(SyncOp.reminderUpdate, {'client_uuid': '00000000-0000-4000-8000-000000000000', 'title': 'stale'});
      await sync.flush();
      expect(applied, {'title': 'server wins'});
      expect(await sync.pendingCount(), 0);
    });

    test('transient failures keep the op for a later retry', () async {
      final adapter = FakeAdapter((r) {
        final ops = body(r)['operations'] as List;
        return (status: 200, body: ok({'results': [for (final o in ops) {'op_id': o['op_id'], 'status': 'retry'}]}));
      });
      final c = await _container(adapter);
      final sync = c.read(syncServiceProvider);
      await sync.enqueue(SyncOp.activity, {'action': 'audio_play'});
      await sync.flush();
      expect(await sync.pendingCount(), 1);
    });
  });
}
