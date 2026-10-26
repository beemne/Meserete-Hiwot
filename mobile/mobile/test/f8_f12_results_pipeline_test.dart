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
import 'package:mezmur_zelideta/features/edu/edu_screens.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';

import 'fakes.dart';

Future<ApiClient> _createApi(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

const _testStudent = AppUser(
  id: 42,
  fullName: 'ዳዊት ተማሪ',
  phone: '+251911000042',
  roleName: 'member',
  roleLevel: 10,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EduRepository F8-F12 Endpoints', () {
    test('calls courseCompletion correctly', () async {
      final api = await _createApi(FakeAdapter((req) {
        expect(req.path, '/edu/courses/10/completion');
        expect(req.queryParameters['user_id'], 42);
        return (
          status: 200,
          body: ok({
            'course_id': 10,
            'user_id': 42,
            'mandatory_published': 5,
            'mandatory_completed': 4,
            'percent': 80.0,
          }),
        );
      }));
      final repo = EduRepository(api);
      final res = await repo.courseCompletion(10, userId: 42);
      expect(res['mandatory_published'], 5);
      expect(res['percent'], 80.0);
    });

    test('calls submissionVersions correctly', () async {
      final api = await _createApi(FakeAdapter((req) {
        expect(req.path, '/edu/submissions/55/versions');
        return (
          status: 200,
          body: ok([
            {'id': 101, 'version_number': 2, 'is_late': true, 'submitted_at': '2026-10-16T12:00:00Z'},
          ]),
        );
      }));
      final repo = EduRepository(api);
      final versions = await repo.submissionVersions(55);
      expect(versions.length, 1);
      expect(versions.first['version_number'], 2);
      expect(versions.first['is_late'], true);
    });

    test('calls myOutcomes and requestRetake', () async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/my-outcomes') {
          return (
            status: 200,
            body: ok([
              {
                'id': 7,
                'course_id': 10,
                'result': 'failed',
                'status': 'finalized',
                'score_percent': 42.0,
                'pass_mark': 50.0,
                'counts_for_progression': true,
              },
            ]),
          );
        }
        if (req.path == '/edu/outcomes/7/retake') {
          expect(req.method, 'POST');
          return (
            status: 201,
            body: ok({'id': 1, 'outcome_id': 7, 'status': 'requested'}),
          );
        }
        throw UnimplementedError(req.path);
      }));
      final repo = EduRepository(api);
      final outcomes = await repo.myOutcomes();
      expect(outcomes.length, 1);
      expect(outcomes.first['result'], 'failed');

      final retake = await repo.requestRetake(7);
      expect(retake['status'], 'requested');
    });

    test('calls questionBanks and quizDraws', () async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/subjects/2/question-banks') {
          return (
            status: 200,
            body: ok([
              {'id': 1, 'title': 'Theology Bank', 'subject_id': 2},
            ]),
          );
        }
        if (req.path == '/edu/quizzes/88/draws') {
          return (
            status: 200,
            body: ok([
              {'id': 1, 'quiz_id': 88, 'question_bank_id': 1, 'question_count': 5},
            ]),
          );
        }
        throw UnimplementedError(req.path);
      }));
      final repo = EduRepository(api);
      final banks = await repo.questionBanks(2);
      expect(banks.length, 1);
      expect(banks.first['title'], 'Theology Bank');

      final draws = await repo.quizDraws(88);
      expect(draws.length, 1);
      expect(draws.first['question_count'], 5);
    });
  });

  group('Edu UI Integration', () {
    testWidgets('EduCourseScreen renders all 5 tabs including Outcomes', (tester) async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/courses/10') {
          return (
            status: 200,
            body: ok({
              'id': 10,
              'name': 'ክርስቲያናዊ ሥነ ምግባር',
              'subject_id': 2,
              'students_count': 15,
              'class_id': 1,
            }),
          );
        }
        if (req.path == '/edu/courses/10/students') {
          return (status: 200, body: ok(<dynamic>[]));
        }
        if (req.path == '/edu/courses/10/assignments') {
          return (status: 200, body: ok(<dynamic>[]));
        }
        if (req.path == '/edu/courses/10/assessments') {
          return (status: 200, body: ok(<dynamic>[]));
        }
        if (req.path == '/edu/courses/10/quizzes') {
          return (status: 200, body: ok(<dynamic>[]));
        }
        if (req.path == '/edu/courses/10/outcomes') {
          return (
            status: 200,
            body: ok([
              {
                'id': 1,
                'user_id': 42,
                'score_percent': 85.0,
                'result': 'passed',
                'status': 'finalized',
                'counts_for_progression': true,
                'student': {'name': 'ዳዊት ተማሪ'},
              },
            ]),
          );
        }
        throw UnimplementedError(req.path);
      }));

      final repo = EduRepository(api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eduRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWith((ref) => _testStudent),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('am')],
            locale: const Locale('en'),
            home: const EduCourseScreen(courseId: 10, initialTab: 'outcomes'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify that all 5 tabs are displayed
      expect(find.byType(Tab), findsNWidgets(5));
      expect(find.text('Course outcomes'), findsOneWidget);

      await tester.tap(find.text('Course outcomes'));
      await tester.pumpAndSettle();

      // Verify outcomes compute & finalize action buttons exist
      expect(find.text('Compute outcomes'), findsOneWidget);
      expect(find.text('Finalize outcomes'), findsOneWidget);

      // Verify student outcome item rendered
      expect(find.text('ዳዊት ተማሪ'), findsOneWidget);
      expect(find.textContaining('85.0%'), findsOneWidget);
      expect(find.textContaining('Passed'), findsOneWidget);
    });
  });
}
