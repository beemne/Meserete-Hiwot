import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/session.dart';
import '../repositories/providers.dart';

/// Unread notification count for the navigation badge.
class UnreadCount extends Notifier<int> {
  @override
  int build() {
    ref.listen(sessionProvider, (_, s) {
      if (s is SignedIn) unawaited(refresh());
      if (s is SignedOut) state = 0;
    });
    return 0;
  }

  Future<void> refresh() async {
    try {
      state = await ref.read(notificationRepositoryProvider).unreadCount();
    } catch (_) {}
  }

  void set(int v) => state = v < 0 ? 0 : v;
  void decrement() => set(state - 1);
}

final unreadCountProvider = NotifierProvider<UnreadCount, int>(UnreadCount.new);
