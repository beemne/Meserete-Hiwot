import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/app/deep_links.dart';
import 'package:mezmur_zelideta/core/l10n/error_text.dart';
import 'package:mezmur_zelideta/core/network/api_exception.dart';
import 'package:mezmur_zelideta/core/utils/formatters.dart';
import 'package:mezmur_zelideta/core/utils/validators.dart';
import 'package:mezmur_zelideta/l10n/app_localizations_am.dart';
import 'package:mezmur_zelideta/models/activity.dart';
import 'package:mezmur_zelideta/models/admin.dart';
import 'package:mezmur_zelideta/models/content.dart';
import 'package:mezmur_zelideta/models/user.dart';

void main() {
  test("program detail parses the absence-permission state; errors are translated", () {
    final p = Program.fromJson({
      "id": 1, "title": "x", "starts_at": "2027-03-10T07:00:00Z", "ends_at": "2027-03-10T09:00:00Z",
      "permission": {"enabled": true, "status": "pending", "can_request": false, "can_cancel": true, "month_used": 1, "monthly_limit": 3, "quarter_used": 2, "quarterly_limit": null, "deadline_at": "2027-03-09T07:00:00Z"},
    });
    expect(p.permission!.status, "pending");
    expect(p.permission!.canCancel, isTrue);
    expect(p.permission!.monthlyLimit, 3);
    expect(p.permission!.quarterlyLimit, isNull);
    expect(Program.fromJson({"id": 2, "title": "y"}).permission, isNull);
    final l = AppLocalizationsAm();
    expect(errorText(l, const ApiException(code: "PERMISSION_MONTHLY_LIMIT")), l.errPermissionMonthly);
  });

  final l = AppLocalizationsAm();

  group('Ethiopic numerals (design uses ፯ ምድቦች)', () {
    test('converts common values', () {
      expect(ethiopicNumeral(7), '፯');
      expect(ethiopicNumeral(10), '፲');
      expect(ethiopicNumeral(23), '፳፫');
      expect(ethiopicNumeral(100), '፻');
      expect(ethiopicNumeral(123), '፻፳፫');
      expect(ethiopicNumeral(10000), '፼');
    });
  });

  group('Ethiopian calendar', () {
    test('new year (Meskerem 1) and a known date', () {
      final ny = EthiopianDate.fromGregorian(DateTime(2025, 9, 11));
      expect([ny.year, ny.month, ny.day], [2018, 1, 1]);
      final d = EthiopianDate.fromGregorian(DateTime(2026, 9, 24));
      expect([d.year, d.month, d.day], [2019, 1, 14]);
      final christmas = EthiopianDate.fromGregorian(DateTime(2026, 1, 7));
      expect([christmas.month, christmas.day], [4, 29]); // Tahsas 29 — Genna
    });

    test('formats Amharic dates with Ethiopian month names', () {
      final f = Formatters(l, 'am');
      expect(f.date(DateTime(2026, 9, 24)), 'መስከረም 14፣ 2019 ዓ.ም');
      expect(f.time(DateTime(2026, 9, 24, 18, 5)), '6:05 ከሰዓት');
    });
  });

  group('validators mirror the backend rules', () {
    final v = Validators(l);
    test('phone numbers', () {
      expect(Validators.normalizePhone('0911 22 33 44'), '+251911223344');
      expect(Validators.normalizePhone('+251711223344'), '+251711223344');
      expect(v.phone('0811223344'), l.vInvalidPhone);
      expect(v.phone(''), l.vRequired);
    });
    test('secrets are PINs of 4 to 6 digits (no passwords)', () {
      expect(v.password('short12'), l.vInvalidPin);
      expect(v.password('onlyletters'), l.vInvalidPin);
      expect(v.password('12345678'), l.vInvalidPin);
      expect(v.password('2468'), isNull);
      expect(v.password(''), l.vRequired);
    });
    test('identifier accepts phone or email', () {
      expect(v.identifier('0911223344'), isNull);
      expect(v.identifier('a@b.co'), isNull);
      expect(v.identifier('nope'), l.vInvalidPhone);
    });
    test('rejects HTML in text', () {
      expect(v.text('<b>x</b>'), l.vHtmlNotAllowed);
    });
  });

  group('error codes → Amharic messages', () {
    test('device lock and network errors', () {
      expect(errorText(l, const ApiException(code: 'DEVICE_ALREADY_REGISTERED', status: 409)), l.errDeviceAlreadyRegistered);
      expect(errorText(l, const ApiException(code: ApiException.network)), l.errorNetwork);
      expect(errorText(l, const ApiException(code: 'SOMETHING_NEW', status: 500)), l.errorServer);
    });
    test('validation errors use the first translatable field code', () {
      const e = ApiException(code: 'VALIDATION_ERROR', status: 422, fieldErrors: {'phone': 'INVALID_PHONE'});
      expect(errorText(l, e), l.vInvalidPhone);
      expect(serverFieldError(l, e, 'phone'), l.vInvalidPhone);
    });
  });

  group('deep links', () {
    test('entity routes', () {
      expect(routeForEntity('program', 5), '/programs/5');
      expect(routeForEntity('mezmur', 9), '/home/mezmur/9');
      expect(routeForEntity('borrowing', 3), '/settings/borrowings/3');
      expect(routeForEntity('page', 2), '/home/page/2');
      expect(routeForEntity(null, null), '/notifications');
    });
    test('push and local payloads', () {
      final push = parsePayload('n:42|program:7');
      expect(push.route, '/programs/7');
      expect(push.notificationId, 42);
      expect(parsePayload('program:3').route, '/programs/3');
      // Personal reminders were replaced by per-program reminders.
      expect(parsePayload('reminders').route, '/programs');
    });
  });

  group('models parse backend JSON (incl. MySQL 0/1 booleans)', () {
    test('borrowing', () {
      final b = Borrowing.fromJson({
        'id': 1,
        'item': {'id': 2, 'name': 'መጽሐፍ', 'code': 'BK-1'},
        'quantity': 2,
        'status': 'active',
        'deadline_state': 'overdue',
        'days_overdue': 3,
        'returned_quantity': 0,
        'fine': {'amount': 30, 'currency': 'ETB', 'status': 'pending', 'overridden': 0},
        'signed': 1,
      });
      expect(b.isOpen, isTrue);
      expect(b.fineAmount, 30);
      expect(b.signed, isTrue);
      expect(b.outstanding, 2);
    });
    test('mezmur without audio has no player', () {
      final m = Mezmur.fromJson({'id': 1, 'title': 'ሀ', 'lyrics': 'ለ', 'audio': null, 'has_audio': false});
      expect(m.hasAudio, isFalse);
      expect(m.audio, isNull);
    });
    test('bulk target modes', () {
      expect(const BulkTarget.users([1, 2]).toJson(), {'user_ids': [1, 2]});
      expect(const BulkTarget.everyone().toJson(), {'all': true});
      expect(const BulkTarget.filter({'q': 'a'}, excludeIds: [3]).toJson(), {'filter': {'q': 'a'}, 'exclude_ids': [3]});
    });
    test('reminder row round-trip', () {
      final r = Reminder(clientUuid: 'u', title: 't', remindAt: DateTime(2030, 1, 1, 9), notificationId: 5, repeat: 'weekly');
      final back = Reminder.fromRow(r.toRow());
      expect(back.remindAt, r.remindAt);
      expect(back.repeat, 'weekly');
    });
  });

  group('new features', () {
    test('YouTube links: only youtube.com / youtu.be, optional', () {
      final v = Validators(l);
      expect(v.youtube(''), isNull);
      expect(v.youtube('https://youtu.be/dQw4w9WgXcQ'), isNull);
      expect(v.youtube('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30'), isNull);
      expect(v.youtube('https://evil.example/watch?v=dQw4w9WgXcQ'), l.vInvalidYoutube);
      expect(v.youtube('http://youtu.be/dQw4w9WgXcQ'), l.vInvalidYoutube);
    });

    test('user parses Telegram status and a pending name/phone change', () {
      final u = AppUser.fromJson({
        'id': 1,
        'full_name': 'አበበ',
        'phone': '+251911223344',
        'telegram': {'linked': true, 'username': 'abebe'},
        'pending_change_request': {'id': 5, 'user_id': 1, 'old_full_name': 'አበበ', 'old_phone': '+251911223344', 'full_name': 'አበበ ከበደ', 'status': 'pending'},
      });
      expect(u.telegramLinked, isTrue);
      expect(u.telegramUsername, 'abebe');
      expect(u.pendingChange!.describe(), 'አበበ → አበበ ከበደ');
    });

    test('reminders can point at a borrowed item', () {
      final r = Reminder(clientUuid: 'u', title: 't', remindAt: DateTime(2030, 1, 1, 9), notificationId: 1, borrowingId: 42);
      expect(Reminder.fromRow(r.toRow()).borrowingId, 42);
      expect(r.toApi()['borrowing_id'], 42);
      expect(r.toApi().containsKey('program_id'), isFalse);
    });

    test('release parsing', () {
      final r = AppRelease.fromJson({'id': 1, 'version_name': '1.1.0', 'version_code': 2, 'is_mandatory': 1, 'file_size': 1048576});
      expect(r.isMandatory, isTrue);
      expect(r.versionCode, 2);
    });
  });

  test('every Amharic string has an English fallback and vice versa', () {
    Map<String, dynamic> load(String f) => jsonDecode(File('lib/l10n/$f').readAsStringSync()) as Map<String, dynamic>;
    Set<String> keys(Map<String, dynamic> m) => m.keys.where((k) => !k.startsWith('@')).toSet();
    final am = keys(load('app_am.arb'));
    final en = keys(load('app_en.arb'));
    expect(am.difference(en), isEmpty);
    expect(en.difference(am), isEmpty);
  });
}
