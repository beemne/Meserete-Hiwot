import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/utils/lrc.dart';
import 'package:mezmur_zelideta/features/admin/import_admin.dart' show toCsv;
import 'package:mezmur_zelideta/features/admin/member_filters.dart';
import 'package:mezmur_zelideta/features/hub/hub_screen.dart' show paymentYearSummary;
import 'package:mezmur_zelideta/features/members/profile_changes.dart' show profileFieldLabel, profileValueLabel;
import 'package:mezmur_zelideta/l10n/app_localizations_en.dart';
import 'package:mezmur_zelideta/models/content.dart';
import 'package:mezmur_zelideta/models/user.dart';

void main() {
  final l = AppLocalizationsEn();

  group('synced lyrics (.lrc)', () {
    test('parses times, shared tags and the offset; finds the line being sung', () {
      final lines = parseLrc('[ti:x]\n[offset:+500]\n[00:10.00]two\n[00:01.50][00:20]one\n\nno tag');
      expect(lines.map((x) => x.text), ['one', 'two', 'one']);
      expect(lines.first.time, const Duration(milliseconds: 1000)); // 1.5 s − 0.5 s offset
      expect(currentLrcLine(lines, Duration.zero), -1);
      expect(currentLrcLine(lines, const Duration(seconds: 12)), 1);
      expect(currentLrcLine(lines, const Duration(minutes: 3)), 2);
      expect(parseLrc('plain lyrics only'), isEmpty);
    });

    test('writes what it reads', () {
      final text = writeLrc(const [LrcLine(Duration(milliseconds: 1230), 'a'), LrcLine(Duration(minutes: 1, seconds: 2), 'b')], title: 'T');
      expect(text, '[ti:T]\n[00:01.23]a\n[01:02.00]b');
      expect(parseLrc(text).map((x) => x.time), const [Duration(milliseconds: 1230), Duration(minutes: 1, seconds: 2)]);
      expect(lyricLines('one\n\n two \n'), ['one', 'two']);
    });

    test('a Mezmur carries its .lrc and list items their audio URL', () {
      final m = Mezmur.fromJson({'id': 1, 'title': 't', 'lyrics': 'x', 'lrc': '[00:01.00]x', 'audio': {'url': 'https://a/b.mp3'}});
      expect(m.lrc, '[00:01.00]x');
      expect(m.summary.audioUrl, 'https://a/b.mp3');
      expect(MezmurSummary.fromJson({'id': 2, 'title': 'u', 'audio_url': 'https://c/d.mp3'}).audioUrl, 'https://c/d.mp3');
    });
  });

  group('categorized member filters', () {
    test('query strings for lists and typed values for bulk targeting', () {
      const f = MemberFilter(gender: 'female', ageMin: 18, hasDevice: false, canLogin: true, departmentId: 3);
      expect(f.toBody(), {'gender': 'female', 'age_min': 18, 'has_device': false, 'department_id': 3});
      expect(f.toQuery(), {'gender': 'female', 'age_min': '18', 'has_device': 'false', 'department_id': '3', 'can_login': 'true'});
      expect(f.count, 5);
      expect(const MemberFilter().isEmpty, isTrue);
      expect(memberFilterLabels(l, f), containsAll([l.female, l.fNoDevice, l.canLogin]));
    });
  });

  test('payments: "all paid" only for a fully paid year', () {
    expect(paymentYearSummary(l, {'year': 2019, 'months_paid': 12, 'full': true}), l.paymentsYearFull('2019'));
    expect(paymentYearSummary(l, {'year': 2019, 'months_paid': 3, 'full': false}), l.paymentsYearPartial('2019', '3', '9'));
    expect(paymentYearSummary(l, {'year': 2019, 'months_paid': 0, 'full': false}), l.paymentsYearNone('2019'));
  });

  test('profile changes: labels and history entries', () {
    expect(profileFieldLabel(l, 'christian_name'), l.christianName);
    expect(profileValueLabel(l, 'gender', 'female'), l.female);
    expect(profileValueLabel(l, 'house_number', null), '—');
    final r = ProfileChangeRequest.fromJson({
      'id': 1, 'user_id': 2, 'old_full_name': 'A', 'old_phone': null, 'status': 'pending', 'note': 'n',
      'changes': [{'field': 'christian_name', 'old': 'x', 'new': 'y'}],
    });
    expect(r.changes.single.newValue, 'y');
    expect(r.note, 'n');
  });

  test('typed Mezmurs become CSV with multi-line lyrics quoted', () {
    final csv = toCsv(['title', 'lyrics'], [{'title': 'a, b', 'lyrics': 'one\ntwo "x"'}]);
    expect(csv, 'title,lyrics\n"a, b","one\ntwo ""x"""');
  });
}
