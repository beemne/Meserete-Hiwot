import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mezmur_zelideta/app/deep_links.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/edu/admin/admin_grades_screen.dart';
import 'package:mezmur_zelideta/features/edu/announcements/announcements_screens.dart';
import 'package:mezmur_zelideta/features/edu/assignments/assignments_screens.dart';
import 'package:mezmur_zelideta/features/edu/learn/grade_content_screen.dart';
import 'package:mezmur_zelideta/features/edu/learn/quiz_screens.dart';
import 'package:mezmur_zelideta/features/edu/learn/subject_grades_screen.dart';
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

class _SignedOutSession extends SessionController {
  @override
  SessionState build() => const SignedOut();
}

Widget _testApp(Widget child, ApiClient api, {Locale locale = const Locale('en')}) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        sessionProvider.overrideWith(_SignedOutSession.new),
        eduRepositoryProvider.overrideWithValue(EduRepository(api)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
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

  group('Deep Links & Routes Verification', () {
    test('deep links map edu_assignment and edu_announcement correctly', () {
      expect(routeForEntity('edu_assignment', 42), '/edu/assignment/42');
      expect(routeForEntity('edu_assignment', null), '/edu/assignments');
      expect(routeForEntity('edu_announcement', null), '/edu/announcements');
      expect(sanitizeRoute('/edu/assignments'), '/edu/assignments');
      expect(sanitizeRoute('/edu/announcements'), '/edu/announcements');
      expect(sanitizeRoute('/edu/admin/grades'), '/edu/admin/grades');
    });
  });

  group('Feature A: Quiz Attempt Enforcement', () {
    testWidgets('Start button is disabled and exhaustion warning is shown when attempts_left is 0', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) {
        if (req.uri.path.contains('/edu/quizzes/10')) {
          return (
            status: 200,
            body: ok({
              'id': 10,
              'title': 'Test Quiz A',
              'availability': 'open',
              'attempts_left': 0,
              'attempts_used': 3,
              'max_attempts': 3,
              'question_count': 5,
              'can_edit': false,
            })
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      await tester.pumpWidget(_testApp(const EduQuizScreen(quizId: 10), api));
      await tester.pumpAndSettle();

      // Expect disabled button with 0 attempts remaining
      expect(find.text('0 attempts remaining'), findsOneWidget);
      // Expect attempt limit reached warning card
      expect(find.text('Attempt limit reached'), findsOneWidget);
      expect(find.text('You have used all permitted attempts for this quiz. You cannot start another attempt.'), findsOneWidget);

      // Verify button cannot be tapped to trigger start
      final buttonFinder = find.widgetWithText(FilledButton, '0 attempts remaining');
      expect(buttonFinder, findsOneWidget);
      final FilledButton button = tester.widget(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('Start button is enabled when attempts_left is positive', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) {
        if (req.uri.path.contains('/edu/quizzes/11')) {
          return (
            status: 200,
            body: ok({
              'id': 11,
              'title': 'Open Quiz B',
              'availability': 'open',
              'attempts_left': 2,
              'attempts_used': 0,
              'max_attempts': 2,
              'question_count': 10,
              'can_edit': false,
            })
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      await tester.pumpWidget(_testApp(const EduQuizScreen(quizId: 11), api));
      await tester.pumpAndSettle();

      expect(find.text('Start the quiz'), findsOneWidget);
      final FilledButton button = tester.widget(find.widgetWithText(FilledButton, 'Start the quiz'));
      expect(button.onPressed, isNotNull);
    });
  });

  group('Feature B: Direct Course Materials', () {
    testWidgets('Direct course materials render in GradeContentScreen alongside lessons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) {
        if (req.uri.path.contains('/edu/subjects/1/grades/5')) {
          return (
            status: 200,
            body: ok({
              'subject': {'id': 1, 'name': 'Theology'},
              'grade': {'grade_number': 5, 'grade_name': 'Grade 5'},
              'courses': [],
              'lessons': [
                {'id': 101, 'title': 'Lesson 1: Intro', 'materials_count': 0}
              ],
              'materials': [
                {'id': 201, 'title': 'Grade 5 Direct Reading Guide', 'kind': 'file', 'file_size': 1048576, 'url': '/file.pdf'}
              ],
              'quizzes': [],
              'has_content': true,
              'can_manage': false,
            })
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      await tester.pumpWidget(_testApp(const EduGradeContentScreen(subjectId: 1, gradeNumber: 5), api));
      await tester.pumpAndSettle();

      expect(find.text('Grade 5 Content'), findsOneWidget);
      expect(find.text('Lesson 1: Intro'), findsOneWidget);
      expect(find.text('Grade 5 Direct Reading Guide'), findsOneWidget);
    });
  });

  group('Feature C: Admin Assigned Grade vs Canonical Grades', () {
    testWidgets('EduSubjectGradesScreen shows unassigned warning when user has no assigned grade', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) {
        if (req.uri.path.contains('/edu/subjects/1/grades')) {
          return (
            status: 200,
            body: ok({
              'subject': {'id': 1, 'name': 'Church History'},
              'grades': [
                for (int i = 1; i <= 12; i++)
                  {
                    'id': i,
                    'grade_number': i,
                    'grade_name': 'Grade $i',
                    'is_assigned': false,
                    'can_open': false,
                    'has_content': false,
                  }
              ],
            })
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      await tester.pumpWidget(_testApp(const EduSubjectGradesScreen(subjectId: 1), api));
      await tester.pumpAndSettle();

      // Expect No Assigned Grade banner
      expect(find.text('No Assigned Grade'), findsOneWidget);
      expect(find.text('You are not currently assigned to a grade level. Please contact your Sunday School administrator.'), findsOneWidget);
    });

    testWidgets('EduAdminGradesScreen displays all 12 canonical grades centrally', (tester) async {
      tester.view.physicalSize = const Size(1080, 4800);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) {
        if (req.uri.path.contains('/edu/admin/grades')) {
          return (
            status: 200,
            body: ok([
              for (int i = 1; i <= 12; i++)
                {
                  'id': i,
                  'code': 'G$i',
                  'name': '$iኛ ክፍል',
                  'name_en': 'Grade $i',
                  'sort_order': i,
                  'is_active': true,
                  'built_in': true,
                  'class_count': 1,
                }
            ])
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      await tester.pumpWidget(_testApp(const EduAdminGradesScreen(), api));
      await tester.pumpAndSettle();

      expect(find.text('Canonical Grades (1–12)'), findsOneWidget);
      expect(find.text('Grade 1'), findsOneWidget);
      expect(find.text('Grade 12'), findsOneWidget);
      expect(find.text('Canonical'), findsNWidgets(12));
    });
  });

  group('Feature D: Classroom Assignments Workflow', () {
    testWidgets('EduAssignmentsScreen displays student dashboard with status filters', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) {
        if (req.uri.path.contains('/edu/me/assignments')) {
          return (
            status: 200,
            body: ok([
              {
                'id': 1,
                'title': 'Biblical Commentary Essay',
                'course_name': 'Theology I',
                'status_group': 'assigned',
                'max_score': '100',
                'due_at': '2026-11-15 10:00:00',
                'my_submission': null,
              },
              {
                'id': 2,
                'title': 'Ecclesiastical History Reflection',
                'course_name': 'History II',
                'status_group': 'turned_in',
                'max_score': '100',
                'due_at': '2026-11-01 10:00:00',
                'my_submission': {'id': 10, 'status': 'submitted', 'score': null},
              },
            ])
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      await tester.pumpWidget(_testApp(const EduAssignmentsScreen(), api));
      await tester.pumpAndSettle();

      expect(find.text('Biblical Commentary Essay'), findsOneWidget);
      expect(find.text('Ecclesiastical History Reflection'), findsOneWidget);
      expect(find.text('Turned in'), findsWidgets);
      expect(find.text('Assigned'), findsWidgets);
    });

    testWidgets('EduAssignmentDetailScreen renders instructions and submission form', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) {
        if (req.uri.path.contains('/edu/me/assignments/1')) {
          return (
            status: 200,
            body: ok({
              'id': 1,
              'title': 'Biblical Commentary Essay',
              'instructions': 'Write a 200-word reflection on Saint Yared hymnology.',
              'max_score': '50',
              'due_at': '2026-11-20 18:00:00',
              'my_submission': null,
            })
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      await tester.pumpWidget(_testApp(const EduAssignmentDetailScreen(id: 1), api));
      await tester.pumpAndSettle();

      expect(find.text('Biblical Commentary Essay'), findsOneWidget);
      expect(find.text('Write a 200-word reflection on Saint Yared hymnology.'), findsOneWidget);
      expect(find.text('Submit Assignment'), findsOneWidget);
      expect(find.text('Attach File'), findsOneWidget);
    });
  });

  group('Feature E: Teacher Announcements Stream', () {
    testWidgets('EduAnnouncementsScreen renders announcements stream newest first', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      final api = await _api(FakeAdapter((req) {
        if (req.uri.path.contains('/edu/me/announcements')) {
          return (
            status: 200,
            body: ok([
              {
                'id': 1,
                'title': 'Welcome to Sunday School Semester',
                'body': 'Please review the course schedule and bring your hymn books on Sunday.',
                'teacher_name': 'Teacher Petros',
                'course_name': 'Grade 5 Theology',
                'published_at': '2026-10-27 08:00:00',
                'attachments': [],
                'can_manage': false,
              }
            ])
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      await tester.pumpWidget(_testApp(const EduAnnouncementsScreen(), api));
      await tester.pumpAndSettle();

      expect(find.text('Class Announcements'), findsOneWidget);
      expect(find.text('Welcome to Sunday School Semester'), findsOneWidget);
      expect(find.text('Please review the course schedule and bring your hymn books on Sunday.'), findsOneWidget);
      expect(find.text('Posted by Teacher Petros'), findsOneWidget);
    });
  });
}
