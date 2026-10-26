import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/storage/local_db.dart';
import '../models/activity.dart';
import '../models/content.dart';
import '../models/json.dart';

class HomeData {
  const HomeData({
    required this.banners,
    required this.featured,
    required this.recent,
    required this.popular,
    required this.categories,
    required this.upcomingPrograms,
    required this.unread,
    this.todayMezmurs = const [],
    this.todayCategories = const [],
    this.fromCache = false,
  });

  final List<Banner> banners;
  final List<MezmurSummary> featured;
  final List<MezmurSummary> recent;
  final List<MezmurSummary> popular;
  final List<CategoryNode> categories;
  final List<Program> upcomingPrograms;
  final int unread;
  final bool fromCache;

  /// "ዛሬ የሚጠኑ" — what the choir practises today, shown first on the home screen.
  final List<MezmurSummary> todayMezmurs;
  final List<CategoryNode> todayCategories;

  factory HomeData.fromJson(Json j, {bool fromCache = false}) => HomeData(
        banners: asList(j['banners'], Banner.fromJson),
        featured: asList(j['featured'], MezmurSummary.fromJson),
        recent: asList(j['recent'], MezmurSummary.fromJson),
        popular: asList(j['popular'], MezmurSummary.fromJson),
        categories: asList(j['categories'], CategoryNode.fromJson),
        upcomingPrograms: asList(j['upcoming_programs'], Program.fromJson),
        unread: asIntOr(j['unread_notifications']),
        todayMezmurs: asList(asJson(j['today'])['mezmurs'], MezmurSummary.fromJson),
        todayCategories: asList(asJson(j['today'])['categories'], CategoryNode.fromJson),
        fromCache: fromCache,
      );
}

/// Mezmurs, categories, banners and internal pages. Key reads fall back to the local cache offline.
class ContentRepository {
  ContentRepository(this._api, this._db);
  final ApiClient _api;
  final LocalDb _db;

  Future<T> _cached<T>(String key, Future<dynamic> Function() fetch, T Function(dynamic json, bool fromCache) parse) async {
    try {
      final data = await fetch();
      await _db.putCache(key, data as Object);
      return parse(data, false);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final cached = await _db.getCache(key);
      if (cached == null) rethrow;
      return parse(cached, true);
    }
  }

  Future<HomeData> home() => _cached('home', () => _api.get<dynamic>('/home'), (j, c) => HomeData.fromJson(asJson(j), fromCache: c));

  Future<List<CategoryNode>> categoryTree() =>
      _cached('categories', () => _api.get<dynamic>('/categories'), (j, _) => (j as List).map((e) => CategoryNode.fromJson(asJson(e))).toList());

  Future<CategoryNode> category(int id) =>
      _cached('category:$id', () => _api.get<dynamic>('/categories/$id'), (j, _) => CategoryNode.fromJson(asJson(j)));

  Future<Paged<MezmurSummary>> categoryMezmurs(int id, {int page = 1}) =>
      _api.getPage('/categories/$id/mezmurs', MezmurSummary.fromJson, page: page, query: {'sort': 'title'});

  Future<Paged<MezmurSummary>> mezmurs({String? q, int? categoryId, String? sort, bool? featured, bool? log, int page = 1}) =>
      _api.getPage('/mezmurs', MezmurSummary.fromJson, page: page, query: {'q': q, 'category_id': categoryId, 'sort': sort, 'featured': featured, 'log': log});

  Future<Mezmur> mezmur(int id) => _api.get('/mezmurs/$id', parse: (d) => Mezmur.fromJson(asJson(d)));

  Future<List<Banner>> banners() => _api.get('/advertisements', parse: (d) => (d as List).map((e) => Banner.fromJson(asJson(e))).toList());

  Future<PageContent> page(int id) => _api.get('/pages/$id', parse: (d) => PageContent.fromJson(asJson(d)));

  /// Offline freshness check for downloaded Mezmurs.
  Future<({List<Mezmur> updated, List<int> removed})> changes(List<({int id, int version})> held) async {
    final data = await _api.post<Json>('/mezmurs/changes',
        body: {'held': held.map((h) => {'id': h.id, 'content_version': h.version}).toList()}, parse: asJson);
    return (
      updated: asList(data['updated'], (j) => Mezmur.fromJson(j)),
      removed: (data['removed'] as List? ?? const []).map((e) => asIntOr(e)).toList(),
    );
  }
}
