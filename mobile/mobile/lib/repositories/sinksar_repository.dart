import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/providers.dart';
import '../core/utils/formatters.dart';
import '../models/sinksar.dart';
import '../services/sinksar_widget_service.dart';

class SinksarRepository {
  SinksarRepository(this._api, [this._widgetService = const SinksarWidgetService()]);
  final ApiClient _api;
  final SinksarWidgetService _widgetService;

  static const String _todayCacheKey = 'sinksar_today_cache';
  static String _dateCacheKey(String date) => 'sinksar_cache_$date';

  /// Get Sinksar for today, with offline cache fallback and Android widget synchronization.
  Future<SinksarDay> today() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await _api.get('/sinksar/today', parse: (j) => SinksarDay.fromJson(j as Map<String, dynamic>));
      await prefs.setString(_todayCacheKey, jsonEncode(res.toJson()));
      await prefs.setString(_dateCacheKey(res.gregorianDate), jsonEncode(res.toJson()));
      unawaited(_widgetService.syncWidget(res));
      return res;
    } catch (_) {
      // 1. Try today cache
      final cached = prefs.getString(_todayCacheKey);
      if (cached != null) {
        try {
          final day = SinksarDay.fromJson(jsonDecode(cached) as Map<String, dynamic>);
          unawaited(_widgetService.syncWidget(day));
          return day;
        } catch (_) {}
      }
      // 2. Fall back to local calculation
      final local = _generateLocalFallback(DateTime.now());
      unawaited(_widgetService.syncWidget(local));
      return local;
    }
  }

  /// Get Sinksar for a specific date (YYYY-MM-DD), with offline cache fallback.
  Future<SinksarDay> forDate(String dateStr) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await _api.get('/sinksar/$dateStr', parse: (j) => SinksarDay.fromJson(j as Map<String, dynamic>));
      await prefs.setString(_dateCacheKey(dateStr), jsonEncode(res.toJson()));
      return res;
    } catch (_) {
      final cached = prefs.getString(_dateCacheKey(dateStr));
      if (cached != null) {
        try {
          return SinksarDay.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        } catch (_) {}
      }
      final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
      return _generateLocalFallback(parsed);
    }
  }

  /// Fallback purely on device when offline and uncached.
  static SinksarDay _generateLocalFallback(DateTime dt) {
    final eth = EthiopianDate.fromGregorian(dt);
    const monthsAm = [
      '', 'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት',
      'መጋቢት', 'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜ'
    ];
    const weekdaysAm = ['ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ'];
    const weekdaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    const monthlyFeastsMap = {
      1: 'ልደታ ለማርያም፣ ኤልያስ ነቢይ',
      2: 'ታዴዎስ ሐዋርያ',
      3: 'በዓለ ዜና ማርቆስ',
      4: 'ዮሐንስ ወልደ ነጎድጓድ',
      5: 'አቡነ ገብረ መንፈስ ቅዱስ (ጴጥሮስ ወጳውሎስ)',
      6: 'ደብረ ቁስቋም (ማርያም በስደት)',
      7: 'በዓለ ሥላሴ (አብ፣ ወልድ፣ መንፈስ ቅዱስ)',
      8: 'አባ ኪሮስ',
      9: 'ቶማስ ሐዋርያ',
      10: 'መስቀለ ክርስቶስ',
      11: 'ሐና ወኢያቄም',
      12: 'ቅዱስ ሚካኤል ሊቀ መላእክት',
      13: 'እግዚአብሔር አብ፣ ሩፋኤል ሊቀ መላእክት',
      14: 'አቡነ አረጋዊ፣ ገብረ ክርስቶስ',
      15: 'ቅዱስ ቂርቆስና እናቱ ኢየሉጣ',
      16: 'ኪዳነ ምሕረት',
      17: 'እስጢፋኖስ ቀዳሜ ሰማዕት',
      18: 'ኤዎስጣቴዎስ',
      19: 'ቅዱስ ገብርኤል ሊቀ መላእክት',
      20: 'ሕንጸተ ቤተ ክርስቲያን (ጽንጸታ ለማርያም)',
      21: 'እግዝእትነ ማርያም (በዓለ እግዝእትነ)',
      22: 'ኡራኤል ሊቀ መላእክት፣ ደቅስዮስ',
      23: 'ቅዱስ ጊዮርጊስ ሰማዕት',
      24: 'አቡነ ተክለ ሃይማኖት',
      25: 'መርቆሬዎስ ሰማዕት',
      26: 'ቶማስ ዘደብረ ማውፃ',
      27: 'መድኃኔ ዓለም',
      28: 'አማኑኤል',
      29: 'በዓለ ወልድ (እግዚእነ ኢየሱስ ክርስቶስ)',
      30: 'ዮሐንስ መጥምቅ',
    };

    final mName = eth.month >= 1 && eth.month <= 13 ? monthsAm[eth.month] : 'ወር';
    final wIdx = dt.weekday - 1; // 1 = Monday -> 0
    final wAm = wIdx >= 0 && wIdx < 7 ? weekdaysAm[wIdx] : '';
    final wEn = wIdx >= 0 && wIdx < 7 ? weekdaysEn[wIdx] : '';

    final mTitle = monthlyFeastsMap[eth.day] ?? 'ወርኀዊ የቅዱሳን መታሰቢያ';
    final gregIso = dt.toIso8601String().substring(0, 10);
    final ethIso = '${eth.year}-${eth.month.toString().padLeft(2, '0')}-${eth.day.toString().padLeft(2, '0')}';

    final isWedFri = dt.weekday == DateTime.wednesday || dt.weekday == DateTime.friday;

    return SinksarDay(
      gregorianDate: gregIso,
      ethiopianDate: ethIso,
      ethiopianYear: eth.year,
      ethiopianMonth: eth.month,
      ethiopianDay: eth.day,
      monthNameAm: mName,
      weekdayAm: wAm,
      weekdayEn: wEn,
      formattedDate: '$mName ${eth.day} ቀን ${eth.year} ዓ.ም',
      formattedFull: '$mName ${eth.day} ቀን ${eth.year} ዓ.ም · $wAm',
      isFasting: isWedFri,
      fastingReason: isWedFri ? 'የረቡዕና ዓርብ ጾም' : null,
      featuredTitle: mTitle,
      summary: 'ወርኀዊ በዓላት፦ $mTitle',
      monthlyFeasts: [
        FeastItem(
          id: '${eth.month}-${eth.day}-local',
          title: mTitle,
          sourceText: '፩. $mTitle',
        ),
      ],
      fullTextAvailable: false,
      hasNarratives: false,
    );
  }

  /// Send a single test Sinksar notification to caller's registered device only.
  Future<Map<String, dynamic>> sendTestNotification({String? targetDate}) async {
    return _api.post<Map<String, dynamic>>(
      '/sinksar/test-notification',
      body: {
        'target_date': ?targetDate,
      },
    );
  }
}

final sinksarRepositoryProvider = Provider<SinksarRepository>((ref) {
  return SinksarRepository(ref.watch(apiClientProvider));
});

final sinksarTodayProvider = FutureProvider.autoDispose<SinksarDay>((ref) {
  return ref.watch(sinksarRepositoryProvider).today();
});

final sinksarDateProvider = FutureProvider.autoDispose.family<SinksarDay, String>((ref, dateStr) {
  return ref.watch(sinksarRepositoryProvider).forDate(dateStr);
});
