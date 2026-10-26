import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../features/auth/session.dart';
import '../models/json.dart';
import '../models/user.dart';
import '../repositories/providers.dart';
import 'sync_service.dart';

/// Account preferences stored on the server, cached for offline use.
/// Changes apply immediately (optimistic); offline changes are queued with base_updated_at so a
/// newer server copy is never silently overwritten.
class PreferencesController extends Notifier<UserPreferences> {
  @override
  UserPreferences build() {
    ref.read(syncServiceProvider).onConflict(SyncOp.preferencesUpdate, (_, server) async {
      if (server is Map) {
        final p = UserPreferences.fromJson(asJson(server));
        await ref.read(accountRepositoryProvider).cachePreferences(p);
        state = p;
      }
    });
    ref.listen(sessionProvider, (_, s) {
      if (s is SignedIn) unawaited(refresh());
    });
    return ref.read(accountRepositoryProvider).cachedPreferences() ?? const UserPreferences();
  }

  Future<void> refresh() async {
    try {
      state = await ref.read(accountRepositoryProvider).preferences();
    } catch (_) {}
  }

  Future<void> update(UserPreferences Function(UserPreferences p) change) async {
    final before = state;
    final next = change(state);
    state = next;
    final repo = ref.read(accountRepositoryProvider);
    try {
      state = await repo.savePreferences(next);
    } on ApiException catch (e) {
      if (!e.isNetwork) {
        state = before;
        rethrow;
      }
      await repo.cachePreferences(next);
      final values = next.toJson()..remove('updated_at');
      await ref.read(syncServiceProvider).enqueue(SyncOp.preferencesUpdate, {
        'values': values,
        if (before.updatedAt != null) 'base_updated_at': before.updatedAt!.toUtc().toIso8601String(),
      });
    }
  }
}

final preferencesProvider = NotifierProvider<PreferencesController, UserPreferences>(PreferencesController.new);
