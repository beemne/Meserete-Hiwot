import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';

/// Centralized diagnostic and application error reporting service.
///
/// Features:
/// - Captures framework, uncaught asynchronous, navigation, API, file, and UI errors.
/// - Sanitizes secrets, JWT tokens, and sensitive query parameters.
/// - Generates unique reference report IDs for user-facing error states.
/// - In-memory and server-side deduplication within a rate-limited window.
/// - Offline queuing: reports recorded while offline are queued and submitted once connectivity returns.
class ErrorReportingService {
  ErrorReportingService(this._ref);

  final Ref _ref;
  static const _pendingReportsKey = 'mz_pending_diagnostic_reports';
  final Set<String> _recentErrorFingerprints = <String>{};
  Timer? _dedupResetTimer;

  static String? appVersion;
  static String platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'));

  static Future<void> initializeAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      appVersion = '1.5.3';
    }
  }

  /// Sanitizes text by stripping passwords, tokens, pins, and auth headers.
  static String sanitize(String text) {
    var out = text;
    // Strip JWT Bearer tokens
    out = out.replaceAll(RegExp(r'(Bearer\s+)[A-Za-z0-9_\-=]+\.[A-Za-z0-9_\-=]+\.?[A-Za-z0-9_\-.\+\/=]*', caseSensitive: false), r'$1[REDACTED_JWT]');
    // Strip passwords and secrets in JSON or query params
    out = out.replaceAll(RegExp(r'("(?:password|pin|access_token|refresh_token|secret)":\s*")[^"]+(")', caseSensitive: false), r'$1[REDACTED]$2');
    out = out.replaceAll(RegExp(r'((?:password|pin|token|secret)=)[^&\s]+', caseSensitive: false), r'$1[REDACTED]');
    return out;
  }

  /// Sanitizes API URLs by stripping query strings that may contain tokens.
  static String sanitizeEndpoint(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path;
    } catch (_) {
      final qIndex = url.indexOf('?');
      return qIndex != -1 ? url.substring(0, qIndex) : url;
    }
  }

  /// Generate a client report reference ID.
  static String generateReportId({bool isUserReport = false}) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = (now.millisecondsSinceEpoch % 1000000).toRadixString(16).toUpperCase().padLeft(4, '0');
    return '${isUserReport ? "REP" : "ERR"}-$dateStr-$rand';
  }

  /// Record an automated error (API error, uncaught exception, file open failure, etc.).
  Future<String> recordError({
    required String module,
    String? screen,
    String? operation,
    String category = 'error',
    String severity = 'error',
    required Object error,
    StackTrace? stackTrace,
    String? endpoint,
    int? httpStatus,
    String? customMessage,
    bool isOffline = false,
  }) async {
    final reportId = generateReportId(isUserReport: false);
    final rawMessage = customMessage ?? error.toString();
    final safeMessage = sanitize(rawMessage);
    final safeTrace = stackTrace != null ? sanitize(stackTrace.toString()) : null;
    final cleanEndpoint = endpoint != null ? sanitizeEndpoint(endpoint) : null;

    // In-memory deduplication: prevent error loops from flooding
    final fingerprint = '$module|$screen|$category|${safeMessage.split('\n').first}';
    if (_recentErrorFingerprints.contains(fingerprint)) {
      debugPrint('[ErrorReporting] Deduplicated repeated error: $fingerprint');
      return reportId;
    }
    _recentErrorFingerprints.add(fingerprint);
    _scheduleFingerprintCleanup();

    final payload = {
      'report_id': reportId,
      'is_user_report': false,
      'module': module,
      'screen': screen,
      'operation': operation,
      'category': category,
      'severity': severity,
      'message': safeMessage,
      'stack_trace': safeTrace,
      'endpoint': cleanEndpoint,
      'http_status': httpStatus,
      'app_version': appVersion ?? '1.5.3',
      'platform': platform,
      'is_offline': isOffline,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    debugPrint('[ErrorReporting] Recording error $reportId ($module/$screen): $safeMessage');
    await _dispatchOrQueue(payload);
    return reportId;
  }

  /// Submit a user problem report with optional description, reproduction steps, and screenshot.
  Future<String> submitProblemReport({
    required String module,
    String? screen,
    required String userDescription,
    String? stepsToReproduce,
    String? screenshotPath,
    bool includeDiagnostics = true,
  }) async {
    final reportId = generateReportId(isUserReport: true);
    final safeDesc = sanitize(userDescription);
    final safeSteps = stepsToReproduce != null ? sanitize(stepsToReproduce) : null;

    final fields = <String, dynamic>{
      'report_id': reportId,
      'is_user_report': 'true',
      'module': module,
      'screen': screen ?? 'unknown',
      'category': 'user_report',
      'severity': 'warning',
      'message': safeDesc,
      'user_description': safeDesc,
      if (safeSteps != null && safeSteps.isNotEmpty) 'reproduce_steps': safeSteps,
      'app_version': appVersion ?? '1.5.3',
      'platform': platform,
      'is_offline': 'false',
    };

    try {
      final api = _ref.read(apiClientProvider);
      if (screenshotPath != null && screenshotPath.isNotEmpty && (!kIsWeb ? File(screenshotPath).existsSync() : true)) {
        await api.upload<void>(
          '/diagnostics/reports',
          filePath: screenshotPath,
          filename: 'screenshot.jpg',
          fields: fields,
        );
      } else {
        await api.post<void>('/diagnostics/reports', body: fields);
      }
      debugPrint('[ErrorReporting] User report $reportId submitted successfully');
      return reportId;
    } catch (e) {
      debugPrint('[ErrorReporting] Failed to submit user report, queuing offline: $e');
      // Queue offline
      fields['is_offline'] = 'true';
      fields['screenshot_path'] = screenshotPath;
      await _queueReport(fields);
      return reportId;
    }
  }

  /// Dispatch immediately to backend or queue if network fails / device is offline.
  Future<void> _dispatchOrQueue(Map<String, dynamic> payload) async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.post<void>('/diagnostics/reports', body: payload);
    } catch (e) {
      debugPrint('[ErrorReporting] Unable to send diagnostic report to server ($e), queuing for sync');
      await _queueReport(payload);
    }
  }

  Future<void> _queueReport(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingReportsKey) ?? <String>[];
      if (existing.length < 50) { // Bound offline queue to 50 items
        existing.add(jsonEncode(payload));
        await prefs.setStringList(_pendingReportsKey, existing);
      }
    } catch (e) {
      debugPrint('[ErrorReporting] Error saving report to preferences: $e');
    }
  }

  /// Flush any queued offline reports when connectivity is restored.
  Future<void> flushOfflineReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queued = prefs.getStringList(_pendingReportsKey);
      if (queued == null || queued.isEmpty) return;

      debugPrint('[ErrorReporting] Flushing ${queued.length} offline diagnostic reports');
      final api = _ref.read(apiClientProvider);
      final remaining = <String>[];

      for (final raw in queued) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          final screenshotPath = map['screenshot_path'] as String?;
          if (screenshotPath != null && (!kIsWeb ? File(screenshotPath).existsSync() : true)) {
            map.remove('screenshot_path');
            await api.upload<void>('/diagnostics/reports', filePath: screenshotPath, fields: map);
          } else {
            await api.post<void>('/diagnostics/reports', body: map);
          }
        } catch (_) {
          remaining.add(raw);
        }
      }

      await prefs.setStringList(_pendingReportsKey, remaining);
    } catch (e) {
      debugPrint('[ErrorReporting] Failed to flush offline reports: $e');
    }
  }

  void _scheduleFingerprintCleanup() {
    _dedupResetTimer?.cancel();
    _dedupResetTimer = Timer(const Duration(minutes: 5), () {
      _recentErrorFingerprints.clear();
    });
  }
}

final errorReportingServiceProvider = Provider<ErrorReportingService>((ref) {
  return ErrorReportingService(ref);
});
