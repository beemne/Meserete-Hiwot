import 'package:shared_preferences/shared_preferences.dart';

/// Device-level preferences cached locally so they work offline.
/// Account-level preferences are also stored on the server (see preferences feature).
class LocalPrefs {
  LocalPrefs(this._p);
  final SharedPreferences _p;

  SharedPreferences get raw => _p;

  static Future<LocalPrefs> load() async => LocalPrefs(await SharedPreferences.getInstance());

  String get localeCode => _p.getString('locale') ?? 'am';
  Future<void> setLocaleCode(String v) => _p.setString('locale', v);

  /// 'system' | 'light' | 'dark'
  String get theme => _p.getString('theme') ?? 'light';
  Future<void> setTheme(String v) => _p.setString('theme', v);

  /// Fingerprint (or the phone's screen lock) asked when the app opens — this phone only.
  bool get biometricLock => _p.getBool('biometric_lock') ?? false;
  Future<void> setBiometricLock(bool v) => _p.setBool('biometric_lock', v);

  bool get wifiOnly => _p.getBool('wifi_only') ?? true;
  Future<void> setWifiOnly(bool v) => _p.setBool('wifi_only', v);

  double get lyricsScale => _p.getDouble('lyrics_scale') ?? 1.0;
  Future<void> setLyricsScale(double v) => _p.setDouble('lyrics_scale', v);

  List<String> get recentSearches => _p.getStringList('recent_searches') ?? const [];
  Future<void> addRecentSearch(String q) {
    final list = [q, ...recentSearches.where((e) => e != q)].take(8).toList();
    return _p.setStringList('recent_searches', list);
  }

  Future<void> clearRecentSearches() => _p.remove('recent_searches');

  String? get cachedPreferences => _p.getString('server_prefs');
  Future<void> setCachedPreferences(String json) => _p.setString('server_prefs', json);

  /// Unsaved editor state (admin editors keep a draft of every change until it is submitted).
  String? draft(String key) => _p.getString('draft:$key');
  Future<void> setDraft(String key, String json) => _p.setString('draft:$key', json);
  Future<void> removeDraft(String key) => _p.remove('draft:$key');

  int get dismissedUpdateCode => _p.getInt('dismissed_update_code') ?? 0;
  Future<void> setDismissedUpdateCode(int v) => _p.setInt('dismissed_update_code', v);

  DateTime? get remindersSyncedAt => DateTime.tryParse(_p.getString('reminders_synced_at') ?? '');
  Future<void> setRemindersSyncedAt(DateTime d) => _p.setString('reminders_synced_at', d.toIso8601String());

  DateTime? get lastSuccessfulSync => DateTime.tryParse(_p.getString('last_successful_sync') ?? '');
  Future<void> setLastSuccessfulSync(DateTime d) => _p.setString('last_successful_sync', d.toIso8601String());

  Future<void> clearUserScoped() async {
    await _p.remove('server_prefs');
    await _p.remove('reminders_synced_at');
    await _p.remove('last_successful_sync');
    await _p.remove('recent_searches');
  }
}
