import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';
import '../models/json.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._store);
  final ApiClient _api;
  final SecureStore _store;

  Future<({String id, String name})> _device() async {
    final id = await _store.deviceId();
    var name = 'Device';
    try {
      final info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await info.androidInfo;
        name = '${a.manufacturer} ${a.model}'.trim();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await info.iosInfo;
        name = i.utsname.machine;
      }
    } catch (_) {}
    return (id: id, name: name.length > 150 ? name.substring(0, 150) : name);
  }

  Future<AppUser> _saveSession(Json data, {String scope = 'app'}) async {
    await _store.saveTokens(access: data['access_token'] as String, refresh: data['refresh_token'] as String, scope: scope);
    final user = AppUser.fromJson(asJson(data['user']));
    return user;
  }

  Future<AppUser> login(String identifier, String password) async {
    final d = await _device();
    final data = await _api.post<Json>('/auth/login', body: {
      'identifier': identifier.trim(),
      'password': password,
      'device_id': d.id,
      'device_name': d.name,
    }, parse: asJson);
    return _saveSession(data);
  }

  /// New accounts are created "pending": nothing is stored locally until an admin approves and the user signs in.
  Future<void> register({required String fullName, required String phone, String? email, required String password, Json extra = const {}}) async {
    final d = await _device();
    await _api.post<Json>('/auth/register', body: {
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'email': (email?.trim().isEmpty ?? true) ? null : email!.trim(),
      'pin': password, // every account's secret is a PIN of 4 to 6 digits
      'device_id': d.id,
      'device_name': d.name,
      ...extra, // member_group, member_type and the membership form (profile)
    }, parse: asJson);
  }

  Future<AppUser> systemLogin(String identifier, String password, String totp) async {
    final d = await _device();
    final data = await _api.post<Json>('/system/auth/login', body: {
      'identifier': identifier.trim(),
      'password': password,
      'totp': totp.trim(),
      'device_id': d.id,
    }, parse: asJson);
    return _saveSession(data, scope: 'system');
  }

  /// Full profile (includes Telegram status and any pending name/phone change).
  Future<AppUser> me() => _api.get('/me', parse: (d) => AppUser.fromJson(asJson(d)));

  Future<void> logout() async {
    try {
      await _api.post<void>('/auth/logout', body: {'refresh_token': _store.refreshToken});
    } catch (_) {
      // Signing out locally must always succeed, even offline.
    }
  }

  Future<AppUser> changePassword(String current, String next) async {
    final data = await _api.post<Json>('/auth/change-password', body: {'current_password': current, 'new_password': next}, parse: asJson);
    return _saveSession(data, scope: _store.scope);
  }

  Future<void> forgotPassword(String identifier) => _api.post<void>('/auth/forgot-password', body: {'identifier': identifier.trim()});

  Future<void> resetPassword(String identifier, String code, String newPassword) =>
      _api.post<void>('/auth/reset-password', body: {'identifier': identifier.trim(), 'code': code.trim(), 'new_password': newPassword});
}
