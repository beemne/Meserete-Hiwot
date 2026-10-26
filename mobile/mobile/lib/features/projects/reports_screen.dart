import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../models/project.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold, DateTimeField;
import 'pm_common.dart';

/// Department project & task report: factual counts (no scores), with filters in categories
/// (User · Project · Task · Date · Budget · Completion).
class ProjectReportsScreen extends ConsumerStatefulWidget {
  const ProjectReportsScreen({super.key, required this.departmentId});
  final int departmentId;
  @override
  ConsumerState<ProjectReportsScreen> createState() => _ProjectReportsScreenState();
}

class _ProjectReportsScreenState extends ConsumerState<ProjectReportsScreen> {
  PmReportFilters _filters = PmReportFilters();
  late Future<Json> _future = _load();
  List<PmUser> _people = const [];

  Future<Json> _load() => ref.read(projectRepositoryProvider).report(widget.departmentId, _filters);

  @override
  void initState() {
    super.initState();
    ref.read(projectRepositoryProvider).people(widget.departmentId).then((p) {
      if (mounted) setState(() => _people = p);
    }).catchError((_) {});
  }

  Future<void> _openFilters() async {
    final next = await showModalBottomSheet<PmReportFilters>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _FilterSheet(initial: _filters.copy(), people: _people),
    );
    if (next == null) return;
    setState(() {
      _filters = next;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.pmReports,
      actions: [
        Badge(
          isLabelVisible: _filters.count > 0,
          label: Text('${_filters.count}'),
          child: IconButton(key: const ValueKey('report-filters'), tooltip: l.pmFilters, icon: const Icon(Icons.filter_list_rounded), onPressed: _openFilters),
        ),
      ],
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _load()));
          if (!snap.hasData) return const LoadingView();
          final d = snap.data!;
          final projects = asJson(d['projects']);
          final tasks = asJson(d['tasks']);
          final tStatus = asJson(tasks['by_status']);
          final budget = asJson(d['budget']);
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              SectionHeader(title: l.projectsTitle),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  PmStat(label: l.pmTotal, value: '${projects['total'] ?? 0}'),
                  PmStat(label: l.pmActive, value: '${projects['active'] ?? 0}'),
                  PmStat(label: l.pmStCompleted, value: '${asJson(projects['by_status'])['completed'] ?? 0}', color: AppColors.success),
                  PmStat(label: l.pmOverdue, value: '${projects['overdue'] ?? 0}', color: AppColors.danger),
                ]),
              ),
              SectionHeader(title: l.pmTasks),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Wrap(alignment: WrapAlignment.spaceAround, spacing: 14, runSpacing: 12, children: [
                  PmStat(label: l.pmTotal, value: '${tasks['total'] ?? 0}'),
                  for (final s in ProjectTask.statuses) PmStat(label: taskStatusLabel(l, s), value: '${tStatus[s] ?? 0}', color: statusColor(s)),
                  PmStat(label: l.pmOverdue, value: '${tasks['overdue'] ?? 0}', color: AppColors.danger),
                ]),
              ),
              SectionHeader(title: l.pmByUser),
              if (asJsonList(d['users']).isEmpty) EmptyView(message: l.noResults, icon: Icons.person_search_rounded),
              for (final u in asJsonList(d['users']))
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${asJson(u['user'])['full_name']}', style: context.sans(14, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '${l.pmProjectsInvolved}: ${u['projects_involved']}',
                        '${l.pmAssigned}: ${u['assigned']}',
                        '${l.pmStCompleted}: ${u['completed']}',
                        '${l.pmStInProgress}: ${u['in_progress']}',
                        '${l.pmStPending}: ${u['pending']}',
                        '${l.pmStBlocked}: ${u['blocked']}',
                        '${l.pmOverdue}: ${u['overdue']}',
                      ].join(' · '),
                      style: context.sans(12, color: context.palette.muted, height: 1.5),
                    ),
                  ]),
                ),
              SectionHeader(title: l.pmBudget),
              Text(
                ['${l.pmBudgetApproved}: ${f.money(asDouble(budget['approved']), 'ETB')}', '${l.pmBudgetSpent}: ${f.money(asDouble(budget['spent']), 'ETB')}', '${l.pmBudgetPending}: ${f.money(asDouble(budget['pending']), 'ETB')}'].join('\n'),
                style: context.sans(13, height: 1.6),
              ),
              SectionHeader(title: l.projectsTitle),
              for (final p in asJsonList(d['project_list']))
                TrackTile(
                  title: '${p['title']}',
                  subtitle: [
                    projectStatusLabel(l, '${p['status']}'),
                    '${p['progress']}%',
                    '${l.pmTasks}: ${asJson(p['tasks'])['completed']}/${asJson(p['tasks'])['total']}',
                    if (asBool(p['overdue'])) l.pmOverdue,
                  ].join(' · '),
                  leading: Icon(Icons.folder_outlined, color: statusColor('${p['status']}')),
                  onTap: () => context.push('/projects/${p['id']}'),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Filters grouped by category.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.people});
  final PmReportFilters initial;
  final List<PmUser> people;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final PmReportFilters f = widget.initial;

  Widget _group(String title, IconData icon, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Icon(icon, color: AppColors.gold),
          title: Text(title, style: context.sans(14, weight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          expandedAlignment: Alignment.centerLeft,
          children: children,
        ),
      );

  Widget _chips<T>(List<(T, String)> items, bool Function(T) selected, void Function(T, bool) onSel) => Wrap(spacing: 6, runSpacing: 4, children: [
        for (final (v, label) in items) FilterChip(label: Text(label), selected: selected(v), onSelected: (x) => setState(() => onSel(v, x))),
      ]);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(children: [
              Expanded(child: Text(l.pmFilters, style: context.serif(18))),
              TextButton(onPressed: () => Navigator.pop(context, PmReportFilters()), child: Text(l.pmClearFilters)),
              FilledButton(key: const ValueKey('report-apply'), onPressed: () => Navigator.pop(context, f), child: Text(l.pmApply)),
            ]),
          ),
          Expanded(
            child: ListView(children: [
              _group(l.pmFilterUser, Icons.person_outline_rounded, [
                if (widget.people.isEmpty) Text('—', style: context.sans(12)),
                _chips<int>([for (final p in widget.people) (p.id, p.fullName)], (v) => f.userIds.contains(v), (v, x) => x ? f.userIds.add(v) : f.userIds.remove(v)),
              ]),
              _group(l.pmFilterProject, Icons.folder_outlined, [
                _chips<String>([for (final s in const ['planning', 'not_started', 'in_progress', 'on_hold', 'completed', 'cancelled']) (s, projectStatusLabel(l, s))], (v) => f.projectStatus.contains(v),
                    (v, x) => x ? f.projectStatus.add(v) : f.projectStatus.remove(v)),
                CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(l.pmOverdue), value: f.projectOverdue, onChanged: (x) => setState(() => f.projectOverdue = x ?? false)),
              ]),
              _group(l.pmFilterTask, Icons.task_alt_rounded, [
                _chips<String>([for (final s in ProjectTask.statuses) (s, taskStatusLabel(l, s))], (v) => f.taskStatus.contains(v), (v, x) => x ? f.taskStatus.add(v) : f.taskStatus.remove(v)),
                const SizedBox(height: 6),
                _chips<String>([for (final p in const ['low', 'medium', 'high', 'urgent']) (p, priorityLabel(l, p))], (v) => f.taskPriority.contains(v), (v, x) => x ? f.taskPriority.add(v) : f.taskPriority.remove(v)),
                CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(l.pmOverdue), value: f.overdue, onChanged: (x) => setState(() => f.overdue = x ?? false)),
              ]),
              _group(l.pmFilterDate, Icons.date_range_rounded, [
                _chips<String>([('today', l.pmToday), ('week', l.pmThisWeek), ('month', l.pmThisMonth), ('custom', l.pmCustomRange)], (v) => f.period == v, (v, x) => f.period = x ? v : null),
                if (f.period != null) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: f.dateField,
                    decoration: InputDecoration(labelText: l.pmDateField),
                    items: [
                      DropdownMenuItem(value: 'deadline', child: Text(l.pmByDeadline)),
                      DropdownMenuItem(value: 'created', child: Text(l.pmByCreated)),
                      DropdownMenuItem(value: 'start', child: Text(l.pmByStart)),
                      DropdownMenuItem(value: 'completed', child: Text(l.pmByCompleted)),
                    ],
                    onChanged: (x) => setState(() => f.dateField = x ?? 'deadline'),
                  ),
                ],
                if (f.period == 'custom') ...[
                  const SizedBox(height: 8),
                  // Ethiopian calendar picker: the period is sent as Gregorian dates.
                  DateTimeField(label: l.from, value: f.from, withTime: false, clearable: true, onChanged: (d) => setState(() => f.from = d)),
                  const SizedBox(height: 8),
                  DateTimeField(label: l.to, value: f.to, withTime: false, clearable: true, onChanged: (d) => setState(() => f.to = d)),
                ],
              ]),
              _group(l.pmFilterBudget, Icons.account_balance_wallet_outlined, [
                _chips<String>([('within', l.pmWithinBudget), ('over', l.pmBudgetOver), ('none', l.pmNoBudget)], (v) => f.budgetStatus == v, (v, x) => f.budgetStatus = x ? v : null),
              ]),
              _group(l.pmFilterCompletion, Icons.percent_rounded, [
                _chips<int>([for (final n in const [25, 50, 75, 100]) (n, l.pmMinProgress('$n'))], (v) => f.minProgress == v, (v, x) => f.minProgress = x ? v : null),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
