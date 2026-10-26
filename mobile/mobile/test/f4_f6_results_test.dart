// Renders visual verification screenshots for Release 1.5.3+19 (F4 Edu Attendance migration & F6 Selection Intervals / Config Versioning).
// Run: flutter test test/f4_f6_results_test.dart --dart-define=SCREENSHOTS=true
// Output: build/screenshots/f4_*.png and build/screenshots/f6_*.png

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
import 'package:mezmur_zelideta/features/admin/selections_admin.dart';
import 'package:mezmur_zelideta/features/auth/session.dart';
import 'package:mezmur_zelideta/features/choir/eligibility_screen.dart';
import 'package:mezmur_zelideta/features/edu/learn/edu_home.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/repositories/providers.dart';
import 'package:mezmur_zelideta/repositories/stage_repository.dart';
import 'package:mezmur_zelideta/repositories/superapp_repositories.dart';
import 'package:mezmur_zelideta/widgets/brand.dart';

import 'fakes.dart';

const _enabled = bool.fromEnvironment('SCREENSHOTS');

const _adminUser = AppUser(
  id: 1,
  fullName: 'ኃይለ ሚካኤል (Admin)',
  phone: '+251911000001',
  roleName: 'admin',
  roleLevel: 100,
  permissions: {'selection.configure', 'selection.exams', 'attendance.take', 'education.manage'},
);

final _selectionExisting = {
  'id': 1,
  'name': 'የትንሣኤ በዓል መዝሙር አገልግሎት መረጣ',
  'from': '2026-09-01',
  'to': '2026-10-15',
  'status': 'open',
  'member_groups': ['youth_adult', 'married'],
  'config': {
    'weights': {
      'course_attendance': 30.0,
      'exam': 20.0,
      'mezmur_attendance': 30.0,
      'contribution': 10.0,
      'participation': 10.0,
    },
    'minimums': {
      'course_attendance': 20.0,
      'exam': 12.0,
      'mezmur_attendance': 20.0,
      'contribution': null,
      'participation': null,
    },
    'total_minimum': 70.0,
    'exams_required': true,
    'education': {
      'class_ids': [1, 2],
      'course_ids': [],
    },
    'mezmur': {
      'category_ids': [1, 2],
      'included_program_ids': [],
      'excluded_program_ids': [],
    },
    'contribution': {
      'year': 2019,
      'start_month': 1,
      'end_month': 5,
      'late_credit': 0.8,
    },
    'bonus': {
      'max': 10.0,
      'category_ids': [],
      'program_ids': [],
    },
    'attendance': {
      'present': 100.0,
      'excused': 50.0,
      'absent': 0.0,
    },
    'attendance_rules': {
      'education': {
        'intervals': [
          {'from': 0.0, 'to': 15.0, 'percent': 100.0},
          {'from': 15.0, 'to': 30.0, 'percent': 75.0},
          {'from': 30.0, 'to': 45.0, 'percent': 50.0},
        ],
        'after_last_percent': 0.0,
      },
      'mezmur': {
        'intervals': [
          {'from': 0.0, 'to': 20.0, 'percent': 100.0},
          {'from': 20.0, 'to': 40.0, 'percent': 80.0},
        ],
        'after_last_percent': 0.0,
      },
    },
  },
};

final _selectionOptions = {
  'categories': [
    {'id': 1, 'name': 'መደበኛ ልምምድ', 'name_en': 'Regular Rehearsal', 'code': 'REG', 'is_regular': true},
    {'id': 2, 'name': 'ልዩ መርሐ ግብር', 'name_en': 'Special Program', 'code': 'SPC', 'is_regular': false},
  ],
  'courses': [
    {'id': 1, 'name': 'የቤተ ክርስቲያን ታሪክ', 'class_id': 1},
    {'id': 2, 'name': 'ትምህርተ ሃይማኖት', 'class_id': 1},
    {'id': 3, 'name': 'ሥርዓተ ቤተ ክርስቲያን', 'class_id': 2},
  ],
  'programs': [
    {'id': 10, 'title': 'ልዩ የትንሣኤ ዝግጅት', 'is_additional': true, 'counts_for_selection': true},
  ],
  'defaults': {
    'weights': {'course_attendance': 30, 'exam': 20, 'mezmur_attendance': 30, 'contribution': 10, 'participation': 10},
    'minimums': {'course_attendance': 20, 'exam': 12, 'mezmur_attendance': 20},
    'total_minimum': 70,
    'exams_required': true,
    'attendance': {'present': 100, 'excused': 50, 'absent': 0},
    'attendance_rules': {
      'education': {
        'intervals': [
          {'from': 0, 'to': 15, 'percent': 100},
          {'from': 15, 'to': 30, 'percent': 75},
        ],
        'after_last_percent': 0,
      },
      'mezmur': {
        'intervals': [
          {'from': 0, 'to': 20, 'percent': 100},
          {'from': 20, 'to': 40, 'percent': 80},
        ],
        'after_last_percent': 0,
      },
    },
  },
};

final _eligibilityData = {
  'selection': {
    'id': 1,
    'name': 'የትንሣኤ በዓል መዝሙር አገልግሎት መረጣ',
    'status': 'finalized',
    'from': '2026-09-01',
    'to': '2026-10-15',
    'config': {
      'total_minimum': 70.0,
      'bonus': {'max': 10.0},
    },
  },
  'config_version': 'Config v1',
  'result': 'qualified',
  'base_score': 84.5,
  'bonus': 4.0,
  'total': 88.5,
  'service_category': 'ዋና መዘምራን',
  'service_rank': 'ከፍተኛ',
  'live': false,
  'period': {
    'from': '2026-09-01',
    'to': '2026-10-15',
  },
  'failed': <dynamic>[],
  'missing': <dynamic>[],
  'components': {
    'course_attendance': {
      'weight': 30.0,
      'counted': true,
      'passed': true,
      'points': 25.5,
      'percent': 85.0,
      'minimum': 20.0,
      'detail': {
        'classes': [
          {'class_name': '7ኛ ክፍል — የቤተ ክርስቲያን ታሪክ', 'attended': 6, 'total': 7, 'percent': 85.7},
        ],
        'explanation': 'የትምህርት ክፍለ-ጊዜ በደቂቃ: 0–15 ደቂቃ 100%, 15–30 ደቂቃ 75%, 30–45 ደቂቃ 50%, ከ45 ደቂቃ በኋላ 0%',
      },
    },
    'mezmur_attendance': {
      'weight': 30.0,
      'counted': true,
      'passed': true,
      'points': 27.0,
      'percent': 90.0,
      'minimum': 20.0,
      'detail': {
        'explanation': 'የመዝሙር መርሃ ግብር በደቂቃ: 0–20 ደቂቃ 100%, 20–40 ደቂቃ 80%, ከ40 ደቂቃ በኋላ 0%',
      },
    },
    'exam': {
      'weight': 20.0,
      'counted': true,
      'passed': true,
      'points': 18.0,
      'percent': 90.0,
      'minimum': 12.0,
      'detail': {},
    },
    'contribution': {
      'weight': 10.0,
      'counted': true,
      'passed': true,
      'points': 10.0,
      'percent': 100.0,
      'detail': {},
    },
    'participation': {
      'weight': 10.0,
      'counted': true,
      'passed': true,
      'points': 4.0,
      'percent': 40.0,
      'detail': {},
    },
  },
  'bonus_detail': {
    'score': 4.0,
  },
};

final _eduHomeData = {
  'featured': [
    {
      'id': 1,
      'target_type': 'subject',
      'target_id': 9,
      'title': 'ነገረ መለኮት — የእምነት መሠረቶች',
      'subtitle': '(Theology)',
      'image_url': null,
      'is_active': true,
      'target': {'route': '/edu/learn/subject/9', 'progress': {'completed': 0, 'total': 12}}
    },
  ],
  'categories': [
    {'id': 1, 'name': 'መጽሐፍ ቅዱስ', 'name_en': 'Holy Bible', 'icon_key': 'bible', 'lesson_count': 15},
    {'id': 2, 'name': 'የቤተ ክርስቲያን ታሪክ', 'name_en': 'Church History', 'icon_key': 'church', 'lesson_count': 10},
  ],
  'continue': {
    'lesson_id': 5,
    'lesson_title': 'ስደትና መስዋዕትነት',
    'subject_name': 'የቤተ ክርስቲያን ታሪክ',
    'subject_name_en': 'Church History',
    'progress': {'completed': 4, 'total': 10}
  },
  'classes': [
    {'id': 1, 'name': '7ኛ ክፍል', 'my_program': 'regular'}
  ],
  'next_sessions': [
    {
      'date': '2026-10-18',
      'class_id': 1,
      'class_name': '7ኛ ክፍል',
      'course_name': 'የቤተ ክርስቲያን ታሪክ',
      'starts': '08:00',
      'ends': '10:00',
      'location': 'አዳራሽ ፩'
    }
  ],
  'open_registration': 0,
  'student': {
    'assignments_due': [],
    'quizzes': [],
    'attendance': [
      {'class_id': 1, 'class_name': '7ኛ ክፍል', 'rate': 92, 'total': 8}
    ],
    'results': [],
  },
  'teaching': null,
  'attendance_classes': [],
  'admin': null,
  'roles': {'student': true},
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
}

void main() {
  Future<void> renderScreenshot(WidgetTester tester, String filename, Widget screen, {AppUser? user, ApiClient? client}) async {
    await tester.runAsync(_loadFonts);
    FlutterSecureStorage.setMockInitialValues({'access_token': 't', 'refresh_token': 'r', 'token_scope': 'app', 'device_id': 'd'});
    final store = SecureStore();
    await tester.runAsync(store.load);

    final api = client ??
        ApiClient(
          store,
          dio: Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
            ..httpClientAdapter = FakeAdapter((req) {
              if (req.path == '/selections/options') {
                return (status: 200, body: ok(_selectionOptions));
              }
              if (req.path == '/edu/me/dashboard') {
                return (status: 200, body: ok(_eduHomeData));
              }
              return (status: 200, body: ok({}));
            }),
        );

    await tester.binding.setSurfaceSize(const Size(412, 892));
    final key = GlobalKey();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(user ?? _adminUser),
          stageRepositoryProvider.overrideWithValue(StageRepository(api)),
          eduRepositoryProvider.overrideWithValue(EduRepository(api)),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            locale: const Locale('am'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: screen,
          ),
        ),
      ),
    );

    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 200));
    }

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/$filename.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });

    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('Renders F6 Selection Editor with Interval Tables', (tester) async {
    await renderScreenshot(
      tester,
      'f6_selection_editor_intervals',
      SelectionEditorScreen(existing: _selectionExisting),
    );
    expect(find.byType(SelectionEditorScreen), findsNothing); // after dispose
  }, skip: !_enabled);

  testWidgets('Renders F6 Eligibility View with Config v1 badge and Interval Explanations', (tester) async {
    await renderScreenshot(
      tester,
      'f6_selection_eligibility_config_v1',
      Scaffold(
        appBar: AppBar(title: const Text('የመመረጥ ውጤት')),
        body: EligibilityView(data: _eligibilityData),
      ),
    );
    expect(find.byType(EligibilityView), findsNothing);
  }, skip: !_enabled);

  testWidgets('Renders F4 EduHomeScreen without legacy attendance entry points', (tester) async {
    await renderScreenshot(
      tester,
      'f4_edu_home_clean',
      const ModuleBackgroundWrapper(
        kind: ModuleBackgroundKind.education,
        child: EduHomeScreen(),
      ),
    );
    expect(find.byType(EduHomeScreen), findsNothing);
  }, skip: !_enabled);
}
