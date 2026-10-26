import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/edu/learn/quiz_screens.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';

import 'fakes.dart';

final quiz16Json = {
  'id': 16,
  'course_id': 7,
  'magazine_id': null,
  'course_name': 'ትምህተ ሐይማኖት',
  'class_name': '6ኛ ክፍል',
  'lesson_id': null,
  'assessment_id': null,
  'title': 'አ',
  'title_en': null,
  'instructions': null,
  'instructions_en': null,
  'opens_at': null,
  'closes_at': null,
  'results_release_at': null,
  'kind': 'quiz',
  'time_limit_minutes': null,
  'max_attempts': 1,
  'scoring': 'best',
  'shuffle': false,
  'review_policy': 'after_close',
  'status': 'draft',
  'availability': 'open',
  'question_count': 0,
  'total_points': 0,
  'has_attempts': false,
  'can_edit': true,
  'questions': [],
  'attempts_used': 0,
  'attempts_left': 1,
  'in_progress_attempt_id': null,
  'last_attempt_id': null,
  'my_score': null,
  'my_max_score': null,
  'score_hidden': false,
  'official': false,
  'needs_grading': false,
};

final quizResultsJson = {
  'quiz': quiz16Json,
  'students': [
    {
      'user_id': 1,
      'full_name': 'ዮናስ ታረቀኝ',
      'attempts': [],
      'score': null,
      'max_score': null,
      'needs_grading': false,
      'transferred_at': null,
    }
  ]
};

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
        locale: const Locale('am'),
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

  testWidgets('EduQuizEditorScreen test', (tester) async {
    final fake = FakeAdapter((req) {
      if (req.path == '/edu/quizzes/16') {
        return (status: 200, body: ok(quiz16Json));
      }
      if (req.path == '/edu/courses/7/assessments') {
        return (status: 200, body: ok([]));
      }
      if (req.path == '/edu/courses/7') {
        return (status: 200, body: ok({'id': 7, 'name': 'Course 7', 'subject_id': 2}));
      }
      if (req.path == '/edu/subjects/2') {
        return (status: 200, body: ok({'id': 2, 'title': 'Subject 2', 'units': [], 'lessons': []}));
      }
      return (status: 404, body: failBody('NOT_FOUND'));
    });

    final api = await _api(fake);
    await tester.pumpWidget(_app(const EduQuizEditorScreen(quizId: 16), api));
    await tester.pumpAndSettle();
    expect(find.byType(EduQuizEditorScreen), findsOneWidget);
  });

  testWidgets('EduQuizScreen test', (tester) async {
    final fake = FakeAdapter((req) {
      if (req.path == '/edu/quizzes/16') {
        return (status: 200, body: ok(quiz16Json));
      }
      return (status: 404, body: failBody('NOT_FOUND'));
    });

    final api = await _api(fake);
    await tester.pumpWidget(_app(const EduQuizScreen(quizId: 16), api));
    await tester.pumpAndSettle();
    expect(find.byType(EduQuizScreen), findsOneWidget);
  });

  testWidgets('EduQuizResultsScreen test', (tester) async {
    final fake = FakeAdapter((req) {
      if (req.path == '/edu/quizzes/16/results') {
        return (status: 200, body: ok(quizResultsJson));
      }
      return (status: 404, body: failBody('NOT_FOUND'));
    });

    final api = await _api(fake);
    await tester.pumpWidget(_app(const EduQuizResultsScreen(quizId: 16), api));
    await tester.pumpAndSettle();
    expect(find.byType(EduQuizResultsScreen), findsOneWidget);
  });
}
