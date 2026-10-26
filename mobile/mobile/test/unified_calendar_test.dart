import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/utils/formatters.dart';
import 'package:mezmur_zelideta/features/programs/calendar/unified_calendar_screen.dart';

void main() {
  group('Unified Ethiopian Yearly Calendar & Scheduling Tests', () {
    test('Ethiopian month days and 13th month leap year behavior', () {
      // Non-leap year: 2018 E.C. (2018 % 4 == 2 -> 5 days)
      expect(EthiopianDate.isLeapYear(2018), isFalse);
      expect(EthiopianDate.daysInMonth(2018, 13), 5);

      // Leap year: 2019 E.C. (2019 % 4 == 3 -> 6 days)
      expect(EthiopianDate.isLeapYear(2019), isTrue);
      expect(EthiopianDate.daysInMonth(2019, 13), 6);

      // Every regular month has exactly 30 days
      for (var m = 1; m <= 12; m++) {
        expect(EthiopianDate.daysInMonth(2019, m), 30);
        expect(EthiopianDate.daysInMonth(2018, m), 30);
      }
    });

    test('Conversion consistency at Ethiopian New Year and Pagume boundaries', () {
      // 2019 E.C. New Year: Meskerem 1, 2019 E.C.
      final newYear19 = EthiopianDate(2019, 1, 1).toGregorian();
      final roundTripNewYear = EthiopianDate.fromGregorian(newYear19);
      expect(roundTripNewYear.year, 2019);
      expect(roundTripNewYear.month, 1);
      expect(roundTripNewYear.day, 1);

      // Pagume 6 in leap year 2019 E.C.
      final pagume6 = EthiopianDate(2019, 13, 6).toGregorian();
      final roundTripPagume6 = EthiopianDate.fromGregorian(pagume6);
      expect(roundTripPagume6.year, 2019);
      expect(roundTripPagume6.month, 13);
      expect(roundTripPagume6.day, 6);

      // Day after Pagume 6 must be Meskerem 1, 2020 E.C.
      final nextDay = pagume6.add(const Duration(days: 1));
      final nextEth = EthiopianDate.fromGregorian(nextDay);
      expect(nextEth.year, 2020);
      expect(nextEth.month, 1);
      expect(nextEth.day, 1);
    });

    test('CalendarOccurrence parses all program categories and attendance details', () {
      final json = {
        'program_id': 101,
        'title': 'የሰንበት ት/ቤት ትምህርት (Sunday School Education)',
        'location': 'አዳራሽ 2',
        'category': {
          'id': 2,
          'name': 'ትምህርትና ሥልጠና',
          'name_en': 'Education and Training',
          'color': '#8B0000',
        },
        'audience': 'all',
        'recurrence': 'weekly',
        'status': 'published',
        'has_end_time': true,
        'is_education': true,
        'classes': [
          {'id': 10, 'name': 'ክፍል 5 (Grade 5)'},
          {'id': 11, 'name': 'ክፍል 6 (Grade 6)'},
        ],
        'requires_attendance': true,
        'my_attendance': 'present',
        'date': '2026-10-24',
        'starts_at': '2026-10-24T06:00:00.000Z',
        'ends_at': '2026-10-24T08:00:00.000Z',
        'ethiopian_date': 'ጥቅምት 14፣ 2019 ዓ.ም',
        'ethiopian': {'year': 2019, 'month': 2, 'day': 14},
        'rescheduled': false,
        'cancelled': false,
      };

      final occ = CalendarOccurrence.fromJson(json);

      expect(occ.programId, 101);
      expect(occ.title, 'የሰንበት ት/ቤት ትምህርት (Sunday School Education)');
      expect(occ.isEducation, isTrue);
      expect(occ.classes.length, 2);
      expect(occ.requiresAttendance, isTrue);
      expect(occ.myAttendance, 'present');
      expect(occ.ethYear, 2019);
      expect(occ.ethMonth, 2);
      expect(occ.ethDay, 14);
      expect(occ.cancelled, isFalse);

      final serialized = occ.toJson();
      expect(serialized['program_id'], 101);
      expect(serialized['requires_attendance'], isTrue);
      expect(serialized['my_attendance'], 'present');
    });

    test('CalendarOccurrence parses cancelled and rescheduled status cleanly', () {
      final json = {
        'program_id': 102,
        'title': 'የመዘምራን ልምምድ (Choir Practice)',
        'location': 'ዋና ቤተመቅደስ',
        'category': {
          'id': 3,
          'name': 'መዝሙር',
          'name_en': 'Mezmur',
          'color': '#D4AF37',
        },
        'recurrence': 'once',
        'status': 'cancelled',
        'requires_attendance': true,
        'date': '2026-10-25',
        'starts_at': '2026-10-25T14:00:00.000Z',
        'ends_at': '2026-10-25T16:00:00.000Z',
        'ethiopian': {'year': 2019, 'month': 2, 'day': 15},
        'cancelled': true,
      };

      final occ = CalendarOccurrence.fromJson(json);
      expect(occ.programId, 102);
      expect(occ.cancelled, isTrue);
      expect(occ.category?.name, 'መዝሙር');
    });
  });
}
