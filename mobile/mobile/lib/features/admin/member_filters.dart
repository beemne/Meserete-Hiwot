import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../members/member_form.dart' show memberGroupLabel, membershipStatusLabel;
import 'org_admin.dart' show departmentName;
import '../../core/member_groups.dart';

/// Filters for member lists, in categories: personal details · membership · account · activity &
/// groups. One value object is used for the users list (query string) and for bulk targeting
/// (notifications, invitations: JSON body), so both select exactly the same people.
@immutable
class MemberFilter {
  const MemberFilter({
    this.gender,
    this.maritalStatus,
    this.ageMin,
    this.ageMax,
    this.memberGroup,
    this.memberType,
    this.membershipStatus,
    this.spiritualLevel,
    this.accountType,
    this.canLogin,
    this.hasDevice,
    this.telegramLinked,
    this.departmentId,
    this.activeWithinDays,
    this.hasActiveBorrowing,
    this.professionCategory,
    this.professionId,
    this.profession,
    this.professionOther,
    this.employmentStatus,
  });

  // Personal
  final String? gender;
  final String? maritalStatus;
  final int? ageMin;
  final int? ageMax;
  // Membership
  final String? memberGroup;
  final String? memberType;
  final String? membershipStatus;
  final int? spiritualLevel;
  // Account
  final String? accountType;
  final bool? canLogin;
  final bool? hasDevice;
  final bool? telegramLinked;
  // Activity & groups
  final int? departmentId;
  final int? activeWithinDays;
  final bool? hasActiveBorrowing;
  // Profession & Livelihood
  final String? professionCategory;
  final int? professionId;
  final String? profession;
  final String? professionOther;
  final String? employmentStatus;

  /// Typed values (bulk-target body).
  Json toBody() => {
        'gender': ?gender,
        'marital_status': ?maritalStatus,
        'age_min': ?ageMin,
        'age_max': ?ageMax,
        'member_group': ?memberGroup,
        'member_type': ?(employmentStatus ?? memberType),
        'membership_status': ?membershipStatus,
        'spiritual_level': ?spiritualLevel,
        'account_type': ?accountType,
        'has_device': ?hasDevice,
        'telegram_linked': ?telegramLinked,
        'department_id': ?departmentId,
        'active_within_days': ?activeWithinDays,
        'has_active_borrowing': ?hasActiveBorrowing,
        'profession_category': ?professionCategory,
        'profession_id': ?professionId,
        'profession': ?profession,
        'profession_other': ?professionOther,
        'employment_status': ?(employmentStatus ?? memberType),
      };

  /// Query-string values (GET lists): booleans and numbers as text; can_login is a list-only filter.
  Json toQuery() => {
        for (final e in toBody().entries) e.key: '${e.value}',
        if (canLogin != null) 'can_login': '$canLogin',
      };

  int get count => toBody().length + (canLogin != null ? 1 : 0);
  bool get isEmpty => count == 0;

  @override
  bool operator ==(Object other) => other is MemberFilter && other.toQuery().toString() == toQuery().toString();
  @override
  int get hashCode => toQuery().toString().hashCode;
}

/// The active filters as short labels (shown as chips above a list).
List<String> memberFilterLabels(AppLocalizations l, MemberFilter f) => [
      if (f.gender != null) f.gender == 'male' ? l.male : l.female,
      if (f.maritalStatus != null) f.maritalStatus == 'married' ? l.married : l.single,
      if (f.ageMin != null || f.ageMax != null) '${l.fAge} ${f.ageMin ?? 0}–${f.ageMax ?? '…'}',
      if (f.memberGroup != null) memberGroupLabel(l, f.memberGroup),
      if (f.memberType != null) f.memberType == 'student' ? l.memberStudent : l.memberWorker,
      if (f.membershipStatus != null) membershipStatusLabel(l, f.membershipStatus),
      if (f.spiritualLevel != null) '${l.spiritualLevel} ${f.spiritualLevel}',
      if (f.accountType != null) f.accountType == 'admin' ? l.adminBadge : l.fMembersOnly,
      if (f.canLogin != null) f.canLogin! ? l.canLogin : l.cannotLogin,
      if (f.hasDevice != null) f.hasDevice! ? l.fHasDevice : l.fNoDevice,
      if (f.telegramLinked != null) f.telegramLinked! ? l.telegramLinked : l.fNoTelegram,
      if (f.departmentId != null) l.fDepartment,
      if (f.activeWithinDays != null) l.fActiveWithin('${f.activeWithinDays}'),
      if (f.hasActiveBorrowing == true) l.hasActiveBorrowing,
      if (f.professionCategory != null) 'ምድብ: ${f.professionCategory!.split(' (').first}',
      if (f.profession != null) 'ሙያ: ${f.profession}',
      if (f.professionOther != null) 'ሌላ: ${f.professionOther}',
      if (f.employmentStatus != null) f.employmentStatus == 'student' ? l.memberStudent : l.memberWorker,
    ];

/// Opens the categorized filter sheet; returns the new filter (null = closed without applying).
Future<MemberFilter?> showMemberFilterSheet(BuildContext context, MemberFilter current, {bool showLoginFilter = true}) =>
    showModalBottomSheet<MemberFilter>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MemberFilterSheet(initial: current, showLoginFilter: showLoginFilter),
    );

class _MemberFilterSheet extends ConsumerStatefulWidget {
  const _MemberFilterSheet({required this.initial, required this.showLoginFilter});
  final MemberFilter initial;
  final bool showLoginFilter;
  @override
  ConsumerState<_MemberFilterSheet> createState() => _MemberFilterSheetState();
}

class _MemberFilterSheetState extends ConsumerState<_MemberFilterSheet> {
  late String? _gender = widget.initial.gender;
  late String? _marital = widget.initial.maritalStatus;
  late RangeValues? _age = widget.initial.ageMin == null && widget.initial.ageMax == null
      ? null
      : RangeValues((widget.initial.ageMin ?? 0).toDouble(), (widget.initial.ageMax ?? 80).toDouble());
  late String? _group = widget.initial.memberGroup;
  late String? _type = widget.initial.memberType;
  late String? _membership = widget.initial.membershipStatus;
  late int? _level = widget.initial.spiritualLevel;
  late String? _account = widget.initial.accountType;
  late bool? _canLogin = widget.initial.canLogin;
  late bool? _device = widget.initial.hasDevice;
  late bool? _telegram = widget.initial.telegramLinked;
  late int? _department = widget.initial.departmentId;
  late int? _active = widget.initial.activeWithinDays;
  late bool? _borrowing = widget.initial.hasActiveBorrowing;
  late String? _professionCategory = widget.initial.professionCategory;
  late final String? _profession = widget.initial.profession;
  late final String? _professionOther = widget.initial.professionOther;
  late String? _employmentStatus = widget.initial.employmentStatus ?? widget.initial.memberType;

  MemberFilter get _value => MemberFilter(
        gender: _gender,
        maritalStatus: _marital,
        ageMin: _age == null || _age!.start <= 0 ? null : _age!.start.round(),
        ageMax: _age == null || _age!.end >= 80 ? null : _age!.end.round(),
        memberGroup: _group,
        memberType: _employmentStatus ?? _type,
        membershipStatus: _membership,
        spiritualLevel: _level,
        accountType: _account,
        canLogin: _canLogin,
        hasDevice: _device,
        telegramLinked: _telegram,
        departmentId: _department,
        activeWithinDays: _active,
        hasActiveBorrowing: _borrowing,
        professionCategory: _professionCategory,
        profession: _profession,
        professionOther: _professionOther,
        employmentStatus: _employmentStatus,
      );

  Widget _section(String title, IconData icon, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.goldDark),
            const SizedBox(width: 6),
            Text(title, style: context.sans(14, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ...children,
        ]),
      );

  /// One choice among [options] (tap again to clear).
  Widget _choices<T>(String label, T? value, List<(T, String)> options, ValueChanged<T?> set) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.sans(12, color: context.palette.muted)),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final (v, text) in options)
              ChoiceChip(label: Text(text), selected: value == v, onSelected: (on) => setState(() => set(on ? v : null))),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final departments = ref.watch(_departmentsProvider).value ?? const <Json>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(children: [
              Expanded(child: Text(l.filters, style: context.serif(19))),
              TextButton(key: const ValueKey('filters-clear'), onPressed: () => Navigator.pop(context, const MemberFilter()), child: Text(l.fClearAll)),
            ]),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), children: [
              _section(l.fPersonal, Icons.person_outline_rounded, [
                _choices(l.gender, _gender, [('male', l.male), ('female', l.female)], (v) => _gender = v),
                _choices(l.maritalSection, _marital, [('married', l.married), ('single', l.single)], (v) => _marital = v),
                Row(children: [
                  Text(l.fAge, style: context.sans(12, color: context.palette.muted)),
                  const Spacer(),
                  Text(_age == null ? l.all : '${_age!.start.round()} – ${_age!.end >= 80 ? '80+' : _age!.end.round()}', style: context.sans(12, weight: FontWeight.w600)),
                  if (_age != null) IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _age = null)),
                ]),
                RangeSlider(
                  values: _age ?? const RangeValues(0, 80),
                  min: 0,
                  max: 80,
                  divisions: 80,
                  onChanged: (v) => setState(() => _age = v),
                ),
              ]),
              _section(l.fMembership, Icons.badge_outlined, [
                _choices(l.memberGroup, _group, [for (final g in MemberGroups.keys(activeOnly: false)) (g, memberGroupLabel(l, g))], (v) => _group = v),
                _choices(l.memberTypeLabel, _type, [('student', l.memberStudent), ('worker', l.memberWorker)], (v) => _type = v),
                _choices(l.membershipStatus, _membership, [for (final m in const ['active', 'inactive', 'university', 'abroad', 'deceased']) (m, membershipStatusLabel(l, m))], (v) => _membership = v),
                _choices(l.spiritualLevel, _level, [for (var i = 1; i <= 5; i++) (i, '$i')], (v) => _level = v),
              ]),
              _section('ሙያ እና የሥራ ሁኔታ (Profession & Work)', Icons.work_outline_rounded, [
                _choices('የሥራ ሁኔታ', _employmentStatus, [('student', l.memberStudent), ('worker', l.memberWorker)], (v) => _employmentStatus = v),
                _choices('የሙያ ዘርፍ', _professionCategory, [
                  ('ቴክኖሎጂ እና ኢንጂነሪንግ (Technology & Engineering)', 'ቴክኖሎጂ'),
                  ('ጤና እና ሕክምና (Health & Medicine)', 'ጤና'),
                  ('ትምህርት እና አካዳሚክ (Education & Academia)', 'ትምህርት'),
                  ('ንግድ እና ፋይናንስ (Business & Finance)', 'ንግድ'),
                  ('ሕግ እና አስተዳደር (Law & Governance)', 'ሕግ'),
                  ('እደ-ጥበብ እና ቴክኒክ (Trades & Craftsmanship)', 'እደ-ጥበብ'),
                  ('ስነ-መለኮት እና መንፈሳዊ አገልግሎት (Theology & Clergy)', 'ስነ-መለኮት'),
                  ('ሌላ ሙያ (Other)', 'ሌላ'),
                ], (v) => _professionCategory = v),
              ]),
              _section(l.fAccount, Icons.manage_accounts_outlined, [
                _choices(l.fAccountType, _account, [('user', l.fMembersOnly), ('admin', l.adminBadge)], (v) => _account = v),
                if (widget.showLoginFilter) _choices(l.canLogin, _canLogin, [(true, l.yes), (false, l.no)], (v) => _canLogin = v),
                _choices(l.device, _device, [(true, l.fHasDevice), (false, l.fNoDevice)], (v) => _device = v),
                _choices(l.telegram, _telegram, [(true, l.telegramLinked), (false, l.fNoTelegram)], (v) => _telegram = v),
              ]),
              _section(l.fActivity, Icons.insights_outlined, [
                if (departments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DropdownButtonFormField<int?>(
                      initialValue: _department,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.fDepartment, isDense: true),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l.all)),
                        for (final d in departments) DropdownMenuItem(value: asIntOr(d['id']), child: Text(departmentName(context, d), overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _department = v),
                    ),
                  ),
                _choices(l.fLastActive, _active, [(7, l.fActiveWithin('7')), (30, l.fActiveWithin('30')), (90, l.fActiveWithin('90'))], (v) => _active = v),
                _choices(l.borrowing, _borrowing, [(true, l.hasActiveBorrowing)], (v) => _borrowing = v),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: FilledButton(
              key: const ValueKey('filters-apply'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => Navigator.pop(context, _value),
              child: Text(_value.isEmpty ? l.fShowAll : l.fApply('${_value.count}')),
            ),
          ),
        ]),
      ),
    );
  }
}

final _departmentsProvider = FutureProvider.autoDispose<List<Json>>((ref) async {
  try {
    return await ref.watch(orgRepositoryProvider).departments();
  } catch (_) {
    return const [];
  }
});

/// "Filters (n)" button + the active filters as removable chips.
class MemberFilterBar extends StatelessWidget {
  const MemberFilterBar({super.key, required this.filter, required this.onChanged, this.showLoginFilter = true});
  final MemberFilter filter;
  final ValueChanged<MemberFilter> onChanged;
  final bool showLoginFilter;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = memberFilterLabels(l, filter);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        ActionChip(
          key: const ValueKey('member-filters'),
          avatar: Icon(Icons.tune_rounded, size: 18, color: filter.isEmpty ? null : AppColors.goldDark),
          label: Text(filter.isEmpty ? l.filters : '${l.filters} (${filter.count})'),
          onPressed: () async {
            final f = await showMemberFilterSheet(context, filter, showLoginFilter: showLoginFilter);
            if (f != null) onChanged(f);
          },
        ),
        for (final t in labels) Padding(padding: const EdgeInsets.only(left: 6), child: Chip(label: Text(t), visualDensity: VisualDensity.compact)),
        if (!filter.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: IconButton(tooltip: l.fClearAll, icon: const Icon(Icons.filter_alt_off_outlined), onPressed: () => onChanged(const MemberFilter())),
          ),
      ]),
    );
  }
}
