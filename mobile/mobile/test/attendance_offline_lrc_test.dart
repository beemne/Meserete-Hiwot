import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/member_groups.dart';
import 'package:mezmur_zelideta/core/utils/lrc.dart';
import 'package:mezmur_zelideta/features/admin/content_admin.dart' show ctaTargetType;
import 'package:mezmur_zelideta/features/admin/lrc_maker.dart';
import 'package:mezmur_zelideta/features/members/member_form.dart' show memberGroupLabel;
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/models/content.dart';
import 'package:mezmur_zelideta/models/json.dart';
import 'package:mezmur_zelideta/services/offline_pack.dart';

void main() {
  group('synced lyrics: repeated lines go back to the line', () {
    test('a line with several times is listed once; the highlight returns to it', () {
      final s = parseLrcSheet('[ti:x]\n[00:01.00][00:10.00]chorus\n[00:05.00]verse\n[00:15.00]end');
      expect(s.lines, ['chorus', 'verse', 'end']);
      expect(s.lineAt(Duration.zero), -1);
      expect(s.lineAt(const Duration(seconds: 2)), 0);
      expect(s.lineAt(const Duration(seconds: 6)), 1);
      expect(s.lineAt(const Duration(seconds: 11)), 0); // back to the chorus, not a new line
      expect(s.lineAt(const Duration(seconds: 20)), 2);
      expect(s.seekFor(0, const Duration(seconds: 6)), const Duration(seconds: 10));
      final again = parseLrcSheet(s.write());
      expect(again.lines, s.lines);
      expect(again.times[0], const [Duration(seconds: 1), Duration(seconds: 10)]);
    });

    test('the maker stamps repeats on the same line (max 3) and Next continues after it; undo restores', () {
      final t = LrcTiming(['a', 'b', 'c']);
      expect(t.next(const Duration(seconds: 1)), isTrue); // a
      expect(t.next(const Duration(seconds: 3)), isTrue); // b
      expect(t.repeat(0, const Duration(seconds: 5)), isTrue); // singers go back to a
      expect(t.cursor, 1);
      expect(t.next(const Duration(seconds: 7)), isTrue); // b again (continues after a)
      expect(t.next(const Duration(seconds: 9)), isTrue); // c
      expect(t.finished, isTrue);
      expect(t.times[0], const [Duration(seconds: 1), Duration(seconds: 5)]);
      expect(t.times[1], const [Duration(seconds: 3), Duration(seconds: 7)]);
      expect(t.repeat(0, const Duration(seconds: 11)), isTrue); // 3rd time
      expect(t.repeat(0, const Duration(seconds: 13)), isFalse); // a 4th is refused
      expect(t.sheet.write(), '[00:01.00][00:05.00][00:11.00]a\n[00:03.00][00:07.00]b\n[00:09.00]c');
      t.undo();
      expect(t.times[0].length, 2);
      expect(t.cursor, 3);
      // a stamp never goes back in time
      final u = LrcTiming(['x', 'y'])..next(const Duration(seconds: 5));
      u.next(const Duration(seconds: 2));
      expect(u.times[1].single, const Duration(seconds: 5));
    });

    test('an existing timing is continued when its lines match', () {
      final t = LrcTiming(['a', 'b', 'c'])..load(parseLrcSheet('[00:01.00][00:05.00]a\n[00:03.00]b'));
      expect(t.times[0].length, 2);
      expect(t.cursor, 1); // the last stamp was "a" (00:05) → next is "b"
    });
  });

  group('offline attendance check (the phone answers like the server)', () {
    final now = DateTime(2026, 10, 5, 10, 0);
    Map<String, dynamic> programWith(Map<String, dynamic> session) => {
          'id': 9,
          'title': 'ጥናት',
          'member_groups': ['distance'],
          'participant_ids': null,
          'occurrences': [
            {
              'date': '2026-10-05',
              'starts_at': DateTime(2026, 10, 5, 9, 55).toUtc().toIso8601String(),
              'ends_at': DateTime(2026, 10, 5, 12).toUtc().toIso8601String(),
              'cancelled': false,
              'closed_at': null,
              'session': session,
            },
          ],
        };
    // Taker 1 started the session at 09:56.
    final program = programWith({'status': 'active', 'taker_id': 1, 'started_at': DateTime(2026, 10, 5, 9, 56).toUtc().toIso8601String()});
    Map<String, dynamic> member(int id, String group) => {'id': id, 'full_name': 'M$id', 'member_group': group, 'membership_status': 'active', 'joined_on': '2026-01-01'};
    Map<String, dynamic> check(
      Map<String, dynamic>? m, {
      Map<String, dynamic>? prog,
      List<Map<String, dynamic>> marks = const [],
      List<Map<String, dynamic>> pending = const [],
      int myId = 1,
      DateTime? at,
      Map<String, dynamic>? local,
      List<String> exempt = const [],
    }) =>
        offlineAttendanceCheck(program: prog ?? program, member: m, date: '2026-10-05', myId: myId, now: at ?? now, marks: marks, pending: pending, localSession: local, exemptGroups: exempt);

    test('eligible member of the program type; signs unless the group is exempt', () {
      final r = check(member(5, 'distance'));
      expect(r['eligible'], isTrue);
      expect(r['offline'], isTrue);
      expect(r['would_record'], 'present');
      expect(r['signature_required'], isTrue);
      expect(check(member(5, 'distance'), exempt: ['distance'])['signature_required'], isFalse);
    });
    test('only the assigned taker records', () {
      expect(check(member(5, 'distance'), myId: 2)['reason'], 'NOT_SESSION_TAKER');
      expect(check(member(5, 'distance'), prog: programWith({'status': 'scheduled', 'taker_id': null}))['reason'], 'NO_ATTENDANCE_TAKERS_ASSIGNED');
    });
    test('nothing before Start; an offline Start on this phone opens it', () {
      final scheduled = programWith({'status': 'scheduled', 'taker_id': 1, 'started_at': null});
      expect(check(member(5, 'distance'), prog: scheduled)['reason'], 'SESSION_NOT_STARTED');
      final r = check(member(5, 'distance'), prog: scheduled, local: {'status': 'active', 'started_at': DateTime(2026, 10, 5, 9, 58).toUtc().toIso8601String(), 'client_uuid': 'u'});
      expect(r['eligible'], isTrue);
      expect(asJson(r['session'])['start_source'], 'offline');
    });
    test('End on this phone (offline) closes it', () {
      final r = check(member(5, 'distance'), local: {'status': 'ended', 'ended_at': DateTime(2026, 10, 5, 9, 59).toUtc().toIso8601String()});
      expect(r['reason'], 'ATTENDANCE_CLOSED');
    });
    test('a queued signed record counts as recorded', () {
      expect(check(member(5, 'distance'), pending: [{'program_id': 9, 'date': '2026-10-05', 'user_id': 5, 'status': 'present', 'signature': 'data:image/png;base64,x'}])['reason'], 'ATTENDANCE_ALREADY_RECORDED');
    });
    test('other member types are not eligible (and never absent)', () => expect(check(member(5, 'youth_adult'))['reason'], 'MEMBER_NOT_IN_GROUP'));
    test('unknown QR', () => expect(check(null)['reason'], 'MEMBER_NOT_FOUND'));
    test('takers do not record themselves', () => expect(check(member(1, 'distance'))['reason'], 'SELF_ATTENDANCE_NOT_ALLOWED'));
    test('already recorded (synced mark or one waiting in this phone\'s queue)', () {
      expect(check(member(5, 'distance'), marks: [{'program_id': 9, 'date': '2026-10-05', 'user_id': 5, 'status': 'present'}])['reason'], 'ATTENDANCE_ALREADY_RECORDED');
      expect(check(member(5, 'distance'), pending: [{'program_id': 9, 'date': '2026-10-05', 'user_id': 5, 'status': 'present'}])['reason'], 'ATTENDANCE_ALREADY_RECORDED');
    });
    test('closed after the program ended', () => expect(check(member(5, 'distance'), at: DateTime(2026, 10, 5, 13))['reason'], 'ATTENDANCE_CLOSED'));
  });

  group('member types and page links', () {
    test('administrator-created types get their server name; built-ins keep theirs', () {
      final l = lookupAppLocalizations(const Locale('en'));
      MemberGroups.set(const [
        MemberGroupInfo(key: 'youth_adult', name: 'ወጣቶች እና አዋቂዎች', nameEn: 'Youth & Adult', builtIn: true),
        MemberGroupInfo(key: 'distance', name: 'የርቀት አባላት', nameEn: 'Distance members'),
        MemberGroupInfo(key: 'old', name: 'የቀድሞ', active: false),
      ]);
      expect(memberGroupLabel(l, 'distance'), 'Distance members');
      expect(memberGroupLabel(l, 'children'), l.groupChildren);
      expect(MemberGroups.keys(), ['youth_adult', 'distance']);
      expect(MemberGroups.keys(activeOnly: false), contains('old'));
      MemberGroups.set(const []);
      expect(MemberGroups.keys(), MemberGroups.builtIn);
    });

    test('a page button can target courses, assignments, pages… and carries the class to open', () {
      expect(ctaTargetType('open_assignment'), 'assignment');
      expect(ctaTargetType('open_url'), isNull);
      final p = PageContent.fromJson({
        'id': 1,
        'title': 'x',
        'cta': {'action': 'open_assignment', 'target_id': 4, 'class_id': 2, 'target_title': 'HW', 'url': null},
      });
      expect((p.ctaAction, p.ctaTargetId, p.ctaClassId, p.ctaTargetTitle), ('open_assignment', 4, 2, 'HW'));
    });
  });
}
