import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/json.dart';
import '../repositories/providers.dart';

/// One member type (group): built in (ሕጻናት / ወጣቶች እና አዋቂዎች / ባለትዳሮች) or created by an administrator
/// (e.g. distance members).
class MemberGroupInfo {
  const MemberGroupInfo({required this.key, required this.name, this.nameEn, this.description, this.active = true, this.builtIn = false, this.memberCount});
  final String key;
  final String name;
  final String? nameEn;
  final String? description;
  final bool active;
  final bool builtIn;
  final int? memberCount;

  factory MemberGroupInfo.fromJson(Json j) => MemberGroupInfo(
        key: asStr(j['key']) ?? '',
        name: asStr(j['name']) ?? '',
        nameEn: asStr(j['name_en']),
        description: asStr(j['description']),
        active: j['is_active'] != false,
        builtIn: j['built_in'] == true,
        memberCount: asInt(j['member_count']),
      );

  String label({required bool english}) => english && (nameEn ?? '').isNotEmpty ? nameEn! : name;
}

/// The member types known to the app. Filled from the server after sign-in ([memberGroupsProvider]);
/// until then (or offline before the first load) only the three built-in types are offered.
class MemberGroups {
  MemberGroups._();
  static const builtIn = ['children', 'youth_adult', 'married'];
  static List<MemberGroupInfo> _all = const [];

  static void set(List<MemberGroupInfo> groups) => _all = groups;
  static List<MemberGroupInfo> get all => _all;

  /// Keys in display order: active ones (for new choices) or every one (filters, existing values).
  static List<String> keys({bool activeOnly = true}) {
    if (_all.isEmpty) return builtIn;
    return [for (final g in _all) if (!activeOnly || g.active) g.key];
  }

  static MemberGroupInfo? of(String? key) {
    for (final g in _all) {
      if (g.key == key) return g;
    }
    return null;
  }
}

/// Loads the member types (switched-off ones too, so old values keep their names).
final memberGroupsProvider = FutureProvider<List<MemberGroupInfo>>((ref) async {
  final list = (await ref.watch(stageRepositoryProvider).memberGroups(all: true)).map(MemberGroupInfo.fromJson).toList();
  MemberGroups.set(list);
  return list;
});
