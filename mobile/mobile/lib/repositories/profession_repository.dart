import '../core/network/api_client.dart';
import '../models/json.dart';
import '../models/profession.dart';

class ProfessionRepository {
  final ApiClient _api;
  ProfessionRepository(this._api);

  Future<List<Profession>> list({String? category, bool admin = false}) async {
    final endpoint = admin ? '/admin/professions' : '/professions';
    final res = await _api.get(endpoint, query: category != null ? {'category': category} : null);
    final data = res is Map ? asJson(res['data']) : asJson(res);
    final items = asJsonList(data['items'] ?? data);
    return items.map(Profession.fromJson).toList();
  }

  Future<List<String>> categories() async {
    final res = await _api.get('/professions/categories');
    final data = res is Map ? (res['data'] as List? ?? []) : (res as List? ?? []);
    return data.map((e) => '$e').toList();
  }

  Future<Profession> create(Map<String, dynamic> body) async {
    final res = await _api.post('/admin/professions', body: body);
    return Profession.fromJson(asJson(res is Map ? res['data'] : res));
  }

  Future<Profession> update(int id, Map<String, dynamic> body) async {
    final res = await _api.put('/admin/professions/$id', body: body);
    return Profession.fromJson(asJson(res is Map ? res['data'] : res));
  }

  Future<void> delete(int id) async {
    await _api.delete('/admin/professions/$id');
  }
}
