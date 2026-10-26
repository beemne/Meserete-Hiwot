import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/edu/edu_academic_calendar.dart';
import 'package:mezmur_zelideta/features/edu/edu_assign.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';

import 'fakes.dart';

Future<ApiClient> _api(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

Widget _app(Widget child, ApiClient api) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        eduRepositoryProvider.overrideWithValue(EduRepository(api)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EduRepository Academic Structure (F1-F3)', () {
    test('academic years and terms CRUD endpoints', () async {
      late FakeAdapter adapter;
      adapter = FakeAdapter((req) {
        if (req.path == '/edu/admin/academic-years' && req.method == 'GET') {
          return (status: 200, body: ok([
            {'id': 1, 'eth_year': 2019, 'name': '2019 ዓ.ም', 'is_current': true, 'status': 'active', 'class_count': 3, 'terms': []},
          ]));
        }
        if (req.path == '/edu/admin/academic-years/1/terms' && req.method == 'GET') {
          return (status: 200, body: ok([
            {'id': 10, 'academic_year_id': 1, 'name': 'Term I', 'sort_order': 1},
          ]));
        }
        if (req.path == '/edu/admin/levels' && req.method == 'GET') {
          return (status: 200, body: ok([
            {'id': 1, 'code': 'G1', 'name': 'Grade 1', 'built_in': true, 'kind': 'grade', 'class_count': 2},
          ]));
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });

      final api = await _api(adapter);
      final repo = EduRepository(api);

      final years = await repo.academicYears();
      expect(years.length, 1);
      expect(years.first['eth_year'], 2019);

      final terms = await repo.terms(1);
      expect(terms.length, 1);
      expect(terms.first['name'], 'Term I');

      final levels = await repo.levels();
      expect(levels.length, 1);
      expect(levels.first['code'], 'G1');
    });

    test('assignable students and assign', () async {
      late FakeAdapter adapter;
      adapter = FakeAdapter((req) {
        if (req.path == '/edu/admin/classes/5/assignable' && req.method == 'GET') {
          return (status: 200, body: {
            'success': true,
            'code': 'OK',
            'message': 'OK',
            'data': [
              {'id': 101, 'full_name': 'Abebe Bikila', 'phone': '0911000000', 'member_id': 'Y-001', 'member_group': 'youth_adult'},
              {'id': 102, 'full_name': 'Derartu Tulu', 'phone': '0922000000', 'member_id': 'Y-002', 'member_group': 'youth_adult'},
            ],
            'meta': {'page': 1, 'pages': 1, 'total': 2},
            'errors': [],
          });
        }
        if (req.path == '/edu/admin/classes/5/assign' && req.method == 'POST') {
          final b = body(req);
          expect(b['user_ids'], [101]);
          expect(b['program'], 'regular');
          return (status: 200, body: ok({
            'assigned_count': 1,
            'results': [
              {'user_id': 101, 'status': 'assigned'},
            ],
          }));
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });

      final api = await _api(adapter);
      final repo = EduRepository(api);

      final assignable = await repo.assignableStudents(5);
      expect(assignable.items.length, 2);
      expect(assignable.items.first['full_name'], 'Abebe Bikila');

      final res = await repo.assignStudents(5, [101], program: 'regular');
      expect(res['assigned_count'], 1);
    });

    test('transfer enrollment', () async {
      late FakeAdapter adapter;
      adapter = FakeAdapter((req) {
        if (req.path == '/edu/admin/enrollments/25/transfer' && req.method == 'POST') {
          final b = body(req);
          expect(b['target_class_id'], 7);
          expect(b['reason'], 'Advancement');
          return (status: 200, body: ok({
            'old_enrollment_id': 25,
            'new_enrollment_id': 26,
            'class_id': 7,
          }));
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });

      final api = await _api(adapter);
      final repo = EduRepository(api);

      final res = await repo.transferEnrollment(25, 7, 'Advancement');
      expect(res['new_enrollment_id'], 26);
    });
  });

  group('Edu UI screens (F1-F2)', () {
    testWidgets('EduAcademicCalendarScreen renders tabs and years', (tester) async {
      final adapter = FakeAdapter((req) {
        if (req.path == '/edu/admin/academic-years') {
          return (status: 200, body: ok([
            {'id': 1, 'eth_year': 2019, 'name': '2019 ዓ.ም', 'is_current': true, 'status': 'active', 'class_count': 2, 'terms': [{'id': 1, 'name': 'Term 1'}]},
          ]));
        }
        if (req.path == '/edu/admin/levels') {
          return (status: 200, body: ok([
            {'id': 1, 'code': 'G1', 'name': 'Grade 1', 'built_in': true, 'kind': 'grade', 'class_count': 2},
          ]));
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });

      final api = await _api(adapter);
      await tester.pumpWidget(_app(const EduAcademicCalendarScreen(), api));
      await tester.pumpAndSettle();

      expect(find.text('Academic Calendar'), findsOneWidget);
      expect(find.text('2019 ዓ.ም'), findsOneWidget);
      expect(find.text('Term 1'), findsOneWidget);

      // Switch to Grade Levels tab
      await tester.tap(find.text('Grade Levels'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Grade 1'), findsOneWidget);
      expect(find.text('Built-in'), findsOneWidget);
    });

    testWidgets('EduAssignStudentsScreen displays eligible members and allows selection', (tester) async {
      final adapter = FakeAdapter((req) {
        if (req.path == '/edu/admin/classes/5/assignable') {
          return (status: 200, body: {
            'success': true,
            'code': 'OK',
            'message': 'OK',
            'data': [
              {'id': 101, 'full_name': 'Kenenisa Bekele', 'phone': '0911223344', 'member_id': 'Y-005', 'member_group': 'youth_adult'},
            ],
            'meta': {'page': 1, 'pages': 1, 'total': 1},
            'errors': [],
          });
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      });

      final api = await _api(adapter);
      await tester.pumpWidget(_app(const EduAssignStudentsScreen(classId: 5, className: 'Adult Class 1'), api));
      await tester.pumpAndSettle();

      expect(find.textContaining('Assign Students · Adult Class 1'), findsOneWidget);
      expect(find.text('Kenenisa Bekele'), findsOneWidget);

      // Checkbox for selection
      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(find.text('Assign Students (1)'), findsOneWidget);
    });
  });
}
