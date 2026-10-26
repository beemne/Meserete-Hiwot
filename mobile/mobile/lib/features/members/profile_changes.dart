import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold;
import 'member_form.dart';

/// The name of a member detail (account, classification or membership-form field).
String profileFieldLabel(AppLocalizations l, String field) => switch (field) {
      'full_name' => l.mfFullName,
      'phone' => l.phoneMobile,
      'email' => l.email,
      'member_group' => l.memberGroup,
      'member_type' => l.memberTypeLabel,
      'can_login' => l.canLogin,
      'membership_status' => l.membershipStatus,
      'membership_status_date' => l.dateOfDeath,
      'membership_status_detail' => '${l.membershipStatus} · ${l.details}',
      'spiritual_level' => l.spiritualLevel,
      'gender' => l.gender,
      'mother_name' => l.motherName,
      'birth_date' => l.birthDate,
      'birth_diocese' => '${l.birthSection} · ${l.birthDiocese}',
      'birth_city' => '${l.birthSection} · ${l.city}',
      'birth_woreda' => '${l.birthSection} · ${l.woreda}',
      'birth_kebele' => '${l.birthSection} · ${l.kebele}',
      'birth_place_name' => l.birthPlaceName,
      'christian_name' => l.christianName,
      'baptism_church' => l.baptismChurch,
      'baptism_date' => l.baptismDate,
      'address_woreda' => '${l.addressSection} · ${l.woreda}',
      'house_number' => l.houseNumber,
      'phone_home' => '${l.addressSection} · ${l.phoneHome}',
      'emergency_name' => '${l.emergencySection} · ${l.mfFullName}',
      'emergency_phone_home' => '${l.emergencySection} · ${l.phoneHome}',
      'emergency_phone_mobile' => '${l.emergencySection} · ${l.phoneMobile}',
      'abinet_education' => l.abinetSection,
      'abinet_other' => '${l.abinetSection} · ${l.other}',
      'theology_education' => l.theology,
      'secular_education' => l.secularSection,
      'institution_name' => l.institutionName,
      'field_of_study' => l.fieldOfStudy,
      'employer_type' => l.livelihoodSection,
      'profession' => l.profession,
      'experience_profession' => l.experienceProfession,
      'church_service' => l.churchService,
      'school_name' => l.studyPlaceName,
      'confession_father_name' => '${l.confessionSection} · ${l.mfFullName}',
      'confession_father_phone' => '${l.confessionSection} · ${l.phone}',
      'marital_status' => l.maritalSection,
      'marriage_type' => l.marriageSection,
      'marriage_other' => '${l.marriageSection} · ${l.other}',
      _ => field,
    };

String profileValueLabel(AppLocalizations l, String field, String? v) {
  if (v == null || v.isEmpty) return '—';
  return switch ((field, v)) {
    ('gender', 'male') => l.male,
    ('gender', 'female') => l.female,
    ('member_group', _) => memberGroupLabel(l, v),
    ('membership_status', _) => membershipStatusLabel(l, v),
    ('member_type', 'student') => l.memberStudent,
    ('member_type', 'worker') => l.memberWorker,
    ('marital_status', 'married') => l.married,
    ('marital_status', 'single') => l.single,
    ('can_login', '1') => l.yes,
    ('can_login', '0') => l.no,
    _ => v,
  };
}

/// "label: old → new" for one detail.
class ChangeLine extends StatelessWidget {
  const ChangeLine({super.key, required this.change});
  final ProfileFieldChange change;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(profileFieldLabel(l, change.field), style: context.sans(12, color: p.muted)),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
          Text(profileValueLabel(l, change.field, change.oldValue), style: context.sans(13, color: p.subtle).copyWith(decoration: TextDecoration.lineThrough)),
          const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.gold),
          Text(profileValueLabel(l, change.field, change.newValue), style: context.sans(13, weight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

String changeStatusLabel(AppLocalizations l, String s) => switch (s) {
      'approved' => l.approved,
      'rejected' => l.rejected,
      'cancelled' => l.libReqCancelled,
      _ => l.pendingStatus,
    };

Color changeStatusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' || 'cancelled' => AppColors.danger,
      _ => AppColors.goldDark,
    };

final _myChangeRequestsProvider = FutureProvider.autoDispose<List<ProfileChangeRequest>>((ref) => ref.watch(accountRepositoryProvider).myChangeRequests());

/// A member edits their details as on the membership form; only what differs is sent to an
/// administrator, who approves or declines it with a reason. Earlier requests are listed below.
class ProfileChangeRequestScreen extends ConsumerStatefulWidget {
  const ProfileChangeRequestScreen({super.key, required this.user, this.profile});
  final AppUser user;
  final Json? profile;
  @override
  ConsumerState<ProfileChangeRequestScreen> createState() => _ProfileChangeRequestScreenState();
}

class _ProfileChangeRequestScreenState extends ConsumerState<ProfileChangeRequestScreen> {
  late final _data = MemberFormData(user: widget.user, profile: widget.profile);
  final _note = TextEditingController();

  @override
  void dispose() {
    _data.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    final body = <String, dynamic>{
      'full_name': _data.name.text.trim(),
      if (_data.phone.text.trim().isNotEmpty) 'phone': _data.phone.text.trim(),
      'profile': _data.profileJson(),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };
    final r = await runWithProgress(context, () => ref.read(accountRepositoryProvider).requestProfileChange(body), success: l.changeRequestSent);
    if (r != null && mounted) {
      ref.invalidate(_myChangeRequestsProvider);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return PatternScaffold(
      appBar: AppBar(title: Text(l.requestProfileChange)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text(l.requestProfileChangeHint, style: context.sans(13, color: context.palette.muted)),
        MemberFormFields(data: _data, mode: MemberFormMode.register),
        const SizedBox(height: 14),
        TextField(key: const ValueKey('change-note'), controller: _note, maxLines: 2, decoration: InputDecoration(labelText: l.changeNote)),
        const SizedBox(height: 14),
        FilledButton.icon(key: const ValueKey('change-send'), onPressed: _send, icon: const Icon(Icons.send_rounded), label: Text(l.sendForApproval)),
        SectionHeader(title: l.myChangeRequests),
        ...ref.watch(_myChangeRequestsProvider).when(
              data: (list) => list.isEmpty
                  ? [Padding(padding: const EdgeInsets.all(8), child: Text(l.noChangeRequests, style: context.sans(13, color: context.palette.muted)))]
                  : [
                      for (final r in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Row(children: [
                                Pill(changeStatusLabel(l, r.status), color: changeStatusColor(r.status)),
                                const Spacer(),
                                Text(f.date(r.createdAt), style: context.sans(11, color: context.palette.subtle)),
                              ]),
                              const SizedBox(height: 6),
                              for (final c in r.changes) ChangeLine(change: c),
                              if (r.reason != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${l.reason}: ${r.reason}', style: context.sans(12, color: AppColors.danger))),
                            ]),
                          ),
                        ),
                    ],
              loading: () => [const LoadingView(padding: EdgeInsets.all(16))],
              error: (e, _) => [ErrorView(error: e)],
            ),
      ]),
    );
  }
}

/// Administrator: every change of a member's details, field by field — old values are never lost.
class ProfileHistoryScreen extends ConsumerWidget {
  const ProfileHistoryScreen({super.key, required this.userId, required this.name});
  final int userId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    String source(String? s) => switch (s) {
          'request' => l.historyByRequest,
          'self' => l.historyBySelf,
          _ => l.historyByAdmin,
        };
    return AdminScaffold(
      title: '${l.changeHistory} · $name',
      body: PagedListView<ProfileFieldChange>(
        fetch: (page) => ref.read(adminRepositoryProvider).profileHistory(userId, page: page),
        emptyMessage: l.noChangeHistory,
        emptyIcon: Icons.history_rounded,
        itemBuilder: (context, c, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ChangeLine(change: c),
              const SizedBox(height: 4),
              Text([f.dateTime(c.createdAt), source(c.source), ?c.changedByName].join(' · '), style: context.sans(11, color: context.palette.subtle)),
            ]),
          ),
        ),
      ),
    );
  }
}
