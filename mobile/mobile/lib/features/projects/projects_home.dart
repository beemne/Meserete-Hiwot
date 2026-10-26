import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/project.dart';
import '../../repositories/providers.dart';
import '../../services/sync_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold, StatTile;
import 'pm_common.dart';
import 'project_editors.dart';
import '../guidance/contextual_help_sheet.dart';

final pmOverviewProvider = FutureProvider.autoDispose<PmOverview>((ref) => ref.watch(projectRepositoryProvider).overview());

/// Project Management home: the departments whose projects this person may see, their own tasks
/// and, for Finance, what is waiting for approval.
class ProjectsHomeScreen extends ConsumerWidget {
  const ProjectsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    return AdminScaffold(
      title: l.projectManagement,
      actions: const [
        ContextualHelpButton(screenRoute: '/projects'),
      ],
      body: AsyncView(
        value: ref.watch(pmOverviewProvider),
        onRetry: () => ref.invalidate(pmOverviewProvider),
        data: (o) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(pmOverviewProvider),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            Row(children: [
              Expanded(
                child: StatTile(
                  key: const ValueKey('pm-my-tasks'),
                  icon: Icons.assignment_ind_rounded,
                  label: l.pmMyTasks,
                  value: '${o.myOpen}',
                  highlight: o.myOverdue > 0,
                  onTap: () => context.push('/projects/my-tasks'),
                ),
              ),
              if (o.pendingApprovals > 0 || o.departments.any((d) => d.canApprove)) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    key: const ValueKey('pm-approvals'),
                    icon: Icons.fact_check_outlined,
                    label: l.pmApprovals,
                    value: '${o.pendingApprovals}',
                    highlight: o.pendingApprovals > 0,
                    onTap: () => context.push('/projects/approvals'),
                  ),
                ),
              ],
            ]),
            if (o.myOverdue > 0)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.pmOverdueCount('${o.myOverdue}'), style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600))),
            SectionHeader(title: l.pmDepartment),
            if (o.departments.isEmpty) EmptyView(message: l.pmNoDepartments, icon: Icons.apartment_rounded),
            for (final d in o.departments)
              TrackTile(
                key: ValueKey('pm-dept-${d.department.id}'),
                title: d.department.label(lang),
                subtitle: [
                  l.pmProjectsCount('${d.total}'),
                  l.pmActiveCount('${d.active}'),
                  if (d.overdue > 0) l.pmOverdueCount('${d.overdue}'),
                  if (d.openIssues > 0) '${l.pmIssues}: ${d.openIssues}',
                ].join(' · '),
                leading: ListThumb(icon: Icons.apartment_rounded, active: d.canManage),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/projects/department/${d.department.id}'),
              ),
          ]),
        ),
      ),
    );
  }
}

/// One department: Overview of its projects, Issues, Suggestions, Reports.
class DepartmentProjectsScreen extends ConsumerStatefulWidget {
  const DepartmentProjectsScreen({super.key, required this.departmentId});
  final int departmentId;
  @override
  ConsumerState<DepartmentProjectsScreen> createState() => _DepartmentProjectsScreenState();
}

class _DepartmentProjectsScreenState extends ConsumerState<DepartmentProjectsScreen> {
  String _filter = 'active'; // active | all | overdue | completed
  final _projects = PagedListController<Project>();
  final _issues = PagedListController<PmIssue>();
  final _suggestions = PagedListController<PmSuggestion>();
  late final LiveProjectFeed _live = LiveProjectFeed(ref, departmentId: widget.departmentId, onChange: (_) {
    _projects.refresh();
    _issues.refresh();
    _suggestions.refresh();
  });

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

  PmDepartmentOverview? _dept(PmOverview? o) => o?.departments.where((d) => d.department.id == widget.departmentId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final d = _dept(ref.watch(pmOverviewProvider).value);
    final repo = ref.read(projectRepositoryProvider);
    return DefaultTabController(
      length: 3,
      child: AdminScaffold(
        title: d?.department.label(lang) ?? l.projectsTitle,
        actions: [
          if (d?.canReports ?? false)
            IconButton(key: const ValueKey('pm-reports'), tooltip: l.pmReports, icon: const Icon(Icons.insights_rounded), onPressed: () => context.push('/projects/department/${widget.departmentId}/reports')),
        ],
        bottom: TabBar(tabs: [Tab(text: l.projectsTitle), Tab(text: l.pmIssues), Tab(text: l.pmSuggestions)]),
        fab: Builder(builder: (context) {
          final tab = DefaultTabController.of(context);
          return AnimatedBuilder(
            animation: tab,
            builder: (context, _) {
              if (tab.index == 0 && (d?.canManage ?? false)) {
                return FloatingActionButton.extended(
                  key: const ValueKey('pm-new-project'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.pmNewProject),
                  onPressed: () async {
                    final p = await Navigator.of(context).push<Project>(MaterialPageRoute(builder: (_) => ProjectEditorScreen(departmentId: widget.departmentId)));
                    if (p != null) {
                      await _projects.refresh();
                      ref.invalidate(pmOverviewProvider);
                    }
                  },
                );
              }
              if (tab.index == 2 && (d?.canSuggest ?? false)) {
                return FloatingActionButton.extended(
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: Text(l.pmSuggest),
                  onPressed: () async {
                    if (await showSuggestionEditor(context, ref, departmentId: widget.departmentId)) await _suggestions.refresh();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          );
        }),
        body: TabBarView(children: [
          Column(children: [
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), children: [
                for (final (v, label) in [('active', l.pmActive), ('overdue', l.pmOverdue), ('completed', l.pmStCompleted), ('all', l.pmAll)])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text(label), selected: _filter == v, onSelected: (_) {
                      setState(() => _filter = v);
                      _projects.refresh();
                    }),
                  ),
              ]),
            ),
            Expanded(
              child: PagedListView<Project>(
                key: ValueKey('projects-$_filter'),
                controller: _projects,
                emptyMessage: l.pmNoProjects,
                emptyIcon: Icons.folder_open_rounded,
                fetch: (page) => repo.projects(
                  departmentId: widget.departmentId,
                  page: page,
                  active: _filter == 'active',
                  overdue: _filter == 'overdue',
                  status: _filter == 'completed' ? 'completed' : null,
                ),
                itemBuilder: (context, p, _) => ProjectCard(project: p, onTap: () async {
                  await context.push('/projects/${p.id}');
                  _projects.refresh();
                }),
              ),
            ),
          ]),
          PagedListView<PmIssue>(
            controller: _issues,
            emptyMessage: l.pmNoIssues,
            emptyIcon: Icons.report_gmailerrorred_rounded,
            fetch: (page) => repo.issues(departmentId: widget.departmentId, page: page),
            itemBuilder: (context, i, _) => IssueTile(issue: i, onTap: () async {
              await context.push('/projects/issues/${i.id}');
              _issues.refresh();
            }),
          ),
          PagedListView<PmSuggestion>(
            controller: _suggestions,
            emptyMessage: l.pmNoSuggestions,
            emptyIcon: Icons.lightbulb_outline_rounded,
            fetch: (page) => repo.suggestions(departmentId: widget.departmentId, page: page),
            itemBuilder: (context, s, _) => SuggestionTile(suggestion: s, onTap: () async {
              await context.push('/projects/suggestions/${s.id}');
              _suggestions.refresh();
            }),
          ),
        ]),
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, this.onTap});
  final Project project;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = project;
    final total = p.taskCounts['total'] ?? 0;
    final done = p.taskCounts['completed'] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: AppCard(
        key: ValueKey('project-${p.id}'),
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p.title, style: context.serif(16, weight: FontWeight.w600))),
            StatusPill(projectStatusLabel(l, p.status), color: statusColor(p.status)),
          ]),
          const SizedBox(height: 6),
          DeadlineText(deadline: p.deadline, secondsRemaining: p.secondsRemaining, overdue: p.overdue, open: p.isOpen),
          const SizedBox(height: 8),
          ProgressLine(value: p.progress),
          const SizedBox(height: 6),
          Text(
            [
              '${l.pmTasks}: $done/$total',
              if ((p.taskCounts['overdue'] ?? 0) > 0) l.pmOverdueCount('${p.taskCounts['overdue']}'),
              if ((p.taskCounts['blocked'] ?? 0) > 0) '${l.pmStBlocked}: ${p.taskCounts['blocked']}',
              if (p.leader != null) p.leader!.fullName,
            ].join(' · '),
            style: context.sans(12, color: context.palette.muted),
          ),
        ]),
      ),
    );
  }
}

class IssueTile extends StatelessWidget {
  const IssueTile({super.key, required this.issue, this.onTap});
  final PmIssue issue;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final i = issue;
    return TrackTile(
      key: ValueKey('issue-${i.id}'),
      title: i.title,
      subtitle: [i.projectTitle, issueStatusLabel(l, i.status), priorityLabel(l, i.priority), if (i.assignee != null) i.assignee!.fullName].join(' · '),
      leading: Icon(Icons.report_gmailerrorred_rounded, color: statusColor(i.status)),
      onTap: onTap,
    );
  }
}

class SuggestionTile extends StatelessWidget {
  const SuggestionTile({super.key, required this.suggestion, this.onTap});
  final PmSuggestion suggestion;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = suggestion;
    return TrackTile(
      key: ValueKey('suggestion-${s.id}'),
      title: s.title,
      subtitle: [?s.projectTitle, suggestionStatusLabel(l, s.status), if (s.author != null) s.author!.fullName].join(' · '),
      leading: Icon(Icons.lightbulb_outline_rounded, color: statusColor(s.status)),
      onTap: onTap,
    );
  }
}

/// Every task the person is responsible for, across departments.
class MyTasksScreen extends ConsumerStatefulWidget {
  const MyTasksScreen({super.key});
  @override
  ConsumerState<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends ConsumerState<MyTasksScreen> {
  String _filter = 'open';
  final _ctrl = PagedListController<ProjectTask>();
  Set<int> _pending = {};
  late final LiveProjectFeed _live = LiveProjectFeed(ref, onChange: (_) => _ctrl.refresh());

  @override
  void initState() {
    super.initState();
    _live.start();
    _loadPending();
  }

  Future<void> _loadPending() async {
    final ops = await ref.read(syncServiceProvider).pending(SyncOp.projectTaskUpdate);
    if (mounted) setState(() => _pending = ops.map((o) => o['task_id'] as int).toSet());
  }

  @override
  void dispose() {
    _live.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(projectRepositoryProvider);
    return AdminScaffold(
      title: l.pmMyTasks,
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), children: [
            for (final (v, label) in [('open', l.pmActive), ('overdue', l.pmOverdue), ('pending', l.pmStPending), ('blocked', l.pmStBlocked), ('completed', l.pmStCompleted), ('all', l.pmAll)])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(label), selected: _filter == v, onSelected: (_) {
                  setState(() => _filter = v);
                  _ctrl.refresh();
                }),
              ),
          ]),
        ),
        Expanded(
          child: PagedListView<ProjectTask>(
            key: ValueKey('my-tasks-$_filter'),
            controller: _ctrl,
            emptyMessage: l.pmNoTasks,
            emptyIcon: Icons.task_alt_rounded,
            fetch: (page) => repo.myTasks(
              page: page,
              open: _filter == 'open',
              overdue: _filter == 'overdue',
              status: const {'pending', 'blocked', 'completed'}.contains(_filter) ? _filter : null,
            ),
            itemBuilder: (context, t, _) => TaskTile(
              task: t,
              showProject: true,
              pendingSync: _pending.contains(t.id),
              onTap: () async {
                await context.push('/projects/tasks/${t.id}');
                await _loadPending();
                _ctrl.refresh();
              },
            ),
          ),
        ),
      ]),
    );
  }
}

/// New suggestion for a department (or one project).
Future<bool> showSuggestionEditor(BuildContext context, WidgetRef ref, {int? departmentId, int? projectId}) async {
  final l = context.l10n;
  final title = TextEditingController();
  final body = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.pmSuggest),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const ValueKey('suggestion-title'), controller: title, decoration: InputDecoration(labelText: l.pmSuggestionTitle)),
        const SizedBox(height: 8),
        TextField(controller: body, minLines: 2, maxLines: 6, decoration: InputDecoration(labelText: l.pmDescription)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.send)),
      ],
    ),
  );
  if (ok != true || title.text.trim().length < 2 || !context.mounted) return false;
  final r = await runWithProgress(
    context,
    () => ref.read(projectRepositoryProvider).createSuggestion({'department_id': ?departmentId, 'project_id': ?projectId, 'title': title.text.trim(), if (body.text.trim().isNotEmpty) 'body': body.text.trim()}),
    success: l.saved,
  );
  return r != null;
}
