import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/local_db.dart';
import 'package:mezmur_zelideta/core/storage/local_prefs.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/admin/programs_admin.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/hub/hub_screen.dart';
import 'package:mezmur_zelideta/services/offline_pack.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes.dart';

class _User extends SessionController {
  _User(this.me);
  final AppUser me;
  @override
  SessionState build() => SignedIn(me);
}

/// The roster's attendance-session header: one HR-assigned taker, Start when available, a running
/// clock from the official start, End; HR assigns but does not record.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final now = DateTime.now().toUtc();
  String iso(DateTime d) => d.toUtc().toIso8601String();

  Map<String, dynamic> session(String status, {int takerId = 7, DateTime? startedAt, bool canAssign = false}) => {
        'id': 1,
        'program_id': 5,
        'date': '2026-10-05',
        'scheduled_start': iso(now.add(const Duration(minutes: 5))),
        'scheduled_end': iso(now.add(const Duration(hours: 2))),
        'available_from': iso(now.subtract(const Duration(minutes: 10))),
        'status': status,
        'taker': {'id': takerId, 'full_name': 'Taker Abebe'},
        'started_at': startedAt == null ? null : iso(startedAt),
        'start_source': startedAt == null ? null : 'server',
        'ended_at': null,
        'end_reason': null,
        'can_assign': canAssign,
        'server_time': iso(now),
      };

  Map<String, dynamic> roster(Map<String, dynamic> s) => {
        'success': true,
        'code': 'OK',
        'message': 'OK',
        'data': [
          {'user_id': 20, 'full_name': 'Member Two', 'member_id': 'MH-20', 'member_group': 'youth_adult', 'status': 'unmarked', 'marked': false},
        ],
        'errors': [],
        'meta': {
          'page': 1,
          'limit': 20,
          'total': 1,
          'pages': 1,
          'occurrence': {'date': '2026-10-05', 'starts_at': s['scheduled_start'], 'ends_at': s['scheduled_end'], 'active': true, 'ended': false, 'closed': false},
          'session': s,
          'signature_policy': {'exempt_groups': <String>[]},
          'summary': {'expected': 1, 'present': 0, 'excused': 0, 'absent': 0, 'unmarked': 1},
        },
      };

  Future<FakeAdapter> pump(WidgetTester tester, {required AppUser user, required Map<String, dynamic> Function() session}) async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1', 'token_scope': 'app', 'device_id': 'd'});
    SharedPreferences.setMockInitialValues({});
    final store = SecureStore();
    await tester.runAsync(store.load);
    final db = await tester.runAsync(() => LocalDb.open(path: inMemoryDatabasePath));
    final prefs = await tester.runAsync(LocalPrefs.load);
    final adapter = FakeAdapter((r) {
      if (r.path.endsWith('/programs/5/attendance')) return (status: 200, body: roster(session()));
      if (r.path == '/sync') {
        return (
          status: 200,
          body: ok({
            'server_time': iso(now),
            'results': [
              for (final op in (body(r)['operations'] as List)) {'op_id': (op as Map)['op_id'], 'status': 'applied', 'server': {'status': 'active'}},
            ],
          }),
        );
      }
      return (status: 200, body: ok(null));
    });
    final api = ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
    await tester.binding.setSurfaceSize(const Size(412, 892));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        localDbProvider.overrideWithValue(db!),
        localPrefsProvider.overrideWithValue(prefs!),
        apiClientProvider.overrideWithValue(api),
        isOnlineProvider.overrideWithValue(true),
        sessionProvider.overrideWith(() => _User(user)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: const AttendanceRosterScreen(programId: 5),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    return adapter;
  }

  const taker = AppUser(id: 7, fullName: 'Taker Abebe', phone: '+251911000007', permissions: {'attendance.manage'});
  const hr = AppUser(id: 9, fullName: 'HR', phone: '+251911000009', permissions: {'attendance.assign', 'attendance.close', 'attendance.manage'});

  testWidgets('the assigned taker sees Start once it is available; nothing can be recorded before', (tester) async {
    await pump(tester, user: taker, session: () => session('scheduled'));
    expect(find.byKey(const ValueKey('att-start')), findsOneWidget);
    expect(find.textContaining('Ready'), findsOneWidget);
    expect(find.text('Taker: Taker Abebe'), findsOneWidget);
    // No QR / manual entry and no mark chips until Start.
    expect(find.byKey(const ValueKey('att-scan')), findsNothing);
    expect(find.byKey(const ValueKey('mark-present-20')), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('after Start: the clock runs from the official start and members can be recorded', (tester) async {
    await pump(tester, user: taker, session: () => session('active', startedAt: now.subtract(const Duration(minutes: 3, seconds: 5))));
    expect(find.byKey(const ValueKey('att-end')), findsOneWidget);
    expect(find.byKey(const ValueKey('att-scan')), findsOneWidget);
    final line = tester.widget<Text>(find.byKey(const ValueKey('att-session-line'))).data!;
    expect(line, contains('03:0'));
    expect(find.byKey(const ValueKey('mark-present-20')), findsOneWidget);
    // Attended asks for the member's signature first (nothing is sent before signing).
    await tester.tap(find.byKey(const ValueKey('mark-present-20')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Member Two'), findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('HR assigns the taker but does not start or record someone else\'s session', (tester) async {
    await pump(tester, user: hr, session: () => session('scheduled', canAssign: true));
    expect(find.byKey(const ValueKey('att-start')), findsNothing);
    expect(find.byKey(const ValueKey('att-assign')), findsOneWidget);
    expect(find.text('Only the assigned taker records this session.'), findsOneWidget);
    expect(find.byKey(const ValueKey('mark-present-20')), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('a member HR assigned to take attendance (no admin panel) gets a Take attendance entry', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1', 'token_scope': 'app', 'device_id': 'd'});
    SharedPreferences.setMockInitialValues({});
    final store = SecureStore();
    await tester.runAsync(store.load);
    final db = await tester.runAsync(() => LocalDb.open(path: inMemoryDatabasePath));
    final prefs = await tester.runAsync(LocalPrefs.load);
    Widget app(bool takes) => ProviderScope(
          overrides: [
            secureStoreProvider.overrideWithValue(store),
            localDbProvider.overrideWithValue(db!),
            localPrefsProvider.overrideWithValue(prefs!),
            isOnlineProvider.overrideWithValue(false),
            sessionProvider.overrideWith(() => _User(const AppUser(id: 30, fullName: 'Plain Member', phone: '+251911000030'))),
            hubBannersProvider.overrideWith((ref) async => const []),
            takesAttendanceProvider.overrideWith((ref) async => takes),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            home: const HubScreen(),
          ),
        );
    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 300));
    // Operational attendance card is excluded from Hub per Section 2.2
    expect(find.byKey(const ValueKey('hub-take-attendance')), findsNothing);
    expect(find.byKey(const ValueKey('shared.home.module_selector.mezmur')), findsOneWidget);
    expect(find.byKey(const ValueKey('shared.home.module_selector.education')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    // The welcome tour schedules itself after the first frame.
    await tester.pump(const Duration(seconds: 30));
  });
}