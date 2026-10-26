import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/local_prefs.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/guidance/contextual_help_sheet.dart';
import 'package:mezmur_zelideta/features/guidance/guidance_center_screen.dart';
import 'package:mezmur_zelideta/features/guidance/tour_engine.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/admin.dart';
import 'package:mezmur_zelideta/models/guidance.dart';
import 'package:mezmur_zelideta/features/guidance/guidance_catalog.dart';
import 'package:mezmur_zelideta/features/guidance/guidance_navigator.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/repositories/guidance_repository.dart';
import 'package:mezmur_zelideta/widgets/brand.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

Future<ApiClient> _api(FakeAdapter adapter) async {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': 'test-token',
    'refresh_token': 'test-refresh',
    'token_scope': 'app',
    'device_id': 'test-device',
  });
  final store = SecureStore();
  await store.load();
  return ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))..httpClientAdapter = adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Guidance Models', () {
    test('GuidanceStep serializes and deserializes correctly', () {
      final json = {
        'step': 1,
        'title': 'Explore Categories',
        'instruction': 'Browse songs by seasonal themes.',
        'target_key': 'tour-category-chip',
        'action_route': '/home/categories',
      };
      final step = GuidanceStep.fromJson(json);
      expect(step.step, 1);
      expect(step.title, 'Explore Categories');
      expect(step.instruction, 'Browse songs by seasonal themes.');
      expect(step.targetKey, 'tour-category-chip');
      expect(step.actionRoute, '/home/categories');

      final serialized = step.toJson();
      expect(serialized['step'], 1);
      expect(serialized['title'], 'Explore Categories');
      expect(serialized['target_key'], 'tour-category-chip');
      expect(serialized['action_route'], '/home/categories');
    });

    test('GuidanceFaq serializes and deserializes correctly', () {
      final json = {
        'question': 'How do I download a hymn?',
        'answer': 'Tap the download icon beside any song.',
      };
      final faq = GuidanceFaq.fromJson(json);
      expect(faq.question, 'How do I download a hymn?');
      expect(faq.answer, 'Tap the download icon beside any song.');
      expect(faq.toJson()['question'], 'How do I download a hymn?');
    });

    test('TourProgress serializes and deserializes correctly', () {
      final now = DateTime.now();
      final tp = TourProgress(
        tourId: 'welcome_tour',
        completed: true,
        dismissed: false,
        completedAt: now,
      );
      final json = tp.toJson();
      expect(json['tour_id'], 'welcome_tour');
      expect(json['completed'], true);
      expect(json['dismissed'], false);

      final reconstructed = TourProgress.fromJson(json);
      expect(reconstructed.tourId, 'welcome_tour');
      expect(reconstructed.completed, true);
      expect(reconstructed.dismissed, false);
    });

    test('GuidanceArticle serializes and deserializes correctly', () {
      final json = {
        'id': 101,
        'slug': 'test-guide',
        'title': 'Test Guide Title',
        'category': 'programs',
        'target_role': 'member',
        'target_screen': '/programs',
        'required_permission': 'programs.manage',
        'tour_id': 'programs_tour',
        'overview': 'This is a test overview.',
        'estimated_read_minutes': 4,
        'status': 'published',
        'steps': [
          {
            'step': 1,
            'title': 'Step 1',
            'instruction': 'Do this first',
            'target_key': 'key-1',
          }
        ],
        'quick_tips': ['Tip 1', 'Tip 2'],
        'faqs': [
          {
            'question': 'Q1?',
            'answer': 'A1.',
          }
        ],
      };

      final article = GuidanceArticle.fromJson(json);
      expect(article.id, 101);
      expect(article.slug, 'test-guide');
      expect(article.title, 'Test Guide Title');
      expect(article.category, 'programs');
      expect(article.targetRole, 'member');
      expect(article.targetScreen, '/programs');
      expect(article.requiredPermission, 'programs.manage');
      expect(article.tourId, 'programs_tour');
      expect(article.overview, 'This is a test overview.');
      expect(article.estimatedReadMinutes, 3);
      expect(article.status, 'published');
      expect(article.steps.length, 1);
      expect(article.steps.first.title, 'Step 1');
      expect(article.quickTips.length, 2);
      expect(article.faqs.length, 1);

      final serialized = article.toJson();
      expect(serialized['slug'], 'test-guide');
      expect(serialized['status'], 'published');
      expect((serialized['steps'] as List).length, 1);
    });
  });

  group('GuidanceRepository', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('fetchArticles returns articles from API when online', () async {
      final apiClient = await _api(FakeAdapter((req) {
        if (req.path.endsWith('/guidance')) {
          return (
            status: 200,
            body: ok([
              {
                'id': 1,
                'slug': 'programs-guide',
                'title': 'Programs & Attendance Guide',
                'category': 'programs',
                'target_role': 'member',
                'target_screen': '/programs',
                'status': 'published',
                'steps': [],
                'quick_tips': [],
                'faqs': [],
              }
            ])
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      final repo = GuidanceRepository(apiClient, prefs);

      final articles = await repo.fetchArticles(category: 'programs');
      expect(articles.length, 1);
      expect(articles.first.slug, 'programs-guide');
      expect(articles.first.category, 'programs');
    });

    test('fetchArticles falls back to offline default seed when API fails', () async {
      final apiClient = await _api(FakeAdapter((req) {
        return (status: 500, body: failBody('SERVER_ERROR'));
      }));

      final repo = GuidanceRepository(apiClient, prefs);

      final articles = await repo.fetchArticles();
      expect(articles.isNotEmpty, true);
      expect(articles.any((a) => a.slug == 'welcome-onboarding'), true);
    });

    test('fetchContextual resolves screen matching', () async {
      final apiClient = await _api(FakeAdapter((req) {
        if (req.uri.path.endsWith('/guidance/contextual')) {
          return (
            status: 200,
            body: ok({
              'id': 2,
              'slug': 'attendance-guide',
              'title': 'Attendance Guide',
              'category': 'attendance',
              'target_role': 'member',
              'target_screen': '/attendance',
              'status': 'published',
              'steps': [],
              'quick_tips': [],
              'faqs': [],
            })
          );
        }
        return (status: 404, body: failBody('NOT_FOUND'));
      }));

      final repo = GuidanceRepository(apiClient, prefs);

      final match = await repo.fetchContextual('/attendance');
      expect(match, isNotNull);
      expect(match?.slug, 'attendance-guide');
      expect(match?.targetScreen, '/attendance');
    });

    test('saveTourProgress and fetchTourProgressMap persistence', () async {
      final apiClient = await _api(FakeAdapter((req) {
        if (req.path.endsWith('/guidance/progress')) {
          return (status: 200, body: ok({'saved': true}));
        }
        return (status: 200, body: ok([]));
      }));

      final repo = GuidanceRepository(apiClient, prefs);

      await repo.saveTourProgress('welcome_tour', completed: true);

      final map = await repo.fetchTourProgressMap();
      expect(map.containsKey('welcome_tour'), true);
      expect(map['welcome_tour']?.completed, true);
      expect(map['welcome_tour']?.dismissed, false);

      await repo.resetTourProgress(tourId: 'welcome_tour');
      final afterReset = await repo.fetchTourProgressMap();
      expect(afterReset.containsKey('welcome_tour'), false);
    });

    test('admin CRUD operations call correct endpoints', () async {
      var created = false;
      var updated = false;
      var published = false;
      var retired = false;
      var deleted = false;

      final apiClient = await _api(FakeAdapter((req) {
        if (req.method == 'POST' && req.path.endsWith('/guidance/admin')) {
          created = true;
          return (
            status: 201,
            body: ok({
              'id': 50,
              'slug': 'new-guide',
              'title': 'New Guide',
              'category': 'general',
              'target_role': 'member',
              'status': 'draft',
              'steps': [],
              'quick_tips': [],
              'faqs': [],
            })
          );
        }
        if (req.method == 'PATCH' && req.path.contains('/guidance/admin/50')) {
          updated = true;
          return (
            status: 200,
            body: ok({
              'id': 50,
              'slug': 'new-guide',
              'title': 'Updated Title',
              'category': 'general',
              'target_role': 'member',
              'status': 'draft',
              'steps': [],
              'quick_tips': [],
              'faqs': [],
            })
          );
        }
        if (req.method == 'POST' && req.path.contains('/guidance/admin/50/publish')) {
          published = true;
          return (
            status: 200,
            body: ok({
              'id': 50,
              'slug': 'new-guide',
              'title': 'Updated Title',
              'category': 'general',
              'target_role': 'member',
              'status': 'published',
              'steps': [],
              'quick_tips': [],
              'faqs': [],
            })
          );
        }
        if (req.method == 'POST' && req.path.contains('/guidance/admin/50/retire')) {
          retired = true;
          return (
            status: 200,
            body: ok({
              'id': 50,
              'slug': 'new-guide',
              'title': 'Updated Title',
              'category': 'general',
              'target_role': 'member',
              'status': 'retired',
              'steps': [],
              'quick_tips': [],
              'faqs': [],
            })
          );
        }
        if (req.method == 'DELETE' && req.path.contains('/guidance/admin/50')) {
          deleted = true;
          return (status: 200, body: ok({'deleted': true}));
        }
        return (status: 200, body: ok([]));
      }));

      final repo = GuidanceRepository(apiClient, prefs);

      final newArticle = await repo.adminCreate({
        'title': 'New Guide',
        'slug': 'new-guide',
        'category': 'general',
        'target_role': 'member',
      });
      expect(created, true);
      expect(newArticle.id, 50);

      final updatedArticle = await repo.adminUpdate(50, {'title': 'Updated Title'});
      expect(updated, true);
      expect(updatedArticle.title, 'Updated Title');

      final pub = await repo.adminPublish(50);
      expect(published, true);
      expect(pub.status, 'published');

      final ret = await repo.adminRetire(50);
      expect(retired, true);
      expect(ret.status, 'retired');

      await repo.adminDelete(50);
      expect(deleted, true);
    });
  });

  group('Perm.guidanceManage permission definition', () {
    test('Perm.guidanceManage equals guidance.manage', () {
      expect(Perm.guidanceManage, 'guidance.manage');
    });
  });

  group('TourCatalog', () {
    test('covers all primary tours required by specification', () {
      final tours = TourCatalog.tours;
      expect(tours.containsKey('welcome_tour'), true);
      expect(tours.containsKey('mezmur_tour'), true);
      expect(tours.containsKey('programs_tour'), true);
      expect(tours.containsKey('attendance_tour'), true);
      expect(tours.containsKey('edu_tour'), true);
      expect(tours.containsKey('projects_tour'), true);
      expect(tours.containsKey('library_tour'), true);
      expect(tours.containsKey('choir_tour'), true);
      expect(tours.containsKey('admin_tour'), true);

      // Verify each tour has non-empty steps with descriptions
      for (final entry in tours.entries) {
        expect(entry.value.isNotEmpty, true, reason: 'Tour ${entry.key} must have steps');
        for (final step in entry.value) {
          expect(step.title.isNotEmpty, true);
          expect(step.description.isNotEmpty, true);
        }
      }
    });
  });

  group('Guidance UI Widgets', () {
    Widget testWrapper(Widget child, [SharedPreferences? prefs, GuidanceRepository? repo]) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          if (prefs != null)
            localPrefsProvider.overrideWithValue(LocalPrefs(prefs)),
          if (repo != null)
            guidanceRepositoryProvider.overrideWithValue(repo),
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
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('ContextualHelpButton renders and opens contextual help sheet on tap', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final apiClient = await _api(FakeAdapter((req) => (status: 200, body: ok([]))));
      final repo = GuidanceRepository(apiClient, prefs);

      await tester.pumpWidget(testWrapper(
        const ContextualHelpButton(screenRoute: '/programs'),
        prefs,
        repo,
      ));
      await tester.pumpAndSettle();

      final button = find.byType(ContextualHelpButton);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      // Bottom sheet should open with help content
      expect(find.byType(ContextualHelpSheet), findsOneWidget);
    });

    testWidgets('GuidanceCenterScreen renders search bar and category chips', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final apiClient = await _api(FakeAdapter((req) => (status: 200, body: ok([]))));
      final repo = GuidanceRepository(apiClient, prefs);

      await tester.pumpWidget(testWrapper(
        const GuidanceCenterScreen(),
        prefs,
        repo,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);
      expect(find.text('የመመሪያ ማዕከል'), findsOneWidget);
    });
  });

  group('GuidanceCatalog', () {
    test('contains comprehensive catalog of built-in articles', () {
      const adminUser = AppUser(
        id: 1,
        fullName: 'Super Admin',
        phone: '0911111111',
        status: 'active',
        accountType: 'admin',
        roleLevel: 100,
        permissions: {'users.view', 'guidance.manage', 'programs.manage', 'attendance.rules', 'notifications.send', 'reports.view', 'projects.view', 'attendance.manage'},
      );

      final adminAll = GuidanceCatalog.getAllArticles(user: adminUser);
      expect(adminAll.length, 71);

      final memberAll = GuidanceCatalog.getAllArticles();
      expect(memberAll.length, 21);

      for (final article in adminAll) {
        expect(article.slug.isNotEmpty, true);
        expect(article.title.isNotEmpty, true);
        expect(article.summary?.isNotEmpty ?? false, true);
        expect(article.content.isNotEmpty, true);
        expect(article.steps.isNotEmpty, true);
        expect(article.tips.isNotEmpty, true);
        expect(article.faqItems.isNotEmpty, true);

        // Verify bilingual extraction works cleanly without errors
        expect(article.titleFor('am').isNotEmpty, true);
        expect(article.titleFor('en').isNotEmpty, true);
      }
    });

    test('Guidance bilingual getters return clean natural text in both languages', () {
      const article = GuidanceArticle(
        id: 99,
        slug: 'test-bilingual',
        category: 'programs',
        title: 'የመርሐ ግብር ቀን መቁጠሪያ (Programs Calendar)',
        summary: 'የመርሐ ግብሮች አጠቃላይ ዝርዝር።',
        content: 'የመርሐ ግብሮች ዝርዝር ማብራሪያ።',
        steps: [
          GuidanceStep(
            step: 1,
            title: 'ማንቂያ ማብራት (Turn on Alarm)',
            description: 'የደወል ምልክቱን በመጫን የ30 ደቂቃ ማንቂያ ያብሩ።',
            tip: 'ደወሉን ያብሩ።',
          ),
        ],
        faqItems: [
          GuidanceFaq(
            question: 'ማንቂያው በሰዓቱ ይደውላል? (Will the alarm ring on time?)',
            answer: 'አዎ በሰዓቱ ይደውላል።',
          ),
        ],
      );

      // Amharic: no parentheticals
      expect(article.titleFor('am'), 'የመርሐ ግብር ቀን መቁጠሪያ');
      expect(article.steps.first.titleFor('am'), 'ማንቂያ ማብራት');
      expect(article.faqItems.first.questionFor('am'), 'ማንቂያው በሰዓቱ ይደውላል?');

      // English: clean English extracted from parentheses
      expect(article.titleFor('en'), 'Programs Calendar');
      expect(article.steps.first.titleFor('en'), 'Turn on Alarm');
      expect(article.faqItems.first.questionFor('en'), 'Will the alarm ring on time?');
    });

    test('hierarchical resolution maps sub-routes to parent article', () {
      final matchExact = GuidanceCatalog.getForScreen('/programs');
      expect(matchExact, isNotNull);
      expect(matchExact?.slug, 'programs-and-alarms');

      final matchSub = GuidanceCatalog.getForScreen('/programs/42');
      expect(matchSub, isNotNull);
      expect(matchSub?.slug, 'programs-and-alarms');
    });

    test('role and permission gating in GuidanceCatalog', () {
      // Non-admin user should not receive admin articles
      const normalUser = AppUser(
        id: 10,
        fullName: 'Regular Member',
        phone: '0911000000',
        status: 'active',
        accountType: 'user',
        permissions: {},
      );

      final adminArticle = GuidanceCatalog.getForScreen('/admin/users', user: normalUser);
      expect(adminArticle, isNull);

      const adminUser = AppUser(
        id: 1,
        fullName: 'Super Admin',
        phone: '0911111111',
        status: 'active',
        accountType: 'admin',
        roleLevel: 100,
        permissions: {'users.view', 'guidance.manage'},
      );

      final allowedArticle = GuidanceCatalog.getForScreen('/admin/users', user: adminUser);
      expect(allowedArticle, isNotNull);
      expect(allowedArticle?.slug, 'admin-users-management');
    });
  });

  group('GuidanceNavigator Registry', () {
    test('destinationRegistry covers essential app routes and provides fallback', () {
      final registry = GuidanceNavigator.destinationRegistry;
      expect(registry.containsKey('/hub'), true);
      expect(registry.containsKey('/home'), true);
      expect(registry.containsKey('/programs'), true);
      expect(registry.containsKey('/attendance'), true);
      expect(registry.containsKey('/edu'), true);
      expect(registry.containsKey('/library'), true);
      expect(registry.containsKey('/choir'), true);
      expect(registry.containsKey('/projects'), true);
      expect(registry.containsKey('/settings/profile'), true);
      expect(registry.containsKey('/settings/payments'), true);
      expect(registry.containsKey('/admin/users'), true);
      expect(registry.containsKey('/admin/programs'), true);
      expect(registry.containsKey('/admin/attendance/rules'), true);

      // Verify each registry destination has a title and fallback
      for (final entry in registry.entries) {
        expect(entry.value.title.isNotEmpty, true);
        expect(entry.value.fallbackRoute.isNotEmpty, true);
        expect(entry.value.fallbackTitle.isNotEmpty, true);
      }
    });
  });

  group('TourController & Interactive Tours', () {
    testWidgets('advances through tour steps via Next button and finishes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('am'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  TourController.instance.startTour(ctx, 'library_tour', force: true);
                },
                child: const Text('Start Tour'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Trigger tour
      await tester.tap(find.text('Start Tour'));
      await tester.pumpAndSettle();

      // Step 1: Favorites
      expect(find.text('የተወደዱ መዝሙራት'), findsOneWidget);
      expect(find.text('ደረጃ 1 ከ 2'), findsOneWidget);
      expect(find.text('ቀጣይ →'), findsOneWidget);

      // Tap Next button
      await tester.tap(find.text('ቀጣይ →'));
      await tester.pumpAndSettle();

      // Step 2: Offline Downloads
      expect(find.text('የወረዱ መዝሙራት'), findsOneWidget);
      expect(find.text('ደረጃ 2 ከ 2'), findsOneWidget);
      expect(find.text('አጠናቅቅ ✓'), findsOneWidget);

      // Tap Finish button
      await tester.tap(find.text('አጠናቅቅ ✓'));
      await tester.pumpAndSettle();

      // Tour dismissed
      expect(find.text('የወረዱ መዝሙራት'), findsNothing);
      expect(TourController.instance.isRunning, isFalse);
    });

    test('TourKeys moduleKeys maps all admin routes to GlobalKeys for spotlight and scrolling', () {
      final keys = TourKeys.moduleKeys;
      expect(keys.containsKey('/admin/users'), true);
      expect(keys.containsKey('/admin/attendance'), true);
      expect(keys.containsKey('/admin/notify'), true);
      expect(keys.containsKey('/admin/departments'), true);
      expect(keys.containsKey('/admin/payments'), true);
      expect(keys.containsKey('/admin/fines'), true);
      expect(keys.containsKey('/admin/items'), true);
      expect(keys.containsKey('/admin/borrowings'), true);
      expect(keys.containsKey('/admin/selections'), true);
      expect(keys.containsKey('/admin/categories'), true);
      expect(keys.containsKey('/admin/mezmurs'), true);
      expect(keys.containsKey('/admin/admins'), true);
      expect(keys.containsKey('/admin/roles'), true);
      expect(keys.containsKey('/admin/settings'), true);
      expect(keys.containsKey('/admin/guidance'), true);
      expect(keys.containsKey('/admin/releases'), true);

      // Verify keys are instantiated GlobalKeys
      for (final key in keys.values) {
        expect(key, isA<GlobalKey>());
      }
    });

    test('Module background kinds resolution assigns general church logo pattern to all non-mezmur/non-edu routes', () {
      expect(moduleKindOf('/hub'), ModuleBackgroundKind.general);
      expect(moduleKindOf('/admin'), ModuleBackgroundKind.general);
      expect(moduleKindOf('/admin/guidance'), ModuleBackgroundKind.general);
      expect(moduleKindOf('/settings'), ModuleBackgroundKind.general);
      expect(moduleKindOf('/settings/guidance'), ModuleBackgroundKind.general);
      expect(moduleKindOf('/programs'), ModuleBackgroundKind.general);
      expect(moduleKindOf('/edu'), ModuleBackgroundKind.education);
      expect(moduleKindOf('/edu/courses'), ModuleBackgroundKind.education);
      expect(moduleKindOf('/home'), ModuleBackgroundKind.mezmur);
      expect(moduleKindOf('/library'), ModuleBackgroundKind.mezmur);
      expect(moduleKindOf('/player'), ModuleBackgroundKind.mezmur);

      // Section-based resolution
      expect(moduleKindFor('/hub', 'education'), ModuleBackgroundKind.education);
      expect(moduleKindFor('/hub', 'mezmur'), ModuleBackgroundKind.mezmur);
      expect(moduleKindFor('/hub', 'hub'), ModuleBackgroundKind.general);
    });

    test('Guidance routes are properly registered and accessible in destinationRegistry', () {
      expect(GuidanceNavigator.destinationRegistry.containsKey('/guidance'), true);
      expect(GuidanceNavigator.destinationRegistry.containsKey('/settings/guidance'), true);
      expect(GuidanceNavigator.destinationRegistry['/guidance']?.title, contains('Guidance Center'));
      expect(GuidanceNavigator.destinationRegistry['/settings/guidance']?.title, contains('Guidance Center'));
    });
  });
}
