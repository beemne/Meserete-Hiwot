import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../widgets/brand.dart';
import '../admin/admin_widgets.dart' show DateTimeField;
import '../../core/member_groups.dart';
import '../../widgets/profession_selector.dart';

/// Labels of the member classification (shared by forms, lists and badges).
/// Built-in and administrator-created member types: the server's name, else the built-in text.
String memberGroupLabel(AppLocalizations l, String? g) {
  final custom = MemberGroups.of(g);
  if (custom != null && custom.name.isNotEmpty) return custom.label(english: l.localeName.startsWith('en'));
  return switch (g) {
    'children' => l.groupChildren,
    'married' => l.groupMarried,
    'youth_adult' || null => l.groupYouth,
    _ => g,
  };
}

String membershipStatusLabel(AppLocalizations l, String? s) => switch (s) {
      'deceased' => l.stDeceased,
      'inactive' => l.stInactive,
      'university' => l.stUniversity,
      'abroad' => l.stAbroad,
      _ => l.stActive,
    };

Color membershipStatusColor(String? s) => switch (s) {
      'deceased' => Colors.blueGrey,
      'inactive' => AppColors.danger,
      'university' || 'abroad' => AppColors.goldDark,
      _ => AppColors.success,
    };

/// Form state: the account, the classification and sections 1-13 of the membership form.
class MemberFormData {
  MemberFormData({AppUser? user, Json? profile}) {
    final p = profile ?? const {};
    name.text = user?.fullName ?? '';
    phone.text = user?.phone ?? '';
    email.text = user?.email ?? '';
    group = user?.memberGroup ?? 'youth_adult';
    memberType = user?.memberType;
    canLogin = user?.canLogin ?? true;
    status = user?.membershipStatus ?? 'active';
    statusDate = Formatters.parseDateOnly(user?.membershipStatusDate);
    statusDetail.text = user?.membershipStatusDetail ?? '';
    spiritualLevel = user?.spiritualLevel;
    for (final k in _texts) {
      text(k).text = asStr(p[k]) ?? '';
    }
    for (final k in _choices) {
      choices[k] = asStr(p[k]);
    }
    birthDate = Formatters.parseDateOnly(asStr(p['birth_date']));
    baptismDate = Formatters.parseDateOnly(asStr(p['baptism_date']));
    professionId = asInt(p['profession_id']);
  }

  static const _texts = [
    'mother_name', 'birth_diocese', 'birth_city', 'birth_woreda', 'birth_kebele', 'birth_place_name', 'christian_name', 'baptism_church',
    'address_woreda', 'house_number', 'phone_home', 'emergency_name', 'emergency_phone_home', 'emergency_phone_mobile', 'abinet_other',
    'institution_name', 'field_of_study', 'profession', 'profession_category', 'profession_other', 'experience_profession', 'church_service', 'school_name', 'confession_father_name',
    'confession_father_phone', 'marriage_other',
  ];
  static const _choices = ['gender', 'abinet_education', 'theology_education', 'secular_education', 'employer_type', 'marital_status', 'marriage_type'];

  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final statusDetail = TextEditingController();
  final _textCtrls = <String, TextEditingController>{};
  final choices = <String, String?>{};
  String group = 'youth_adult';
  String? memberType;
  bool canLogin = true;
  String status = 'active';
  DateTime? statusDate;
  int? spiritualLevel;
  DateTime? birthDate;
  DateTime? baptismDate;
  int? professionId;

  TextEditingController text(String k) => _textCtrls.putIfAbsent(k, TextEditingController.new);

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Json profileJson() => {
        for (final k in _texts) k: _t(text(k)),
        for (final k in _choices) k: choices[k],
        'profession_id': professionId,
        'birth_date': birthDate == null ? null : Formatters.isoDate(birthDate!),
        'baptism_date': baptismDate == null ? null : Formatters.isoDate(baptismDate!),
      };

  /// Body for the admin create / update endpoints.
  Json adminJson() => {
        'full_name': name.text.trim(),
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
        'email': _t(email),
        'member_group': group,
        'member_type': group == 'children' ? null : memberType,
        'can_login': canLogin,
        'membership_status': status,
        'membership_status_date': status == 'deceased' && statusDate != null ? Formatters.isoDate(statusDate!) : null,
        'membership_status_detail': status == 'university' || status == 'abroad' ? _t(statusDetail) : null,
        'spiritual_level': spiritualLevel,
        'profile': profileJson(),
      };

  void dispose() {
    for (final c in [name, phone, email, password, statusDetail, ..._textCtrls.values]) {
      c.dispose();
    }
  }
}

/// Where the form is shown: an administrator (every field) or a member registering.
enum MemberFormMode { admin, register }

/// Sections 1-13 of the membership form (form.dot), with the classification on top for admins.
class MemberFormFields extends StatefulWidget {
  const MemberFormFields({super.key, required this.data, required this.mode, this.passwordField, this.serverError});
  final MemberFormData data;
  final MemberFormMode mode;

  /// Registration only: the password field(s), placed after the account fields.
  final Widget? passwordField;
  final String? Function(String field)? serverError;

  @override
  State<MemberFormFields> createState() => _MemberFormFieldsState();
}

class _MemberFormFieldsState extends State<MemberFormFields> {
  MemberFormData get d => widget.data;
  bool get admin => widget.mode == MemberFormMode.admin;

  Widget _section(String number, String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(number.isEmpty ? title : '$number. $title', style: context.serif(15, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...children.expand((w) => [w, const SizedBox(height: 10)]).toList()..removeLast(),
          ]),
        ),
      );

  Widget _field(String key, String label, {TextInputType? keyboard}) =>
      TextFormField(controller: d.text(key), keyboardType: keyboard, decoration: InputDecoration(labelText: label, errorText: widget.serverError?.call('profile.$key')));

  Widget _choice(String key, Map<String, String> options) => Wrap(spacing: 8, runSpacing: 6, children: [
        for (final e in options.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: d.choices[key] == e.key,
            onSelected: (v) => setState(() => d.choices[key] = v ? e.key : null),
          ),
      ]);

  Widget _row(List<Widget> children) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: children[i])],
      ]);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final isChild = d.group == 'children';
    final edu = {'masters': l.eduMasters, 'degree': l.eduDegree, 'diploma': l.eduDiploma, 'certificate': l.eduCertificate};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ---- account + classification
      _section('', admin ? l.memberAccount : l.registerTitle, [
        TextFormField(
          controller: d.name,
          textCapitalization: TextCapitalization.words,
          validator: (s) => v.text(s, min: 2, max: 150),
          decoration: InputDecoration(labelText: l.mfFullName, errorText: widget.serverError?.call('full_name')),
        ),
        TextFormField(
          controller: d.phone,
          keyboardType: TextInputType.phone,
          // Members who sign in need a phone; children may have none.
          validator: (s) => (admin && !d.canLogin && (s ?? '').trim().isEmpty) ? null : v.phone(s),
          decoration: InputDecoration(labelText: l.phoneMobile, hintText: '09XXXXXXXX', errorText: widget.serverError?.call('phone')),
        ),
        TextFormField(controller: d.email, keyboardType: TextInputType.emailAddress, validator: (s) => v.email(s, optional: true), decoration: InputDecoration(labelText: l.emailOptional)),
        ?widget.passwordField,
        Text(l.memberGroup, style: context.sans(13, weight: FontWeight.w600)),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final g in [for (final k in MemberGroups.keys()) if (admin || k != 'children') k, if (!MemberGroups.keys().contains(d.group)) d.group])
            ChoiceChip(
              label: Text(memberGroupLabel(l, g)),
              selected: d.group == g,
              onSelected: (_) => setState(() {
                d.group = g;
                if (g == 'children') d.canLogin = false;
              }),
            ),
        ]),
        if (!isChild) ...[
          Text(l.memberTypeLabel, style: context.sans(13, weight: FontWeight.w600)),
          Wrap(spacing: 8, children: [
            for (final t in const ['student', 'worker'])
              ChoiceChip(label: Text(t == 'worker' ? l.memberWorker : l.memberStudent), selected: d.memberType == t, onSelected: (s) => setState(() => d.memberType = s ? t : null)),
          ]),
        ],
        if (admin) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.canLogin),
            subtitle: Text(l.canLoginHint, style: context.sans(12, color: context.palette.muted)),
            value: d.canLogin,
            onChanged: (x) => setState(() => d.canLogin = x),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: d.status,
            decoration: InputDecoration(labelText: l.membershipStatus),
            items: [for (final s in const ['active', 'inactive', 'university', 'abroad', 'deceased']) DropdownMenuItem(value: s, child: Text(membershipStatusLabel(l, s), overflow: TextOverflow.ellipsis))],
            onChanged: (x) => setState(() => d.status = x ?? 'active'),
          ),
          if (d.status == 'deceased')
            DateTimeField(pastOnly: true, label: l.dateOfDeath, value: d.statusDate, withTime: false, onChanged: (x) => setState(() => d.statusDate = x)),
          if (d.status == 'university' || d.status == 'abroad')
            TextFormField(
              controller: d.statusDetail,
              validator: (s) => (s ?? '').trim().isEmpty ? l.vRequired : null,
              decoration: InputDecoration(labelText: d.status == 'university' ? l.universityName : l.countryName),
            ),
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: d.spiritualLevel,
            decoration: InputDecoration(labelText: l.spiritualLevel),
            items: [DropdownMenuItem<int?>(value: null, child: Text(l.notSet)), for (var i = 1; i <= 12; i++) DropdownMenuItem<int?>(value: i, child: Text(l.levelN('$i')))],
            onChanged: (x) => setState(() => d.spiritualLevel = x),
          ),
        ],
      ]),
      // ---- 1-13: the membership form
      _section('1', l.gender, [_choice('gender', {'male': l.male, 'female': l.female})]),
      _section('2', l.motherName, [_field('mother_name', l.motherName)]),
      _section('3', l.birthSection, [
        DateTimeField(pastOnly: true, label: l.birthDate, value: d.birthDate, withTime: false, clearable: true, onChanged: (x) => setState(() => d.birthDate = x)),
        _row([_field('birth_diocese', l.birthDiocese), _field('birth_city', l.city)]),
        _row([_field('birth_woreda', l.woreda), _field('birth_kebele', l.kebele)]),
        _field('birth_place_name', l.birthPlaceName),
      ]),
      _section('4', l.christianName, [
        _field('christian_name', l.christianName),
        _field('baptism_church', l.baptismChurch),
        DateTimeField(pastOnly: true, label: l.baptismDate, value: d.baptismDate, withTime: false, clearable: true, onChanged: (x) => setState(() => d.baptismDate = x)),
      ]),
      _section('5', l.addressSection, [
        _row([_field('address_woreda', l.woreda), _field('house_number', l.houseNumber)]),
        _field('phone_home', l.phoneHome, keyboard: TextInputType.phone),
      ]),
      _section('6', l.emergencySection, [
        _field('emergency_name', l.mfFullName),
        _row([_field('emergency_phone_home', l.phoneHome, keyboard: TextInputType.phone), _field('emergency_phone_mobile', l.phoneMobile, keyboard: TextInputType.phone)]),
      ]),
      _section('7', l.abinetSection, [
        _choice('abinet_education', {'qes': l.abinetQes, 'deacon': l.abinetDeacon, 'none': l.abinetNone, 'other': l.other}),
        if (d.choices['abinet_education'] == 'other') _field('abinet_other', l.other),
      ]),
      _section('8', l.spiritualSection, [
        Text(l.theology, style: context.sans(12, color: context.palette.muted)),
        _choice('theology_education', edu),
        if (!admin)
          const SizedBox.shrink()
        else
          Text('${l.spiritualLevel}: ${d.spiritualLevel == null ? l.notSet : l.levelN('${d.spiritualLevel}')}', style: context.sans(12, color: context.palette.muted)),
      ]),
      _section('9', l.secularSection, [
        _choice('secular_education', {'doctorate': l.eduDoctorate, ...edu}),
        _field('institution_name', l.institutionName),
        _field('field_of_study', l.fieldOfStudy),
      ]),
      if (!isChild)
        _section('10', l.livelihoodSection, [
          if (d.memberType == 'worker') ...[
            _choice('employer_type', {'private': l.employerPrivate, 'government': l.employerGovernment}),
            ProfessionSelectorField(
              selectedProfession: d.text('profession').text.isEmpty ? null : d.text('profession').text,
              selectedProfessionOther: d.text('profession_other'),
              initialProfessionId: d.professionId,
              initialCategory: d.text('profession_category').text.isEmpty ? null : d.text('profession_category').text,
              onChanged: ({required name, required category, id}) {
                setState(() {
                  d.text('profession').text = name;
                  d.text('profession_category').text = category;
                  d.professionId = id;
                });
              },
            ),
            _field('experience_profession', l.experienceProfession),
            _field('church_service', l.churchService),
          ] else if (d.memberType == 'student')
            _field('school_name', l.studyPlaceName)
          else
            Text(l.chooseStudentWorker, style: context.sans(12, color: context.palette.muted)),
        ]),
      _section('11', l.confessionSection, [
        _field('confession_father_name', l.mfFullName),
        _field('confession_father_phone', l.phone, keyboard: TextInputType.phone),
      ]),
      _section('12', l.maritalSection, [_choice('marital_status', {'married': l.married, 'single': l.single})]),
      if (d.choices['marital_status'] == 'married')
        _section('13', l.marriageSection, [
          _choice('marriage_type', {'teklil': l.teklil, 'kurban': l.kurban, 'other': l.other}),
          if (d.choices['marriage_type'] == 'other') _field('marriage_other', l.other),
        ]),
    ]);
  }
}

/// A member's details laid out as the membership form (read-only).
class MemberProfileView extends StatelessWidget {
  const MemberProfileView({super.key, required this.user, required this.profile, this.departments = const [], this.showAccount = true});
  final AppUser user;
  final Json profile;
  final List<Json> departments;
  final bool showAccount;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    String? val(String k) {
      final s = asStr(profile[k]);
      return s == null || s.isEmpty ? null : s;
    }

    String? date(String k) => val(k) == null ? null : f.date(Formatters.parseDateOnly(val(k)));
    final choiceLabels = <String, String>{
      'male': l.male, 'female': l.female, 'qes': l.abinetQes, 'deacon': l.abinetDeacon, 'none': l.abinetNone, 'other': l.other,
      'masters': l.eduMasters, 'degree': l.eduDegree, 'diploma': l.eduDiploma, 'certificate': l.eduCertificate, 'doctorate': l.eduDoctorate,
      'private': l.employerPrivate, 'government': l.employerGovernment, 'married': l.married, 'single': l.single, 'teklil': l.teklil, 'kurban': l.kurban,
    };
    String? choice(String k) => val(k) == null ? null : (choiceLabels[val(k)] ?? val(k));

    Widget row(String label, String? value) => value == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 130, child: Text(label, style: context.sans(12, color: p.muted))),
              Expanded(child: Text(value, style: context.sans(14, color: p.text))),
            ]),
          );
    Widget section(String n, String title, List<Widget> rows) {
      final shown = rows.where((w) => w is! SizedBox).toList();
      if (shown.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.isEmpty ? title : '$n. $title', style: context.serif(14, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            ...shown,
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header like the paper form: title, name and the photo box.
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.formTitle, style: context.sans(12, color: p.muted, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(user.fullName, style: context.serif(18, color: p.text)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill(memberGroupLabel(l, user.memberGroup)),
                Pill(
                  user.membershipStatusDetail != null ? '${membershipStatusLabel(l, user.membershipStatus)} · ${user.membershipStatusDetail}' : membershipStatusLabel(l, user.membershipStatus),
                  color: membershipStatusColor(user.membershipStatus),
                ),
                if (!user.isChild && user.memberType != null) Pill(user.memberType == 'worker' ? l.memberWorker : l.memberStudent),
                if (user.spiritualLevel != null) Pill(l.levelN('${user.spiritualLevel}'), icon: Icons.menu_book_rounded),
                if (!user.canLogin) Pill(l.cannotLogin, color: AppColors.danger),
                for (final d in departments)
                  Pill(
                    '${asStr(d['name']) ?? ''}${d['role'] == 'leader' ? ' · ${l.deptLeader}' : ''}',
                    icon: d['role'] == 'leader' ? Icons.workspace_premium_rounded : Icons.groups_rounded,
                    color: d['role'] == 'leader' ? AppColors.goldDark : null,
                  ),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 84,
              height: 104,
              decoration: BoxDecoration(border: Border.all(color: p.border), borderRadius: BorderRadius.circular(14)),
              child: user.avatarUrl != null ? Image.network(user.avatarUrl!, fit: BoxFit.cover) : Center(child: Text(l.photo, style: context.serif(14, color: AppColors.goldDark))),
            ),
          ),
        ]),
      ),
      if (user.membershipStatus == 'deceased' && user.membershipStatusDate != null)
        section('', l.membershipStatus, [row(l.dateOfDeath, f.date(Formatters.parseDateOnly(user.membershipStatusDate)))]),
      if (showAccount)
        section('', l.memberAccount, [row(l.phoneMobile, user.phone.isEmpty ? null : user.phone), row(l.emailOptional, user.email)]),
      section('1', l.gender, [row(l.gender, choice('gender'))]),
      section('2', l.motherName, [row(l.motherName, val('mother_name'))]),
      section('3', l.birthSection, [
        row(l.birthDate, date('birth_date')),
        row(l.birthDiocese, val('birth_diocese')),
        row(l.city, val('birth_city')),
        row(l.woreda, val('birth_woreda')),
        row(l.kebele, val('birth_kebele')),
        row(l.birthPlaceName, val('birth_place_name')),
      ]),
      section('4', l.christianName, [row(l.christianName, val('christian_name')), row(l.baptismChurch, val('baptism_church')), row(l.baptismDate, date('baptism_date'))]),
      section('5', l.addressSection, [row(l.woreda, val('address_woreda')), row(l.houseNumber, val('house_number')), row(l.phoneHome, val('phone_home'))]),
      section('6', l.emergencySection, [row(l.mfFullName, val('emergency_name')), row(l.phoneHome, val('emergency_phone_home')), row(l.phoneMobile, val('emergency_phone_mobile'))]),
      section('7', l.abinetSection, [row(l.abinetSection, choice('abinet_education')), row(l.other, val('abinet_other'))]),
      section('8', l.spiritualSection, [row(l.theology, choice('theology_education')), row(l.spiritualLevel, user.spiritualLevel == null ? null : l.levelN('${user.spiritualLevel}'))]),
      section('9', l.secularSection, [row(l.secularSection, choice('secular_education')), row(l.institutionName, val('institution_name')), row(l.fieldOfStudy, val('field_of_study'))]),
      section('10', l.livelihoodSection, [
        row(l.memberTypeLabel, user.memberType == null ? null : (user.memberType == 'worker' ? l.memberWorker : l.memberStudent)),
        row(l.employerPrivate.isEmpty ? '' : l.employer, choice('employer_type')),
        row(l.profession, val('profession')),
        row(l.experienceProfession, val('experience_profession')),
        row(l.churchService, val('church_service')),
        row(l.studyPlaceName, val('school_name')),
      ]),
      section('11', l.confessionSection, [row(l.mfFullName, val('confession_father_name')), row(l.phone, val('confession_father_phone'))]),
      section('12', l.maritalSection, [row(l.maritalSection, choice('marital_status'))]),
      section('13', l.marriageSection, [row(l.marriageSection, choice('marriage_type')), row(l.other, val('marriage_other'))]),
    ]);
  }
}
