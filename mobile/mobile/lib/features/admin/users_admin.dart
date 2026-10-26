import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../settings/attendance_calendar.dart' show AttendanceCalendarView;
import '../members/member_editor.dart';
import '../members/member_form.dart';
import '../members/profile_changes.dart' show ProfileHistoryScreen;
import 'admin_widgets.dart';
import 'member_filters.dart';
import 'programs_admin.dart' show pickProgram;
import '../guidance/contextual_help_sheet.dart';

/// Users: search, filter, paginate, select (individual / visible / all matching) and bulk actions.
class UsersAdminScreen extends ConsumerStatefulWidget {
  const UsersAdminScreen({super.key});
  @override
  ConsumerState<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends ConsumerState<UsersAdminScreen> {
  final _ctrl = PagedListController<AppUser>();
  String _q = '';
  String? _status;
  MemberFilter _more = const MemberFilter();
  final _selected = <int, String>{};
  bool _allMatching = false;
  int _total = 0;

  Json get _filter => {
        'q': _q.isEmpty ? null : _q,
        'status': _status,
        ..._more.toQuery(),
      };

  bool get _selecting => _allMatching || _selected.isNotEmpty;
  int get _count => _allMatching ? _total : _selected.length;

  BulkTarget get _target {
    if (!_allMatching) return BulkTarget.users(_selected.keys.toList());
    final f = <String, dynamic>{
      if (_q.isNotEmpty) 'q': _q,
      'status': ?_status,
      ..._more.toBody(),
    };
    return f.isEmpty ? const BulkTarget.everyone() : BulkTarget.filter(f);
  }

  void _resetSelection() => setState(() {
        _selected.clear();
        _allMatching = false;
      });

  Future<bool> _confirmCount() async {
    final l = context.l10n;
    // The server resolves the selection (also for "all matching") and reports the real count.
    final count = await runWithProgress(context, () => ref.read(adminRepositoryProvider).previewTarget(_target));
    if (count == null || !mounted) return false;
    return showConfirm(context, l.bulkConfirm(count));
  }

  Future<void> _bulkNotify() async {
    if (!await _confirmCount() || !mounted) return;
    await context.push('/admin/notify', extra: _target);
    _resetSelection();
  }

  Future<void> _bulkInvite() async {
    final l = context.l10n;
    final program = await pickProgram(context);
    if (program == null || !mounted || !await _confirmCount() || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(adminRepositoryProvider).addParticipants(program.id, _target));
    if (r != null && mounted) {
      showSnack(context, l.invitedResult(asIntOr(r['added'])));
      _resetSelection();
    }
  }

  Future<void> _create() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MemberEditorScreen()));
    await _ctrl.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider)!;
    final repo = ref.read(adminRepositoryProvider);
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: _selecting ? l.selectedCount(_count) : l.users,
      actions: [
        if (_selecting) IconButton(tooltip: l.clearSelection, icon: const Icon(Icons.close_rounded), onPressed: _resetSelection),
        PopupMenuButton<String>(
          onSelected: (v) => setState(() {
            if (v == 'visible') {
              _allMatching = false;
              for (final u in _ctrl.items) {
                _selected[u.id] = u.fullName;
              }
            } else if (v == 'matching') {
              _allMatching = true;
            } else {
              _resetSelection();
            }
          }),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'visible', child: Text(l.selectAll)),
            PopupMenuItem(value: 'matching', child: Text(l.selectAllMatching)),
            PopupMenuItem(value: 'clear', child: Text(l.clearSelection)),
          ],
        ),
        const ContextualHelpButton(screenRoute: '/admin/users'),
      ],
      fab: _selecting || !user.can(Perm.usersCreate)
          ? null
          : FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.person_add_alt_rounded), label: Text(l.createUser)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            ChoiceChip(label: Text(l.all), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
            const SizedBox(width: 6),
            ChoiceChip(label: Text(l.statusPending), selected: _status == 'pending', onSelected: (_) => setState(() => _status = 'pending')),
            const SizedBox(width: 6),
            ChoiceChip(label: Text(l.statusActive), selected: _status == 'active', onSelected: (_) => setState(() => _status = 'active')),
            const SizedBox(width: 6),
            ChoiceChip(label: Text(l.statusDisabled), selected: _status == 'disabled', onSelected: (_) => setState(() => _status = 'disabled')),
          ]),
        ),
        // Categorized filters: personal · membership · account · activity & groups.
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: MemberFilterBar(filter: _more, onChanged: (f) => setState(() => _more = f)),
        ),
        if (_allMatching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Pill(l.allMatchingSelected(_total), icon: Icons.select_all_rounded),
          ),
        Expanded(
          child: PagedListView<AppUser>(
            key: ValueKey(_filter.toString()),
            controller: _ctrl,
            fetch: (page) => repo.users(filter: _filter, page: page),
            onPageLoaded: (p) => setState(() => _total = p.total),
            emptyMessage: l.noResults,
            emptyIcon: Icons.people_outline_rounded,
            itemBuilder: (context, u, _) {
              final sel = _allMatching || _selected.containsKey(u.id);
              return TrackTile(
                title: u.fullName,
                subtitle: [if (u.isAccountAdmin) l.adminBadge, if (u.memberId != null) u.memberId!, if (u.phone.isNotEmpty) u.phone, memberGroupLabel(l, u.memberGroup), if (u.membershipStatus != 'active') membershipStatusLabel(l, u.membershipStatus), if (!u.canLogin) l.cannotLogin, if (u.status == 'disabled') l.statusDisabled, if (u.status == 'pending') l.statusPending, if (u.lastLoginAt != null) '${l.lastLogin}: ${f.relative(u.lastLoginAt)}'].join(' · '),
                selected: sel,
                leading: _selecting
                    ? Checkbox(value: sel, onChanged: _allMatching ? null : (v) => setState(() => v == true ? _selected[u.id] = u.fullName : _selected.remove(u.id)))
                    : CircleAvatar(
                        radius: 22,
                        backgroundColor: context.palette.pill,
                        backgroundImage: u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null,
                        child: u.avatarUrl == null ? Text(u.fullName.characters.first, style: context.serif(16)) : null,
                      ),
                trailing: u.hasDevice ? const Icon(Icons.smartphone_rounded, size: 16, color: AppColors.gold) : null,
                onLongPress: () => setState(() => _selected[u.id] = u.fullName),
                onTap: () {
                  if (_selecting) {
                    if (!_allMatching) setState(() => sel ? _selected.remove(u.id) : _selected[u.id] = u.fullName);
                    return;
                  }
                  context.push('/admin/users/${u.id}').then((_) => _ctrl.refresh());
                },
              );
            },
          ),
        ),
        if (_selecting)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                if (user.can(Perm.notificationsSend))
                  FilledButton.icon(onPressed: _bulkNotify, icon: const Icon(Icons.send_rounded, size: 18), label: Text(l.bulkNotify)),
                if (user.can(Perm.programsManage))
                  OutlinedButton.icon(onPressed: _bulkInvite, icon: const Icon(Icons.event_rounded, size: 18), label: Text(l.bulkInvite)),
                if (user.can(Perm.borrowingManage) && !_allMatching)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/admin/borrowings/bulk', extra: UserSelection(ids: _selected.keys.toSet(), names: Map.of(_selected))),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(l.bulkBorrow),
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
final _userDetailProvider = FutureProvider.autoDispose.family<({AppUser user, Json profile, List<Json> departments}), int>((ref, id) => ref.watch(adminRepositoryProvider).user(id));
final _devicesProvider = FutureProvider.autoDispose.family<({Json current, List<Json> history}), int>((ref, id) => ref.watch(adminRepositoryProvider).deviceHistory(id));

class UserDetailAdminScreen extends ConsumerWidget {
  const UserDetailAdminScreen({super.key, required this.userId});
  final int userId;

  String _event(AppLocalizations l, String e) => switch (e) {
        'bound' => l.devBound,
        'login' => l.devLogin,
        'login_rejected' => l.devLoginRejected,
        'reset' => l.devReset,
        'force_logout' => l.devForceLogout,
        _ => e,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    final repo = ref.read(adminRepositoryProvider);
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    void refresh() {
      ref.invalidate(_userDetailProvider(userId));
      ref.invalidate(_devicesProvider(userId));
    }

    return AdminScaffold(
      title: l.details,
      body: AsyncView(
        value: ref.watch(_userDetailProvider(userId)),
        onRetry: refresh,
        data: (d) {
          final u = d.user;
          final devices = ref.watch(_devicesProvider(userId));
          return ListView(padding: const EdgeInsets.all(16), children: [
            // The member as on the membership form (classification, departments as badges).
            MemberProfileView(user: u, profile: d.profile, departments: d.departments),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(
                '${l.account}: ${switch (u.status) { 'active' => l.statusActive, 'pending' => l.statusPending, _ => l.statusDisabled }}',
                color: switch (u.status) { 'active' => AppColors.success, 'pending' => AppColors.goldDark, _ => AppColors.danger },
              ),
            ]),
            SettingsGroup(children: [
              if (me.can(Perm.usersUpdate))
                SettingsTile(
                  icon: Icons.edit_note_rounded,
                  label: l.editMember,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MemberEditorScreen(user: u, profile: d.profile)));
                    refresh();
                  },
                ),
              if (me.canAny([Perm.attendanceManage, Perm.attendanceReports]))
                SettingsTile(
                  icon: Icons.calendar_month_rounded,
                  label: l.attendance,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => AdminScaffold(
                      title: '${l.attendance} · ${u.fullName}',
                      body: AttendanceCalendarView(fetch: (from, to, cat) => ref.read(programRepositoryProvider).userCalendar(u.id, from: from, to: to, categoryId: cat)),
                    ),
                  )),
                ),
              if (me.can(Perm.borrowingManage))
                SettingsTile(icon: Icons.inventory_2_outlined, label: l.activeBorrowings, onTap: () => context.push('/admin/borrowings', extra: {'user_id': u.id})),
              // Every change of this member's details (old → new); earlier values are never lost.
              SettingsTile(
                key: const ValueKey('user-change-history'),
                icon: Icons.history_rounded,
                label: l.changeHistory,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileHistoryScreen(userId: u.id, name: u.fullName))),
              ),
              SettingsTile(label: l.registeredAt, value: f.date(u.createdAt)),
              SettingsTile(label: l.lastLogin, value: f.dateTime(u.lastLoginAt)),
            ]),
            SettingsGroup(title: l.device, children: [
              SettingsTile(icon: Icons.smartphone_rounded, label: u.deviceName ?? l.noDevice),
              if (me.can(Perm.usersResetDevice)) ...[
                SettingsTile(
                  icon: Icons.phonelink_erase_rounded,
                  label: l.resetDevice,
                  onTap: () async {
                    if (!await showConfirm(context, l.resetDeviceConfirm, destructive: true) || !context.mounted) return;
                    final reason = await promptText(context, title: l.resetDevice, label: l.resetReason);
                    if (reason == null || !context.mounted) return;
                    await runWithProgress(context, () => repo.resetDevice(u.id, reason: reason.isEmpty ? null : reason), success: l.deviceResetDone);
                    refresh();
                  },
                ),
                SettingsTile(
                  icon: Icons.logout_rounded,
                  label: l.forceLogout,
                  onTap: () async {
                    if (await showConfirm(context, l.forceLogoutConfirm) && context.mounted) await runWithProgress(context, () => repo.forceLogout(u.id), success: l.done);
                    refresh();
                  },
                ),
              ],
            ]),
            SettingsGroup(title: l.deviceHistory, children: [
              ...devices.when(
                data: (h) => h.history.isEmpty
                    ? [SettingsTile(label: l.noDevice)]
                    : h.history.map((e) => SettingsTile(
                          label: '${_event(l, '${e['event']}')} · ${e['device_name'] ?? '—'}',
                          value: '${f.dateTime(asDate(e['created_at']))}${e['actor_name'] != null ? '\n${e['actor_name']}' : ''}',
                        )),
                loading: () => [const LoadingView(padding: EdgeInsets.all(12))],
                error: (e, _) => [ErrorView(error: e)],
              ),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (me.can(Perm.usersDisable))
                OutlinedButton.icon(
                  icon: Icon(u.status == 'active' ? Icons.block_rounded : Icons.check_circle_outline_rounded),
                  label: Text(u.status == 'active' ? l.disable : (u.status == 'pending' ? l.approve : l.enable)),
                  onPressed: () async {
                    if (u.status == 'active' && !await showConfirm(context, l.disableConfirm, destructive: true)) return;
                    if (!context.mounted) return;
                    await runWithProgress(context, () => repo.setUserEnabled(u.id, u.status != 'active'), success: l.saved);
                    refresh();
                  },
                ),
              if (me.can(Perm.usersUpdate))
                OutlinedButton.icon(
                  icon: const Icon(Icons.password_rounded),
                  label: Text(l.resetUserPassword),
                  onPressed: () async {
                    final r = await runWithProgress(context, () => repo.resetUserPassword(u.id));
                    if (r != null && context.mounted) await showTempPassword(context, r.password, viaTelegram: r.viaTelegram);
                  },
                ),
              if (me.can(Perm.activityLogsView))
                OutlinedButton.icon(
                  icon: const Icon(Icons.timeline_rounded),
                  label: Text(l.activityLogs),
                  onPressed: () => context.push('/admin/activity', extra: {'user_id': u.id}),
                ),
              // A member can be made an administrator; they keep everything a member has.
              if (me.can(Perm.adminsManage) && !u.isAccountAdmin && u.status == 'active' && u.id != me.id)
                FilledButton.tonalIcon(
                  key: const ValueKey('user-promote'),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: Text(l.promoteToAdmin),
                  onPressed: () async {
                    final roles = await runWithProgress(context, () => repo.roles());
                    if (roles == null || !context.mounted) return;
                    final assignable = roles.where((r) => r.assignable && r.isActive).toList();
                    final roleId = await showDialog<int>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: Text(l.promoteChooseRole),
                        children: [
                          Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text(l.promoteHint(u.fullName), style: ctx.sans(12, color: ctx.palette.muted))),
                          for (final r in assignable) SimpleDialogOption(key: ValueKey('promote-role-${r.slug}'), onPressed: () => Navigator.pop(ctx, r.id), child: Text(r.name)),
                        ],
                      ),
                    );
                    if (roleId == null || !context.mounted) return;
                    final a = await runWithProgress(context, () => repo.promoteToAdmin(u.id, roleId), success: l.promoted);
                    if (a != null && context.mounted) context.push('/admin/admins/${a.id}');
                    refresh();
                  },
                ),
            ]),
          ]);
        },
      ),
    );
  }
}
