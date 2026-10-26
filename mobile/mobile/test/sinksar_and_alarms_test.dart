import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/app/deep_links.dart';
import 'package:mezmur_zelideta/features/programs/alarm_screen.dart';
import 'package:mezmur_zelideta/features/sinksar/holy_day_banner.dart';
import 'package:mezmur_zelideta/l10n/app_localizations.dart';
import 'package:mezmur_zelideta/features/programs/program_detail_screen.dart' show programProvider;
import 'package:mezmur_zelideta/core/utils/formatters.dart';
import 'package:mezmur_zelideta/models/activity.dart';
import 'package:mezmur_zelideta/models/sinksar.dart';
import 'package:mezmur_zelideta/repositories/sinksar_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 & Phase 2: Complete Notification Routing Tests', () {
    test('routes every notification entity type to the exact screen', () {
      expect(routeForEntity('alarm', 12), '/alarm/12');
      expect(routeForEntity('program_alarm', 12), '/alarm/12');
      expect(routeForEntity('program', 7), '/programs/7');
      expect(routeForEntity('program_reminder', 7), '/programs/7');
      expect(routeForEntity('attendance', 5), '/programs/5');
      expect(routeForEntity('attendance_session', 5), '/programs/5');
      expect(routeForEntity('mezmur', 3), '/home/mezmur/3');
      expect(routeForEntity('chat', 2), '/settings/chat/2');
      expect(routeForEntity('payment', 1), '/settings/payments');
      expect(routeForEntity('borrowing', 4), '/settings/borrowings/4');
      expect(routeForEntity('project', 6), '/projects/6');
      expect(routeForEntity('task', 8), '/projects/tasks/8');
      expect(routeForEntity('edu_quiz', 11), '/edu/quiz/11');
      expect(routeForEntity('edu_score', 11), '/edu/progress');
      expect(routeForEntity('edu_certificate', 1), '/edu/more');
      expect(routeForEntity('sinksar', null), '/sinksar');
      expect(routeForEntity('holy_day', null), '/sinksar');
      expect(routeForEntity('sinksar', null, extra: '2026-10-25'), '/sinksar/2026-10-25');
    });

    test('parses typed notification payloads (local, push, cold-start, deep links)', () {
      // 1. Direct alarms
      final alarm = parsePayload('alarm:15');
      expect(alarm.route, '/alarm/15');
      expect(alarm.notificationId, isNull);

      // 2. Direct Sinksar
      final sinks1 = parsePayload('sinksar');
      expect(sinks1.route, '/sinksar');
      expect(sinks1.notificationId, isNull);

      final sinks2 = parsePayload('sinksar:2026-10-25');
      expect(sinks2.route, '/sinksar/2026-10-25');
      expect(sinks2.notificationId, isNull);

      // 3. Push notifications with tracking ID and entity
      final push1 = parsePayload('n:88|alarm:15');
      expect(push1.route, '/alarm/15');
      expect(push1.notificationId, 88);

      final push2 = parsePayload('n:99|sinksar:2026-10-25');
      expect(push2.route, '/sinksar/2026-10-25');
      expect(push2.notificationId, 99);

      final push3 = parsePayload('n:105|route:/sinksar');
      expect(push3.route, '/sinksar');
      expect(push3.notificationId, 105);

      final push4 = parsePayload('n:42|program:7');
      expect(push4.route, '/programs/7');
      expect(push4.notificationId, 42);

      // 4. Direct route override
      final routePayload = parsePayload('route:/settings/notifications');
      expect(routePayload.route, '/settings/notifications');
      expect(routePayload.notificationId, isNull);
    });
  });

  group('Phase 4: Sinksar Models & Offline Fallback Tests', () {
    test('SinksarDay serializes and deserializes accurately', () {
      final json = {
        'gregorian_date': '2026-10-25',
        'ethiopian_date': '2019-02-15',
        'ethiopian_year': 2019,
        'ethiopian_month': 2,
        'ethiopian_day': 15,
        'month_name_am': 'ጥቅምት',
        'weekday_am': 'እሑድ',
        'weekday_en': 'Sunday',
        'formatted_date': 'ጥቅምት 15 ቀን 2019 ዓ.ም',
        'formatted_full': 'ጥቅምት 15 ቀን 2019 ዓ.ም · እሑድ',
        'is_fasting': 0,
        'fasting_reason': null,
        'featured_title': 'ቅዱስ ቂርቆስና ኢየሉጣ',
        'summary': 'የዕለቱ የቅዱሳን መታሰቢያ',
        'annual_feasts': [
          {'id': '2-15-1', 'title': 'ቅዱስ ቂርቆስና እናቱ ኢየሉጣ', 'sourceText': '፩. ቅዱስ ቂርቆስ'}
        ],
        'monthly_feasts': [
          {'id': '2-15-m', 'title': 'ቂርቆስና ኢየሉጣ', 'sourceText': 'ቂርቆስና ኢየሉጣ'}
        ],
        'full_text_available': 0,
        'narratives': [],
        'has_narratives': 0,
      };

      final day = SinksarDay.fromJson(json);
      expect(day.gregorianDate, '2026-10-25');
      expect(day.ethiopianYear, 2019);
      expect(day.ethiopianMonth, 2);
      expect(day.ethiopianDay, 15);
      expect(day.monthNameAm, 'ጥቅምት');
      expect(day.featuredTitle, 'ቅዱስ ቂርቆስና ኢየሉጣ');
      expect(day.annualFeasts.length, 1);
      expect(day.annualFeasts.first.title, 'ቅዱስ ቂርቆስና እናቱ ኢየሉጣ');
      expect(day.isFasting, isFalse);
      expect(day.fullTextAvailable, isFalse);
    });
  });

  group('Phase 3 & 5: Widget Verification Tests', () {
    testWidgets('HolyDayBanner renders branding, Ethiopian date, and feast title', (tester) async {
      const mockDay = SinksarDay(
        gregorianDate: '2026-10-25',
        ethiopianDate: '2019-02-15',
        ethiopianYear: 2019,
        ethiopianMonth: 2,
        ethiopianDay: 15,
        monthNameAm: 'ጥቅምት',
        weekdayAm: 'እሑድ',
        weekdayEn: 'Sunday',
        formattedDate: 'ጥቅምት 15 ቀን 2019 ዓ.ም',
        formattedFull: 'ጥቅምት 15 ቀን 2019 ዓ.ም · እሑድ',
        isFasting: false,
        featuredTitle: 'ቅዱስ ቂርቆስና ኢየሉጣ',
        annualFeasts: [
          FeastItem(id: '1', title: 'ቅዱስ ቂርቆስ', sourceText: '፩. ቅዱስ ቂርቆስ'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sinksarTodayProvider.overrideWith((ref) => Future.value(mockDay)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('am'),
            home: Scaffold(
              body: HolyDayBanner(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('የዕለቱን ስንክሳር አንብብ'), findsOneWidget);
      expect(find.text('ቅዱስ ቂርቆስና ኢየሉጣ'), findsOneWidget);
      expect(find.textContaining('ጥቅምት 15'), findsWidgets);
    });

    testWidgets('AlarmScreen renders Orthodox church branding, program details, Stop and Snooze', (tester) async {
      final mockProgram = Program(
        id: 7,
        title: 'የሰንበት ትምህርት ቤት ጉባኤ',
        description: 'የሳምንታዊ መንፈሳዊ ትምህርት እና የመዝሙር ጥናት ፕሮግራም',
        location: 'ዋናው አዳራሽ',
        startsAt: DateTime(2026, 10, 25, 9, 0),
        endsAt: DateTime(2026, 10, 25, 12, 0),
        category: const ProgramCategory(id: 1, name: 'ጉባኤ'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            programProvider(7).overrideWith((ref) => Future.value(mockProgram)),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('am'),
            home: AlarmScreen(programId: 7),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Meserete Hiwot Orthodox branding
      expect(find.text('መሠረተ ሕይወት'), findsOneWidget);
      expect(find.text('የመርሐ ግብር ማንቂያ'), findsOneWidget);

      // Verify program info
      expect(find.text('የሰንበት ትምህርት ቤት ጉባኤ'), findsOneWidget);
      expect(find.text('ዋናው አዳራሽ'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('አቁም'), findsOneWidget);
      expect(find.text('አሸልብ (10 ደቂቃ)'), findsOneWidget);
      expect(find.text('የመርሐ ግብሩን ሙሉ ዝርዝር ተመልከት'), findsOneWidget);
    });
  });

  group('Phase 8: Sinksar Android Home-Screen Widget Integration Tests', () {
    test('verifies accurate Ethiopian Calendar conversions for known Orthodox feast dates', () {
      // 1. Enkutatash (Ethiopian New Year 2019)
      final enkutatash = EthiopianDate.fromGregorian(DateTime(2026, 9, 11));
      expect(enkutatash.year, 2019);
      expect(enkutatash.month, 1);
      expect(enkutatash.day, 1);
      expect(enkutatash.toGregorian(), DateTime(2026, 9, 11));

      // 2. Meskel (Finding of True Cross)
      final meskel = EthiopianDate.fromGregorian(DateTime(2026, 9, 27));
      expect(meskel.year, 2019);
      expect(meskel.month, 1);
      expect(meskel.day, 17);
      expect(meskel.toGregorian(), DateTime(2026, 9, 27));

      // 3. Known day: Tikimt 15 (Kirkos & Iyeluta)
      final tikimt15 = EthiopianDate.fromGregorian(DateTime(2026, 10, 25));
      expect(tikimt15.year, 2019);
      expect(tikimt15.month, 2);
      expect(tikimt15.day, 15);
      expect(tikimt15.toGregorian(), DateTime(2026, 10, 25));

      // 4. Genna (Ethiopian Christmas)
      final genna = EthiopianDate.fromGregorian(DateTime(2027, 1, 7));
      expect(genna.year, 2019);
      expect(genna.month, 4);
      expect(genna.day, 29);
      expect(genna.toGregorian(), DateTime(2027, 1, 7));

      // 5. Timket (Epiphany)
      final timket = EthiopianDate.fromGregorian(DateTime(2027, 1, 19));
      expect(timket.year, 2019);
      expect(timket.month, 5);
      expect(timket.day, 11);
      expect(timket.toGregorian(), DateTime(2027, 1, 19));
    });

    test('verifies Sinksar widget deep linking and payload parsing', () {
      final p1 = parsePayload('sinksar:2026-10-25');
      expect(p1.route, '/sinksar/2026-10-25');

      final p2 = parsePayload('sinksar');
      expect(p2.route, '/sinksar');

      final p3 = parsePayload('n:200|sinksar:2026-10-25');
      expect(p3.route, '/sinksar/2026-10-25');
      expect(p3.notificationId, 200);

      final p4 = routeForEntity('sinksar', null, extra: '2026-10-25');
      expect(p4, '/sinksar/2026-10-25');
    });

    test('verifies SinksarDay payload structure for Android widget RemoteViews', () {
      const day = SinksarDay(
        gregorianDate: '2026-10-25',
        ethiopianDate: '2019-02-15',
        ethiopianYear: 2019,
        ethiopianMonth: 2,
        ethiopianDay: 15,
        monthNameAm: 'ጥቅምት',
        weekdayAm: 'እሑድ',
        weekdayEn: 'Sunday',
        formattedDate: 'ጥቅምት 15 ቀን 2019 ዓ.ም',
        formattedFull: 'ጥቅምት 15 ቀን 2019 ዓ.ም · እሑድ',
        isFasting: false,
        fastingReason: null,
        featuredTitle: '፲፪ቱ ቅዱሳን ሐዋርያት',
        summary: 'ዓመታዊ፦ ፲፪ቱ ሐዋርያት · ወርኀዊ፦ ቅዱስ ቂርቆስና እናቱ ኢየሉጣ',
        annualFeasts: [
          FeastItem(id: '1', title: '፲፪ቱ ቅዱሳን ሐዋርያት', sourceText: '፩. ፲፪ቱ ሐዋርያት')
        ],
        monthlyFeasts: [
          FeastItem(id: '2', title: 'ቅዱስ ቂርቆስና እናቱ ኢየሉጣ', sourceText: '፩. ቅዱስ ቂርቆስ')
        ],
      );

      final map = <String, dynamic>{
        'gregorian_date': day.gregorianDate,
        'ethiopian_date': day.ethiopianDate,
        'formatted_date': day.formattedDate,
        'formatted_full': day.formattedFull,
        'featured_title': day.featuredTitle,
        'annual_feasts': day.annualFeasts.map((f) => {'title': f.title}).toList(),
        'monthly_feasts': day.monthlyFeasts.map((f) => {'title': f.title}).toList(),
        'summary': day.summary,
        'is_fasting': day.isFasting,
        'fasting_reason': day.fastingReason,
      };

      expect(map['gregorian_date'], '2026-10-25');
      expect(map['ethiopian_date'], '2019-02-15');
      expect(map['formatted_date'], 'ጥቅምት 15 ቀን 2019 ዓ.ም');
      expect(map['featured_title'], '፲፪ቱ ቅዱሳን ሐዋርያት');
      expect((map['annual_feasts'] as List).first['title'], '፲፪ቱ ቅዱሳን ሐዋርያት');
      expect((map['monthly_feasts'] as List).first['title'], 'ቅዱስ ቂርቆስና እናቱ ኢየሉጣ');
      expect(map['is_fasting'], isFalse);
    });
  });
}

