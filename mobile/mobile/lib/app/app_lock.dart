import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../core/l10n/l10n.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/session.dart';

/// Fingerprint lock: each member may lock the app on their own phone with the phone's fingerprint
/// sensor (or its screen lock when no finger is enrolled). The fingerprint is checked by the phone
/// itself (Android BiometricPrompt): nothing about it is stored by the app or sent to the server.
/// It protects the app on this phone only — it is not used to identify members (attendance stays
/// QR / manual).
class AppLock {
  AppLock(this._ref);
  final Ref _ref;
  final _auth = LocalAuthentication();

  bool get enabled => _ref.read(localPrefsProvider).biometricLock;

  /// Whether this phone can verify its owner (fingerprint, face or screen lock).
  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Show the phone's own fingerprint prompt (screen lock allowed as a fallback).
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, options: const AuthenticationOptions(stickyAuth: true));
    } on PlatformException {
      return false;
    }
  }

  /// Turn the lock on (after one successful check) or off.
  Future<bool> setEnabled(bool on, String reason) async {
    if (on && (!await available() || !await authenticate(reason))) return false;
    await _ref.read(localPrefsProvider).setBiometricLock(on);
    return true;
  }
}

final appLockProvider = Provider<AppLock>(AppLock.new);

/// Covers the app with a lock screen when it opens, or comes back after a while in the background,
/// while the fingerprint lock is on and someone is signed in.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  /// Time in the background after which the lock is asked again.
  static const relockAfter = Duration(seconds: 60);

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  late bool _locked = ref.read(appLockProvider).enabled;
  DateTime? _pausedAt;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The fingerprint prompt itself pauses the app: ignore that.
    if (_asking) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _pausedAt == null ? Duration.zero : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (ref.read(appLockProvider).enabled && away >= AppLockGate.relockAfter && !_locked) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    final l = lookupAppLocalizations(ref.read(appSettingsProvider).locale);
    final ok = await ref.read(appLockProvider).authenticate(l.bioReason);
    _asking = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(sessionProvider) is SignedIn;
    if (!_locked || !signedIn || !ref.watch(appLockProvider).enabled) return widget.child;
    final l = context.l10n;
    return Stack(children: [
      // The app stays alive underneath (audio keeps playing) but cannot be seen or touched.
      Offstage(child: widget.child),
      Positioned.fill(
        child: Material(
          color: AppColors.maroon,
          child: SafeArea(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.fingerprint_rounded, size: 88, color: Colors.white),
                const SizedBox(height: 16),
                Text(l.bioLocked, style: context.serif(20, color: Colors.white)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('app-unlock'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.white),
                  onPressed: _unlock,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(l.bioUnlock),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
