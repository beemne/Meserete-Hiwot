import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../models/guidance.dart';
import '../models/json.dart';
import '../core/providers.dart';
import '../features/guidance/guidance_catalog.dart';

final guidanceRepositoryProvider = Provider<GuidanceRepository>((ref) {
  return GuidanceRepository(ref.watch(apiClientProvider), ref.watch(localPrefsProvider).raw);
});

class GuidanceFilter {
  const GuidanceFilter({this.category, this.screen, this.search, this.tourId});
  final String? category;
  final String? screen;
  final String? search;
  final String? tourId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuidanceFilter &&
          other.category == category &&
          other.screen == screen &&
          other.search == search &&
          other.tourId == tourId;

  @override
  int get hashCode => Object.hash(category, screen, search, tourId);
}

class AdminGuidanceFilter {
  const AdminGuidanceFilter({this.status, this.category, this.search});
  final String? status;
  final String? category;
  final String? search;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminGuidanceFilter &&
          other.status == status &&
          other.category == category &&
          other.search == search;

  @override
  int get hashCode => Object.hash(status, category, search);
}

final guidanceArticlesProvider = FutureProvider.family<List<GuidanceArticle>, GuidanceFilter>((ref, filter) async {
  return ref.watch(guidanceRepositoryProvider).fetchArticles(
        category: filter.category,
        screen: filter.screen,
        search: filter.search,
        tourId: filter.tourId,
      );
});

final contextualGuidanceProvider = FutureProvider.family<GuidanceArticle?, String>((ref, screenRoute) async {
  return ref.watch(guidanceRepositoryProvider).fetchContextual(screenRoute);
});

final tourProgressProvider = FutureProvider<Map<String, TourProgress>>((ref) async {
  return ref.watch(guidanceRepositoryProvider).fetchTourProgressMap();
});

final adminGuidanceArticlesProvider = FutureProvider.family<List<GuidanceArticle>, AdminGuidanceFilter>((ref, filter) async {
  return ref.watch(guidanceRepositoryProvider).adminFetchAll(
        status: filter.status,
        category: filter.category,
        search: filter.search,
      );
});

class GuidanceRepository {
  GuidanceRepository(this._api, this._prefs);
  final ApiClient _api;
  final SharedPreferences _prefs;

  static const _keyPrefix = 'mz_guidance_tour_';

  /// Fetch guidance articles filtered by category/screen/search with offline fallback.
  Future<List<GuidanceArticle>> fetchArticles({
    String? category,
    String? screen,
    String? search,
    String? tourId,
  }) async {
    try {
      final query = <String, dynamic>{
        if (category != null && category.isNotEmpty) 'category': category,
        if (screen != null && screen.isNotEmpty) 'screen': screen,
        if (search != null && search.isNotEmpty) 'search': search,
        if (tourId != null && tourId.isNotEmpty) 'tour_id': tourId,
      };

      final res = await _api.get<dynamic>('/guidance', query: query);
      final list = (res is List ? res : (res is Map ? (res['data'] as List? ?? const []) : const []))
          .map((e) => GuidanceArticle.fromJson(e as Json))
          .toList();

      // Cache articles locally for offline use
      if (list.isNotEmpty && query.isEmpty) {
        final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
        await _prefs.setString('mz_cached_guidance_articles', encoded);
      }

      return list;
    } catch (_) {
      // Fallback to locally cached or default seeded articles
      return _loadFallbackArticles(category: category, screen: screen, search: search, tourId: tourId);
    }
  }

  /// Contextual guidance for a specific screen
  Future<GuidanceArticle?> fetchContextual(String screenRoute) async {
    try {
      final res = await _api.get<dynamic>('/guidance/contextual', query: {'screen': screenRoute});
      final data = res is Map ? (res['data'] ?? res) : null;
      if (data != null && data is Map<String, dynamic> && data.isNotEmpty) {
        return GuidanceArticle.fromJson(data);
      }
    } catch (_) {
      // fall back to local
    }

    // 1. Try matching from GuidanceCatalog built-in directory
    final catalogMatch = GuidanceCatalog.getForScreen(screenRoute);
    if (catalogMatch != null) return catalogMatch;

    // 2. Match from cached articles
    final all = await fetchArticles();
    final normalized = screenRoute.split('?').first;
    for (final a in all) {
      if (a.targetScreen != null && a.targetScreen!.startsWith(normalized)) {
        return a;
      }
    }
    return null;
  }

  /// Single article detail
  Future<GuidanceArticle> fetchArticle(String slugOrId) async {
    try {
      final res = await _api.get<dynamic>('/guidance/$slugOrId');
      final data = res is Map ? (res['data'] ?? res) : res;
      return GuidanceArticle.fromJson(data as Json);
    } catch (_) {
      final all = await fetchArticles();
      final match = all.where((a) => a.slug == slugOrId || '${a.id}' == slugOrId).firstOrNull;
      if (match != null) return match;
      rethrow;
    }
  }

  /// Get tour progress as map of tourId -> TourProgress
  Future<Map<String, TourProgress>> fetchTourProgressMap() async {
    final map = <String, TourProgress>{};

    // 1. Read local preferences
    final keys = _prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final k in keys) {
      final tid = k.substring(_keyPrefix.length);
      final raw = _prefs.getString(k);
      if (raw != null) {
        try {
          map[tid] = TourProgress.fromJson(jsonDecode(raw) as Json);
        } catch (_) {}
      }
    }

    // 2. Fetch from backend if signed in
    try {
      final res = await _api.get<dynamic>('/guidance/progress');
      final list = (res is List ? res : (res is Map ? (res['data'] as List? ?? const []) : const []));
      for (final item in list) {
        final tp = TourProgress.fromJson(item as Json);
        map[tp.tourId] = tp;
        await _prefs.setString('$_keyPrefix${tp.tourId}', jsonEncode(tp.toJson()));
      }
    } catch (_) {}

    return map;
  }

  /// Save tour progress
  Future<void> saveTourProgress(String tourId, {required bool completed, bool dismissed = false}) async {
    final tp = TourProgress(
      tourId: tourId,
      completed: completed,
      dismissed: dismissed,
      completedAt: completed ? DateTime.now() : null,
    );

    // Save locally immediately
    await _prefs.setString('$_keyPrefix$tourId', jsonEncode(tp.toJson()));

    // Sync to backend asynchronously
    try {
      await _api.post<dynamic>('/guidance/progress', body: {
        'tour_id': tourId,
        'completed': completed,
        'dismissed': dismissed,
      });
    } catch (_) {}
  }

  /// Reset tour progress
  Future<void> resetTourProgress({String? tourId}) async {
    if (tourId != null) {
      await _prefs.remove('$_keyPrefix$tourId');
    } else {
      final keys = _prefs.getKeys().where((k) => k.startsWith(_keyPrefix)).toList();
      for (final k in keys) {
        await _prefs.remove(k);
      }
    }

    try {
      await _api.post<dynamic>('/guidance/progress/reset', body: {
        'tour_id': tourId,
      });
    } catch (_) {}
  }

  // --- Admin CRUD methods ---

  Future<List<GuidanceArticle>> adminFetchAll({String? status, String? category, String? search}) async {
    final query = <String, dynamic>{
      if (status != null && status.isNotEmpty) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final res = await _api.get<dynamic>('/guidance/admin/all', query: query);
    final list = (res is List ? res : (res is Map ? (res['data'] as List? ?? const []) : const []));
    return list.map((e) => GuidanceArticle.fromJson(e as Json)).toList();
  }

  Future<GuidanceArticle> adminCreate(Json data) async {
    final res = await _api.post<dynamic>('/guidance/admin', body: data);
    final item = res is Map ? (res['data'] ?? res) : res;
    return GuidanceArticle.fromJson(item as Json);
  }

  Future<GuidanceArticle> adminUpdate(int id, Json data) async {
    final res = await _api.patch<dynamic>('/guidance/admin/$id', body: data);
    final item = res is Map ? (res['data'] ?? res) : res;
    return GuidanceArticle.fromJson(item as Json);
  }

  Future<GuidanceArticle> adminPublish(int id) async {
    final res = await _api.post<dynamic>('/guidance/admin/$id/publish');
    final item = res is Map ? (res['data'] ?? res) : res;
    return GuidanceArticle.fromJson(item as Json);
  }

  Future<GuidanceArticle> adminRetire(int id) async {
    final res = await _api.post<dynamic>('/guidance/admin/$id/retire');
    final item = res is Map ? (res['data'] ?? res) : res;
    return GuidanceArticle.fromJson(item as Json);
  }

  Future<void> adminDelete(int id) async {
    await _api.delete('/guidance/admin/$id');
  }

  // --- Fallback Data ---

  List<GuidanceArticle> _loadFallbackArticles({
    String? category,
    String? screen,
    String? search,
    String? tourId,
  }) {
    final cachedStr = _prefs.getString('mz_cached_guidance_articles');
    List<GuidanceArticle> items = [];
    if (cachedStr != null) {
      try {
        final decoded = jsonDecode(cachedStr) as List;
        items = decoded.map((e) => GuidanceArticle.fromJson(e as Json)).toList();
      } catch (_) {}
    }

    if (items.isEmpty) {
      items = GuidanceCatalog.getAllArticles();
    }

    return items.where((a) {
      if (category != null && category.isNotEmpty && a.category != category) return false;
      if (screen != null && screen.isNotEmpty && a.targetScreen != screen) return false;
      if (tourId != null && tourId.isNotEmpty && a.tourId != tourId) return false;
      if (search != null && search.isNotEmpty) {
        final term = search.toLowerCase();
        final match = a.title.toLowerCase().contains(term) ||
            (a.summary?.toLowerCase().contains(term) ?? false) ||
            a.content.toLowerCase().contains(term);
        if (!match) return false;
      }
      return true;
    }).toList();
  }
}
