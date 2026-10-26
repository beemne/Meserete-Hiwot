import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart' show Paged;
import '../../core/network/api_exception.dart';
import '../../services/offline_pack.dart';
import '../../core/config/app_config.dart';
import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/activity.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';
import '../members/profile_changes.dart' show ChangeLine, ProfileHistoryScreen;
import 'admin_widgets.dart';

// =============================================================================
// Name / phone change requests (users.view to see, users.update to decide)
// =============================================================================
class ChangeRequestsScreen extends ConsumerStatefulWidget {
  const ChangeRequestsScreen({super.key});
  @override
  ConsumerState<ChangeRequestsScreen> createState() => _ChangeRequestsScreenState();
}

class _ChangeRequestsScreenState extends ConsumerState<ChangeRequestsScreen> {
  final _ctrl = PagedListController<ProfileChangeRequest>();
  String _status = 'pending';

  Future<void> _decide(ProfileChangeRequest r, bool approve) async {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    if (approve) {
      final note = await promptText(context, title: l.approve, label: l.approveNote, maxLines: 2);
      if (note == null || !mounted) return;
      await runWithProgress(context, () => repo.approveChange(r.id, note: note.trim().isEmpty ? null : note.trim()), success: l.approved);
    } else {
      // Declining always gives the member a reason.
      final reason = await promptText(context, title: l.reject, label: l.declineReason, maxLines: 2, required: true);
      if (reason == null || reason.trim().isEmpty || !mounted) return;
      await runWithProgress(context, () => repo.rejectChange(r.id, reason: reason.trim()), success: l.rejected);
    }
    await _ctrl.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.changeRequests,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'pending', label: Text(l.pendingStatus)),
              ButtonSegment(value: 'approved', label: Text(l.approved)),
              ButtonSegment(value: 'rejected', label: Text(l.rejected)),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: PagedListView<ProfileChangeRequest>(
            key: ValueKey(_status),
            controller: _ctrl,
            fetch: (page) => ref.read(adminRepositoryProvider).changeRequests(status: _status, page: page),
            emptyMessage: l.noChangeRequests,
            emptyIcon: Icons.fact_check_outlined,
            separator: const SizedBox(height: 10),
            itemBuilder: (context, r, _) => AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(r.userName ?? r.oldFullName, style: context.serif(16))),
                  Text(f.relative(r.createdAt), style: context.sans(11, color: context.palette.subtle)),
                ]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileHistoryScreen(userId: r.userId, name: r.userName ?? r.oldFullName))),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: Text(l.changeHistory),
                  ),
                ),
                const SizedBox(height: 8),
                for (final c in r.changes) ChangeLine(change: c),
                if (r.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${r.note}”', style: context.sans(12, color: context.palette.muted).copyWith(fontStyle: FontStyle.italic))),
                if (r.reason != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.reason!, style: context.sans(12, color: context.palette.muted))),
                if (r.reviewedByName != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('— ${r.reviewedByName}', style: context.sans(11, color: context.palette.subtle))),
                if (r.status == 'pending') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _decide(r, false), child: Text(l.reject))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: () => _decide(r, true), child: Text(l.approve))),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// Attendance module: pick a program (today/upcoming first) → roster.
// Only administrators with attendance.manage record attendance; users never self-register it.
// =============================================================================
class AttendanceHomeScreen extends ConsumerStatefulWidget {
  const AttendanceHomeScreen({super.key});
  @override
  ConsumerState<AttendanceHomeScreen> createState() => _AttendanceHomeScreenState();
}

class _AttendanceHomeScreenState extends ConsumerState<AttendanceHomeScreen> {
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final me = ref.watch(currentUserProvider);
    return AdminScaffold(
      title: l.attendance,
      actions: [
        IconButton(tooltip: l.permissionRequests, icon: const Icon(Icons.edit_calendar_outlined), onPressed: () => context.push('/admin/permissions')),
        if (me?.canAny([Perm.attendanceCorrectionRequest, Perm.attendanceCorrectionApprove]) ?? false)
          IconButton(tooltip: l.attCorrections, icon: const Icon(Icons.rule_rounded), onPressed: () => context.push('/admin/attendance/corrections')),
        if (me?.can(Perm.attendanceOverride) ?? false)
          IconButton(key: const ValueKey('att-conflicts'), tooltip: l.attConflicts, icon: const Icon(Icons.cloud_sync_outlined), onPressed: () => context.push('/admin/attendance/conflicts')),
        if (me?.can(Perm.attendanceConfigure) ?? false)
          IconButton(tooltip: l.attSignaturePolicy, icon: const Icon(Icons.draw_outlined), onPressed: () => context.push('/admin/attendance/rules')),
        const ContextualHelpButton(screenRoute: '/admin/attendance'),
      ],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [ButtonSegment(value: false, label: Text(l.attendanceToday)), ButtonSegment(value: true, label: Text(l.attendanceRecent))],
            selected: {_past},
            onSelectionChanged: (s) => setState(() => _past = s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 6),
            Expanded(child: Text(l.attendanceOnlyAdmins, style: context.sans(12, color: context.palette.muted))),
          ]),
        ),
        Expanded(
          child: PagedListView<Program>(
            key: ValueKey(_past),
            // Only the programs this person may take attendance for; offline, the programs kept on the
            // phone (offline pack) when the list was never opened online.
            fetch: (page) async {
              try {
                return await ref.read(adminRepositoryProvider).takeablePrograms(scope: _past ? 'past' : 'upcoming', page: page);
              } on ApiException catch (e) {
                if (!e.isNetwork || page > 1) rethrow;
                final saved = await ref.read(offlinePackProvider).programs();
                final items = [
                  for (final p in saved)
                    Program.fromJson({...p, 'starts_at': asJsonList(p['occurrences']).firstOrNull?['starts_at'], 'ends_at': asJsonList(p['occurrences']).firstOrNull?['ends_at']}),
                ];
                return Paged(items: items, page: 1, pages: 1, total: items.length, meta: const {'offline': true});
              }
            },
            emptyMessage: l.noPrograms,
            emptyIcon: Icons.event_busy_outlined,
            itemBuilder: (context, p, _) => TrackTile(
              title: p.title,
              subtitle: '${f.dateTime(p.startsAt)} · ${l.participantsCount(p.participantCount)}',
              leading: ListThumb(icon: Icons.how_to_reg_rounded, imageUrl: p.imageUrl, active: !_past),
              trailing: const Icon(Icons.chevron_right_rounded),
              // Without registered participants, start from all users so walk-ins can be marked.
              onTap: () => context.push('/admin/programs/${p.id}/attendance${p.participantCount == 0 ? '?source=all' : ''}'),
            ),
          ),
        ),
      ]),
    );
  }
}

// =============================================================================
// Absence permission requests (attendance.manage): review + policy (deadline, quotas, weight).
// =============================================================================
class PermissionRequestsScreen extends ConsumerStatefulWidget {
  const PermissionRequestsScreen({super.key});
  @override
  ConsumerState<PermissionRequestsScreen> createState() => _PermissionRequestsScreenState();
}

class _PermissionRequestsScreenState extends ConsumerState<PermissionRequestsScreen> {
  final _ctrl = PagedListController<PermissionRequest>();
  String _status = 'pending';

  Future<void> _decide(PermissionRequest r, bool approve) async {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    final note = await promptText(context, title: approve ? l.approve : l.reject, label: l.overrideReason, maxLines: 2);
    if (note == null || !mounted) return;
    await runWithProgress(context, () => repo.reviewPermission(r.id, approve: approve, note: note.trim().isEmpty ? null : note.trim()),
        success: approve ? l.approved : l.rejected);
    await _ctrl.refresh();
  }

  /// Undo an approval given by mistake (reason required; the member is told).
  Future<void> _cancelExcuse(PermissionRequest r) async {
    final l = context.l10n;
    final reason = await promptText(context, title: l.permissionCancelExcuse, label: l.overrideReason, hint: l.permissionCancelExcuseHint, maxLines: 2, required: true);
    if (reason == null || reason.length < 3 || !mounted) return;
    await runWithProgress(context, () => ref.read(adminRepositoryProvider).cancelApprovedPermission(r.id, reason), success: l.permissionCancelled);
    await _ctrl.refresh();
  }

  Future<void> _policy() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: const _PermissionPolicyEditor()),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final p = context.palette;
    return AdminScaffold(
      title: l.permissionRequests,
      actions: [IconButton(tooltip: l.permissionPolicy, icon: const Icon(Icons.tune_rounded), onPressed: _policy)],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'pending', label: Text(l.pendingStatus)),
              ButtonSegment(value: 'approved', label: Text(l.approved)),
              ButtonSegment(value: 'rejected', label: Text(l.rejected)),
              ButtonSegment(value: 'cancelled', label: Text(l.permissionCancelled)),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: PagedListView<PermissionRequest>(
            key: ValueKey(_status),
            controller: _ctrl,
            fetch: (page) => ref.read(adminRepositoryProvider).permissionRequests(status: _status, page: page),
            emptyMessage: l.noPermissionRequests,
            emptyIcon: Icons.edit_calendar_outlined,
            separator: const SizedBox(height: 10),
            itemBuilder: (context, r, _) => AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(r.fullName, style: context.serif(16))),
                  if (r.createdAt != null) Text(f.relative(r.createdAt!), style: context.sans(11, color: p.subtle)),
                ]),
                const SizedBox(height: 4),
                Text([r.programTitle, if (r.startsAt != null) f.dateTime(r.startsAt!)].join(' · '), style: context.sans(13, color: p.text)),
                if (r.reason != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.reason!, style: context.sans(13, color: p.muted))),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.permissionUsage(r.monthUsed, r.quarterUsed), style: context.sans(11, color: p.subtle)),
                ),
                if (r.reviewNote != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('— ${r.reviewNote!}', style: context.sans(11, color: p.subtle))),
                if (r.status == 'cancelled' && r.cancelReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l.permissionCancelledBy(r.cancelledByName ?? '—', r.cancelReason!), style: context.sans(11, color: AppColors.danger)),
                  ),
                if (r.status != 'cancelled') const SizedBox(height: 10),
                // An approval given by mistake is cancelled (not turned into a rejection).
                if (r.status == 'approved')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => _cancelExcuse(r),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: Text(l.permissionCancelExcuse),
                  )
                else if (r.status != 'cancelled')
                  Row(children: [
                    if (r.status != 'rejected') Expanded(child: OutlinedButton(onPressed: () => _decide(r, false), child: Text(l.reject))),
                    if (r.status == 'pending') const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: () => _decide(r, true), child: Text(l.approve))),
                  ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PermissionPolicyEditor extends ConsumerStatefulWidget {
  const _PermissionPolicyEditor();
  @override
  ConsumerState<_PermissionPolicyEditor> createState() => _PermissionPolicyEditorState();
}

class _PermissionPolicyEditorState extends ConsumerState<_PermissionPolicyEditor> {
  final _form = GlobalKey<FormState>();
  final _hours = TextEditingController();
  final _month = TextEditingController();
  final _quarter = TextEditingController();
  final _weight = TextEditingController();
  bool _enabled = true;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_hours, _month, _quarter, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final j = await ref.read(adminRepositoryProvider).permissionPolicy();
      if (!mounted) return;
      setState(() {
        _enabled = j['enabled'] != false;
        _hours.text = '${asIntOr(j['deadline_hours'], 24)}';
        _month.text = asInt(j['monthly_limit'])?.toString() ?? '';
        _quarter.text = asInt(j['quarterly_limit'])?.toString() ?? '';
        _weight.text = '${j['weight'] ?? 0.5}';
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  /// Empty is allowed (= unlimited); otherwise a whole number in range.
  String? _optionalInt(String? s, int max) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    return (v == null || v < 0 || v > max) ? '0 – $max' : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    int? opt(TextEditingController c) => c.text.trim().isEmpty ? null : int.parse(c.text.trim());
    try {
      await ref.read(adminRepositoryProvider).savePermissionPolicy({
        'enabled': _enabled,
        'deadline_hours': int.parse(_hours.text.trim()),
        'monthly_limit': opt(_month),
        'quarterly_limit': opt(_quarter),
        'weight': double.parse(_weight.text.trim()),
      });
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_loading) return const SizedBox(height: 200, child: LoadingView());
    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
          Text(l.permissionPolicy, style: context.serif(19)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.permissionsEnabled), value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
          TextFormField(
            controller: _hours,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.permissionDeadlineHours),
            validator: (s) => (s ?? '').trim().isEmpty ? '0 – 1440' : _optionalInt(s, 1440),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _month, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.permissionMonthlyLimit), validator: (s) => _optionalInt(s, 100)),
          const SizedBox(height: 12),
          TextFormField(controller: _quarter, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.permissionQuarterlyLimit), validator: (s) => _optionalInt(s, 300)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.permissionWeight, helperText: l.permissionWeightHint, helperMaxLines: 2),
            validator: (s) {
              final v = double.tryParse((s ?? '').trim());
              return (v == null || v < 0 || v > 1) ? '0 – 1' : null;
            },
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
          const SizedBox(height: 14),
          FilledButton(onPressed: _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}

// =============================================================================
// App versions (releases.manage): publish APKs for the download page / force update.
// =============================================================================
final _releasesProvider = FutureProvider.autoDispose<List<AppRelease>>((ref) => ref.watch(adminRepositoryProvider).releases());

String downloadPageUrl() => '${Uri.parse(AppConfig.apiBaseUrl).origin}/download';

class ReleasesScreen extends ConsumerWidget {
  const ReleasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.releases,
      actions: [
        IconButton(
          tooltip: l.openDownloadPage,
          icon: const Icon(Icons.open_in_browser_rounded),
          onPressed: () => launchUrl(Uri.parse(downloadPageUrl()), mode: LaunchMode.externalApplication),
        ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: const _PublishSheet()),
          );
          if (ok == true) ref.invalidate(_releasesProvider);
        },
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(l.newRelease),
      ),
      body: AsyncView(
        value: ref.watch(_releasesProvider),
        onRetry: () => ref.invalidate(_releasesProvider),
        data: (list) => list.isEmpty
            ? EmptyView(message: l.noResults, icon: Icons.system_update_outlined)
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
                for (final r in list)
                  TrackTile(
                    title: 'v${r.versionName} (${r.versionCode})',
                    subtitle: [
                      f.date(r.createdAt),
                      Formatters.fileSize(r.fileSize),
                      l.downloadsCount(r.downloadCount),
                      if (r.isMandatory) l.mandatoryUpdate.split(' (').first,
                      if (!r.isPublished) l.statusDraft,
                    ].join(' · '),
                    leading: ListThumb(icon: Icons.android_rounded, active: r.isMandatory),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        final repo = ref.read(adminRepositoryProvider);
                        switch (v) {
                          case 'mandatory':
                            await runWithProgress(context, () => repo.updateRelease(r.id, {'is_mandatory': !r.isMandatory}), success: l.saved);
                          case 'publish':
                            await runWithProgress(context, () => repo.updateRelease(r.id, {'is_published': !r.isPublished}), success: l.saved);
                          case 'delete':
                            if (await showConfirm(context, l.deleteConfirm, destructive: true) && context.mounted) {
                              await runWithProgress(context, () => repo.deleteRelease(r.id), success: l.deleted);
                            }
                        }
                        ref.invalidate(_releasesProvider);
                      },
                      itemBuilder: (_) => [
                        CheckedPopupMenuItem(value: 'mandatory', checked: r.isMandatory, child: Text(l.mandatoryUpdate.split(' (').first)),
                        PopupMenuItem(value: 'publish', child: Text(r.isPublished ? l.unpublish : l.publish)),
                        PopupMenuItem(value: 'delete', child: Text(l.delete, style: const TextStyle(color: AppColors.danger))),
                      ],
                    ),
                    onTap: r.releaseNotes == null ? null : () => showInfo(context, r.releaseNotes!, title: 'v${r.versionName}'),
                  ),
              ]),
      ),
    );
  }
}

class _PublishSheet extends ConsumerStatefulWidget {
  const _PublishSheet();
  @override
  ConsumerState<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends ConsumerState<_PublishSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _notes = TextEditingController();
  final _minCode = TextEditingController();
  bool _mandatory = false;
  String? _path;
  String? _fileName;
  double? _progress;
  Object? _error;

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    setState(() {
      _path = files.first.path;
      _fileName = files.first.name;
    });
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_path == null) {
      showSnack(context, l.chooseApk);
      return;
    }
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).publishRelease(
            filePath: _path!,
            versionName: _name.text.trim(),
            versionCode: int.parse(_code.text.trim()),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            mandatory: _mandatory,
            minSupportedCode: int.tryParse(_minCode.text.trim()),
            onProgress: (p) => setState(() => _progress = p),
          );
      if (mounted) {
        showSnack(context, l.uploadDone);
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _error = e;
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Text(l.newRelease, style: context.serif(19)),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _progress != null ? null : _pick, icon: const Icon(Icons.attach_file_rounded), label: Text(_fileName ?? l.chooseApk)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            validator: (s) => RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.]+)?$').hasMatch(s?.trim() ?? '') ? null : l.vInvalidVersion,
            decoration: InputDecoration(labelText: l.versionName),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            validator: (s) => v.intRange(s, min: 1, max: 2100000000),
            decoration: InputDecoration(labelText: l.versionCode, errorText: serverFieldError(l, _error, 'version_code')),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _notes, minLines: 2, maxLines: 6, decoration: InputDecoration(labelText: l.releaseNotes, alignLabelWithHint: true)),
          const SizedBox(height: 12),
          TextFormField(controller: _minCode, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, max: 2100000000, optional: true), decoration: InputDecoration(labelText: l.minSupportedCode)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.mandatoryUpdate), value: _mandatory, onChanged: (x) => setState(() => _mandatory = x)),
          if (_progress != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: LinearProgressIndicator(value: _progress)),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
          FilledButton(onPressed: _progress != null ? null : _submit, child: Text(l.publish)),
        ]),
      ),
    );
  }
}
