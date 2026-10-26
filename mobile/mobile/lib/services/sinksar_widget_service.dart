import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sinksar.dart';

final sinksarWidgetServiceProvider = Provider<SinksarWidgetService>((ref) {
  return const SinksarWidgetService();
});

/// Bridge service between Flutter and the Android Sinksar Home-Screen Widget.
class SinksarWidgetService {
  const SinksarWidgetService();

  static const MethodChannel _channel = MethodChannel('mezmur/sinksar_widget');

  /// Push the latest Sinksar day data to the Android home-screen widget.
  /// Operates safely without crashing on non-Android platforms (e.g. Web or iOS).
  Future<void> syncWidget(SinksarDay day) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final map = <String, dynamic>{
        'gregorian_date': day.gregorianDate,
        'ethiopian_date': day.ethiopianDate,
        'formatted_date': day.formattedDate,
        'formatted_full': day.formattedFull,
        'featured_title': day.featuredTitle,
        'annual_feasts': day.annualFeasts.map((f) => {'title': f.title}).toList(),
        'monthly_feasts': day.monthlyFeasts.map((f) => {'title': f.title}).toList(),
        'summary': day.summary ?? '',
        'is_fasting': day.isFasting,
        'fasting_reason': day.fastingReason,
      };
      await _channel.invokeMethod('updateWidgetData', map);
    } catch (e) {
      debugPrint('SinksarWidgetService.syncWidget failed: $e');
    }
  }

  /// Request the launcher to pin a Sinksar widget (Android 8.0+).
  /// [expanded] = true for 4x2 detailed widget, false for 2x1 compact widget.
  Future<bool> requestPinWidget({required bool expanded}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestPinWidget', {
        'type': expanded ? 'expanded' : 'compact',
      });
      return res ?? false;
    } catch (e) {
      debugPrint('SinksarWidgetService.requestPinWidget failed: $e');
      return false;
    }
  }

  /// Check whether any Sinksar widgets are active on the home screen.
  Future<({bool hasWidgets, bool compact, bool expanded})> isWidgetPinned() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return (hasWidgets: false, compact: false, expanded: false);
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('isWidgetPinned');
      if (res != null) {
        return (
          hasWidgets: res['hasWidgets'] == true,
          compact: res['compact'] == true,
          expanded: res['expanded'] == true,
        );
      }
    } catch (e) {
      debugPrint('SinksarWidgetService.isWidgetPinned failed: $e');
    }
    return (hasWidgets: false, compact: false, expanded: false);
  }

  /// Initialize callback for widget deep-link launches.
  void initWidgetLaunchHandler(void Function(String payload) onLaunch) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetLaunch') {
        final payload = call.arguments?['payload']?.toString();
        if (payload != null && payload.isNotEmpty) {
          onLaunch(payload);
        }
      }
    });

    // Check if app was started with a pending widget payload
    _channel.invokeMethod<String>('getPendingLaunchPayload').then((p) {
      if (p != null && p.isNotEmpty) {
        onLaunch(p);
      }
    }).catchError((_) {});
  }

  /// Request background refresh from Android native code.
  Future<bool> refreshWidget() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _channel.invokeMethod<bool>('refreshWidget');
      return res ?? false;
    } catch (e) {
      debugPrint('SinksarWidgetService.refreshWidget failed: $e');
      return false;
    }
  }
}
