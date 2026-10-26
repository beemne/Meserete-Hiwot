import 'json.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.avatarUrl,
    this.status = 'active',
    this.accountType = 'user',
    this.deviceName,
    this.lastLoginAt,
    this.createdAt,
    this.mustChangePassword = false,
    this.roleSlug,
    this.roleName,
    this.roleLevel,
    this.permissions = const {},
    this.hasDevice = false,
    this.telegramLinked = false,
    this.telegramUsername,
    this.pendingChange,
    this.memberType,
    this.memberGroup = 'youth_adult',
    this.canLogin = true,
    this.membershipStatus = 'active',
    this.membershipStatusDate,
    this.membershipStatusDetail,
    this.spiritualLevel,
    this.adminDepartments = const [],
    this.roles = const [],
    this.memberNo,
    this.memberId,
    this.moduleAccess = const ModuleAccess(),
  });

  /// Mezmur and Education access permissions
  final ModuleAccess moduleAccess;

  /// Permanent member number and its display form with the group prefix ("መ/ሕ/ወ/17"); the
  /// server formats it (the prefix is configurable). Null for accounts without a number.
  final int? memberNo;
  final String? memberId;

  final int id;
  final String fullName;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final String status;
  final String accountType;
  final String? deviceName;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final bool mustChangePassword;
  final String? roleSlug;
  final String? roleName;
  final int? roleLevel;
  final Set<String> permissions;
  final bool hasDevice;
  final bool telegramLinked;
  final String? telegramUsername;

  /// student | worker (sets the monthly payment rate); null = not set yet.
  final String? memberType;

  /// children | youth_adult | married
  final String memberGroup;

  /// Members who cannot sign in (e.g. children until an administrator allows it).
  final bool canLogin;

  /// active | deceased | inactive | university | abroad (+ date of death / university / country)
  final String membershipStatus;
  final String? membershipStatusDate;
  final String? membershipStatusDetail;

  /// Sunday School (spiritual education) level 1-12.
  final int? spiritualLevel;

  /// Department administrators (members with admin roles): their departments and roles.
  final List<Json> adminDepartments;
  final List<String> roles;

  bool get isChild => memberGroup == 'children';

  /// Name/phone change waiting for admin approval (regular users only).
  final ProfileChangeRequest? pendingChange;

  /// An administrator account (not a member).
  bool get isAccountAdmin => accountType == 'admin';

  /// Anyone with admin screens: administrator accounts and members who are department
  /// administrators (they keep every member feature).
  bool get isAdmin => isAccountAdmin || permissions.isNotEmpty;

  /// A member acting as a department administrator.
  bool get isMemberStaff => !isAccountAdmin && permissions.isNotEmpty;
  bool get isSuperAdmin =>
      (roleLevel != null && roleLevel! >= 90) ||
      roleSlug == 'superadmin' ||
      roleSlug == 'super_admin' ||
      roleSlug == 'system_authority' ||
      roleSlug == 'high_admin' ||
      roles.any((r) {
        final lower = r.toLowerCase();
        return lower.contains('super') ||
            lower.contains('system') ||
            lower.contains('high_admin') ||
            r.contains('ከፍተኛ አስተዳዳሪ') ||
            r.contains('የስርዓት አስተዳዳሪ');
      });
  bool can(String permission) => isSuperAdmin || permissions.contains(permission);
  bool canAny(Iterable<String> ps) => isSuperAdmin || ps.any(permissions.contains);

  factory AppUser.fromJson(Json j) {
    final role = asJson(j['role']);
    final tg = asJson(j['telegram']);
    return AppUser(
      id: asIntOr(j['id']),
      fullName: asStr(j['full_name']) ?? '',
      phone: asStr(j['phone']) ?? '',
      email: asStr(j['email']),
      avatarUrl: asStr(j['profile_image_url']),
      status: asStr(j['status']) ?? 'active',
      accountType: asStr(j['account_type']) ?? 'user',
      deviceName: asStr(j['device_name']),
      lastLoginAt: asDate(j['last_login_at']),
      createdAt: asDate(j['created_at']),
      mustChangePassword: asBool(j['must_change_password']),
      roleSlug: asStr(role['slug']),
      roleName: asStr(role['name']),
      roleLevel: asInt(role['level']),
      permissions: {...(j['permissions'] as List? ?? const []).map((e) => '$e')},
      hasDevice: asBool(j['has_device']) || j['device_name'] != null,
      telegramLinked: asBool(tg['linked']),
      telegramUsername: asStr(tg['username']),
      memberType: asStr(j['member_type']),
      memberGroup: asStr(j['member_group']) ?? 'youth_adult',
      canLogin: j['can_login'] == null || asBool(j['can_login']),
      membershipStatus: asStr(j['membership_status']) ?? 'active',
      membershipStatusDate: asStr(j['membership_status_date']),
      membershipStatusDetail: asStr(j['membership_status_detail']),
      spiritualLevel: asInt(j['spiritual_level']),
      adminDepartments: asJsonList(j['admin_departments']),
      roles: [
        ...(j['roles'] as List? ?? []).map((e) => '$e'),
        if (asStr(role['name']) != null) asStr(role['name'])!,
        if (asStr(role['slug']) != null) asStr(role['slug'])!,
        ...asJsonList(j['admin_departments']).map((d) => asStr(d['role']) ?? asStr(d['role_name'])).whereType<String>(),
      ],
      memberNo: asInt(j['member_no']),
      memberId: asStr(j['member_id']),
      moduleAccess: ModuleAccess.fromJson(j['module_access']),
      pendingChange: j['pending_change_request'] is Map ? ProfileChangeRequest.fromJson(asJson(j['pending_change_request'])) : null,
    );
  }

  Json toJson() => {
        'id': id,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'profile_image_url': avatarUrl,
        'status': status,
        'account_type': accountType,
        'device_name': deviceName,
        'must_change_password': mustChangePassword,
        if (roleName != null || roleSlug != null) 'role': {'name': roleName, 'slug': roleSlug, 'level': roleLevel},
        'permissions': permissions.toList(),
        'admin_departments': adminDepartments,
        'telegram': {'linked': telegramLinked, 'username': telegramUsername},
        'member_type': memberType,
        'member_group': memberGroup,
        'can_login': canLogin,
        'membership_status': membershipStatus,
        'membership_status_date': membershipStatusDate,
        'membership_status_detail': membershipStatusDetail,
        'spiritual_level': spiritualLevel,
        'member_no': memberNo,
        'member_id': memberId,
        'module_access': moduleAccess.toJson(),
      };
}

class ModuleAccess {
  final bool mezmur;
  final bool education;

  const ModuleAccess({this.mezmur = true, this.education = true});

  factory ModuleAccess.fromJson(dynamic j) {
    if (j is Map) {
      return ModuleAccess(
        mezmur: j['mezmur'] != false,
        education: j['education'] != false,
      );
    }
    return const ModuleAccess();
  }

  Map<String, dynamic> toJson() => {'mezmur': mezmur, 'education': education};

  bool get hasBoth => mezmur && education;
  bool get onlyMezmur => mezmur && !education;
  bool get onlyEducation => !mezmur && education;
  bool get none => !mezmur && !education;
}

class ProfileChangeRequest {
  const ProfileChangeRequest({
    required this.id,
    required this.userId,
    this.userName,
    required this.oldFullName,
    required this.oldPhone,
    this.fullName,
    this.phone,
    this.status = 'pending',
    this.reason,
    this.reviewedByName,
    this.createdAt,
    this.changes = const [],
    this.note,
  });

  final int id;
  final int userId;
  final String? userName;
  final String oldFullName;
  final String oldPhone;
  final String? fullName;
  final String? phone;
  final String status;
  final String? reason;
  final String? reviewedByName;
  final DateTime? createdAt;

  /// Every requested change (name, phone and membership-form fields), old → new.
  final List<ProfileFieldChange> changes;

  /// The member's message to the administrator.
  final String? note;

  String describe() => [if (fullName != null) '$oldFullName → $fullName', if (phone != null) '$oldPhone → $phone'].join(' · ');

  factory ProfileChangeRequest.fromJson(Json j) => ProfileChangeRequest(
        id: asIntOr(j['id']),
        userId: asIntOr(j['user_id']),
        userName: asStr(j['user_name']),
        oldFullName: asStr(j['old_full_name']) ?? '',
        oldPhone: asStr(j['old_phone']) ?? '',
        fullName: asStr(j['full_name']),
        phone: asStr(j['phone']),
        status: asStr(j['status']) ?? 'pending',
        reason: asStr(j['reason']),
        reviewedByName: asStr(j['reviewed_by_name']),
        createdAt: asDate(j['created_at']),
        changes: asList(j['changes'], ProfileFieldChange.fromJson),
        note: asStr(j['note']),
      );
}

/// One changed detail: the field, its old and its new value (also a history entry).
class ProfileFieldChange {
  const ProfileFieldChange({required this.field, this.oldValue, this.newValue, this.source, this.changedByName, this.createdAt});
  final String field;
  final String? oldValue;
  final String? newValue;
  final String? source; // request | admin | self (history)
  final String? changedByName;
  final DateTime? createdAt;

  factory ProfileFieldChange.fromJson(Json j) => ProfileFieldChange(
        field: asStr(j['field']) ?? '',
        oldValue: asStr(j['old']),
        newValue: asStr(j['new']),
        source: asStr(j['source']),
        changedByName: asStr(j['changed_by_name']),
        createdAt: asDate(j['created_at']),
      );
}

class UserPreferences {
  const UserPreferences({
    this.notificationsEnabled = true,
    this.audioAutoplay = false,
    this.downloadAudio = true,
    this.theme = 'system',
    this.reminderTime = '18:00',
    this.language = 'am',
    this.lyricsFontScale = 100,
    this.preferredCategoryIds = const [],
    this.updatedAt,
  });

  final bool notificationsEnabled;
  final bool audioAutoplay;
  final bool downloadAudio;
  final String theme;
  final String reminderTime;
  final String language;
  final int lyricsFontScale;
  final List<int> preferredCategoryIds;
  final DateTime? updatedAt;

  factory UserPreferences.fromJson(Json j) => UserPreferences(
        notificationsEnabled: asBool(j['notifications_enabled']),
        audioAutoplay: asBool(j['audio_autoplay']),
        downloadAudio: j['download_audio'] == null || asBool(j['download_audio']),
        theme: asStr(j['theme']) ?? 'system',
        reminderTime: asStr(j['reminder_time']) ?? '18:00',
        language: asStr(j['language']) ?? 'am',
        lyricsFontScale: asIntOr(j['lyrics_font_scale'], 100),
        preferredCategoryIds: (j['preferred_category_ids'] as List? ?? const []).map((e) => asIntOr(e)).toList(),
        updatedAt: asDate(j['updated_at']),
      );

  Json toJson() => {
        'notifications_enabled': notificationsEnabled,
        'audio_autoplay': audioAutoplay,
        'download_audio': downloadAudio,
        'theme': theme,
        'reminder_time': reminderTime,
        'language': language,
        'lyrics_font_scale': lyricsFontScale,
        'preferred_category_ids': preferredCategoryIds,
        if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
      };

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? audioAutoplay,
    bool? downloadAudio,
    String? theme,
    String? reminderTime,
    String? language,
    int? lyricsFontScale,
    List<int>? preferredCategoryIds,
  }) =>
      UserPreferences(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        audioAutoplay: audioAutoplay ?? this.audioAutoplay,
        downloadAudio: downloadAudio ?? this.downloadAudio,
        theme: theme ?? this.theme,
        reminderTime: reminderTime ?? this.reminderTime,
        language: language ?? this.language,
        lyricsFontScale: lyricsFontScale ?? this.lyricsFontScale,
        preferredCategoryIds: preferredCategoryIds ?? this.preferredCategoryIds,
        updatedAt: updatedAt,
      );
}
