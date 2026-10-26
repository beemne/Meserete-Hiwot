import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

/// Ge'ez (Ethiopic) numerals, as used in the design ("፯ ምድቦች").
String ethiopicNumeral(int n) {
  if (n <= 0) return '$n';
  const ones = ['', '፩', '፪', '፫', '፬', '፭', '፮', '፯', '፰', '፱'];
  const tens = ['', '፲', '፳', '፴', '፵', '፶', '፷', '፸', '፹', '፺'];
  String below100(int v) => '${tens[v ~/ 10]}${ones[v % 10]}';
  // Split into base-100 groups; odd groups get ፻, even (>0) get ፼.
  final groups = <int>[];
  var x = n;
  while (x > 0) {
    groups.add(x % 100);
    x ~/= 100;
  }
  final buf = StringBuffer();
  for (var i = groups.length - 1; i >= 0; i--) {
    final g = groups[i];
    final isTop = i == groups.length - 1;
    if (g == 0) {
      if (i > 0 && i.isEven) buf.write('፼');
      continue;
    }
    // "፻" and "፼" are written without a leading ፩.
    if (!(g == 1 && i > 0 && isTop)) buf.write(below100(g));
    if (i > 0) buf.write(i.isOdd ? '፻' : '፼');
  }
  return buf.toString();
}

/// Ethiopian calendar date (Amete Mihret), converted via Julian Day Number.
class EthiopianDate {
  const EthiopianDate(this.year, this.month, this.day);
  final int year;
  final int month; // 1..13
  final int day;

  static int _jdnFromGregorian(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d + (153 * mm + 2) ~/ 5 + 365 * yy + yy ~/ 4 - yy ~/ 100 + yy ~/ 400 - 32045;
  }

  factory EthiopianDate.fromGregorian(DateTime date) {
    final jdn = _jdnFromGregorian(date.year, date.month, date.day);
    const epoch = 1723856; // JDN offset for the Ethiopic calendar
    final r = (jdn - epoch) % 1461;
    final n = r % 365 + 365 * (r ~/ 1460);
    final year = 4 * ((jdn - epoch) ~/ 1461) + r ~/ 365 - r ~/ 1460;
    return EthiopianDate(year, n ~/ 30 + 1, n % 30 + 1);
  }

  /// Pagume (month 13) has 6 days in the year before a Gregorian leap year, otherwise 5.
  static bool isLeapYear(int year) => year % 4 == 3;
  static int daysInMonth(int year, int month) => month < 13 ? 30 : (isLeapYear(year) ? 6 : 5);

  /// Back to the Gregorian calendar (local date, midnight).
  DateTime toGregorian() {
    const epoch = 1723856;
    // Exact inverse of fromGregorian: 4-year cycles of 1461 days, the 4th year (year % 4 == 3) has Pagume 6.
    final jdn = epoch + 1461 * (year ~/ 4) + 365 * (year % 4) + 30 * (month - 1) + day - 1;
    // JDN → Gregorian (Fliegel & Van Flandern).
    var l = jdn + 68569;
    final n = 4 * l ~/ 146097;
    l = l - (146097 * n + 3) ~/ 4;
    final i = 4000 * (l + 1) ~/ 1461001;
    l = l - 1461 * i ~/ 4 + 31;
    final j = 80 * l ~/ 2447;
    final d = l - 2447 * j ~/ 80;
    l = j ~/ 11;
    final m = j + 2 - 12 * l;
    final y = 100 * (n - 49) + i + l;
    return DateTime(y, m, d);
  }

  @override
  bool operator ==(Object other) => other is EthiopianDate && other.year == year && other.month == month && other.day == day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() => '$year-$month-$day';
}

class Formatters {
  Formatters(this.l, this.localeCode);
  final AppLocalizations l;
  final String localeCode;

  bool get _amharic => localeCode == 'am';

  String monthName(int m) => [
        l.ethMonth1, l.ethMonth2, l.ethMonth3, l.ethMonth4, l.ethMonth5, l.ethMonth6, l.ethMonth7,
        l.ethMonth8, l.ethMonth9, l.ethMonth10, l.ethMonth11, l.ethMonth12, l.ethMonth13,
      ][m - 1];

  String weekday(DateTime d) =>
      [l.weekday1, l.weekday2, l.weekday3, l.weekday4, l.weekday5, l.weekday6, l.weekday7][d.weekday - 1];

  /// Every date is shown in the Ethiopian calendar, in both languages (storage stays Gregorian):
  /// "መስከረም 14፣ 2019 ዓ.ም" / "Meskerem 14, 2019 E.C.".
  String date(DateTime? value, {bool withWeekday = false}) {
    if (value == null) return '—';
    final d = value.toLocal();
    final e = EthiopianDate.fromGregorian(d);
    final sep = _amharic ? '፣' : ',';
    final s = '${monthName(e.month)} ${e.day}$sep ${e.year} ${l.calendarEthiopian}';
    return withWeekday ? '${weekday(d)}$sep $s' : s;
  }

  /// The Gregorian date, for the rare place that must show it next to the Ethiopian one.
  String gregorianDate(DateTime? value) => value == null ? '—' : DateFormat('MMM d, y', 'en').format(value.toLocal());

  /// Short Ethiopian date without year: "መስከረም 14" / "Meskerem 14".
  String shortDate(DateTime? value) {
    if (value == null) return '—';
    final e = EthiopianDate.fromGregorian(value.toLocal());
    return '${monthName(e.month)} ${e.day}';
  }

  /// 12-hour clock with ጠዋት/ከሰዓት in Amharic.
  String time(DateTime? value) {
    if (value == null) return '—';
    final d = value.toLocal();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? l.timeMorning : l.timeAfternoon}';
  }

  String dateTime(DateTime? value) => value == null ? '—' : '${date(value)} · ${time(value)}';

  /// Parse a YYYY-MM-DD date-only value as a local calendar date.
  static DateTime? parseDateOnly(String? s) {
    if (s == null || s.length < 10) return null;
    final p = s.substring(0, 10).split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static String isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String duration(Duration? d) {
    if (d == null) return '';
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String durationSec(int? seconds) => seconds == null ? '' : duration(Duration(seconds: seconds));

  /// Formats reminder lead times in hours and minutes (Requirement 12).
  /// E.g.: "30 ደቂቃ", "1 ሰዓት", "1 ሰዓት ከ 30 ደቂቃ", "2 ሰዓት"
  static String formatReminderDuration(int minutes, {bool isEn = false}) {
    if (minutes <= 0) return isEn ? '0 minutes' : '0 ደቂቃ';
    if (minutes < 60) {
      return isEn ? '$minutes minutes' : '$minutes ደቂቃ';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      if (hours >= 24 && hours % 24 == 0) {
        final days = hours ~/ 24;
        if (isEn) return days == 1 ? '1 day' : '$days days';
        return '$days ቀን';
      }
      if (isEn) return hours == 1 ? '1 hour' : '$hours hours';
      return '$hours ሰዓት';
    }
    if (isEn) {
      final hStr = hours == 1 ? '1 hour' : '$hours hours';
      return '$hStr $remainingMinutes minutes';
    }
    return '$hours ሰዓት ከ $remainingMinutes ደቂቃ';
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String relative(DateTime? value) {
    if (value == null) return '';
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inMinutes < 1) return l.justNow;
    if (diff.inHours < 1) return l.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.daysAgo(diff.inDays);
    return date(value);
  }

  String money(num amount, String currency) => l.fineAmountValue(NumberFormat('#,##0.##').format(amount), currency);

  /// An Ethiopian month and year — "መስከረም 2019" / "Meskerem 2019".
  String monthYear(DateTime d) {
    final e = EthiopianDate.fromGregorian(d.toLocal());
    return '${monthName(e.month)} ${e.year}';
  }
}
