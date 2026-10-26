import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  // Regression: the reduced tz database lacked this alias and crashed start-up (no push registration).
  test('the time zone database used by the app knows Ethiopia', () {
    tzdata.initializeTimeZones();
    expect(tz.getLocation('Africa/Addis_Ababa').currentTimeZone.offset, const Duration(hours: 3));
  });
}
