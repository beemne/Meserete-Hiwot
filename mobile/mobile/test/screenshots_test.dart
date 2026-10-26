// Renders key screens to PNG with the real Ethiopic fonts for visual review against the design.
//   flutter test test/screenshots_test.dart --dart-define=SCREENSHOTS=true
// Output: build/screenshots/*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Banner;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/l10n/l10n.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/providers.dart';
import 'package:mezmur_zelideta/core/storage/local_db.dart';
import 'package:mezmur_zelideta/core/storage/local_prefs.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/auth_screens.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/home/home_screen.dart';
import 'package:mezmur_zelideta/features/mezmurs/category_screen.dart';
import 'package:mezmur_zelideta/features/settings/settings_screen.dart';
import 'package:mezmur_zelideta/models/activity.dart';
import 'package:mezmur_zelideta/models/content.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/repositories/content_repository.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

const _cats = [
  CategoryNode(id: 1, name: 'የቅድስት ሥላሴ', totalMezmurCount: 3, mezmurCount: 3),
  CategoryNode(id: 2, name: 'የቅድስት ኪዳነምሕረት', totalMezmurCount: 3, mezmurCount: 3),
  CategoryNode(id: 3, name: 'የቅዱስ ገብርኤል', totalMezmurCount: 3, mezmurCount: 3),
  CategoryNode(id: 4, name: 'የመላእክት', totalMezmurCount: 4, mezmurCount: 4),
  CategoryNode(id: 5, name: 'በዓላት', totalMezmurCount: 10, mezmurCount: 10),
  CategoryNode(id: 6, name: 'የንስሐ', totalMezmurCount: 1, mezmurCount: 1),
  CategoryNode(id: 7, name: 'ልዩ ልዩ', totalMezmurCount: 5, mezmurCount: 5),
];

const _tracks = [
  MezmurSummary(id: 1, title: 'ቅዱስ ቅዱስ ቅዱስ እግዚአብሔር', categoryName: 'የቅድስት ሥላሴ', hasAudio: true, audioDurationSec: 272),
  MezmurSummary(id: 2, title: 'ሥላሴን አመስግኑ', categoryName: 'የቅድስት ሥላሴ', hasAudio: true, audioDurationSec: 310),
  MezmurSummary(id: 3, title: 'አንድም ሦስትም', categoryName: 'የቅድስት ሥላሴ', audioDurationSec: 287, hasAudio: true),
];

class _FakeContent extends ContentRepository {
  _FakeContent(super.api, super.db);
  @override
  Future<HomeData> home() async => HomeData(
        banners: const [Banner(id: 1, kind: 'event', title: 'የወጣቶች የመዝሙር ምሽት', shortDescription: 'ቅዳሜ ምሽት — ይመዝገቡ', targetType: 'page', targetId: 1)],
        featured: const [],
        recent: _tracks,
        popular: const [],
        categories: _cats,
        upcomingPrograms: [Program(id: 1, title: 'ወርሃዊ የጸሎት ጉባኤ', location: 'ዋናው አዳራሽ', startsAt: DateTime(2026, 10, 3, 9), endsAt: DateTime(2026, 10, 3, 12), myParticipation: 'registered')],
        unread: 2,
      );
  @override
  Future<CategoryNode> category(int id) async => const CategoryNode(id: 1, name: 'የቅድስት ሥላሴ', totalMezmurCount: 3);
  @override
  Future<Paged<MezmurSummary>> categoryMezmurs(int id, {int page = 1}) async => const Paged(items: _tracks, page: 1, pages: 1, total: 3);
}

class _Signed extends SessionController {
  @override
  SessionState build() => const SignedIn(AppUser(id: 1, fullName: 'አበበ ከበደ', phone: '+251911223344'));
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await family('NotoSansEthiopic', ['assets/fonts/NotoSansEthiopic-400.ttf', 'assets/fonts/NotoSansEthiopic-600.ttf']);
  await family('NotoSerifEthiopic', ['assets/fonts/NotoSerifEthiopic-600.ttf', 'assets/fonts/NotoSerifEthiopic-700.ttf']);
  await family('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> shot(WidgetTester tester, String name, Widget screen) async {
    await tester.runAsync(_loadFonts);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final store = SecureStore();
    final db = await tester.runAsync(() => LocalDb.open(path: inMemoryDatabasePath));
    final prefs = await tester.runAsync(LocalPrefs.load);
    await tester.binding.setSurfaceSize(const Size(412, 892));
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        localDbProvider.overrideWithValue(db!),
        localPrefsProvider.overrideWithValue(prefs!),
        isOnlineProvider.overrideWithValue(true),
        sessionProvider.overrideWith(_Signed.new),
        contentRepositoryProvider.overrideWith((ref) => _FakeContent(ref.watch(apiClientProvider), db)),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('am'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: screen,
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('01 home', (t) => shot(t, '01_home', const HomeScreen()), skip: !_enabled);
  testWidgets('02 category', (t) => shot(t, '02_category', const CategoryScreen(categoryId: 1)), skip: !_enabled);
  testWidgets('05 settings', (t) => shot(t, '05_settings', const SettingsScreen()), skip: !_enabled);
  testWidgets('login', (t) => shot(t, 'login', const LoginScreen()), skip: !_enabled);
}
