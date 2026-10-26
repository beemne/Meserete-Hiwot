import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../models/activity.dart';
import '../../models/json.dart';
import '../../models/project.dart';
import '../../repositories/providers.dart';
import '../../widgets/dialogs.dart';
import '../admin/admin_widgets.dart' show AdminScaffold, DateTimeField;
import 'pm_common.dart';

/// Create (departmentId) or edit (project) a project. Pops with the saved project.
class ProjectEditorScreen extends ConsumerStatefulWidget {
  const ProjectEditorScreen({super.key, this.departmentId, this.project});
  final int? departmentId;
  final Project? project;
  @override
  ConsumerState<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends ConsumerState<ProjectEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.project?.title);
  late final _desc = TextEditingController(text: widget.project?.description);
  late final _notes = TextEditingController(text: widget.project?.notes);
  late final _progress = TextEditingController(text: '${widget.project?.progress ?? 0}');
  late DateTime? _start = widget.project?.startDate;
  late DateTime? _deadline = widget.project?.deadline;
  late String _status = widget.project?.status ?? 'planning';
  late String _priority = widget.project?.priority ?? 'medium';
  late String _mode = widget.project?.progressMode ?? 'tasks';
  late bool _allowLate = widget.project?.allowLateTasks ?? false;
  late PmUser? _leader = widget.project?.leader;
  Set<int> _team = {};
  bool _saving = false;
  Object? _error;

  int get _departmentId => widget.project?.department.id ?? widget.departmentId!;

  String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(projectRepositoryProvider);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'start_date': _start == null ? null : _d(_start!),
      'deadline': _deadline?.toUtc().toIso8601String(),
      'status': _status,
      'priority': _priority,
      'progress_mode': _mode,
      if (_mode == 'manual') 'progress': int.tryParse(_progress.text.trim()) ?? 0,
      'allow_late_tasks': _allowLate,
      'leader_id': _leader?.id,
    };
    try {
      final p = widget.project == null
          ? await repo.createProject({...body, 'department_id': _departmentId, 'team': _team.toList()})
          : await repo.updateProject(widget.project!.id, body);
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return AdminScaffold(
      title: widget.project == null ? l.pmNewProject : l.pmEditProject,
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          TextFormField(key: const ValueKey('project-title'), controller: _title, validator: (s) => v.text(s, min: 2, max: 200), decoration: InputDecoration(labelText: l.pmTitle)),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, minLines: 2, maxLines: 8, validator: (s) => v.text(s, max: 20000, optional: true), decoration: InputDecoration(labelText: l.pmDescription, alignLabelWithHint: true)),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_pin_rounded),
            title: Text(l.pmLeader),
            subtitle: Text(_leader?.fullName ?? '—'),
            trailing: const Icon(Icons.edit_rounded, size: 18),
            onTap: () async {
              final picked = await pickPeople(context, ref, _departmentId, single: true);
              if (picked == null || picked.isEmpty || !context.mounted) return;
              final people = await ref.read(projectRepositoryProvider).people(_departmentId);
              setState(() => _leader = people.where((p) => p.id == picked.first).firstOrNull);
            },
          ),
          if (widget.project == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups_rounded),
              title: Text(l.pmTeam),
              subtitle: Text(_team.isEmpty ? '—' : '${_team.length}'),
              trailing: const Icon(Icons.edit_rounded, size: 18),
              onTap: () async {
                final picked = await pickPeople(context, ref, _departmentId, selected: _team);
                if (picked != null) setState(() => _team = picked);
              },
            ),
          const SizedBox(height: 8),
          DateTimeField(label: l.pmStartDate, value: _start, withTime: false, clearable: true, onChanged: (d) => setState(() => _start = d)),
          const SizedBox(height: 12),
          DateTimeField(key: const ValueKey('project-deadline'), label: l.pmProjectDeadline, value: _deadline, clearable: true, onChanged: (d) => setState(() => _deadline = d)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(labelText: l.status),
            items: [for (final s in const ['planning', 'not_started', 'in_progress', 'on_hold', 'completed', 'cancelled']) DropdownMenuItem(value: s, child: Text(projectStatusLabel(l, s)))],
            onChanged: (x) => setState(() => _status = x ?? _status),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: InputDecoration(labelText: l.pmPriority),
            items: [for (final p in const ['low', 'medium', 'high', 'urgent']) DropdownMenuItem(value: p, child: Text(priorityLabel(l, p)))],
            onChanged: (x) => setState(() => _priority = x ?? _priority),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: InputDecoration(labelText: l.pmProgressMode),
            items: [
              DropdownMenuItem(value: 'tasks', child: Text(l.pmProgressTasks)),
              DropdownMenuItem(value: 'weighted', child: Text(l.pmProgressWeighted)),
              DropdownMenuItem(value: 'manual', child: Text(l.pmProgressManual)),
            ],
            onChanged: (x) => setState(() => _mode = x ?? _mode),
          ),
          if (_mode == 'manual') ...[
            const SizedBox(height: 12),
            TextFormField(controller: _progress, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, max: 100), decoration: InputDecoration(labelText: l.pmProgress, suffixText: '%')),
          ],
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.pmAllowLateTasks), value: _allowLate, onChanged: (x) => setState(() => _allowLate = x)),
          TextFormField(controller: _notes, minLines: 2, maxLines: 6, decoration: InputDecoration(labelText: l.pmNotes, alignLabelWithHint: true)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
          const SizedBox(height: 16),
          FilledButton(key: const ValueKey('project-save'), onPressed: _saving ? null : _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}

final _upcomingProgramsProvider = FutureProvider.autoDispose<List<Program>>((ref) async => (await ref.watch(programRepositoryProvider).list(scope: 'upcoming', limit: 100)).items);

/// Create (project) or edit (task) a task. Pops with the saved task.
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({super.key, this.project, this.task, this.suggestionId});
  final Project? project;
  final ProjectTask? task;

  /// Converting a suggestion into a task (the suggestion's text is the default).
  final int? suggestionId;
  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _desc = TextEditingController(text: widget.task?.description);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late final _weight = TextEditingController(text: '${widget.task?.weight ?? 1}');
  late DateTime? _start = widget.task?.startDate;
  late DateTime? _deadline = widget.task?.deadline;
  late String _priority = widget.task?.priority ?? 'medium';
  late int? _programId = widget.task?.programId;
  late Set<int> _assignees = {...?widget.task?.assignees.map((a) => a.id)};
  late final Map<int, String> _names = {for (final a in widget.task?.assignees ?? const <PmUser>[]) a.id: a.fullName};
  bool _afterDeadline = false;
  bool _saving = false;
  Object? _error;

  int get _departmentId => widget.task?.departmentId ?? widget.project!.department.id;
  DateTime? get _projectDeadline => widget.task?.projectDeadline ?? widget.project?.deadline;

  String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(projectRepositoryProvider);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'start_date': _start == null ? null : _d(_start!),
      'deadline': _deadline?.toUtc().toIso8601String(),
      'priority': _priority,
      'weight': int.tryParse(_weight.text.trim()) ?? 1,
      'program_id': _programId,
      if (_afterDeadline) 'allow_after_project_deadline': true,
    };
    try {
      final ProjectTask t;
      if (widget.task == null) {
        t = await repo.createTask(widget.project!.id, {...body, 'assignee_ids': _assignees.toList()});
      } else {
        t = await repo.updateTask(widget.task!.id, body);
      }
      if (mounted) Navigator.pop(context, t);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final late = _deadline != null && _projectDeadline != null && _deadline!.isAfter(_projectDeadline!);
    final programs = ref.watch(_upcomingProgramsProvider).value ?? const <Program>[];
    return AdminScaffold(
      title: widget.task == null ? l.pmNewTask : l.pmEditTask,
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          TextFormField(key: const ValueKey('task-title'), controller: _title, validator: (s) => v.text(s, min: 2, max: 200), decoration: InputDecoration(labelText: l.pmTitle)),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, minLines: 2, maxLines: 8, validator: (s) => v.text(s, max: 20000, optional: true), decoration: InputDecoration(labelText: l.pmDescription, alignLabelWithHint: true)),
          if (widget.task == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.group_add_rounded),
              title: Text(l.pmResponsible),
              subtitle: Text(_assignees.isEmpty ? '—' : _assignees.map((id) => _names[id] ?? '#$id').join(', ')),
              trailing: const Icon(Icons.edit_rounded, size: 18),
              onTap: () async {
                final people = await ref.read(projectRepositoryProvider).people(_departmentId).catchError((_) => <PmUser>[]);
                if (!context.mounted) return;
                final picked = await pickPeople(context, ref, _departmentId, selected: _assignees);
                if (picked == null) return;
                setState(() {
                  _assignees = picked;
                  for (final p in people) {
                    _names[p.id] = p.fullName;
                  }
                });
              },
            ),
          const SizedBox(height: 8),
          DateTimeField(label: l.pmStartDate, value: _start, withTime: false, clearable: true, onChanged: (d) => setState(() => _start = d)),
          const SizedBox(height: 12),
          DateTimeField(
            key: const ValueKey('task-deadline'),
            label: l.pmTaskDeadline,
            value: _deadline,
            clearable: true,
            errorText: late && !_afterDeadline && !(widget.project?.allowLateTasks ?? false) ? l.errTaskAfterProjectDeadline : null,
            onChanged: (d) => setState(() => _deadline = d),
          ),
          if (_projectDeadline != null)
            Padding(padding: const EdgeInsets.only(top: 4, left: 4), child: DeadlineText(deadline: _projectDeadline, open: false)),
          if (late && (widget.project?.canManageDepartment ?? true))
            CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text(l.pmAfterProjectDeadline), value: _afterDeadline, onChanged: (x) => setState(() => _afterDeadline = x ?? false)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: InputDecoration(labelText: l.pmPriority),
            items: [for (final p in const ['low', 'medium', 'high', 'urgent']) DropdownMenuItem(value: p, child: Text(priorityLabel(l, p)))],
            onChanged: (x) => setState(() => _priority = x ?? _priority),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _weight, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, min: 1, max: 100), decoration: InputDecoration(labelText: l.pmWeight)),
          const SizedBox(height: 12),
          // A task may point at an existing program / event (no copy is made).
          DropdownButtonFormField<int?>(
            initialValue: programs.any((p) => p.id == _programId) ? _programId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.pmProgram),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(widget.task?.programTitle != null && !programs.any((p) => p.id == _programId) ? widget.task!.programTitle! : l.pmNoProgram)),
              for (final p in programs) DropdownMenuItem<int?>(value: p.id, child: Text(p.title, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (x) => setState(() => _programId = x),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _notes, minLines: 2, maxLines: 6, decoration: InputDecoration(labelText: l.pmNotes, alignLabelWithHint: true)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
          const SizedBox(height: 16),
          FilledButton(key: const ValueKey('task-save'), onPressed: _saving ? null : _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}

/// New problem report for a project (optionally about one task).
Future<bool> showIssueEditor(BuildContext context, WidgetRef ref, {required int projectId, int? taskId}) async {
  final l = context.l10n;
  final title = TextEditingController();
  final desc = TextEditingController();
  var priority = 'medium';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(l.pmReportIssue),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(key: const ValueKey('issue-title'), controller: title, decoration: InputDecoration(labelText: l.pmIssueTitle)),
            const SizedBox(height: 8),
            TextField(controller: desc, minLines: 2, maxLines: 6, decoration: InputDecoration(labelText: l.pmDescription)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: priority,
              decoration: InputDecoration(labelText: l.pmPriority),
              items: [for (final p in const ['low', 'medium', 'high', 'urgent']) DropdownMenuItem(value: p, child: Text(priorityLabel(l, p)))],
              onChanged: (x) => setS(() => priority = x ?? priority),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.send)),
        ],
      ),
    ),
  );
  if (ok != true || title.text.trim().length < 2 || !context.mounted) return false;
  final Json body = {'title': title.text.trim(), 'priority': priority, 'task_id': ?taskId, if (desc.text.trim().isNotEmpty) 'description': desc.text.trim()};
  final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).createIssue(projectId, body), success: l.saved);
  return r != null;
}

/// Small read-only row used on detail pages.
class PmInfoRow extends StatelessWidget {
  const PmInfoRow({super.key, required this.icon, required this.label, required this.child});
  final IconData icon;
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: context.sans(12, color: context.palette.muted))),
          Expanded(child: child),
        ]),
      );
}
