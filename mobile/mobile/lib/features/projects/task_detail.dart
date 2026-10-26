import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/project.dart';
import '../../repositories/providers.dart';
import '../../services/sync_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold;
import 'pm_common.dart';
import 'project_detail.dart' show openPmFile;
import 'project_editors.dart';
import '../../widgets/typed_picker.dart';

final taskDetailProvider = FutureProvider.autoDispose.family<ProjectTask, int>((ref, id) => ref.watch(projectRepositoryProvider).task(id));
final _taskCommentsProvider = FutureProvider.autoDispose.family<List<PmComment>, int>((ref, id) => ref.watch(projectRepositoryProvider).taskComments(id));
final _taskFilesProvider = FutureProvider.autoDispose.family<List<PmFile>, ({int project, int task})>((ref, k) => ref.watch(projectRepositoryProvider).files(k.project, taskId: k.task));

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final int taskId;
  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  LiveProjectFeed? _live;
  bool _waitingSync = false;
  double? _dragProgress;
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPending();
  }

  @override
  void dispose() {
    _live?.stop();
    _comment.dispose();
    super.dispose();
  }

  void _startLive(int projectId) {
    if (_live != null) return;
    _live = LiveProjectFeed(ref, projectId: projectId, onChange: (events) {
      if (events.any((e) => e['task_id'] == widget.taskId)) _reload();
    })
      ..start();
  }

  Future<void> _checkPending() async {
    final ops = await ref.read(syncServiceProvider).pending(SyncOp.projectTaskUpdate);
    if (mounted) setState(() => _waitingSync = ops.any((o) => o['task_id'] == widget.taskId));
  }

  void _reload() {
    ref.invalidate(taskDetailProvider(widget.taskId));
    ref.invalidate(_taskCommentsProvider(widget.taskId));
    _checkPending();
  }

  Future<void> _setStatus(ProjectTask t, String status) async {
    final details = await askStatusDetails(context, status);
    if (details == null || !mounted) return;
    await _submit(t, details);
  }

  Future<void> _submit(ProjectTask t, Map<String, dynamic> change) async {
    final outcome = await runWithProgress(context, () => submitTaskChange(ref, t, change));
    if (outcome == null || !mounted) return;
    showTaskChangeOutcome(context, outcome);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final async = ref.watch(taskDetailProvider(widget.taskId));
    final t = async.value;
    if (t != null) _startLive(t.projectId);
    return AdminScaffold(
      title: t?.title ?? l.pmTasks,
      actions: [
        if (t?.canEdit ?? false)
          PopupMenuButton<String>(
            onSelected: (v) async {
              final repo = ref.read(projectRepositoryProvider);
              switch (v) {
                case 'edit':
                  final saved = await Navigator.of(context).push<ProjectTask>(MaterialPageRoute(builder: (_) => TaskEditorScreen(task: t)));
                  if (saved != null) _reload();
                case 'ask':
                  await runWithProgress(context, () => repo.askStatus(t!.id), success: l.pmAskedStatus);
                case 'cancel':
                  await _submit(t!, {'status': 'cancelled'});
                case 'delete':
                  if (!await showConfirm(context, l.pmDeleteTaskConfirm, destructive: true, confirmLabel: l.delete) || !context.mounted) return;
                  final ok = await runWithProgress(context, () async {
                    await repo.deleteTask(t!.id);
                    return true;
                  });
                  if (ok == true && context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(l.edit)),
              if (t!.isOpen) PopupMenuItem(value: 'ask', child: Text(l.pmAskStatus)),
              if (t.isOpen) PopupMenuItem(value: 'cancel', child: Text(l.pmStCancelled)),
              PopupMenuItem(value: 'delete', child: Text(l.delete)),
            ],
          ),
      ],
      body: AsyncView(
        value: async,
        onRetry: _reload,
        data: (t) => RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  StatusPill(taskStatusLabel(l, t.status), color: statusColor(t.status), icon: taskStatusIcon(t.status)),
                  StatusPill(priorityLabel(l, t.priority), color: priorityColor(t.priority), icon: Icons.flag_rounded),
                  if (t.overdue) StatusPill(l.pmOverdue, color: AppColors.danger, icon: Icons.warning_amber_rounded),
                  if (_waitingSync) StatusPill(l.pmWaitingSync, color: AppColors.goldDark, icon: Icons.cloud_upload_outlined),
                ]),
                if (t.status == 'pending' && (t.pendingReason != null || t.statusReason != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text([if (t.pendingReason != null) pendingReasonLabel(l, t.pendingReason!), ?t.statusReason].join(' — '), style: context.sans(13, color: AppColors.goldDark)),
                  ),
                if (t.status == 'blocked' && t.statusReason != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(t.statusReason!, style: context.sans(13, color: AppColors.danger))),
                const SizedBox(height: 12),
                ProgressLine(value: _dragProgress?.round() ?? t.progress),
                if (t.canUpdateStatus && t.isOpen)
                  Slider(
                    key: const ValueKey('task-progress'),
                    value: _dragProgress ?? t.progress.toDouble(),
                    max: 100,
                    divisions: 20,
                    label: '${(_dragProgress ?? t.progress.toDouble()).round()}%',
                    onChanged: (v) => setState(() => _dragProgress = v),
                    onChangeEnd: (v) async {
                      await _submit(t, {'progress': v.round()});
                      if (mounted) setState(() => _dragProgress = null);
                    },
                  ),
                const SizedBox(height: 4),
                PmInfoRow(icon: Icons.folder_outlined, label: l.projectsTitle, child: InkWell(onTap: () => context.push('/projects/${t.projectId}'), child: Text(t.projectTitle, style: context.sans(13, color: AppColors.maroon, weight: FontWeight.w600)))),
                PmInfoRow(icon: Icons.groups_rounded, label: l.pmResponsible, child: Text(t.assignees.isEmpty ? '—' : t.assignees.map((a) => a.fullName).join(', '))),
                PmInfoRow(icon: Icons.flag_circle_outlined, label: l.pmTaskDeadline, child: DeadlineText(deadline: t.deadline, secondsRemaining: t.secondsRemaining, overdue: t.overdue, open: t.isOpen)),
                PmInfoRow(icon: Icons.outlined_flag_rounded, label: l.pmProjectDeadline, child: DeadlineText(deadline: t.projectDeadline, open: false)),
                if (t.startDate != null) PmInfoRow(icon: Icons.play_circle_outline_rounded, label: l.pmStartDate, child: Text(f.date(t.startDate))),
                if (t.programTitle != null)
                  PmInfoRow(icon: Icons.event_rounded, label: l.pmProgram, child: InkWell(onTap: () => context.push('/programs/${t.programId}'), child: Text(t.programTitle!, style: context.sans(13, color: AppColors.maroon, weight: FontWeight.w600)))),
                if (t.issueTitle != null) PmInfoRow(icon: Icons.report_gmailerrorred_rounded, label: l.pmRelatedIssue, child: Text(t.issueTitle!)),
                if (t.completedBy != null) PmInfoRow(icon: Icons.check_circle_outline_rounded, label: l.pmStCompleted, child: Text(l.pmCompletedBy(t.completedBy!.fullName, f.dateTime(t.completedAt)))),
                if (t.completionNote != null) PmInfoRow(icon: Icons.notes_rounded, label: l.pmCompletionNote, child: Text(t.completionNote!)),
              ]),
            ),
            if (t.canUpdateStatus && t.status != 'cancelled') ...[
              SectionHeader(title: l.pmChangeStatus),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in const ['not_started', 'in_progress', 'pending', 'blocked', 'completed'])
                  if (s != t.status)
                    ActionChip(
                      key: ValueKey('task-status-$s'),
                      avatar: Icon(taskStatusIcon(s), size: 18, color: statusColor(s)),
                      label: Text(taskStatusLabel(l, s)),
                      onPressed: () => _setStatus(t, s),
                    ),
              ]),
            ],
            if (t.canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  key: const ValueKey('task-assign'),
                  icon: const Icon(Icons.group_add_rounded),
                  label: Text(l.pmAssign),
                  onPressed: () async {
                    final picked = await pickPeople(context, ref, t.departmentId, selected: t.assignees.map((a) => a.id).toSet());
                    if (picked == null || !context.mounted) return;
                    final reason = t.assignees.isEmpty ? '' : await promptText(context, title: l.pmAssign, label: l.pmReassignReason);
                    if (reason == null || !context.mounted) return;
                    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).setAssignees(t.id, picked.toList(), reason: reason.trim().isEmpty ? null : reason.trim()), success: l.saved);
                    if (r != null) _reload();
                  },
                ),
              ),
            if (t.description != null && t.description!.isNotEmpty) ...[SectionHeader(title: l.pmDescription), Text(t.description!, style: context.sans(14, height: 1.6))],
            if (t.notes != null && t.notes!.isNotEmpty) ...[SectionHeader(title: l.pmNotes), Text(t.notes!, style: context.sans(14, height: 1.6))],
            SectionHeader(
              title: l.pmFiles,
              trailing: t.canUpdateStatus ? l.pmUploadFile : null,
              onTrailingTap: () async {
                final path = (await pickTypedFile(context))?.path;
                if (path == null || !context.mounted) return;
                await runWithProgress(context, () => ref.read(projectRepositoryProvider).uploadFile(t.projectId, path, taskId: t.id), success: l.saved);
                ref.invalidate(_taskFilesProvider((project: t.projectId, task: t.id)));
              },
            ),
            ...(ref.watch(_taskFilesProvider((project: t.projectId, task: t.id))).value ?? const <PmFile>[]).map((x) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.description_outlined, color: AppColors.maroon),
                  title: Text(x.name ?? '#${x.id}'),
                  subtitle: Text(Formatters.fileSize(x.size)),
                  onTap: () => openPmFile(context, ref, x.url, name: x.name, mime: x.mime),
                )),
            SectionHeader(title: l.pmComments),
            ...(ref.watch(_taskCommentsProvider(t.id)).value ?? const <PmComment>[]).map((c) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  title: Text(c.body),
                  subtitle: Text([c.user?.fullName ?? '—', f.dateTime(c.createdAt)].join(' · ')),
                )),
            Row(children: [
              Expanded(child: TextField(controller: _comment, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: l.pmAddComment))),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.maroon),
                onPressed: () async {
                  final text = _comment.text.trim();
                  if (text.isEmpty) return;
                  final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).addTaskComment(t.id, text));
                  if (r != null) {
                    _comment.clear();
                    ref.invalidate(_taskCommentsProvider(t.id));
                  }
                },
              ),
            ]),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.report_gmailerrorred_rounded),
              label: Text(l.pmReportIssue),
              onPressed: () => showIssueEditor(context, ref, projectId: t.projectId, taskId: t.id),
            ),
          ]),
        ),
      ),
    );
  }
}
