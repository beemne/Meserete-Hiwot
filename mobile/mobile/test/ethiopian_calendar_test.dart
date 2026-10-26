import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/core/utils/formatters.dart';

void main() {
  test('Ethiopian New Year falls on the right Gregorian day', () {
    expect(EthiopianDate(2019, 1, 1).toGregorian(), DateTime(2026, 9, 11));
    expect(EthiopianDate(2020, 1, 1).toGregorian(), DateTime(2027, 9, 12)); // after Pagume 6
    expect(EthiopianDate.fromGregorian(DateTime(2027, 9, 11)), const EthiopianDate(2019, 13, 6));
    expect(EthiopianDate.daysInMonth(2019, 13), 6);
    expect(EthiopianDate.daysInMonth(2018, 13), 5);
  });

  test('every day from 2015 to 2035 converts to Ethiopian and back', () {
    for (var d = DateTime.utc(2015, 1, 1); d.isBefore(DateTime.utc(2035, 1, 1)); d = d.add(const Duration(days: 1))) {
      final local = DateTime(d.year, d.month, d.day);
      final e = EthiopianDate.fromGregorian(local);
      expect(e.day, inInclusiveRange(1, EthiopianDate.daysInMonth(e.year, e.month)));
      expect(e.toGregorian(), local, reason: '$local → $e');
    }
  });
}
