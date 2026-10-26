import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/app/chrome.dart';
import 'package:mezmur_zelideta/features/settings/attendance_calendar.dart';
import 'package:mezmur_zelideta/models/activity.dart';
import 'package:mezmur_zelideta/models/user.dart';
import 'package:mezmur_zelideta/services/local_notifications.dart';

void main() {
  group('Home tab icon follows the section', () {
    test('hub / ትምህርት / መዝሙር', () {
      expect(homeSectionOf('/hub'), HomeSection.hub);
      expect(homeSectionOf('/notifications'), HomeSection.hub);
      expect(homeSectionOf('/edu/class/3'), HomeSection.education);
      expect(homeSectionOf('/home'), HomeSection.mezmur);
      expect(homeSectionOf('/home/category/4'), HomeSection.mezmur);
    });

    testWidgets('kebero icon paints in both styles', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Row(children: [KeberoIcon(size: 24), KeberoIcon(size: 48, filled: true), HomeTabIcon(section: HomeSection.mezmur, selected: true)])),
      ));
      expect(find.byType(KeberoIcon), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('Recurring programs', () {
    final json = {
      'id': 7,
      'title': 'ሰንበት',
      'starts_at': '2026-09-06T06:00:00.000Z',
      'ends_at': '2026-09-06T08:00:00.000Z',
      'status': 'published',
      'recurrence': 'weekly',
      'category': {'id': 2, 'name': 'ትምህርት', 'name_en': 'Education', 'color': '#1F5F8B'},
      'next_occurrence': {'date': '2026-10-04', 'starts_at': '2026-10-04T06:00:00.000Z', 'ends_at': '2026-10-04T08:00:00.000Z'},
      'upcoming_occurrences': [
        {'date': '2026-10-04', 'starts_at': '2026-10-04T06:00:00.000Z', 'ends_at': '2026-10-04T08:00:00.000Z'},
        {'date': '2026-10-11', 'starts_at': '2026-10-11T06:00:00.000Z', 'ends_at': '2026-10-11T08:00:00.000Z'},
      ],
    };

    test('parses category, recurrence and next occurrence', () {
      final p = Program.fromJson(json);
      expect(p.isRecurring, isTrue);
      expect(p.category!.label('en'), 'Education');
      expect(p.category!.label('am'), 'ትምህርት');
      expect(p.displayStart.toUtc(), DateTime.parse('2026-10-04T06:00:00.000Z'));
      expect(p.isPast, isFalse); // the first date is past, but the series is not
    });

    test('alarms at the reminder times before every upcoming occurrence (default 1 day + 1 hour)', () {
      final p = Program.fromJson(json);
      final times = LocalNotifications.programAlarmTimes(p, DateTime.parse('2026-10-01T00:00:00Z')).map((d) => d.toUtc()).toList();
      expect(times, [
        DateTime.parse('2026-10-03T06:00:00.000Z'),
        DateTime.parse('2026-10-04T05:00:00.000Z'),
        DateTime.parse('2026-10-10T06:00:00.000Z'),
        DateTime.parse('2026-10-11T05:00:00.000Z'),
      ]);
      // alarms whose time has passed are skipped
      final later = LocalNotifications.programAlarmTimes(p, DateTime.parse('2026-10-04T05:30:00Z')).map((d) => d.toUtc()).toList();
      expect(later, [DateTime.parse('2026-10-10T06:00:00.000Z'), DateTime.parse('2026-10-11T05:00:00.000Z')]);
      // ids never collide between programs / slots
      expect(LocalNotifications.programAlarmId(7, 1), isNot(LocalNotifications.programAlarmId(8, 0)));
      expect(LocalNotifications.programAlarmId(7, 23), lessThan(LocalNotifications.programAlarmId(8, 0)));
    });

    test('the program\'s own reminder times, or the member\'s choice (2 days / 1 day / 6 h / 1 h)', () {
      final p = Program.fromJson({
        'id': 1, 'title': 'x', 'starts_at': '2026-10-04T06:00:00Z', 'ends_at': '2026-10-04T07:00:00Z',
        'reminder': {'enabled': true, 'offsets': [2880, 360]},
      });
      expect(LocalNotifications.programAlarmTimes(p, DateTime.parse('2026-10-01T00:00:00Z')).map((d) => d.toUtc()),
          [DateTime.parse('2026-10-02T06:00:00Z'), DateTime.parse('2026-10-04T00:00:00Z')]);
      final mine = Program.fromJson({
        'id': 1, 'title': 'x', 'starts_at': '2026-10-04T06:00:00Z', 'ends_at': '2026-10-04T07:00:00Z',
        'reminder': {'enabled': true, 'offsets': [2880, 360]}, 'my_reminder_offsets': [60],
      });
      expect(LocalNotifications.programAlarmTimes(mine, DateTime.parse('2026-10-01T00:00:00Z')).map((d) => d.toUtc()), [DateTime.parse('2026-10-04T05:00:00Z')]);
      final none = Program.fromJson({
        'id': 1, 'title': 'x', 'starts_at': '2026-10-04T06:00:00Z', 'ends_at': '2026-10-04T07:00:00Z', 'my_reminder_offsets': <int>[],
      });
      expect(LocalNotifications.programAlarmTimes(none, DateTime.parse('2026-10-01T00:00:00Z')), isEmpty);
    });

    test('a program without an end time', () {
      final p = Program.fromJson({'id': 1, 'title': 'x', 'starts_at': '2026-10-04T06:00:00Z', 'ends_at': '2026-10-04T20:59:59Z', 'has_end_time': false, 'attendance_window': {'on_time_minutes': 30, 'late_minutes': 15}});
      expect(p.hasEndTime, isFalse);
      expect(p.onTimeMinutes, 30);
      expect(p.lateMinutes, 15);
    });
  });

  group('Attendance calendar', () {
    test('colour for every state, with an icon', () {
      expect(attendanceStyle('none').color, Colors.white);
      expect(attendanceStyle('present').color, const Color(0xFF2E7D32)); // green
      expect(attendanceStyle('late').color, const Color(0xFFC0CA33)); // lime
      expect(attendanceStyle('excused').color, const Color(0xFFFDD835)); // yellow
      expect(attendanceStyle('absent').color, const Color(0xFFC62828)); // red
      expect(attendanceStyle('upcoming').color, attendanceStyle('today').color); // golden
      for (final s in ['none', 'upcoming', 'present', 'late', 'excused', 'absent']) {
        expect(attendanceStyle(s).icon, isNotNull);
      }
    });

    test('parses days and server statistics', () {
      final c = AttendanceCalendar.fromJson({
        'days': [
          {
            'date': '2026-09-27',
            'state': 'late',
            'occurrences': [
              {'program_id': 1, 'title': 'x', 'date': '2026-09-27', 'starts_at': '2026-09-27T06:00:00Z', 'ends_at': '2026-09-27T07:00:00Z', 'status': 'late'},
            ],
          },
        ],
        'stats': {'total_programs': 4, 'attended': 1, 'late': 1, 'excused': 1, 'absent': 1, 'percentage': 62.5},
      });
      expect(c.days['2026-09-27']!.state, 'late');
      expect(c.days['2026-09-27']!.entries.single.status, 'late');
      expect(c.stats.percentage, 62.5);
      expect(c.stats.total, 4);
    });
  });

  test('member type is read from the profile', () {
    final u = AppUser.fromJson({'id': 3, 'full_name': 'a', 'phone': '0911', 'member_type': 'worker'});
    expect(u.memberType, 'worker');
    expect(AppUser.fromJson(u.toJson()).memberType, 'worker');
  });

  test('notification tray tags match the server (n<id>)', () {
    expect(LocalNotifications.messageTag(42), 'n42');
  });
}
