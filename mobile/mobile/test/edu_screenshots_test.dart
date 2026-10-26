// Renders the ትምህርት learning screens to PNG with the real Ethiopic fonts and the Education
// background, for visual review against the design (test data only — never shipped).
//   flutter test test/edu_screenshots_test.dart --dart-define=SCREENSHOTS=true
// Output: build/screenshots/edu_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/network/api_client.dart';
import 'package:mezmur_zelideta/core/storage/secure_store.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/edu/learn/edu_home.dart';
import 'package:mezmur_zelideta/features/edu/learn/learn_screens.dart';
import 'package:mezmur_zelideta/features/edu/learn/quiz_screens.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';
import 'package:mezmur_zelideta/widgets/brand.dart';

import 'fakes.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

final _data = <String, Object>{
  '/edu/me/dashboard': {
    'featured': [
      {'id': 1, 'target_type': 'subject', 'target_id': 9, 'title': 'ነገረ መለኮት — የእምነት መሠረቶች', 'subtitle': '(Theology)', 'image_url': null, 'is_active': true,
        'target': {'route': '/edu/learn/subject/9', 'progress': {'completed': 0, 'total': 12}}},
    ],
    'categories': [
      {'id': 1, 'name': 'መጽሐፍ ቅዱስ', 'name_en': 'Holy Bible', 'icon_key': 'bible', 'lesson_count': 15},
      {'id': 2, 'name': 'የቤተ ክርስቲያን ታሪክ', 'name_en': 'Church History', 'icon_key': 'church', 'lesson_count': 10},
      {'id': 3, 'name': 'ሥርዓተ አምልኮ', 'name_en': 'Liturgy & Order', 'icon_key': 'censer', 'lesson_count': 8},
      {'id': 4, 'name': 'ነገረ ቅዱሳን', 'name_en': 'Hagiography', 'icon_key': 'saint', 'lesson_count': 12},
    ],
    'continue': {'lesson_id': 5, 'lesson_title': 'ስደትና መስዋዕትነት', 'subject_name': 'የቤተ ክርስቲያን ታሪክ', 'subject_name_en': 'Church History', 'progress': {'completed': 4, 'total': 10}},
    'classes': [{'id': 1, 'name': '7ኛ', 'my_program': 'regular'}],
    'next_sessions': [{'date': '2026-10-18', 'class_id': 1, 'class_name': '7ኛ', 'course_name': 'የቤተ ክርስቲያን ታሪክ', 'starts': '08:00', 'ends': '10:00', 'location': 'አዳራሽ'}],
    'open_registration': 0,
    'student': {
      'assignments_due': [{'id': 3, 'title': 'ስለ ኒቅያ ጉባኤ ጽሑፍ', 'due_at': '2026-10-20T10:00:00.000Z', 'course_name': 'የቤተ ክርስቲያን ታሪክ', 'class_id': 1, 'overdue': false}],
      'quizzes': [{'id': 8, 'title': 'ሳምንታዊ ፈተና ፫', 'course_name': 'የቤተ ክርስቲያን ታሪክ', 'availability': 'open', 'attempts_left': 1}],
      'attendance': [{'class_id': 1, 'class_name': '7ኛ', 'rate': 86, 'total': 7}],
      'results': [{'assessment_id': 1, 'title': 'የመካከለኛ ፈተና', 'score': 42, 'max_score': 50, 'course_name': 'ትምህርተ ሃይማኖት', 'class_id': 1}],
    },
    'teaching': null,
    'attendance_classes': [],
    'admin': null,
    'roles': {'student': true},
  },
  '/edu/subjects/2': {
    'id': 2, 'name': 'የቤተ ክርስቲያን ታሪክ', 'name_en': 'Church History', 'description': 'ከሐዋርያት ዘመን እስከ ዓለም አቀፍ ጉባኤያት።',
    'status': 'published', 'visibility': 'enrolled', 'sequential': true, 'can_open': true, 'can_edit': false, 'enrolled': true,
    'my_progress': {'completed': 1, 'total': 3, 'percent': 33},
    'units': [
      {'id': 1, 'title': 'ምዕራፍ ፩፦ የቤተ ክርስቲያን አመጣጥ', 'lessons': [
        {'id': 4, 'title': 'ሐዋርያዊት ቤተ ክርስቲያን', 'summary': '(The Apostolic Church)', 'status': 'published', 'completed': true, 'est_minutes': 15},
        {'id': 5, 'title': 'ስደትና መስዋዕትነት', 'summary': '(Persecution and Martyrdom)', 'status': 'published', 'opened': true, 'est_minutes': 20},
        {'id': 6, 'title': 'ዓለም አቀፍ ጉባኤያት', 'summary': '(Ecumenical Councils)', 'status': 'published', 'locked': true},
      ]},
    ],
    'lessons': [],
  },
  '/edu/lessons/5': {
    'id': 5, 'title': '፩.፩ የቤተ ክርስቲያን መሠረት', 'summary': '(1.1 The Foundation of the Church)', 'status': 'published',
    'body': 'ቅድስት ቤተ ክርስቲያን በጌታችን በመድኃኒታችን በኢየሱስ ክርስቶስ ደም የተመሠረተች ናት። በሐዋርያት ስብከትም በዓለም ሁሉ ተስፋፋች።\n\n> «በዚህች ዓለት ላይ ቤተ ክርስቲያኔን እሠራለሁ» ማቴ. ፲፮፥፲፰\n\n## በበዓለ ሃምሳ\n- መንፈስ ቅዱስ በሐዋርያት ላይ ወረደ\n- ሦስት ሺህ ሰዎች ተጠመቁ',
    'scripture_refs': 'ማቴ. ፲፮፥፲፰፤ የሐዋ. ፪', 'unit': {'id': 1, 'title': 'ምዕራፍ ፩'}, 'subject': {'id': 2, 'name': 'የቤተ ክርስቲያን ታሪክ', 'name_en': 'Church History'},
    'position': 2, 'total': 3, 'prev_id': 4, 'next_id': 6, 'completed': false, 'bookmarked': false, 'can_edit': false,
    'materials': [
      {'id': 2, 'kind': 'file', 'title': 'የትምህርቱ ትረካ', 'name': 'narration.mp3', 'mime': 'audio/mpeg', 'size': 3400000},
      {'id': 1, 'kind': 'file', 'title': 'የትምህርቱ ማስታወሻ', 'name': 'notes.pdf', 'mime': 'application/pdf', 'size': 240000},
    ],
    'quizzes': [],
  },
  '/edu/attempts/11': {
    'id': 11, 'quiz_id': 8, 'attempt_no': 1, 'status': 'in_progress', 'seconds_left': 540, 'max_score': 4,
    'quiz': {'id': 8, 'title': 'ሳምንታዊ ፈተና', 'review_policy': 'practice', 'official': false},
    'questions': [
      {'id': 1, 'type': 'single', 'prompt': 'የመጀመሪያው የቤተ ክርስቲያን ጉባኤ የት ተካሄደ?', 'points': 1, 'response': 'a', 'options': [
        {'id': 'a', 'text': 'ኢየሩሳሌም'}, {'id': 'b', 'text': 'አንጾኪያ'}, {'id': 'c', 'text': 'ሮም'}, {'id': 'd', 'text': 'እስክንድርያ'}]},
      {'id': 2, 'type': 'true_false', 'prompt': 'የኒቅያ ጉባኤ በ፫፻፳፭ ዓ.ም. ተካሄደ', 'points': 1},
      {'id': 3, 'type': 'single', 'prompt': '…', 'points': 1, 'options': [{'id': 'a', 'text': '…'}, {'id': 'b', 'text': '…'}]},
      {'id': 4, 'type': 'short_text', 'prompt': '…', 'points': 1},
    ],
  },
};

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
  Future<void> shot(WidgetTester tester, String name, Widget screen, {bool dark = false}) async {
    await tester.runAsync(_loadFonts);
    FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
    final store = SecureStore();
    await tester.runAsync(store.load);
    final api = ApiClient(store, dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
      ..httpClientAdapter = FakeAdapter((req) {
        final r = _data[req.path];
        return r == null ? (status: 404, body: failBody('NOT_FOUND')) : (status: 200, body: ok(r));
      }));
    await tester.binding.setSurfaceSize(const Size(412, 892));
    final key = GlobalKey();
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(null), eduRepositoryProvider.overrideWithValue(EduRepository(api))],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('am'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: ModuleBackgroundWrapper(kind: ModuleBackgroundKind.education, child: screen),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('edu home', (t) => shot(t, 'edu_home', const EduHomeScreen()), skip: !_enabled);
  testWidgets('edu home dark', (t) => shot(t, 'edu_home_dark', const EduHomeScreen(), dark: true), skip: !_enabled);
  testWidgets('edu subject', (t) => shot(t, 'edu_subject', const EduSubjectScreen(subjectId: 2)), skip: !_enabled);
  testWidgets('edu lesson', (t) => shot(t, 'edu_lesson', const EduLessonScreen(lessonId: 5)), skip: !_enabled);
  testWidgets('edu quiz', (t) => shot(t, 'edu_quiz', const EduAttemptScreen(attemptId: 11)), skip: !_enabled);
}
