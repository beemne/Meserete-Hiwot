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
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold;
import '../auth/session.dart';
import 'pm_common.dart';
import 'project_editors.dart';

final _issueProvider = FutureProvider.autoDispose.family<PmIssue, int>((ref, id) => ref.watch(projectRepositoryProvider).issue(id));
final _projectForIssueProvider = FutureProvider.autoDispose.family<Project, int>((ref, id) => ref.watch(projectRepositoryProvider).project(id));

class IssueDetailScreen extends ConsumerStatefulWidget {
  const IssueDetailScreen({super.key, required this.issueId});
  final int issueId;
  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  final _comment = TextEditingController();

  Future<void> _update(Json body) async {
    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).updateIssue(widget.issueId, body), success: context.l10n.saved);
    if (r != null) ref.invalidate(_issueProvider(widget.issueId));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final async = ref.watch(_issueProvider(widget.issueId));
    return AdminScaffold(
      title: l.pmIssues,
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(_issueProvider(widget.issueId)),
        data: (i) {
          final project = ref.watch(_projectForIssueProvider(i.projectId)).value;
          final manage = project?.canManage ?? false;
          final me = ref.watch(currentUserProvider)?.id; // a hint for the buttons; the server decides
          final assignee = i.assignee?.id == me;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.title, style: context.serif(18)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  StatusPill(issueStatusLabel(l, i.status), color: statusColor(i.status)),
                  StatusPill(priorityLabel(l, i.priority), color: priorityColor(i.priority), icon: Icons.flag_rounded),
                ]),
                const SizedBox(height: 8),
                PmInfoRow(icon: Icons.folder_outlined, label: l.projectsTitle, child: InkWell(onTap: () => context.push('/projects/${i.projectId}'), child: Text(i.projectTitle, style: context.sans(13, color: AppColors.maroon, weight: FontWeight.w600)))),
                if (i.taskTitle != null) PmInfoRow(icon: Icons.task_alt_rounded, label: l.pmTasks, child: InkWell(onTap: () => context.push('/projects/tasks/${i.taskId}'), child: Text(i.taskTitle!))),
                PmInfoRow(icon: Icons.person_outline_rounded, label: l.pmReporter, child: Text(i.reporter?.fullName ?? '—')),
                PmInfoRow(icon: Icons.engineering_outlined, label: l.pmAssignee, child: Text(i.assignee?.fullName ?? '—')),
                if (i.createdAt != null) PmInfoRow(icon: Icons.schedule_rounded, label: l.date, child: Text(f.dateTime(i.createdAt))),
                if (i.description != null && i.description!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(i.description!, style: context.sans(14, height: 1.6))),
                if (i.resolution != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${l.pmResolution}: ${i.resolution}', style: context.sans(13, color: AppColors.success))),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (manage)
                OutlinedButton.icon(
                  icon: const Icon(Icons.engineering_outlined),
                  label: Text(l.pmAssign),
                  onPressed: () async {
                    final picked = await pickPeople(context, ref, project!.department.id, single: true);
                    if (picked != null && picked.isNotEmpty) await _update({'assignee_id': picked.first});
                  },
                ),
              if (manage && i.status == 'open') OutlinedButton(onPressed: () => _update({'status': 'under_review'}), child: Text(l.pmReview)),
              if ((manage || assignee) && const {'assigned', 'open', 'under_review'}.contains(i.status)) OutlinedButton(onPressed: () => _update({'status': 'in_progress'}), child: Text(l.pmStInProgress)),
              if ((manage || assignee) && !const {'resolved', 'closed'}.contains(i.status))
                FilledButton.tonal(
                  onPressed: () async {
                    final r = await promptText(context, title: l.pmIsResolved, label: l.pmResolution, maxLines: 4, required: true);
                    if (r != null && r.trim().isNotEmpty) await _update({'status': 'resolved', 'resolution': r.trim()});
                  },
                  child: Text(l.pmIsResolved),
                ),
              if (manage && i.status != 'closed') OutlinedButton(onPressed: () => _update({'status': 'closed'}), child: Text(l.pmIsClosed)),
              if (manage && const {'resolved', 'closed'}.contains(i.status)) OutlinedButton(onPressed: () => _update({'status': 'open'}), child: Text(l.pmIsOpen)),
            ]),
            SectionHeader(title: l.pmComments),
            for (final c in i.comments)
              ListTile(dense: true, leading: const Icon(Icons.chat_bubble_outline_rounded, size: 20), title: Text(c.body), subtitle: Text([c.user?.fullName ?? '—', f.dateTime(c.createdAt)].join(' · '))),
            Row(children: [
              Expanded(child: TextField(controller: _comment, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: l.pmAddComment))),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.maroon),
                onPressed: () async {
                  final text = _comment.text.trim();
                  if (text.isEmpty) return;
                  await runWithProgress(context, () => ref.read(projectRepositoryProvider).addIssueComment(i.id, text));
                  _comment.clear();
                  ref.invalidate(_issueProvider(widget.issueId));
                },
              ),
            ]),
          ]);
        },
      ),
    );
  }
}

final _suggestionProvider = FutureProvider.autoDispose.family<PmSuggestion, int>((ref, id) => ref.watch(projectRepositoryProvider).suggestion(id));

class SuggestionDetailScreen extends ConsumerStatefulWidget {
  const SuggestionDetailScreen({super.key, required this.suggestionId});
  final int suggestionId;
  @override
  ConsumerState<SuggestionDetailScreen> createState() => _SuggestionDetailScreenState();
}

class _SuggestionDetailScreenState extends ConsumerState<SuggestionDetailScreen> {
  final _comment = TextEditingController();

  Future<void> _review(String status) async {
    final l = context.l10n;
    final note = await promptText(context, title: suggestionStatusLabel(l, status), label: l.pmNotes, maxLines: 3, required: status == 'rejected');
    if (note == null || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).reviewSuggestion(widget.suggestionId, status, note: note.trim().isEmpty ? null : note.trim()), success: l.saved);
    if (r != null) ref.invalidate(_suggestionProvider(widget.suggestionId));
  }

  Future<void> _convert(PmSuggestion s) async {
    final l = context.l10n;
    int? projectId = s.projectId;
    if (projectId == null) {
      final projects = await runWithProgress(context, () => ref.read(projectRepositoryProvider).projects(departmentId: s.departmentId, active: true));
      if (projects == null || !mounted) return;
      projectId = await showModalBottomSheet<int>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(l.pmChooseProject, style: context.serif(17))),
            for (final p in projects.items.where((p) => p.canManage)) ListTile(title: Text(p.title), onTap: () => Navigator.pop(ctx, p.id)),
          ]),
        ),
      );
    }
    if (projectId == null || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).convertSuggestion(s.id, projectId!, const {}), success: l.saved);
    if (r == null || !mounted) return;
    ref.invalidate(_suggestionProvider(widget.suggestionId));
    final taskId = asInt(asJson(r['task'])['id']);
    if (taskId != null) await context.push('/projects/tasks/$taskId');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.pmSuggestions,
      body: AsyncView(
        value: ref.watch(_suggestionProvider(widget.suggestionId)),
        onRetry: () => ref.invalidate(_suggestionProvider(widget.suggestionId)),
        data: (s) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: context.serif(18)),
              const SizedBox(height: 8),
              StatusPill(suggestionStatusLabel(l, s.status), color: statusColor(s.status)),
              const SizedBox(height: 8),
              if (s.projectTitle != null) PmInfoRow(icon: Icons.folder_outlined, label: l.projectsTitle, child: Text(s.projectTitle!)),
              PmInfoRow(icon: Icons.person_outline_rounded, label: l.pmCreatedBy, child: Text([s.author?.fullName ?? '—', f.date(s.createdAt)].join(' · '))),
              if (s.body != null && s.body!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.body!, style: context.sans(14, height: 1.6))),
              if (s.reviewNote != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('— ${s.reviewNote}', style: context.sans(13, color: context.palette.muted))),
            ]),
          ),
          if (s.canReview && s.status != 'converted') ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (s.status == 'submitted') OutlinedButton(onPressed: () => _review('under_review'), child: Text(l.pmReview)),
              if (s.status != 'accepted') OutlinedButton(onPressed: () => _review('accepted'), child: Text(l.pmAccept)),
              if (s.status != 'rejected') OutlinedButton(onPressed: () => _review('rejected'), child: Text(l.pmReject)),
              FilledButton.icon(key: const ValueKey('suggestion-convert'), icon: const Icon(Icons.add_task_rounded), label: Text(l.pmConvertToTask), onPressed: () => _convert(s)),
            ]),
          ],
          if (s.convertedTaskId != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(icon: const Icon(Icons.task_alt_rounded), label: Text(l.pmOpenTask), onPressed: () => context.push('/projects/tasks/${s.convertedTaskId}')),
            ),
          if (s.projectId != null) ...[
            SectionHeader(title: l.pmComments),
            for (final c in s.comments) ListTile(dense: true, title: Text(c.body), subtitle: Text([c.user?.fullName ?? '—', f.dateTime(c.createdAt)].join(' · '))),
            Row(children: [
              Expanded(child: TextField(controller: _comment, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: l.pmAddComment))),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.maroon),
                onPressed: () async {
                  final text = _comment.text.trim();
                  if (text.isEmpty) return;
                  await runWithProgress(context, () => ref.read(projectRepositoryProvider).addSuggestionComment(s.id, text));
                  _comment.clear();
                  ref.invalidate(_suggestionProvider(widget.suggestionId));
                },
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
