import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Blocks screenshots, screen recording and the recent-apps preview (Android FLAG_SECURE) while
/// [child] is shown — for member information, profiles and QR codes only; the rest of the app
/// (Mezmur pages…) can still be captured. Nested / overlapping secure screens are counted, so
/// leaving one never unprotects another that is still open. It cannot stop someone photographing
/// the screen with another device.
class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child});
  final Widget child;

  static const _channel = MethodChannel('mezmur/settings');
  static int _open = 0;

  static Future<void> _apply(bool on) async {
    try {
      await _channel.invokeMethod('setSecure', {'on': on});
    } catch (_) {
      // Not Android / widget tests: nothing to do.
    }
  }

  /// Turn protection on for something that is not a widget (e.g. a full-screen reader).
  static void acquire() {
    if (_open++ == 0) _apply(true);
  }

  static void release() {
    if (_open == 0) return;
    if (--_open == 0) _apply(false);
  }

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    SecureScreen.acquire();
  }

  @override
  void dispose() {
    SecureScreen.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
