import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/providers.dart';
import '../models/content.dart';
import '../models/json.dart';
import 'sync_service.dart';

/// Favorite Mezmur ids, available offline. Writes are optimistic and go through the sync queue.
class FavoritesController extends Notifier<Set<int>> {
  late Future<void> _ready;

  @override
  Set<int> build() {
    _ready = _load();
    return const {};
  }

  Future<void> _load() async {
    final rows = await ref.read(localDbProvider).db.query('favorites', columns: ['mezmur_id']);
    state = rows.map((r) => r['mezmur_id'] as int).toSet();
  }

  bool isFavorite(int id) => state.contains(id);

  Future<bool> toggle(MezmurSummary m) async {
    await _ready; // never let the initial load overwrite a user action
    final db = ref.read(localDbProvider).db;
    final sync = ref.read(syncServiceProvider);
    if (state.contains(m.id)) {
      state = {...state}..remove(m.id);
      await db.delete('favorites', where: 'mezmur_id = ?', whereArgs: [m.id]);
      await sync.enqueue(SyncOp.favoriteRemove, {'mezmur_id': m.id});
      return false;
    }
    state = {...state, m.id};
    await db.insert('favorites', {'mezmur_id': m.id, 'json': jsonEncode(_summaryJson(m))}, conflictAlgorithm: ConflictAlgorithm.replace);
    await sync.enqueue(SyncOp.favoriteAdd, {'mezmur_id': m.id});
    return true;
  }

  /// Offline list of favorites (summaries captured when favorited / last pulled).
  Future<List<MezmurSummary>> offlineList() async {
    final rows = await ref.read(localDbProvider).db.query('favorites');
    return rows.where((r) => r['json'] != null).map((r) => MezmurSummary.fromJson(asJson(jsonDecode(r['json'] as String)))).toList();
  }

  /// Replace local state with the server's list (only when no favorite ops are pending).
  Future<void> pull() async {
    await _ready;
    final db = ref.read(localDbProvider).db;
    final pending = await db.query('sync_queue', where: 'type LIKE ?', whereArgs: ['favorite.%'], limit: 1);
    if (pending.isNotEmpty) return;
    final api = ref.read(apiClientProvider);
    final page = await api.getPage('/favorites', MezmurSummary.fromJson, limit: 100);
    final batch = db.batch()..delete('favorites');
    for (final m in page.items) {
      batch.insert('favorites', {'mezmur_id': m.id, 'json': jsonEncode(_summaryJson(m))});
    }
    await batch.commit(noResult: true);
    state = page.items.map((m) => m.id).toSet();
    if (page.hasMore) {
      final ids = await api.get<List<dynamic>>('/favorites', query: {'ids_only': 'true'});
      state = ids.map((e) => asIntOr(e)).toSet();
    }
  }

  static Json _summaryJson(MezmurSummary m) => {
        'id': m.id,
        'title': m.title,
        'excerpt': m.excerpt,
        'category': m.categoryId == null ? null : {'id': m.categoryId, 'name': m.categoryName},
        'cover_url': m.coverUrl,
        'has_audio': m.hasAudio,
        'audio_duration_sec': m.audioDurationSec,
        'is_favorite': true,
      };
}

final favoritesProvider = NotifierProvider<FavoritesController, Set<int>>(FavoritesController.new);
