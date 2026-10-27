import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezmur_zelideta/app/deep_links.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mezmur_zelideta/features/edu/learn/edu_home.dart';
import 'package:mezmur_zelideta/features/edu/learn/grade_content_screen.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';

import 'fakes.dart';

Future<ApiClient> _api(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

class _SignedOutSession extends SessionController {
  @override
  SessionState build() => const SignedOut();
}

Widget _app(Widget child, ApiClient api) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        sessionProvider.overrideWith(_SignedOutSession.new),
        eduRepositoryProvider.overrideWithValue(EduRepository(api)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('am'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        home: child,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 1 & 5: Removed Routes and Fallbacks', () {
    test('Academic Calendar routes redirect safely to fallbacks', () {
      expect(sanitizeRoute('/edu/calendar'), '/edu');
      expect(sanitizeRoute('/edu/calendar/123'), '/edu');
      expect(sanitizeRoute('/admin/edu/academic-years'), '/edu/manage');
      expect(sanitizeRoute('/admin/edu/academic-years/1'), '/edu/manage');
    });

    test('Units and Lessons routes redirect safely to content admin', () {
      expect(sanitizeRoute('/edu/content/units-lessons'), '/edu/content');
      expect(sanitizeRoute('/edu/content/units-lessons?subject_id=1'), '/edu/content');
    });
  });

  group('Requirement 2: Exact 7 Canonical Subjects in Exact Order', () {
    test('canonicalCategoriesList contains exactly the 7 required Amharic subjects', () {
      expect(canonicalCategoriesList.length, 7);
      expect(canonicalCategoriesList[0].name, 'ትምህርተ ሃይማኖት');
      expect(canonicalCategoriesList[1].name, 'የመጽሐፍ ቅዱስ ጥናት');
      expect(canonicalCategoriesList[2].name, 'ክርስቲያናዊ ሥነምግባር');
      expect(canonicalCategoriesList[3].name, 'ሥርዓተ ቤተ ክርስቲያን');
      expect(canonicalCategoriesList[4].name, 'የቤተክርስትያን ታሪክ');
      expect(canonicalCategoriesList[5].name, 'ልሳነ ግእዝ');
      expect(canonicalCategoriesList[6].name, 'ዜማ');

      for (int i = 0; i < 7; i++) {
        expect(canonicalCategoriesList[i].order, i + 1);
      }
    });

    testWidgets('EduHomeScreen displays all 7 subjects in order and has no FAB', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) => (status: 200, body: ok({
            'featured': [],
            'categories': [
              {'id': 1, 'name': 'ትምህርተ ሃይማኖት', 'sort_order': 1},
              {'id': 4, 'name': 'የመጽሐፍ ቅዱስ ጥናት', 'sort_order': 2},
              {'id': 5, 'name': 'ክርስቲያናዊ ሥነምግባር', 'sort_order': 3},
              {'id': 6, 'name': 'ሥርዓተ ቤተ ክርስቲያን', 'sort_order': 4},
              {'id': 3, 'name': 'የቤተክርስትያን ታሪክ', 'sort_order': 5},
              {'id': 7, 'name': 'ልሳነ ግእዝ', 'sort_order': 6},
              {'id': 8, 'name': 'ዜማ', 'sort_order': 7},
            ],
            'continue': null,
            'classes': [],
            'next_sessions': [],
            'open_registration': 0,
            'student': null,
            'teaching': null,
            'attendance_classes': [],
            'admin': null,
            'roles': {'student': true},
          }))));

      await tester.pumpWidget(_app(const EduHomeScreen(), api));
      await tester.pumpAndSettle();

      // Check all 7 canonical names exist
      expect(find.text('ትምህርተ ሃይማኖት'), findsOneWidget);
      expect(find.text('የመጽሐፍ ቅዱስ ጥናት'), findsOneWidget);
      expect(find.text('ክርስቲያናዊ ሥነምግባር'), findsOneWidget);
      expect(find.text('ሥርዓተ ቤተ ክርስቲያን'), findsOneWidget);
      expect(find.text('የቤተክርስትያን ታሪክ'), findsOneWidget);
      expect(find.text('ልሳነ ግእዝ'), findsOneWidget);
      expect(find.text('ዜማ'), findsOneWidget);

      // Requirement 3: Ensure no student-facing FloatingActionButton or "Add New" exists
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('አዲስ የትምህርት ዓይነት'), findsNothing);
      expect(find.text('አዲስ ምድብ'), findsNothing);
    });
  });

  group('Requirement 4: No Add Content on Category -> Grade', () {
    testWidgets('EduGradeContentScreen has no Add Content button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) => (status: 200, body: ok({
            'subject': {'id': 1, 'name': 'ትምህርተ ሃይማኖት'},
            'grade': {'number': 1, 'grade_name': '1ኛ ክፍል'},
            'courses': [],
            'lessons': [],
            'units': [],
            'materials': [],
            'quizzes': [],
            'can_manage': false,
          }))));

      await tester.pumpWidget(_app(const EduGradeContentScreen(subjectId: 1, gradeNumber: 1), api));
      await tester.pumpAndSettle();

      expect(find.text('1ኛ ክፍል ይዘት'), findsOneWidget);
      expect(find.text('ይዘት ጨምር'), findsNothing);
      expect(find.text('Add Content'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('Requirement 6: Notification Routing to Exact Destinations', () {
    test('Lesson notification routes to exact lesson', () {
      expect(routeForEntity('edu_lesson', 42), '/edu/learn/lesson/42');
      final p = parsePayload('n:101|edu_lesson:42');
      expect(p.route, '/edu/learn/lesson/42');
      expect(p.notificationId, 101);
    });

    test('Quiz notification routes to exact quiz', () {
      expect(routeForEntity('edu_quiz', 15), '/edu/quiz/15');
      final p = parsePayload('n:102|edu_quiz:15');
      expect(p.route, '/edu/quiz/15');
      expect(p.notificationId, 102);
    });

    test('Quiz result / grading notification routes to exact attempt', () {
      expect(
        routeForEntity('edu_grading', 15, data: {'quiz_id': 15, 'attempt_id': 99}),
        '/edu/attempt/99',
      );
      final p = parsePayload('n:103|edu_grading:15|attempt_id:99');
      expect(p.route, '/edu/attempt/99');
      expect(p.notificationId, 103);
    });

    test('Material notification routes to exact lesson or materials directory', () {
      expect(
        routeForEntity('edu_material', 7, data: {'lesson_id': 42}),
        '/edu/learn/lesson/42',
      );
      expect(routeForEntity('edu_material', 7), '/edu/content/materials');
    });

    test('Class assignment and promotion notifications route to classes', () {
      expect(routeForEntity('edu_class', 3), '/edu/classes');
      expect(routeForEntity('edu_promotion', 3), '/edu/classes');
    });

    test('Payment notifications route to payment settings', () {
      expect(routeForEntity('payment', 5), '/settings/payments');
      expect(routeForEntity('payment_receipt', 5), '/settings/payments');
    });

    test('Borrowing notifications route to specific borrowing', () {
      expect(routeForEntity('borrowing', 12), '/settings/borrowings/12');
      expect(routeForEntity('library_request', 8), '/library-request/8');
    });

    test('Sinksar notifications route to exact date', () {
      expect(routeForEntity('sinksar', null, extra: '2026-10-26'), '/sinksar/2026-10-26');
      expect(routeForEntity('sinksar', null, data: {'date': '2026-10-26'}), '/sinksar/2026-10-26');
    });

    test('Alarm and program notifications route to specific alarm or program', () {
      expect(routeForEntity('alarm', 55), '/alarm/55');
      expect(routeForEntity('program', 77), '/programs/77');
    });

    test('Removed calendar notification payload redirects to education home', () {
      final p = parsePayload('n:200|route:/edu/calendar');
      expect(p.route, '/edu');
    });

    test('Removed units and lessons notification payload redirects to education content', () {
      final p = parsePayload('n:201|route:/edu/content/units-lessons');
      expect(p.route, '/edu/content');
    });
  });
}
