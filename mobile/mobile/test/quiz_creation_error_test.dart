import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/l10n/error_text.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/network/api_exception.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';

import 'fakes.dart';

Future<ApiClient> _makeApi(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 'test-token', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Education Quiz Error Text Handling', () {
    late AppLocalizations lEn;
    late AppLocalizations lAm;

    setUpAll(() async {
      lEn = await AppLocalizations.delegate.load(const Locale('en'));
      lAm = await AppLocalizations.delegate.load(const Locale('am'));
    });

    test('Maps NOT_TEACHER to informative message', () {
      const err = ApiException(code: 'NOT_TEACHER', status: 403);
      expect(errorText(lEn, err), 'Only the course teacher can do this');
      expect(errorText(lAm, err), 'የትምህርቱ አስተማሪ ብቻ ነው ይህን ማድረግ የሚችለው');
    });

    test('Maps NOT_SUBJECT_EDITOR to localized message', () {
      const err = ApiException(code: 'NOT_SUBJECT_EDITOR', status: 403);
      expect(errorText(lEn, err), lEn.errNotSubjectEditor);
      expect(errorText(lAm, err), lAm.errNotSubjectEditor);
    });

    test('Maps COURSE_NOT_FOUND, LESSON_NOT_FOUND, ASSESSMENT_NOT_FOUND to friendly text', () {
      expect(errorText(lEn, const ApiException(code: 'COURSE_NOT_FOUND', status: 422)), 'Course not found');
      expect(errorText(lAm, const ApiException(code: 'COURSE_NOT_FOUND', status: 422)), 'የትምህርት ክፍለ ጊዜ አልተገኘም');

      expect(errorText(lEn, const ApiException(code: 'LESSON_NOT_FOUND', status: 422)), 'Lesson not found');
      expect(errorText(lAm, const ApiException(code: 'LESSON_NOT_FOUND', status: 422)), 'ትምህርቱ አልተገኘም');

      expect(errorText(lEn, const ApiException(code: 'ASSESSMENT_NOT_FOUND', status: 422)), 'Assessment not found');
      expect(errorText(lAm, const ApiException(code: 'ASSESSMENT_NOT_FOUND', status: 422)), 'የውጤት መመዝገቢያ አልተገኘም');
    });

    test('Maps CLOSES_BEFORE_OPENS and ASSESSMENT_REQUIRED', () {
      expect(errorText(lEn, const ApiException(code: 'CLOSES_BEFORE_OPENS', status: 422)), 'Closing date must be after opening date');
      expect(errorText(lAm, const ApiException(code: 'CLOSES_BEFORE_OPENS', status: 422)), 'የመዝጊያ ቀን ከመክፈቻ ቀን በኋላ መሆን አለበት');

      expect(errorText(lEn, const ApiException(code: 'ASSESSMENT_REQUIRED', status: 422)), 'An assessment is required for this exam');
      expect(errorText(lAm, const ApiException(code: 'ASSESSMENT_REQUIRED', status: 422)), 'ለፈተናው የውጤት መመዝገቢያ ያስፈልጋል');
    });

    test('Surfaces clean server messages without raw SQL or technical details', () {
      const cleanErr = ApiException(code: 'CUSTOM_FAIL', status: 400, message: 'Please select an active semester');
      expect(errorText(lEn, cleanErr), 'Please select an active semester');

      const sqlErr = ApiException(code: 'SERVER_ERROR', status: 500, message: 'SQLSTATE[42S22]: Column not found');
      expect(errorText(lEn, sqlErr), lEn.errorServer);
    });

    test('Field-level errors for quiz creation validation are translated in fieldErrorsSummary', () {
      const err = ApiException(
        code: 'VALIDATION_ERROR',
        status: 422,
        fieldErrors: {'closes_at': 'CLOSES_BEFORE_OPENS', 'assessment_id': 'ASSESSMENT_REQUIRED'},
      );
      final summary = fieldErrorsSummary(lEn, err, (f) => f);
      expect(summary, contains('Closing date must be after opening date'));
      expect(summary, contains('Assessment is required'));
    });
  });

  group('EduRepository createSubjectQuiz', () {
    test('creates quiz for subject successfully', () async {
      final fake = FakeAdapter((req) {
        expect(req.path, '/edu/subjects/12/quizzes');
        expect(req.method, 'POST');
        expect(body(req), {'title': 'Week 1 Quiz'});
        return (
          status: 200,
          body: ok({
            'id': 101,
            'title': 'Week 1 Quiz',
            'course_id': 5,
            'status': 'draft',
          }),
        );
      });

      final api = await _makeApi(fake);
      final repo = EduRepository(api);
      final res = await repo.createSubjectQuiz(12, {'title': 'Week 1 Quiz'});

      expect(res['id'], 101);
      expect(res['title'], 'Week 1 Quiz');
      expect(res['status'], 'draft');
    });
  });
}
