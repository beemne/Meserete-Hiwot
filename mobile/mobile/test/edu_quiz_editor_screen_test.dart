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
import 'package:mezmur_zelideta/features/edu/learn/quiz_screens.dart';
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

  testWidgets('EduQuizEditorScreen loads newly created quiz and renders settings without crashing', (tester) async {
    final fake = FakeAdapter((req) {
      if (req.path == '/edu/quizzes/50') {
        return (
          status: 200,
          body: ok({
            'id': 50,
            'title': 'Test Quiz Title',
            'title_en': 'Test Quiz Title EN',
            'course_id': 12,
            'status': 'draft',
            'max_attempts': 1,
            'scoring': 'best',
            'review_policy': 'after_close',
            'shuffle': false,
            'questions': [],
          }),
        );
      }
      if (req.path == '/edu/courses/12/assessments') {
        // Return 403 or empty to test resilience
        return (status: 403, body: failBody('NOT_TEACHER'));
      }
      if (req.path == '/edu/courses/12') {
        return (status: 200, body: ok({'id': 12, 'name': 'Course 12', 'subject_id': 8}));
      }
      if (req.path == '/edu/subjects/8') {
        return (status: 200, body: ok({'id': 8, 'title': 'Subject 8', 'units': [], 'lessons': []}));
      }
      return (status: 404, body: failBody('NOT_FOUND'));
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = await _api(fake);
    await tester.pumpWidget(_app(const EduQuizEditorScreen(quizId: 50), api));

    // Initially loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Pump to complete async _load
    await tester.pumpAndSettle();

    // Verify quiz title is loaded into text field
    expect(find.text('Test Quiz Title'), findsWidgets);
    expect(find.text('Test Quiz Title EN'), findsOneWidget);

    // Verify settings headers and questions section
    expect(find.text('Quiz settings'), findsOneWidget);
    expect(find.text('Questions'), findsOneWidget);

    // Verify empty questions card is displayed
    expect(find.text('No questions yet'), findsOneWidget);

    // Tap "Add question" button
    final addQBtn = find.text('Add question').first;
    await tester.tap(addQBtn);
    await tester.pumpAndSettle();

    // A question editor should now be present
    expect(find.text('Question 1'), findsOneWidget);
  });

  testWidgets('EduQuizEditorScreen saves question and handles single-choice answers safely', (tester) async {
    Map<String, dynamic>? updatedQuestionsBody;
    final fake = FakeAdapter((req) {
      if (req.path == '/edu/quizzes/50') {
        return (
          status: 200,
          body: ok({
            'id': 50,
            'title': 'Math Quiz',
            'course_id': 10,
            'status': 'draft',
            'max_attempts': 2,
            'scoring': 'best',
            'review_policy': 'after_submit',
            'shuffle': true,
            'questions': [],
          }),
        );
      }
      if (req.path == '/edu/courses/10/assessments') {
        return (status: 200, body: ok([]));
      }
      if (req.path == '/edu/courses/10') {
        return (status: 200, body: ok({'id': 10, 'name': 'Course 10'}));
      }
      if (req.path == '/edu/quizzes/50/questions' && req.method == 'PUT') {
        updatedQuestionsBody = body(req);
        return (
          status: 200,
          body: ok({
            'id': 50,
            'title': 'Math Quiz',
            'course_id': 10,
            'status': 'draft',
            'questions': [
              {
                'id': 1,
                'type': 'single',
                'prompt': 'What is 2+2?',
                'options': [
                  {'id': 'a', 'text': '3'},
                  {'id': 'b', 'text': '4'},
                ],
                'answer': 'b',
                'points': 1,
              }
            ],
          }),
        );
      }
      return (status: 404, body: failBody('NOT_FOUND'));
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = await _api(fake);
    await tester.pumpWidget(_app(const EduQuizEditorScreen(quizId: 50), api));
    await tester.pumpAndSettle();

    // Tap "Add question"
    await tester.tap(find.text('Add question').first);
    await tester.pumpAndSettle();

    // Fill the question prompt (which has label 'Question (English)' or 'Question (አማርኛ) *')
    final promptFinder = find.widgetWithText(TextField, 'Question (English)');
    expect(promptFinder, findsOneWidget);
    await tester.enterText(promptFinder, 'What is 2+2?');
    await tester.pumpAndSettle();

    // Fill options
    final opt1 = find.widgetWithText(TextField, 'Option 1');
    final opt2 = find.widgetWithText(TextField, 'Option 2');
    if (opt1.evaluate().isNotEmpty && opt2.evaluate().isNotEmpty) {
      await tester.enterText(opt1, '3');
      await tester.enterText(opt2, '4');
      await tester.pumpAndSettle();
    }

    // Select second option as correct
    final radios = find.byIcon(Icons.radio_button_unchecked_rounded);
    if (radios.evaluate().length >= 2) {
      await tester.tap(radios.at(1));
      await tester.pumpAndSettle();
    }

    // Save questions
    final saveQBtn = find.text('Save questions');
    if (saveQBtn.evaluate().isNotEmpty) {
      await tester.tap(saveQBtn);
      await tester.pump();
      await tester.pumpAndSettle();
    }

    expect(updatedQuestionsBody != null, isTrue);
    final qList = updatedQuestionsBody!['questions'] as List;
    expect(qList.length, 1);
    expect(qList.first['type'], 'single');
  });
}
