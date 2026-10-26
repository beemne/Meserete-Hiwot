import '../models/json.dart';

class FeastItem {
  const FeastItem({
    required this.id,
    required this.title,
    required this.sourceText,
  });

  final String id;
  final String title;
  final String sourceText;

  factory FeastItem.fromJson(Json j) => FeastItem(
        id: asStr(j['id']) ?? '',
        title: asStr(j['title']) ?? '',
        sourceText: asStr(j['sourceText']) ?? asStr(j['title']) ?? '',
      );

  Json toJson() => {
        'id': id,
        'title': title,
        'sourceText': sourceText,
      };
}

class SinksarNarrative {
  const SinksarNarrative({
    required this.id,
    required this.title,
    this.source,
    this.summary,
    required this.body,
    this.verified = false,
  });

  final int id;
  final String title;
  final String? source;
  final String? summary;
  final String body;
  final bool verified;

  factory SinksarNarrative.fromJson(Json j) => SinksarNarrative(
        id: asInt(j['id']) ?? 0,
        title: asStr(j['title']) ?? '',
        source: asStr(j['source']),
        summary: asStr(j['summary']),
        body: asStr(j['body']) ?? '',
        verified: j['verified'] == true || j['verified'] == 1,
      );

  Json toJson() => {
        'id': id,
        'title': title,
        'source': source,
        'summary': summary,
        'body': body,
        'verified': verified,
      };
}

class SinksarDay {
  const SinksarDay({
    required this.gregorianDate,
    required this.ethiopianDate,
    required this.ethiopianYear,
    required this.ethiopianMonth,
    required this.ethiopianDay,
    required this.monthNameAm,
    required this.weekdayAm,
    required this.weekdayEn,
    required this.formattedDate,
    required this.formattedFull,
    required this.isFasting,
    this.fastingReason,
    required this.featuredTitle,
    this.summary,
    this.annualFeasts = const [],
    this.monthlyFeasts = const [],
    this.fullTextAvailable = false,
    this.narratives = const [],
    this.hasNarratives = false,
  });

  final String gregorianDate;
  final String ethiopianDate;
  final int ethiopianYear;
  final int ethiopianMonth;
  final int ethiopianDay;
  final String monthNameAm;
  final String weekdayAm;
  final String weekdayEn;
  final String formattedDate;
  final String formattedFull;
  final bool isFasting;
  final String? fastingReason;
  final String featuredTitle;
  final String? summary;
  final List<FeastItem> annualFeasts;
  final List<FeastItem> monthlyFeasts;
  final bool fullTextAvailable;
  final List<SinksarNarrative> narratives;
  final bool hasNarratives;

  factory SinksarDay.fromJson(Json j) => SinksarDay(
        gregorianDate: asStr(j['gregorian_date']) ?? '',
        ethiopianDate: asStr(j['ethiopian_date']) ?? '',
        ethiopianYear: asInt(j['ethiopian_year']) ?? 0,
        ethiopianMonth: asInt(j['ethiopian_month']) ?? 0,
        ethiopianDay: asInt(j['ethiopian_day']) ?? 0,
        monthNameAm: asStr(j['month_name_am']) ?? '',
        weekdayAm: asStr(j['weekday_am']) ?? '',
        weekdayEn: asStr(j['weekday_en']) ?? '',
        formattedDate: asStr(j['formatted_date']) ?? '',
        formattedFull: asStr(j['formatted_full']) ?? '',
        isFasting: j['is_fasting'] == true || j['is_fasting'] == 1,
        fastingReason: asStr(j['fasting_reason']),
        featuredTitle: asStr(j['featured_title']) ?? 'የቅዱሳን መታሰቢያ',
        summary: asStr(j['summary']),
        annualFeasts: asList(j['annual_feasts'], FeastItem.fromJson),
        monthlyFeasts: asList(j['monthly_feasts'], FeastItem.fromJson),
        fullTextAvailable: j['full_text_available'] == true || j['full_text_available'] == 1,
        narratives: asList(j['narratives'], SinksarNarrative.fromJson),
        hasNarratives: j['has_narratives'] == true || (j['narratives'] is List && (j['narratives'] as List).isNotEmpty),
      );

  Json toJson() => {
        'gregorian_date': gregorianDate,
        'ethiopian_date': ethiopianDate,
        'ethiopian_year': ethiopianYear,
        'ethiopian_month': ethiopianMonth,
        'ethiopian_day': ethiopianDay,
        'month_name_am': monthNameAm,
        'weekday_am': weekdayAm,
        'weekday_en': weekdayEn,
        'formatted_date': formattedDate,
        'formatted_full': formattedFull,
        'is_fasting': isFasting,
        'fasting_reason': fastingReason,
        'featured_title': featuredTitle,
        'summary': summary,
        'annual_feasts': annualFeasts.map((e) => e.toJson()).toList(),
        'monthly_feasts': monthlyFeasts.map((e) => e.toJson()).toList(),
        'full_text_available': fullTextAvailable,
        'narratives': narratives.map((e) => e.toJson()).toList(),
        'has_narratives': hasNarratives,
      };
}
