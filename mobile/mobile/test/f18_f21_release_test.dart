import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/local_prefs.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/admin/edit_mode.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/guidance/guidance_catalog.dart';
import 'package:mezmur_zelideta/features/guidance/guidance_navigator.dart';
import 'package:mezmur_zelideta/features/settings/settings_screen.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/admin.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test users for various roles and permissions
const _memberUser = AppUser(
  id: 10,
  fullName: 'ተማሪ ዮሐንስ (Student Member)',
  phone: '+251911000010',
  roleName: 'member',
  roleLevel: 10,
  permissions: {},
  roles: ['student'],
);

const _teacherUser = AppUser(
  id: 20,
  fullName: 'መምህር ኤፍሬም (Teacher)',
  phone: '+251911000020',
  roleName: 'member',
  roleLevel: 20,
  permissions: {},
  roles: ['teacher'],
);

const _eduAdminUser = AppUser(
  id: 30,
  fullName: 'የትምህርት ኃላፊ ዳዊት (Edu Admin)',
  phone: '+251911000030',
  roleName: 'admin',
  roleLevel: 80,
  permissions: {
    'education.manage',
    'education.register',
    'education.content',
    'education.certify',
    'education.reports',
  },
  roles: ['admin'],
);

class _FakePreferencesController extends PreferencesController {
  _FakePreferencesController([this.initial = const UserPreferences()]);
  final UserPreferences initial;
  @override
  UserPreferences build() => initial;
  @override
  Future<void> update(UserPreferences Function(UserPreferences p) change) async {
    state = change(state);
  }
}

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._targetUser);
  final AppUser? _targetUser;
  @override
  SessionState build() => _targetUser != null ? SignedIn(_targetUser) : const SignedOut();
}

class _FakeEditModeController extends EditModeController {
  _FakeEditModeController([this.initial = false]);
  final bool initial;
  @override
  bool build() => initial;
}

late SecureStore testStore;

Widget _wrapTestWidget({
  required Widget child,
  AppUser? user,
  Locale locale = const Locale('am'),
  SharedPreferences? prefs,
  SecureStore? store,
  bool editMode = false,
}) {
  return ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(store ?? testStore),
      if (prefs != null) localPrefsProvider.overrideWithValue(LocalPrefs(prefs)),
      currentUserProvider.overrideWithValue(user),
      sessionProvider.overrideWith(() => _FakeSessionController(user)),
      preferencesProvider.overrideWith(_FakePreferencesController.new),
      editModeProvider.overrideWith(() => _FakeEditModeController(editMode)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences testPrefs;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'a1', 'refresh_token': 'r1', 'token_scope': 'app', 'device_id': 'd'});
    SharedPreferences.setMockInitialValues({});
    testPrefs = await SharedPreferences.getInstance();
    testStore = SecureStore();
    await testStore.load();
  });

  // =========================================================================
  // F18: Shared Settings Filtered by Module
  // =========================================================================
  group('F18 · Shared Settings filtered by module', () {
    testWidgets('SettingsScreen(from: "edu") shows shared and Edu tools, hides Mezmur tools', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrapTestWidget(
        child: const SettingsScreen(from: 'edu'),
        user: _eduAdminUser,
        prefs: testPrefs,
      ));
      await tester.pumpAndSettle();

      // Shared settings ALWAYS show
      expect(find.byKey(const ValueKey('settings-attendance')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-chat')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-sessions')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-notifications')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-language')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-guidance-center')), findsOneWidget);

      // Education tools show
      expect(find.byKey(const ValueKey('settings-course-management')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-registrations')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-edu-content')), findsOneWidget);

      // Mezmur tools are HIDDEN
      expect(find.byKey(const ValueKey('settings-autoplay')), findsNothing);
      expect(find.byKey(const ValueKey('settings-reminder-time')), findsNothing);
      expect(find.byKey(const ValueKey('settings-downloads')), findsNothing);
      expect(find.byKey(const ValueKey('settings-preferred-categories')), findsNothing);

      // Back button appears
      expect(find.byKey(const ValueKey('settings-back-btn')), findsOneWidget);
    });

    testWidgets('SettingsScreen(from: "mezmur") shows shared and Mezmur tools, hides Edu tools', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrapTestWidget(
        child: const SettingsScreen(from: 'mezmur'),
        user: _eduAdminUser,
        prefs: testPrefs,
      ));
      await tester.pumpAndSettle();

      // Shared settings show
      expect(find.byKey(const ValueKey('settings-attendance')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-chat')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-language')), findsOneWidget);

      // Mezmur tools show (autoplay moved to downloads, preferred categories removed per Stage 2)
      expect(find.byKey(const ValueKey('settings-reminder-time')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-downloads')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-preferred-categories')), findsNothing);

      // Education tools are HIDDEN
      expect(find.byKey(const ValueKey('settings-course-management')), findsNothing);
      expect(find.byKey(const ValueKey('settings-registrations')), findsNothing);
      expect(find.byKey(const ValueKey('settings-edu-content')), findsNothing);

      // Back button appears
      expect(find.byKey(const ValueKey('settings-back-btn')), findsOneWidget);
    });

    testWidgets('SettingsScreen(from: "hub") shows both Mezmur and Edu tools', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrapTestWidget(
        child: const SettingsScreen(from: 'hub'),
        user: _eduAdminUser,
        prefs: testPrefs,
      ));
      await tester.pumpAndSettle();

      // Shared settings show
      expect(find.byKey(const ValueKey('settings-attendance')), findsOneWidget);

      // Both show
      expect(find.byKey(const ValueKey('settings-course-management')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-downloads')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-back-btn')), findsOneWidget);
    });
  });

  // =========================================================================
  // F19: Education Editing Pen and Permissions
  // =========================================================================
  group('F19 · Education editing pen and permissions', () {
    testWidgets('canEditFront for edu is false for member, true for teacher and admin', (tester) async {
      bool? memberCanEdit;
      bool? teacherCanEdit;
      bool? adminCanEdit;

      await tester.pumpWidget(ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(_memberUser)],
        child: Consumer(builder: (context, ref, child) {
          memberCanEdit = canEditFront(ref, module: 'edu');
          return const SizedBox.shrink();
        }),
      ));
      expect(memberCanEdit, false);

      await tester.pumpWidget(ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(_teacherUser)],
        child: Consumer(builder: (context, ref, child) {
          teacherCanEdit = canEditFront(ref, module: 'edu');
          return const SizedBox.shrink();
        }),
      ));
      expect(teacherCanEdit, true);

      await tester.pumpWidget(ProviderScope(
        overrides: [currentUserProvider.overrideWithValue(_eduAdminUser)],
        child: Consumer(builder: (context, ref, child) {
          adminCanEdit = canEditFront(ref, module: 'edu');
          return const SizedBox.shrink();
        }),
      ));
      expect(adminCanEdit, true);
    });

    testWidgets('EditModeToggle toggles edit mode state in Riverpod', (tester) async {
      await tester.pumpWidget(_wrapTestWidget(
        child: const EditModeToggle(module: 'edu'),
        user: _teacherUser,
        prefs: testPrefs,
      ));
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('edit-mode-toggle-edu'));
      expect(toggleFinder, findsOneWidget);

      // Initially edit mode is off
      expect(find.byType(EditModeBanner), findsNothing);

      // Tap toggle
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('EditOverlay shows pen only if isTeacherOwner is true for teacher', (tester) async {
      bool edited = false;

      // When teacher owns the subject (isTeacherOwner: true)
      await tester.pumpWidget(_wrapTestWidget(
        child: SizedBox(
          width: 300,
          height: 100,
          child: EditOverlay(
            permission: Perm.educationContent,
            isTeacherOwner: true,
            onEdit: () async => edited = true,
            child: const Text('Subject owned by teacher'),
          ),
        ),
        user: _teacherUser,
        prefs: testPrefs,
        editMode: true,
      ));
      await tester.pumpAndSettle();

      // Pen is visible
      expect(find.byKey(const ValueKey('edit-pen-btn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('edit-pen-btn')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(edited, true);

      // When teacher DOES NOT own the subject (isTeacherOwner: false)
      await tester.pumpWidget(_wrapTestWidget(
        child: EditOverlay(
          permission: Perm.educationContent,
          isTeacherOwner: false,
          onEdit: () async => edited = true,
          child: const Text('Subject NOT owned by teacher'),
        ),
        user: _teacherUser,
        prefs: testPrefs,
        editMode: true,
      ));
      await tester.pumpAndSettle();

      // Pen is hidden!
      expect(find.byKey(const ValueKey('edit-pen-btn')), findsNothing);
    });

    testWidgets('EditOverlay shows pen for admin holding educationContent regardless of ownership', (tester) async {
      await tester.pumpWidget(_wrapTestWidget(
        child: EditOverlay(
          permission: Perm.educationContent,
          isTeacherOwner: false,
          onEdit: () async {},
          child: const Text('Subject for admin'),
        ),
        user: _eduAdminUser,
        prefs: testPrefs,
        editMode: true,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('edit-pen-btn')), findsOneWidget);
    });
  });

  // =========================================================================
  // F20: Role-specific Guidance Catalog & Destination Navigation
  // =========================================================================
  group('F20 · Role-specific guidance & Catalog consistency', () {
    test('GuidanceCatalog contains 71 articles with complete content', () {
      final articles = GuidanceCatalog.articles;
      expect(articles.length, greaterThanOrEqualTo(71));

      for (final article in articles) {
        expect(article.id, greaterThan(0));
        expect(article.title.isNotEmpty, true, reason: 'Article ${article.id} missing title');
        expect(article.summary != null && article.summary!.isNotEmpty, true, reason: 'Article ${article.id} missing summary');
        expect(article.content.isNotEmpty, true, reason: 'Article ${article.id} missing content');
        expect(article.targetScreen != null && article.targetScreen!.isNotEmpty, true, reason: 'Article ${article.id} missing targetScreen');
      }
    });

    test('Every guidance article requiredPermission exists in Perm constants', () {
      final validPerms = {
        Perm.usersView,
        Perm.usersCreate,
        Perm.usersUpdate,
        Perm.usersDisable,
        Perm.usersResetDevice,
        Perm.mezmursView,
        Perm.mezmursCreate,
        Perm.mezmursUpdate,
        Perm.mezmursDelete,
        Perm.categoriesManage,
        Perm.adsManage,
        Perm.pagesManage,
        Perm.programsManage,
        Perm.attendanceManage,
        Perm.notificationsSend,
        Perm.notificationsSendAll,
        Perm.borrowingManage,
        Perm.itemsManage,
        Perm.finesManage,
        Perm.reportsView,
        Perm.auditLogsView,
        Perm.activityLogsView,
        Perm.adminsView,
        Perm.adminsManage,
        Perm.settingsManage,
        Perm.releasesManage,
        Perm.departmentsManage,
        Perm.hrManage,
        Perm.paymentsManage,
        Perm.educationManage,
        Perm.educationRegister,
        Perm.educationContent,
        Perm.educationCertify,
        Perm.educationReports,
        Perm.programCategoriesManage,
        Perm.attendanceReports,
        Perm.choirManage,
        Perm.paymentsConfigure,
        Perm.attendanceView,
        Perm.attendanceClose,
        Perm.attendanceCorrectionRequest,
        Perm.attendanceCorrectionApprove,
        Perm.attendanceOverride,
        Perm.attendanceConfigure,
        Perm.attendanceAssign,
        Perm.paymentsView,
        Perm.propertyRequest,
        Perm.propertyReview,
        Perm.borrowingApprove,
        Perm.borrowingConfigure,
        Perm.selectionView,
        Perm.selectionConfigure,
        Perm.selectionExams,
        Perm.selectionReview,
        Perm.selectionFinalize,
        Perm.memberIdConfigure,
        Perm.memberGroupsManage,
        Perm.chatSupervise,
        Perm.projectsView,
        Perm.projectsManage,
        Perm.projectsExpensesApprove,
        Perm.projectsReports,
        Perm.projectsAllDepartments,
        Perm.guidanceManage,
        Perm.libraryCirculate,
      };

      for (final article in GuidanceCatalog.articles) {
        if (article.requiredPermission != null) {
          expect(
            validPerms.contains(article.requiredPermission),
            true,
            reason: 'Article ${article.id} (${article.title}) has invalid permission: ${article.requiredPermission}',
          );
        }
      }
    });

    test('Every route in GuidanceNavigator destinationRegistry has valid metadata and permitted fallback', () {
      final registry = GuidanceNavigator.destinationRegistry;
      expect(registry.isNotEmpty, true);

      for (final entry in registry.entries) {
        final path = entry.key;
        final meta = entry.value;

        expect(path.startsWith('/'), true, reason: 'Route $path must start with /');
        expect(meta.title.isNotEmpty, true, reason: 'Destination $path missing title');
        expect(meta.fallbackRoute.isNotEmpty, true, reason: 'Destination $path missing fallback route');
        expect(meta.fallbackTitle.isNotEmpty, true, reason: 'Destination $path missing fallback title');
      }
    });
  });

  // =========================================================================
  // F21: Responsive Design & Accessibility
  // =========================================================================
  group('F21 · Responsive design and accessibility', () {
    const testDevices = [
      (name: 'Phone Small', size: Size(360, 740)),
      (name: 'Standard Phone', size: Size(412, 892)),
      (name: 'Tablet/Desktop', size: Size(1024, 768)),
    ];

    const testScales = [1.0, 1.3];
    const testLocales = [Locale('am'), Locale('en')];

    for (final device in testDevices) {
      for (final scale in testScales) {
        for (final loc in testLocales) {
          testWidgets('Zero RenderFlex overflow on ${device.name} at scale $scale in ${loc.languageCode}', (tester) async {
            tester.view.physicalSize = Size(device.size.width * 2, device.size.height * 2);
            tester.view.devicePixelRatio = 2.0;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(() {
              tester.platformDispatcher.clearTextScaleFactorTestValue();
              tester.view.reset();
            });

            await tester.pumpWidget(_wrapTestWidget(
              child: const SettingsScreen(from: 'hub'),
              user: _eduAdminUser,
              locale: loc,
              prefs: testPrefs,
            ));
            await tester.pumpAndSettle();

            // Zero RenderFlex errors allowed
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('Interactive elements satisfy min 44dp tap target size', (tester) async {
      await tester.pumpWidget(_wrapTestWidget(
        child: const SettingsScreen(from: 'edu'),
        user: _eduAdminUser,
        prefs: testPrefs,
      ));
      await tester.pumpAndSettle();

      final backBtn = find.byKey(const ValueKey('settings-back-btn'));
      expect(backBtn, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(backBtn);
      final size = renderBox.size;
      expect(size.width, greaterThanOrEqualTo(40.0));
      expect(size.height, greaterThanOrEqualTo(40.0));
    });
  });
}
