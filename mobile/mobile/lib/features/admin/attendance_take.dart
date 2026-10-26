import '../../widgets/secure_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../features/auth/session.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../services/offline_pack.dart';
import '../../widgets/brand.dart';
import '../members/member_form.dart' show memberGroupLabel;
import 'admin_widgets.dart' show pickUsers;
import 'stage_admin.dart' show attendanceStatusLabel;
import '../../widgets/dialogs.dart' show runWithProgress;

/// Step 1 of taking attendance (QR scan or a manual pick): who is this member and may they be
/// recorded at this program / date. Online the server answers; offline — or when the server
/// cannot be reached — the copies kept on the phone (member directory, programs, recorded marks,
/// marks waiting to sync) answer the same questions. Nothing is written here.
Future<Json> identifyForAttendance(WidgetRef ref, {required int programId, String? date, String? uuid, int? userId}) async {
  final me = ref.read(currentUserProvider);
  if (ref.read(isOnlineProvider)) {
    try {
      return await ref.read(stageRepositoryProvider).checkAttendance(programId, uuid: uuid, userId: userId, date: date);
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
    }
  }
  return ref.read(offlinePackProvider).check(
        programId: programId,
        date: date,
        uuid: uuid,
        userId: userId,
        myId: me?.id ?? 0,
      );
}

enum VerifyAction { record, next }

/// Step 2: the taker compares the photo with the person, sees the member ID and type and whether
/// they may be recorded, and only then records. While scanning, "Scan next" goes on to the next QR.
Future<VerifyAction?> showAttendanceVerify(BuildContext context, Json info, {bool scanning = false}) => showModalBottomSheet<VerifyAction>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SecureScreen(child: AttendanceVerifySheet(info: info, scanning: scanning)),
    );

class AttendanceVerifySheet extends StatelessWidget {
  const AttendanceVerifySheet({super.key, required this.info, this.scanning = false});
  final Json info;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final m = asJson(info['member']);
    final eligible = info['eligible'] == true;
    final reason = asStr(info['reason']);
    final existing = info['attendance'] is Map ? asJson(info['attendance']) : null;
    final would = asStr(info['would_record']);
    final avatar = asStr(m['avatar_url']);
    final name = asStr(m['full_name']) ?? '—';
    final recordedAt = DateTime.tryParse(asStr(existing?['attended_at']) ?? asStr(existing?['recorded_at']) ?? '')?.toLocal();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.attVerifyTitle, style: context.serif(18)),
          const SizedBox(height: 4),
          Text(l.attVerifyHint, textAlign: TextAlign.center, style: context.sans(12, color: p.muted)),
          const SizedBox(height: 16),
          if (m.isNotEmpty) ...[
            // A large photo: the taker checks the face against the person in front of them.
            CircleAvatar(
              key: const ValueKey('verify-photo'),
              radius: 64,
              backgroundColor: p.pill,
              backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
              child: avatar == null ? Text(name.characters.first, style: context.serif(40)) : null,
            ),
            const SizedBox(height: 12),
            Text(name, key: const ValueKey('verify-name'), textAlign: TextAlign.center, style: context.serif(20)),
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
              if (asStr(m['member_id']) != null) Pill(asStr(m['member_id'])!, icon: Icons.badge_outlined),
              Pill(memberGroupLabel(l, asStr(m['member_group'])), icon: Icons.groups_2_outlined),
            ]),
            const SizedBox(height: 14),
          ],
          Container(
            key: ValueKey('verify-${eligible ? 'ok' : 'no'}'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (eligible ? AppColors.success : AppColors.danger).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(eligible ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: eligible ? AppColors.success : AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    eligible ? l.attEligible : errorText(l, ApiException(code: reason ?? ApiException.unknown)),
                    style: context.sans(13, weight: FontWeight.w600),
                  ),
                  if (eligible && would != null) Text(l.attWillBe(attendanceStatusLabel(l, would)), style: context.sans(12, color: p.muted)),
                  if (existing != null)
                    Text(
                      [
                        attendanceStatusLabel(l, asStr(existing['status'])),
                        asStr(existing['via']) == 'qr' ? l.attMethodQr : l.attMethodManual,
                        if (asStr(existing['recorded_by_name']) != null) l.attRecordedBy(asStr(existing['recorded_by_name'])!, recordedAt == null ? '' : f.time(recordedAt)),
                      ].join(' · '),
                      style: context.sans(12, color: p.muted),
                    ),
                ]),
              ),
            ]),
          ),
          if (info['offline'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Icon(Icons.cloud_off_rounded, size: 16, color: p.subtle),
                const SizedBox(width: 6),
                Expanded(child: Text(l.attOfflineChecked, style: context.sans(11, color: p.subtle))),
              ]),
            ),
          const SizedBox(height: 16),
          if (eligible)
            FilledButton.icon(
              key: const ValueKey('verify-record'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () => Navigator.pop(context, VerifyAction.record),
              icon: const Icon(Icons.how_to_reg_rounded),
              label: Text(l.attRecord),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))),
            if (scanning)
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('verify-next'),
                  onPressed: () => Navigator.pop(context, VerifyAction.next),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(l.attScanNext),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

/// Manual entry for members without a smartphone: search by name or member ID (online on the
/// server, offline in the member list kept on the phone) and pick the member.
Future<int?> findMemberForAttendance(BuildContext context, {required int programId}) => showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FindMemberSheet(programId: programId),
    );

class _FindMemberSheet extends ConsumerStatefulWidget {
  const _FindMemberSheet({required this.programId});
  final int programId;
  @override
  ConsumerState<_FindMemberSheet> createState() => _FindMemberSheetState();
}

class _FindMemberSheetState extends ConsumerState<_FindMemberSheet> {
  List<Json> _rows = const [];
  bool _loading = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    List<Json> rows;
    final pack = ref.read(offlinePackProvider);
    if (!ref.read(isOnlineProvider) || await pack.memberCount() > 0) {
      rows = await pack.searchMembers(q);
    } else {
      try {
        final page = await ref.read(adminRepositoryProvider).roster(widget.programId, source: 'all', q: q.isEmpty ? null : q);
        rows = [for (final r in page.items) {...r, 'id': r['user_id']}];
      } catch (_) {
        rows = await pack.searchMembers(q);
      }
    }
    if (mounted && seq == _seq) {
      setState(() {
        _rows = rows;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const ValueKey('find-member-q'),
              autofocus: true,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.attFindMember),
              onChanged: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _rows.isEmpty && !_loading
                ? Center(child: Text(l.attNoMembersFound, style: context.sans(13, color: p.muted)))
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final r = _rows[i];
                      final avatar = asStr(r['avatar_url']);
                      final name = asStr(r['full_name']) ?? '—';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.pill,
                          backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                          child: avatar == null ? Text(name.characters.first) : null,
                        ),
                        title: Text(name),
                        subtitle: Text([?asStr(r['member_id']), memberGroupLabel(l, asStr(r['member_group']))].join(' · ')),
                        onTap: () => Navigator.pop(context, asIntOr(r['id'])),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Program editor section: the program's ONE default attendance taker, assigned by HR
/// (attendance.assign). Every occurrence's session starts with this taker; HR can still assign a
/// different taker to one occurrence from its roster.
class ProgramTakersSection extends ConsumerStatefulWidget {
  const ProgramTakersSection({super.key, required this.programId});
  final int programId;
  @override
  ConsumerState<ProgramTakersSection> createState() => _ProgramTakersSectionState();
}

class _ProgramTakersSectionState extends ConsumerState<ProgramTakersSection> {
  List<Json>? _takers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await ref.read(stageRepositoryProvider).attendanceTakers(widget.programId);
      if (mounted) setState(() => _takers = t);
    } catch (_) {
      if (mounted) setState(() => _takers = const []);
    }
  }

  Future<void> _save(List<int> ids) async {
    final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).setAttendanceTakers(widget.programId, ids), success: context.l10n.saved);
    if (r != null && mounted) setState(() => _takers = r);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final takers = _takers;
    final canAssign = ref.watch(currentUserProvider)?.can(Perm.attendanceAssign) ?? false;
    final taker = takers == null || takers.isEmpty ? null : takers.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(l.attTaker, style: context.sans(13, weight: FontWeight.w600))),
        if (canAssign)
          TextButton.icon(
            key: const ValueKey('takers-add'),
            onPressed: takers == null
                ? null
                : () async {
                    final sel = await pickUsers(context, title: l.attTaker, multiple: false);
                    if (sel == null || sel.ids.isEmpty || !mounted) return;
                    await _save([sel.ids.first]);
                  },
            icon: const Icon(Icons.manage_accounts_rounded, size: 18),
            label: Text(taker == null ? l.add : l.change),
          ),
      ]),
      Text(canAssign ? l.attTakerHint : l.attTakerHrOnly, style: context.sans(11, color: p.muted)),
      const SizedBox(height: 6),
      if (takers == null)
        const LinearProgressIndicator(minHeight: 2)
      else if (taker == null)
        Pill(l.attNoTakerAssigned, icon: Icons.person_off_outlined, color: AppColors.danger)
      else
        InputChip(
          label: Text(asStr(taker['full_name']) ?? '#${taker['id']}'),
          onDeleted: canAssign ? () => _save(const []) : null,
        ),
    ]);
  }
}
