import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/project.dart';
import '../../repositories/providers.dart';
import '../../services/file_opening_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold;
import 'activity_detail.dart';
import 'budget_screens.dart';
import 'pm_common.dart';
import 'project_editors.dart';
import 'projects_home.dart' show IssueTile, pmOverviewProvider, showSuggestionEditor;
import '../../widgets/typed_picker.dart';

final projectDetailProvider = FutureProvider.autoDispose.family<Project, int>((ref, id) => ref.watch(projectRepositoryProvider).project(id));
final projectTasksProvider = FutureProvider.autoDispose.family<List<ProjectTask>, int>((ref, id) async => (await ref.watch(projectRepositoryProvider).tasks(id)).items);
final projectFilesProvider = FutureProvider.autoDispose.family<List<PmFile>, int>((ref, id) => ref.watch(projectRepositoryProvider).files(id));

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final int projectId;
  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  // Live updates: another person's change (or a status set from the chat Task Bot) shows up
  // without pulling to refresh.
  late final LiveProjectFeed _live = LiveProjectFeed(ref, projectId: widget.projectId, onChange: (_) => _reload());
  final _issues = PagedListController<PmIssue>();
  int _activityKey = 0;

  void _reload() {
    ref.invalidate(projectDetailProvider(widget.projectId));
    ref.invalidate(projectTasksProvider(widget.projectId));
    ref.invalidate(projectFilesProvider(widget.projectId));
    ref.invalidate(projectBudgetProvider(widget.projectId));
    _issues.refresh();
    if (mounted) setState(() => _activityKey++);
  }

  @override
  void initState() {
    super.initState();
    _live.start();
  }

  @override
  void dispose() {
    _live.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(projectDetailProvider(widget.projectId));
    final p = async.value;
    return DefaultTabController(
      length: 7,
      child: AdminScaffold(
        title: p?.title ?? l.projectsTitle,
        actions: [
          if (p?.canManage ?? false)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  final saved = await Navigator.of(context).push<Project>(MaterialPageRoute(builder: (_) => ProjectEditorScreen(project: p)));
                  if (saved != null) _reload();
                } else if (v == 'delete') {
                  if (!await showConfirm(context, l.pmDeleteProjectConfirm, destructive: true, confirmLabel: l.delete) || !context.mounted) return;
                  final ok = await runWithProgress(context, () async {
                    await ref.read(projectRepositoryProvider).deleteProject(p!.id);
                    return true;
                  });
                  if (ok == true && context.mounted) {
                    ref.invalidate(pmOverviewProvider);
                    context.pop();
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l.edit)),
                if (p!.canManageDepartment) PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
        ],
        bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
          Tab(text: l.pmOverview),
          Tab(text: l.pmTasks),
          Tab(text: l.pmTeam),
          Tab(text: l.pmIssues),
          Tab(text: l.pmBudget),
          Tab(text: l.pmFiles),
          Tab(text: l.pmActivity),
        ]),
        body: AsyncView(
          value: async,
          onRetry: _reload,
          data: (p) => TabBarView(children: [
            _Overview(project: p, onChanged: _reload),
            _Tasks(project: p, onChanged: _reload),
            _Team(project: p, onChanged: _reload),
            _Issues(project: p, controller: _issues),
            ProjectBudgetView(projectId: p.id),
            _Files(project: p),
            _Activity(key: ValueKey('activity-$_activityKey'), projectId: p.id),
          ]),
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.project, required this.onChanged});
  final Project project;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = project;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final lang = Localizations.localeOf(context).languageCode;
    final c = p.taskCounts;
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              StatusPill(projectStatusLabel(l, p.status), color: statusColor(p.status)),
              StatusPill(priorityLabel(l, p.priority), color: priorityColor(p.priority), icon: Icons.flag_rounded),
              if (p.overdue) StatusPill(l.pmOverdue, color: AppColors.danger, icon: Icons.warning_amber_rounded),
            ]),
            const SizedBox(height: 12),
            ProgressLine(value: p.progress),
            const SizedBox(height: 8),
            PmInfoRow(icon: Icons.apartment_rounded, label: l.pmDepartment, child: Text(p.department.label(lang))),
            PmInfoRow(icon: Icons.person_pin_rounded, label: l.pmLeader, child: Text(p.leader?.fullName ?? '—')),
            PmInfoRow(icon: Icons.play_circle_outline_rounded, label: l.pmStartDate, child: Text(p.startDate == null ? '—' : f.date(p.startDate))),
            PmInfoRow(icon: Icons.flag_circle_outlined, label: l.pmProjectDeadline, child: DeadlineText(deadline: p.deadline, secondsRemaining: p.secondsRemaining, overdue: p.overdue, open: p.isOpen)),
            if (p.createdBy != null) PmInfoRow(icon: Icons.edit_note_rounded, label: l.pmCreatedBy, child: Text(p.createdBy!.fullName)),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            PmStat(label: l.pmTotal, value: '${c['total'] ?? 0}'),
            PmStat(label: l.pmStCompleted, value: '${c['completed'] ?? 0}', color: AppColors.success),
            PmStat(label: l.pmStInProgress, value: '${c['in_progress'] ?? 0}'),
            PmStat(label: l.pmStPending, value: '${c['pending'] ?? 0}', color: AppColors.gold),
            PmStat(label: l.pmStBlocked, value: '${c['blocked'] ?? 0}', color: AppColors.danger),
            PmStat(label: l.pmOverdue, value: '${c['overdue'] ?? 0}', color: AppColors.danger),
          ]),
        ),
        if (p.budget.approved != null || p.budget.proposed != null) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.pmBudget, style: context.sans(13, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                [
                  if (p.budget.approved != null) '${l.pmBudgetApproved}: ${f.money(p.budget.approved!, p.budget.currency)}' else '${l.pmBudgetProposed}: ${f.money(p.budget.proposed!, p.budget.currency)}',
                  '${l.pmBudgetSpent}: ${f.money(p.budget.spent, p.budget.currency)}',
                  if (p.budget.remaining != null) '${l.pmBudgetRemaining}: ${f.money(p.budget.remaining!, p.budget.currency)}',
                ].join('\n'),
                style: context.sans(13, height: 1.5),
              ),
              if (p.budget.utilization != null) ...[const SizedBox(height: 8), ProgressLine(value: p.budget.utilization!.round(), label: l.pmBudgetUsed('${p.budget.utilization}'))],
            ]),
          ),
        ],
        if (p.description != null && p.description!.isNotEmpty) ...[
          SectionHeader(title: l.pmDescription),
          Text(p.description!, style: context.sans(14, height: 1.6)),
        ],
        if (p.notes != null && p.notes!.isNotEmpty) ...[
          SectionHeader(title: l.pmNotes),
          Text(p.notes!, style: context.sans(14, height: 1.6)),
        ],
        const SizedBox(height: 16),
        if (p.canReportIssue)
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.report_gmailerrorred_rounded),
              label: Text(l.pmReportIssue),
              onPressed: () async {
                if (await showIssueEditor(context, ref, projectId: p.id)) onChanged();
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.lightbulb_outline_rounded),
              label: Text(l.pmSuggest),
              onPressed: () => showSuggestionEditor(context, ref, projectId: p.id),
            ),
          ]),
      ]),
    );
  }
}

class _Tasks extends ConsumerStatefulWidget {
  const _Tasks({required this.project, required this.onChanged});
  final Project project;
  final VoidCallback onChanged;
  @override
  ConsumerState<_Tasks> createState() => _TasksState();
}

class _TasksState extends ConsumerState<_Tasks> {
  Set<int> _pending = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final ops = await ref.read(syncServiceProvider).pending(SyncOp.projectTaskUpdate);
    if (mounted) setState(() => _pending = ops.map((o) => o['task_id'] as int).toSet());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = widget.project;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: p.canManage && p.isOpen
          ? FloatingActionButton.extended(
              key: const ValueKey('pm-new-task'),
              icon: const Icon(Icons.add_task_rounded),
              label: Text(l.pmNewTask),
              onPressed: () async {
                final t = await Navigator.of(context).push<ProjectTask>(MaterialPageRoute(builder: (_) => TaskEditorScreen(project: p)));
                if (t != null) widget.onChanged();
              },
            )
          : null,
      body: AsyncView(
        value: ref.watch(projectTasksProvider(p.id)),
        onRetry: () => ref.invalidate(projectTasksProvider(p.id)),
        data: (tasks) => tasks.isEmpty
            ? EmptyView(message: l.pmNoTasks, icon: Icons.task_alt_rounded)
            : RefreshIndicator(
                onRefresh: () async => widget.onChanged(),
                child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
                  for (final t in tasks)
                    TaskTile(
                      task: t,
                      pendingSync: _pending.contains(t.id),
                      onTap: () async {
                        await context.push('/projects/tasks/${t.id}');
                        await _loadPending();
                        widget.onChanged();
                      },
                    ),
                ]),
              ),
      ),
    );
  }
}

class _Team extends ConsumerWidget {
  const _Team({required this.project, required this.onChanged});
  final Project project;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = project;
    return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 32), children: [
      if (p.canManage)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.group_add_rounded),
            label: Text(l.pmEditTeam),
            onPressed: () async {
              final picked = await pickPeople(context, ref, p.department.id, selected: p.team.map((m) => m.id).toSet());
              if (picked == null || !context.mounted) return;
              final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).setTeam(p.id, picked.toList()), success: l.saved);
              if (r != null) onChanged();
            },
          ),
        ),
      if (p.team.isEmpty) EmptyView(message: l.noResults, icon: Icons.groups_outlined),
      for (final m in p.team)
        TrackTile(
          title: m.fullName,
          subtitle: [personRoleLabel(l, m.role), ?m.memberId].join(' · '),
          leading: ListThumb(icon: m.role == 'leader' ? Icons.star_rounded : Icons.person_rounded, active: m.role == 'leader', imageUrl: m.avatarUrl),
        ),
    ]);
  }
}

class _Issues extends ConsumerWidget {
  const _Issues({required this.project, required this.controller});
  final Project project;
  final PagedListController<PmIssue> controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: project.canReportIssue
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.report_gmailerrorred_rounded),
              label: Text(l.pmReportIssue),
              onPressed: () async {
                if (await showIssueEditor(context, ref, projectId: project.id)) await controller.refresh();
              },
            )
          : null,
      body: PagedListView<PmIssue>(
        controller: controller,
        emptyMessage: l.pmNoIssues,
        emptyIcon: Icons.report_gmailerrorred_rounded,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        fetch: (page) => ref.read(projectRepositoryProvider).issues(projectId: project.id, page: page),
        itemBuilder: (context, i, _) => IssueTile(issue: i, onTap: () async {
          await context.push('/projects/issues/${i.id}');
          await controller.refresh();
        }),
      ),
    );
  }
}

/// Open a private project file / receipt via [FileOpeningService] with caching,
/// offline support, and unified in-app preview.
Future<void> openPmFile(BuildContext context, WidgetRef ref, String url, {String? name, String? mime}) async {
  await ref.read(fileOpeningServiceProvider).openFile(
    context,
    source: url,
    filename: name,
    mime: mime,
  );
}

class _Files extends ConsumerWidget {
  const _Files({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: project.canManage || project.team.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(l.pmUploadFile),
              onPressed: () async {
                final path = (await pickTypedFile(context))?.path;
                if (path == null || !context.mounted) return;
                final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).uploadFile(project.id, path), success: l.saved);
                if (r != null) ref.invalidate(projectFilesProvider(project.id));
              },
            )
          : null,
      body: AsyncView(
        value: ref.watch(projectFilesProvider(project.id)),
        onRetry: () => ref.invalidate(projectFilesProvider(project.id)),
        data: (files) => files.isEmpty
            ? EmptyView(message: l.pmNoFiles, icon: Icons.folder_open_rounded)
            : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
                for (final x in files)
                  TrackTile(
                    title: x.name ?? '#${x.id}',
                    subtitle: [Formatters.fileSize(x.size), if (x.uploadedBy != null) x.uploadedBy!.fullName, if (x.createdAt != null) f.date(x.createdAt)].join(' · '),
                    leading: Icon(x.mime.startsWith('image/') ? Icons.image_outlined : Icons.description_outlined, color: AppColors.maroon),
                    onTap: () => openPmFile(context, ref, x.url, name: x.name, mime: x.mime),
                    trailing: project.canManage
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              if (!await showConfirm(context, '${l.delete}?', destructive: true) || !context.mounted) return;
                              await runWithProgress(context, () => ref.read(projectRepositoryProvider).deleteFile(x.id));
                              ref.invalidate(projectFilesProvider(project.id));
                            },
                          )
                        : null,
                  ),
              ]),
      ),
    );
  }
}

/// Activity history (the audit records of the project).
class _Activity extends ConsumerWidget {
  const _Activity({super.key, required this.projectId});
  final int projectId;

  String _text(AppLocalizations l, PmActivity a) {
    final after = a.details['after'];
    final status = after is Map ? after['status'] : null;
    final kind = switch (a.action) {
      'project.create' => l.pmNewProject,
      'project.task.create' => l.pmNewTask,
      'project.task.assign' || 'project.task.reassign' => l.pmAssign,
      'project.task.completed' => l.pmStCompleted,
      'project.task.pending' => l.pmStPending,
      'project.task.blocked' => l.pmStBlocked,
      'project.task.deadline' => l.pmTaskDeadline,
      'project.issue.create' => l.pmReportIssue,
      'project.suggestion.create' => l.pmSuggest,
      'project.expense.submit' => l.pmNewExpense,
      _ => a.action.replaceFirst('project.', '').replaceAll('_', ' ').replaceAll('.', ' · '),
    };
    final reason = a.details['reason'];
    return [kind, if (status is String) taskStatusLabel(l, status), if (reason is String && reason.isNotEmpty) reason].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return PagedListView<PmActivity>(
      emptyMessage: l.pmNoActivity,
      emptyIcon: Icons.history_rounded,
      fetch: (page) => ref.read(projectRepositoryProvider).activity(projectId, page: page),
      itemBuilder: (context, a, _) => ListTile(
        dense: true,
        leading: Icon(a.details['source'] == 'chat_bot' ? Icons.smart_toy_outlined : (a.details['source'] == 'offline_sync' ? Icons.cloud_sync_outlined : Icons.history_rounded), color: AppColors.gold),
        title: Text(_text(l, a)),
        subtitle: Text([a.actorName ?? '—', f.dateTime(a.createdAt)].join(' · ')),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProjectActivityDetailScreen(projectId: projectId, activityId: a.id, title: _text(l, a)))),
      ),
    );
  }
}
