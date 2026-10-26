import 'json.dart';

class Profession {
  final int id;
  final String category;
  final String name;
  final bool isActive;
  final int sortOrder;

  const Profession({
    required this.id,
    required this.category,
    required this.name,
    this.isActive = true,
    this.sortOrder = 0,
  });

  bool get isOther =>
      name.toLowerCase().contains('other') ||
      name.contains('ሌላ') ||
      category.toLowerCase().contains('other') ||
      category.contains('ሌላ');

  factory Profession.fromJson(Json j) => Profession(
        id: asIntOr(j['id']),
        category: asStr(j['category']) ?? '',
        name: asStr(j['name']) ?? '',
        isActive: j['is_active'] == null || asBool(j['is_active']),
        sortOrder: asInt(j['sort_order']) ?? 0,
      );

  Json toJson() => {
        'id': id,
        'category': category,
        'name': name,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}
