import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../services/book_vault.dart';

sealed class SessionState {
  const SessionState();
}

class SessionUnknown extends SessionState {
  const SessionUnknown();
}

class SignedOut extends SessionState {
  const SignedOut({this.reasonCode});

  /// e.g. SESSION_REVOKED after an admin device reset — shown once on the login screen.
  final String? reasonCode;
}

class SignedIn extends SessionState {
  const SignedIn(this.user, {this.isSystem = false, this.offline = false});
  final AppUser user;

  /// Signed in through the internal system login (scope "system").
  final bool isSystem;

  /// Restored from the cached profile because the server was unreachable.
  final bool offline;
}

/// Hooks other services register to react to sign-in / sign-out (push, sync, downloads…).
typedef SessionHook = Future<void> Function(AppUser? user);

class SessionController extends Notifier<SessionState> {
  final _onSignIn = <SessionHook>[];
  final _onSignOut = <SessionHook>[];

  void addSignInHook(SessionHook h) => _onSignIn.add(h);
  void addSignOutHook(SessionHook h) => _onSignOut.add(h);

  @override
  SessionState build() {
    ref.read(apiClientProvider).onSessionExpired = () => unawaited(expire());
    // A refused action (403) may mean a permission was just revoked: reload the account (at most
    // every 15 s) so menus and route guards follow the server at once, not only at the next start.
    ref.read(apiClientProvider).onForbidden = () {
      final now = DateTime.now();
      if (_lastForbiddenRefresh != null && now.difference(_lastForbiddenRefresh!) < const Duration(seconds: 15)) return;
      _lastForbiddenRefresh = now;
      if (state is SignedIn) unawaited(refreshUser());
    };
    Future.microtask(bootstrap);
    return const SessionUnknown();
  }

  AppUser? get user => switch (state) { SignedIn(:final user) => user, _ => null };

  Future<void> bootstrap() async {
    final store = ref.read(secureStoreProvider);
    await store.load();
    if (!store.hasSession) {
      state = const SignedOut();
      return;
    }
    try {
      final me = await ref.read(authRepositoryProvider).me();
      await _enter(me);
    } on ApiException catch (e) {
      // Only a real rejection signs out. Offline, a timeout, a server error or a token refresh that
      // could not reach the server opens the app with the saved account; it reconnects later.
      if (!e.endsSession) {
        final cached = await store.readUserJson();
        if (cached != null) {
          state = SignedIn(AppUser.fromJson(asJson(jsonDecode(cached))), isSystem: store.scope == 'system', offline: true);
          await _runHooks(_onSignIn, user);
          return;
        }
      }
      await _clear(reason: e.isUnauthorized ? e.code : null);
    }
  }

  Future<void> _enter(AppUser u) async {
    final store = ref.read(secureStoreProvider);
    await store.saveUserJson(jsonEncode(u.toJson()));
    state = SignedIn(u, isSystem: store.scope == 'system');
    await _runHooks(_onSignIn, u);
  }

  Future<void> _runHooks(List<SessionHook> hooks, AppUser? u) async {
    for (final h in hooks) {
      try {
        await h(u);
      } catch (e) {
        debugPrint('session hook failed: $e');
      }
    }
  }

  Future<void> login(String identifier, String password) async => _enter(await ref.read(authRepositoryProvider).login(identifier, password));

  /// Registration does not sign in: the account waits for an administrator's approval.
  Future<void> register({required String fullName, required String phone, String? email, required String password, Json extra = const {}}) =>
      ref.read(authRepositoryProvider).register(fullName: fullName, phone: phone, email: email, password: password, extra: extra);

  Future<void> systemLogin(String identifier, String password, String totp) async =>
      _enter(await ref.read(authRepositoryProvider).systemLogin(identifier, password, totp));

  Future<void> changePassword(String current, String next) async =>
      _enter(await ref.read(authRepositoryProvider).changePassword(current, next));

  /// Refresh the profile (e.g. after editing it, or when permissions may have changed).
  Future<void> refreshUser() async {
    try {
      final me = await ref.read(authRepositoryProvider).me();
      final store = ref.read(secureStoreProvider);
      await store.saveUserJson(jsonEncode(me.toJson()));
      state = SignedIn(me, isSystem: store.scope == 'system');
    } catch (_) {}
  }

  void updateUser(AppUser u) {
    final s = state;
    if (s is SignedIn) state = SignedIn(u, isSystem: s.isSystem);
    unawaited(ref.read(secureStoreProvider).saveUserJson(jsonEncode(u.toJson())));
  }

  DateTime? _lastForbiddenRefresh;

  bool _signingOut = false;

  /// Sign out safely: pending offline changes are preserved by default so they can sync later.
  /// If [discard] is true, the leaving user's queued offline changes are explicitly discarded.
  Future<void> logout({bool discard = false}) async {
    if (_signingOut || state is! SignedIn) return;
    final leavingUser = user;
    _signingOut = true;
    try {
      await _runHooks(_onSignOut, leavingUser).timeout(const Duration(seconds: 10), onTimeout: () {});
      await ref.read(authRepositoryProvider).logout().timeout(const Duration(seconds: 8), onTimeout: () {});
    } finally {
      await _clear(discardUserId: discard ? leavingUser?.id : null);
      _signingOut = false;
    }
  }

  /// The server rejected our tokens (device reset, revoked, expired refresh).
  Future<void> expire() async {
    if (state is! SignedIn) return;
    final leavingUser = user;
    await _runHooks(_onSignOut, leavingUser);
    // On expire, rows are kept tagged with the user's ID (never discarded automatically).
    await _clear(reason: 'SESSION_REVOKED', discardUserId: null);
  }

  Future<void> _clear({String? reason, int? discardUserId}) async {
    // Every step runs even if an earlier one fails; the tokens go first.
    Future<void> step(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        debugPrint('sign-out cleanup failed: $e');
      }
    }

    await step(() => ref.read(secureStoreProvider).clearTokens());
    await step(() => ref.read(localDbProvider).clearUserData(discardUserId: discardUserId));
    await step(() => ref.read(localPrefsProvider).clearUserScoped());
    await step(BookVault.wipe); // downloaded library books belong to the signed-in member
    state = SignedOut(reasonCode: reason);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

final currentUserProvider = Provider<AppUser?>((ref) {
  final s = ref.watch(sessionProvider);
  return s is SignedIn ? s.user : null;
});

/// Convenience permission check for widgets (UI gating only — the backend enforces everything).
final canProvider = Provider.family<bool, String>((ref, permission) => ref.watch(currentUserProvider)?.can(permission) ?? false);
