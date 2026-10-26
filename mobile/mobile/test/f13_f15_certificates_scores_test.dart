import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/edu/edu_scores_screen.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/json.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';

import 'fakes.dart';

Future<ApiClient> _createApi(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EduRepository F13-F15 Endpoints', () {
    test('calls myCertificates and courseEligibleCertificates', () async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/my-certificates') {
          return (
            status: 200,
            body: ok([
              {
                'id': 1,
                'number': 'MH-2017-000001',
                'verify_code': 'ABC1234567',
                'course_name': 'ክርስቲያናዊ ሥነ ምግባር 101',
                'status': 'valid',
              }
            ]),
          );
        }
        if (req.path == '/edu/courses/5/certificates/eligible') {
          return (
            status: 200,
            body: ok([
              {
                'user_id': 10,
                'full_name': 'አበበ ተማሪ',
                'score_percent': 85.0,
                'completion_percent': 100.0,
                'eligible': true,
                'has_certificate': false,
              }
            ]),
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = EduRepository(api);
      final myCerts = await repo.myCertificates();
      expect(myCerts.length, 1);
      expect(myCerts[0]['number'], 'MH-2017-000001');

      final eligible = await repo.courseEligibleCertificates(5);
      expect(eligible.length, 1);
      expect(eligible[0]['user_id'], 10);
      expect(eligible[0]['eligible'], true);
    });

    test('calls issueCertificates and revokeCertificate', () async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/courses/5/certificates/issue') {
          expect(req.data['user_ids'], [10]);
          return (
            status: 200,
            body: ok([
              {
                'id': 101,
                'number': 'MH-2017-000001',
                'verify_code': 'XYZ9876543',
                'status': 'valid',
              }
            ]),
          );
        }
        if (req.path == '/edu/certificates/101/revoke') {
          expect(req.data['reason'], 'Grading error');
          return (
            status: 200,
            body: ok({
              'id': 101,
              'status': 'revoked',
              'revoked_reason': 'Grading error',
            }),
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = EduRepository(api);
      final issued = await repo.issueCertificates(5, [10]);
      expect(issued.length, 1);
      expect(issued[0]['id'], 101);

      final revoked = await repo.revokeCertificate(101, 'Grading error');
      expect(revoked['status'], 'revoked');
    });

    test('calls adminScores and adminActivity', () async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/admin/scores') {
          expect(req.queryParameters['year_id'], 1);
          return (
            status: 200,
            body: ok({
              'scores': [
                {
                  'user_id': 10,
                  'full_name': 'አበበ ተማሪ',
                  'academic_score': 88.5,
                  'engagement_score': 92.0,
                  'outcomes_count': 2,
                  'breakdown': {
                    'lessons': {'completed': 10, 'accessible': 10, 'rate': 100.0},
                    'assignments': {'submitted': 3, 'accessible': 3, 'rate': 100.0},
                    'quizzes': {'passed': 2, 'accessible': 3, 'rate': 66.7},
                  },
                }
              ],
            }),
          );
        }
        if (req.path == '/edu/admin/activity') {
          return (
            status: 200,
            body: ok({
              'activity': [
                {
                  'class_id': 1,
                  'class_name': 'ክፍል ሀ',
                  'lesson_opens': 45,
                  'lesson_completions': 38,
                  'assignment_submissions': 25,
                  'quiz_attempts': 30,
                  'certificates_issued': 5,
                }
              ],
            }),
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = EduRepository(api);
      final scores = await repo.adminScores(yearId: 1);
      final list = asJsonList(scores['scores']);
      expect(list.length, 1);
      expect(list[0]['academic_score'], 88.5);
      expect(list[0]['engagement_score'], 92.0);

      final act = await repo.adminActivity();
      final actList = asJsonList(act['activity']);
      expect(actList.length, 1);
      expect(actList[0]['certificates_issued'], 5);
    });
  });

  group('EduScoresScreen UI', () {
    testWidgets('renders academic and engagement scores correctly', (tester) async {
      final api = await _createApi(FakeAdapter((req) {
        if (req.path == '/edu/admin/scores') {
          return (
            status: 200,
            body: ok({
              'scores': [
                {
                  'user_id': 10,
                  'full_name': 'አበበ ተማሪ',
                  'member_id': 'መ/ሕ/ወ/10',
                  'class_name': 'ክፍል ሀ',
                  'academic_score': 88.5,
                  'engagement_score': 92.0,
                  'outcomes_count': 2,
                  'breakdown': {
                    'lessons': {'completed': 10, 'accessible': 10, 'rate': 100.0},
                    'assignments': {'submitted': 3, 'accessible': 3, 'rate': 100.0},
                    'quizzes': {'passed': 2, 'accessible': 3, 'rate': 66.7},
                  },
                }
              ],
            }),
          );
        }
        if (req.path == '/edu/admin/activity') {
          return (
            status: 200,
            body: ok({'activity': []}),
          );
        }
        return (status: 404, body: 'Not found');
      }));

      final repo = EduRepository(api);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eduRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const EduScoresScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('አበበ ተማሪ'), findsOneWidget);
      expect(find.text('88.5%'), findsOneWidget);
      expect(find.text('92.0%'), findsOneWidget);
      expect(find.text('ክፍል ሀ'), findsOneWidget);
    });
  });
}
