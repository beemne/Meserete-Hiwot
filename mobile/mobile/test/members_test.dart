import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/l10n/l10n.dart';
import 'package:mezmur_zelideta/core/theme/app_theme.dart';
import 'package:mezmur_zelideta/features/choir/eligibility_screen.dart';
import 'package:mezmur_zelideta/features/members/department_participation.dart';
import 'package:mezmur_zelideta/features/members/member_form.dart';
import 'package:mezmur_zelideta/models/activity.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/l10n/app_localizations_en.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  group('Ethiopian periods (payments, participation)', () {
    test('months are Ethiopian; ጳጉሜ belongs to ነሐሴ', () {
      expect(ethPeriod(DateTime(2026, 9, 11)), '2019-01'); // Meskerem 1, 2019
      expect(ethPeriod(DateTime(2026, 9, 10)), '2018-12'); // Pagume 5 → Nehase
      expect(ethPeriod(DateTime(2027, 1, 15)), '2019-05'); // Tir 7
    });

    test('shifting crosses the year both ways and never lands on ጳጉሜ', () {
      expect(shiftPeriod('2019-12', 1), '2020-01');
      expect(shiftPeriod('2019-01', -1), '2018-12');
      expect(shiftPeriod('2019-03', 12), '2020-03');
      expect(shiftPeriod('2019-03', 11), '2020-02');
    });

    testWidgets('labels use Ethiopian month names in English too', (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        label = periodLabel(context, '2019-01');
        return const SizedBox();
      })));
      final l = AppLocalizationsEn();
      expect(label, contains('2019'));
      expect(label, isNot(contains('September')));
      expect(l.localeName, 'en');
    });
  });

  group('membership form', () {
    test('children carry no student / worker type', () {
      final d = MemberFormData()
        ..name.text = 'ሕጻን'
        ..group = 'children'
        ..memberType = 'student';
      final body = d.adminJson();
      expect(body['member_group'], 'children');
      expect(body['member_type'], isNull);
      expect(body.containsKey('phone'), isFalse); // children may have no phone
    });

    test('status detail is only sent for university / abroad', () {
      final d = MemberFormData()
        ..status = 'abroad'
        ..statusDetail.text = 'Canada';
      expect(d.adminJson()['membership_status_detail'], 'Canada');
      d.status = 'inactive';
      expect(d.adminJson()['membership_status_detail'], isNull);
    });

    for (final locale in const [Locale('en'), Locale('am')]) {
      testWidgets('the admin form renders every section without overflow on a small phone (${locale.languageCode})', (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        final data = MemberFormData()..status = 'university';
        await tester.pumpWidget(_wrap(Scaffold(body: SingleChildScrollView(child: MemberFormFields(data: data, mode: MemberFormMode.admin))), locale: locale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TextFormField).evaluate().length + find.byType(TextField).evaluate().length, greaterThan(20));
        await tester.binding.setSurfaceSize(null);
      });
    }
  });

  for (final locale in const [Locale('en'), Locale('am')]) {
    testWidgets('holiday selection result renders every component, failures and missing data (${locale.languageCode})', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      Map<String, dynamic> c(num w, num? m, {num? percent, bool counted = true, bool passed = true, String? reason, Map<String, dynamic> detail = const {}}) =>
          {'weight': w, 'minimum': m, 'percent': percent, 'points': percent == null ? null : percent * w / 100, 'counted': counted, 'passed': passed, 'reason': reason, 'detail': detail};
      final data = <String, dynamic>{
        'selection': {
          'id': 1,
          'name': 'ጥምቀት 2019',
          'from': '2026-09-01',
          'to': '2026-09-30',
          'status': 'review',
          'formula': 'x',
          'config': {'total_minimum': 43, 'bonus': {'max': 30}},
        },
        'components': {
          'course_attendance': c(25, 10, percent: 75, detail: {'classes': [{'class_name': 'ክፍል 1', 'attended': 3, 'total': 4, 'percent': 75}]}),
          'exam': c(25, 10, counted: false, reason: 'exam_not_required'),
          'mezmur_attendance': c(30, 15, percent: 20, passed: false, detail: {'attended': 1, 'late': 0, 'total': 5}),
          'contribution': c(10, 3, percent: 100, detail: {'months': [{'period': '2019-01', 'required': 100, 'status': 'paid'}]}),
          'participation': c(10, 5, percent: 80, detail: {'average': 8, 'max_score': 10, 'months': [{'period': '2019-01', 'score': 8, 'department': 'ክፍል'}], 'missing': [{'period': '2018-12', 'department': 'ክፍል'}]}),
        },
        'base_score': 55.1,
        'bonus': 12,
        'bonus_detail': {'percent': 40},
        'total': 67.1,
        'result': 'qualified',
        'override': 'qualified',
        'override_reason': 'በኮሚቴ',
        'failed': [{'component': 'mezmur_attendance', 'required': 15, 'current': 6, 'shortfall': 9}],
        'missing': [{'component': 'participation', 'reason': 'missing_months'}],
      };
      await tester.pumpWidget(_wrap(Scaffold(body: EligibilityView(data: data, forMember: false, footer: const [Text('FOOTER')])), locale: locale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('FOOTER'), 300);
      expect(find.text('FOOTER'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    });
  }

  test('a member with department roles is a staff member but keeps member features', () {
    final u = AppUser.fromJson({
      'id': 5,
      'full_name': 'አባል',
      'account_type': 'user',
      'permissions': ['items.manage'],
      'admin_departments': [
        {'id': 5, 'name': 'ሒሳብ እና ንብረት ክፍል', 'name_en': 'Finance and Property Department'},
      ],
    });
    expect(u.isAdmin, isTrue);
    expect(u.isMemberStaff, isTrue);
    expect(u.isAccountAdmin, isFalse);
    expect(u.adminDepartments.single['name_en'], 'Finance and Property Department');
    final plain = AppUser.fromJson({'id': 6, 'full_name': 'ሌላ', 'account_type': 'user'});
    expect(plain.isAdmin, isFalse);
  });

  test('programs carry Ethiopian recurrence days and the additional-session flags', () {
    final p = Program.fromJson({
      'id': 1,
      'title': 'ሰርክ',
      'starts_at': '2026-09-30T14:00:00Z',
      'ends_at': '2026-09-30T16:00:00Z',
      'recurrence': 'ethiopian_days',
      'ethiopian_days': [1, 10, 19],
      'is_additional': 1,
      'counts_for_selection': 0,
    });
    expect(p.ethiopianDays, [1, 10, 19]);
    expect(p.isAdditional, isTrue);
    expect(p.countsForSelection, isFalse);
  });
}
