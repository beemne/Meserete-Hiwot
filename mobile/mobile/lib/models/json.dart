/// Tolerant JSON readers (MySQL booleans may arrive as 0/1, numbers as strings).
typedef Json = Map<String, dynamic>;

int? asInt(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
int asIntOr(Object? v, [int or = 0]) => asInt(v) ?? or;
double asDouble(Object? v, [double or = 0]) => v == null ? or : (v is num ? v.toDouble() : double.tryParse('$v') ?? or);
bool asBool(Object? v) => v == true || v == 1 || v == '1' || v == 'true';
String? asStr(Object? v) => v?.toString();
DateTime? asDate(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
Json asJson(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
List<Json> asJsonList(Object? v) => v is List ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : const [];
/// A list of JSON objects mapped by [f] (non-object entries are skipped).
List<T> asList<T>(Object? v, T Function(Json) f) => asJsonList(v).map(f).toList();

/// A list of plain values (ids, names …): every entry mapped by [f]. Use this, not [asList], for
/// lists that are not objects — [asList] would drop them all.
List<T> asValues<T>(Object? v, T Function(Object? e) f) => v is List ? v.map(f).toList() : <T>[];
