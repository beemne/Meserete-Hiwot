import '../l10n/l10n.dart';

/// Client-side validation mirroring the backend rules (backend stays authoritative).
class Validators {
  Validators(this.l);
  final AppLocalizations l;

  static final _phone = RegExp(r'^(?:\+?251|0)?([79]\d{8})$');
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _html = RegExp(r'<\s*/?\s*[a-zA-Z][^>]*>');

  /// Normalise an Ethiopian mobile number to +2519XXXXXXXX (or null if invalid).
  static String? normalizePhone(String raw) {
    final m = _phone.firstMatch(raw.replaceAll(RegExp(r'[\s\-()]'), ''));
    return m == null ? null : '+251${m.group(1)}';
  }

  String? required(String? v) => (v == null || v.trim().isEmpty) ? l.vRequired : null;

  String? text(String? v, {int min = 1, int max = 255, bool optional = false}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return optional ? null : l.vRequired;
    if (s.length < min) return l.vTooShort;
    if (s.length > max) return l.vTooLong;
    if (_html.hasMatch(s)) return l.vHtmlNotAllowed;
    return null;
  }

  String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return l.vRequired;
    return normalizePhone(v) == null ? l.vInvalidPhone : null;
  }

  String? email(String? v, {bool optional = false}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return optional ? null : l.vRequired;
    return _email.hasMatch(s) ? null : l.vInvalidEmail;
  }

  String? identifier(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return l.vRequired;
    if (s.contains('@')) return email(s);
    return normalizePhone(s) == null ? l.vInvalidPhone : null;
  }

  /// Every account (members, administrators, the system authority) uses a PIN of 4 to 6 digits.
  String? password(String? v) => pin(v);

  static final _pin = RegExp(r'^\d{4,6}$');

  /// A PIN: 4 to 6 digits.
  static bool isPin(String v) => _pin.hasMatch(v);

  String? pin(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return l.vRequired;
    return isPin(s) ? null : l.vInvalidPin;
  }

  /// A new PIN (the old "PIN or password" choice no longer exists).
  String? pinOrPassword(String? v) => pin(v);

  String? Function(String?) confirmPin(String Function() original) =>
      (v) => (v ?? '') == original() ? null : l.vPinMismatch;

  String? Function(String?) confirm(String Function() original) =>
      (v) => (v ?? '') == original() ? null : l.vPinMismatch;

  String? code6(String? v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : l.vInvalidCode;

  String? intRange(String? v, {int min = 0, int max = 1 << 31, bool optional = false}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return optional ? null : l.vRequired;
    final n = int.tryParse(s);
    if (n == null) return l.vInvalidNumber;
    if (n < 0 && min >= 0) return l.vNegativeAmount;
    if (n < min || n > max) return l.vInvalidNumber;
    return null;
  }

  static final _youtube = RegExp(r'^https://(www\.|m\.|music\.)?(youtube\.com/(watch\?v=|shorts/|live/|embed/)|youtu\.be/)[A-Za-z0-9_-]{6,}([?&#][^\s<>"]*)?$');

  /// Optional YouTube link (youtube.com / youtu.be only).
  String? youtube(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    return _youtube.hasMatch(s) ? null : l.vInvalidYoutube;
  }

  String? amount(String? v, {bool optional = false}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return optional ? null : l.vRequired;
    final n = double.tryParse(s);
    if (n == null) return l.vInvalidNumber;
    if (n < 0) return l.vNegativeAmount;
    return null;
  }
}
