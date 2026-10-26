import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/app/router.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';

import 'fakes.dart';

Future<ApiClient> _api(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

const adminUser = AppUser(
  id: 1,
  fullName: 'Admin',
  phone: '0911000000',
  roleSlug: 'high_admin',
  roleName: 'High Admin',
  roleLevel: 100,
  roles: ['high_admin'],
  permissions: {
    'education.manage',
    'education.content',
    'education.reports',
  },
  moduleAccess: ModuleAccess(mezmur: true, education: true),
);

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._targetUser);
  final AppUser? _targetUser;
  @override
  SessionState build() => _targetUser != null ? SignedIn(_targetUser) : const SignedOut();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Navigate to /edu/admin/quizzes and click Edit', (tester) async {
    final fake = FakeAdapter((req) {
      if (req.path == '/edu/quizzes' || req.path.startsWith('/edu/courses') && req.path.endsWith('/quizzes')) {
        return (status: 200, body: ok([
          {
            'id': 16,
            'title': 'እ',
            'status': 'draft',
            'question_count': 0,
            'time_limit_minutes': null,
          }
        ]));
      }
      if (req.path == '/edu/quizzes/16') {
        return (status: 200, body: ok({
          'id': 16,
          'title': 'እ',
          'course_id': 7,
          'status': 'draft',
          'questions': [],
        }));
      }
      if (req.path == '/edu/quizzes/16/results') {
        return (status: 200, body: ok({
          'quiz': {'id': 16, 'title': 'እ'},
          'students': [],
        }));
      }
      if (req.path == '/edu/subjects') {
        return (status: 200, body: ok([]));
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
      return (status: 200, body: ok({}));
    });

    final api = await _api(fake);
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(adminUser),
        sessionProvider.overrideWith(() => _FakeSessionController(adminUser)),
        eduRepositoryProvider.overrideWithValue(EduRepository(api)),
      ],
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      container.dispose();
    });

    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    router.go('/edu/admin/quizzes');
    await tester.pumpAndSettle();

    // Verify we are on Quizzes & Evaluations Hub
    expect(find.text('Quizzes & Evaluations Hub'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);

    // Click Edit
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    print('Current location after Edit: ${router.routeInformationProvider.value.uri.path}');
  });
}
