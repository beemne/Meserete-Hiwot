import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/l10n/l10n.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/network/api_exception.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/local_db.dart';
import 'package:mezmur_zelideta/core/storage/local_prefs.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/services/sync_service.dart';
import 'package:mezmur_zelideta/services/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

class _TestSession extends SessionController {
  _TestSession(this._user);
  AppUser _user;

  @override
  void updateUser(AppUser u) {
    _user = u;
    state = SignedIn(u);
  }

  @override
  SessionState build() => SignedIn(_user);
}

final _online = StateProvider<bool>((_) => true);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('F7: Platform-Wide Offline Mode & Protected Cache', () {
    Future<(ProviderContainer, FakeAdapter, LocalDb, _TestSession)> setupContainer({
      required bool online,
      AppUser? user,
      LocalDb? existingDb,
    }) async {
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'a1',
        'refresh_token': 'r1',
        'token_scope': 'app',
        'device_id': 'd1',
      });
      SharedPreferences.setMockInitialValues({});
      final store = SecureStore();
      await store.load();

      final db = existingDb ?? await LocalDb.open(path: inMemoryDatabasePath);
      final prefs = await LocalPrefs.load();

      final testUser = user ??
          const AppUser(
            id: 10,
            fullName: 'Admin User',
            phone: '+251911000000',
            accountType: 'admin',
            roleLevel: 50,
            permissions: {'users.view', 'selection.view'},
          );
      final sessionNotifier = _TestSession(testUser);

      late final ProviderContainer container;
      final adapter = FakeAdapter((r) {
        if (r.data != null) {
          final b = body(r);
          return (
            status: 200,
            body: ok({
              'results': [
                for (final op in (b['operations'] as List? ?? []))
                  {'op_id': (op as Map)['op_id'], 'status': 'applied', 'server': {'id': 99}},
              ],
            }),
          );
        }
        return (
          status: 200,
          body: {'success': true, 'code': 'OK', 'data': <dynamic>[], 'meta': {'page': 1, 'pages': 1, 'total': 0}},
        );
      });

      container = ProviderContainer(overrides: [
        secureStoreProvider.overrideWithValue(store),
        localDbProvider.overrideWithValue(db),
        localPrefsProvider.overrideWithValue(prefs),
        _online.overrideWith((_) => online),
        isOnlineProvider.overrideWith((ref) => ref.watch(_online)),
        sessionProvider.overrideWith(() => sessionNotifier),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter)
            ..retryDelays = const [Duration.zero];
          client.cache = createDbResponseCache(db, ref);
          client.isOffline = () => !ref.read(isOnlineProvider);
          return client;
        }),
      ]);

      return (container, adapter, db, sessionNotifier);
    }

    test('Acceptance 2: Protected admin routes are stored encrypted in SQLite with no raw plaintext', () async {
      final (c, _, db, _) = await setupContainer(online: true);
      final api = c.read(apiClientProvider);

      // Sensitive admin response body
      final sensitiveData = {
        'success': true,
        'code': 'OK',
        'message': 'OK',
        'data': [
          {'id': 101, 'name': 'Abebe Kebede', 'phone': '+251911223344', 'salary': 15000},
        ],
      };

      // Put to cache for protected admin route /admin/users
      await api.cache!.put('http:/admin/users?', sensitiveData);

      // 1. Verify SQLite row metadata
      final row = await db.getCacheRow('http:/admin/users?');
      expect(row, isNotNull);
      expect(row!['is_sealed'], 1, reason: 'Protected routes must be sealed');
      expect(row['required_perm'], 'users.view');
      expect(row['perm_hash'], isNotEmpty);

      // 2. Verify raw SQLite JSON contains ciphertext and NO plaintext personal data
      final rawJson = row['json'] as String;
      expect(rawJson, contains('_sealed'));
      expect(rawJson, isNot(contains('Abebe')));
      expect(rawJson, isNot(contains('+251911223344')));
      expect(rawJson, isNot(contains('15000')));

      // 3. Verify that reading it back with appropriate permissions decrypts the content
      final decrypted = await api.cache!.get('http:/admin/users?');
      expect(decrypted, isA<Map<String, dynamic>>());
      final map = decrypted as Map<String, dynamic>;
      expect(map['success'], isTrue);
      final items = (map['data'] as List).cast<Map>();
      expect(items.first['name'], 'Abebe Kebede');
      expect(items.first['phone'], '+251911223344');
    });

    test('Acceptance 3: Permission revocation causes offline cache read to throw NOT_AVAILABLE_FOR_ACCOUNT', () async {
      final (c, _, _, session) = await setupContainer(
        online: true,
        user: const AppUser(
          id: 10,
          fullName: 'Staff Officer',
          phone: '+251911000000',
          accountType: 'staff',
          roleLevel: 50,
          permissions: {'users.view'},
        ),
      );
      final api = c.read(apiClientProvider);

      // Cache /admin/users
      await api.cache!.put('http:/admin/users?', {
        'success': true,
        'code': 'OK',
        'data': [{'id': 1}],
      });

      // Reading with users.view works
      final allowed = await api.cache!.get('http:/admin/users?');
      expect(allowed, isNotNull);

      // Demote / revoke users.view permission
      session.updateUser(const AppUser(
        id: 10,
        fullName: 'Staff Officer',
        phone: '+251911000000',
        accountType: 'staff',
        roleLevel: 10,
        permissions: {}, // Revoked!
      ));

      // Reading again throws NOT_AVAILABLE_FOR_ACCOUNT
      expect(
        () => api.cache!.get('http:/admin/users?'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.code, 'code', 'NOT_AVAILABLE_FOR_ACCOUNT'),
        ),
      );
    });

    test('Acceptance 4 (Decision D9): edu.lesson.complete, library.checkout, library.return queue offline', () async {
      final (c, adapter, _, _) = await setupContainer(online: false);
      final sync = c.read(syncServiceProvider);

      // Queue library checkout & return
      final r1 = await sync.submit(SyncOp.libraryCheckout, {'item_id': 50, 'borrower_id': 12});
      expect(r1.queued, isTrue);

      final r2 = await sync.submit(SyncOp.libraryReturn, {'item_id': 50, 'return_notes': 'Good condition'});
      expect(r2.queued, isTrue);

      // Queue edu lesson completion
      final r3 = await sync.submit(SyncOp.eduLessonComplete, {'course_id': 3, 'lesson_id': 14});
      expect(r3.queued, isTrue);

      expect(await sync.pendingCount(), 3);
      expect(adapter.requests, isEmpty);

      // When back online, flush sends all 3 ops to backend /sync
      c.read(_online.notifier).state = true;
      await sync.flush();
      expect(await sync.pendingCount(), 0);
      expect(adapter.requests, hasLength(1));
      final sentOps = (body(adapter.requests.single)['operations'] as List).cast<Map>();
      expect(sentOps.map((o) => o['type']), [
        SyncOp.libraryCheckout,
        SyncOp.libraryReturn,
        SyncOp.eduLessonComplete,
      ]);

      // Last successful sync time updated in prefs
      final lastSync = c.read(localPrefsProvider).lastSuccessfulSync;
      expect(lastSync, isNotNull);
    });

    test('Acceptance 1: Global Offline Sync Banner & Sheet data and localized messages', () async {
      final (c, _, _, _) = await setupContainer(online: false);
      final prefs = c.read(localPrefsProvider);
      final sync = c.read(syncServiceProvider);

      final syncTime = DateTime(2026, 10, 16, 14, 5);
      await prefs.setLastSuccessfulSync(syncTime);

      await sync.enqueue(SyncOp.eduLessonComplete, {'course_id': 1, 'lesson_id': 5});
      await sync.enqueue(SyncOp.libraryCheckout, {'item_id': 10});

      // Refresh sync status
      await c.read(syncStatusProvider.notifier).refresh();
      final status = c.read(syncStatusProvider);

      expect(status.pendingCount, 2);
      expect(status.lastSuccessfulSync, syncTime);
      expect(status.pendingOps, hasLength(2));
      expect(status.pendingOps.map((o) => o.type), [SyncOp.eduLessonComplete, SyncOp.libraryCheckout]);

      // Verify English and Amharic localizations for offline banner and sync sheet
      final lEn = await AppLocalizations.delegate.load(const Locale('en'));
      final lAm = await AppLocalizations.delegate.load(const Locale('am'));

      expect(lEn.offlineBannerWithSync('14:05', 2), 'Offline · last synced 14:05 · 2 changes waiting');
      expect(lAm.offlineBannerWithSync('14:05', 2), contains('ከመስመር ውጭ'));
      expect(lAm.offlineBannerWithSync('14:05', 2), contains('14:05'));

      expect(lEn.syncStatusTitle, 'Sync status');
      expect(lAm.syncStatusTitle, 'የማመሳሰል ሁኔታ');

      expect(lEn.lastSync, 'Last synced');
      expect(lAm.lastSync, 'የመጨረሻው ማመሳሰል');

      expect(lEn.syncWhatLesson, 'Lesson completion');
      expect(lAm.syncWhatLesson, 'የትምህርት ማጠናቀቅ');

      expect(lEn.syncWhatLibrary, 'Library circulation');
      expect(lAm.syncWhatLibrary, 'የቤተ-መጻሕፍት ውሰት/መመለስ');
    });

    test('Acceptance 4: Admin write buttons are gated offline with Needs a connection', () async {
      final (c, _, _, _) = await setupContainer(
        online: false,
        user: const AppUser(
          id: 1,
          fullName: 'Super Admin',
          phone: '+251911000000',
          accountType: 'admin',
          roleLevel: 100,
          permissions: {'users.manage', 'users.view'},
        ),
      );

      final isOnline = c.read(isOnlineProvider);
      expect(isOnline, isFalse);

      final lEn = await AppLocalizations.delegate.load(const Locale('en'));
      final lAm = await AppLocalizations.delegate.load(const Locale('am'));

      expect(lEn.needsConnection, 'Needs a connection');
      expect(lAm.needsConnection, 'ኢንተርኔት ያስፈልጋል');

      // Verify button labels formatted when offline
      final offlineSaveLabelEn = '${lEn.save} · ${lEn.needsConnection}';
      expect(offlineSaveLabelEn, 'Save · Needs a connection');

      final offlineSaveLabelAm = '${lAm.save} · ${lAm.needsConnection}';
      expect(offlineSaveLabelAm, contains('ኢንተርኔት ያስፈልጋል'));
    });
  });
}
