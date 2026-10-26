import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../models/project.dart';
import '../../repositories/providers.dart';
import '../../services/sync_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';

// ---------------------------------------------------------------------------- labels
String projectStatusLabel(AppLocalizations l, String s) => switch (s) {
      'planning' => l.pmStPlanning,
      'not_started' => l.pmStNotStarted,
      'in_progress' => l.pmStInProgress,
      'on_hold' => l.pmStOnHold,
      'completed' => l.pmStCompleted,
      _ => l.pmStCancelled,
    };

String taskStatusLabel(AppLocalizations l, String s) => switch (s) {
      'not_started' => l.pmStNotStarted,
      'pending' => l.pmStPending,
      'in_progress' => l.pmStInProgress,
      'blocked' => l.pmStBlocked,
      'completed' => l.pmStCompleted,
      _ => l.pmStCancelled,
    };

String priorityLabel(AppLocalizations l, String p) => switch (p) {
      'low' => l.pmPrLow,
      'high' => l.pmPrHigh,
      'urgent' => l.pmPrUrgent,
      _ => l.pmPrMedium,
    };

String pendingReasonLabel(AppLocalizations l, String r) => switch (r) {
      'approval' => l.pmReasonApproval,
      'materials' => l.pmReasonMaterials,
      'finance' => l.pmReasonFinance,
      'another_task' => l.pmReasonAnotherTask,
      'another_department' => l.pmReasonAnotherDepartment,
      'paused' => l.pmReasonPaused,
      _ => l.pmReasonOther,
    };

String issueStatusLabel(AppLocalizations l, String s) => switch (s) {
      'open' => l.pmIsOpen,
      'under_review' => l.pmIsUnderReview,
      'assigned' => l.pmIsAssigned,
      'in_progress' => l.pmStInProgress,
      'resolved' => l.pmIsResolved,
      _ => l.pmIsClosed,
    };

String suggestionStatusLabel(AppLocalizations l, String s) => switch (s) {
      'submitted' => l.pmSgSubmitted,
      'under_review' => l.pmIsUnderReview,
      'accepted' => l.pmSgAccepted,
      'rejected' => l.pmSgRejected,
      _ => l.pmSgConverted,
    };

String expenseStatusLabel(AppLocalizations l, String s) => switch (s) {
      'approved' => l.pmExApproved,
      'rejected' => l.pmSgRejected,
      'recorded' => l.pmExRecorded,
      'cancelled' => l.pmStCancelled,
      _ => l.pmStPending,
    };

Color statusColor(String s) => switch (s) {
      'completed' || 'resolved' || 'accepted' || 'approved' || 'recorded' || 'converted' => AppColors.success,
      'blocked' || 'cancelled' || 'rejected' => AppColors.danger,
      'pending' || 'on_hold' || 'under_review' => AppColors.gold,
      'in_progress' || 'assigned' => const Color(0xFF1F5F8B),
      _ => const Color(0xFF8A7A7D),
    };

Color priorityColor(String p) => switch (p) {
      'urgent' => AppColors.danger,
      'high' => const Color(0xFFD9822B),
      'low' => const Color(0xFF8A7A7D),
      _ => const Color(0xFF1F5F8B),
    };

IconData taskStatusIcon(String s) => switch (s) {
      'completed' => Icons.check_circle_rounded,
      'in_progress' => Icons.timelapse_rounded,
      'pending' => Icons.hourglass_top_rounded,
      'blocked' => Icons.block_rounded,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.radio_button_unchecked_rounded,
    };

/// "3 d 4 h left" / "Overdue by 2 h" from seconds remaining.
String timeLeftText(AppLocalizations l, int seconds) {
  final s = seconds.abs();
  final parts = <String>[];
  final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60;
  if (d > 0) parts.add(l.pmDays('$d'));
  if (h > 0 && d < 7) parts.add(l.pmHours('$h'));
  if (d == 0 && h == 0) parts.add(l.pmMinutes('${m < 1 ? 1 : m}'));
  final t = parts.join(' ');
  return seconds >= 0 ? l.pmTimeLeft(t) : l.pmOverdueBy(t);
}

// ---------------------------------------------------------------------------- small widgets
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Pill(text, color: color, background: color.withValues(alpha: 0.13), icon: icon);
}

class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, this.label});
  final int value;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: value.clamp(0, 100) / 100, minHeight: 7, backgroundColor: p.border, color: value >= 100 ? AppColors.success : AppColors.gold),
        ),
      ),
      const SizedBox(width: 8),
      Text(label ?? '$value%', style: context.sans(12, weight: FontWeight.w600, color: p.muted)),
    ]);
  }
}

/// Deadline line with the time left / overdue, in red when overdue.
class DeadlineText extends StatelessWidget {
  const DeadlineText({super.key, required this.deadline, this.secondsRemaining, this.overdue = false, this.open = true});
  final DateTime? deadline;
  final int? secondsRemaining;
  final bool overdue;
  final bool open;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    if (deadline == null) return Text(l.pmNoDeadline, style: context.sans(12, color: context.palette.subtle));
    final left = open && secondsRemaining != null ? ' · ${timeLeftText(l, secondsRemaining!)}' : '';
    return Text('${f.dateTime(deadline)}$left', style: context.sans(12, color: overdue ? AppColors.danger : context.palette.muted, weight: overdue ? FontWeight.w600 : FontWeight.w400));
  }
}

/// One task row (lists in a project, My Tasks, reports).
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.onTap, this.showProject = false, this.pendingSync = false});
  final ProjectTask task;
  final VoidCallback? onTap;
  final bool showProject;
  final bool pendingSync;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = task;
    final color = statusColor(t.status);
    return TrackTile(
      key: ValueKey('task-${t.id}'),
      title: t.title,
      subtitle: [
        if (showProject) t.projectTitle,
        taskStatusLabel(l, t.status),
        if (t.status == 'pending' && t.pendingReason != null) pendingReasonLabel(l, t.pendingReason!),
        if (t.assignees.isNotEmpty) t.assignees.map((a) => a.fullName.split(' ').first).join(', '),
        if (t.overdue) l.pmOverdue,
        if (pendingSync) l.pmWaitingSync,
      ].join(' · '),
      leading: Icon(taskStatusIcon(t.status), color: color, size: 28),
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${t.progress}%', style: context.sans(12, weight: FontWeight.w700, color: color)),
        if (t.priority == 'high' || t.priority == 'urgent') Icon(Icons.flag_rounded, size: 16, color: priorityColor(t.priority)),
      ]),
      onTap: onTap,
    );
  }
}

/// Pick people of a department (multi-select). Returns the chosen ids or null.
Future<Set<int>?> pickPeople(BuildContext context, WidgetRef ref, int departmentId, {Set<int> selected = const {}, bool single = false}) async {
  final people = await runWithProgress(context, () => ref.read(projectRepositoryProvider).people(departmentId));
  if (people == null || !context.mounted) return null;
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => _PeoplePicker(people: people, selected: selected, single: single),
  );
}

String personRoleLabel(AppLocalizations l, String? role) => switch (role) {
      'leader' => l.pmRoleLeader,
      'admin' => l.pmRoleAdmin,
      _ => l.pmRoleMember,
    };

class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({required this.people, required this.selected, required this.single});
  final List<PmUser> people;
  final Set<int> selected;
  final bool single;
  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  late final Set<int> _sel = {...widget.selected};
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = widget.people.where((p) => _q.isEmpty || p.fullName.toLowerCase().contains(_q.toLowerCase())).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(children: [
              Expanded(child: Text(l.pmSelectPeople, style: context.serif(17))),
              if (!widget.single) FilledButton(onPressed: () => Navigator.pop(context, _sel), child: Text(l.save)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.search), onChanged: (v) => setState(() => _q = v.trim())),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyView(message: l.noResults, icon: Icons.person_search_rounded)
                : ListView(children: [
                    for (final p in list)
                      widget.single
                          ? ListTile(title: Text(p.fullName), subtitle: Text([personRoleLabel(l, p.role), ?p.memberId].join(' · ')), onTap: () => Navigator.pop(context, {p.id}))
                          : CheckboxListTile(
                              key: ValueKey('pick-person-${p.id}'),
                              value: _sel.contains(p.id),
                              title: Text(p.fullName),
                              subtitle: Text([personRoleLabel(l, p.role), ?p.memberId].join(' · ')),
                              onChanged: (v) => setState(() => v == true ? _sel.add(p.id) : _sel.remove(p.id)),
                            ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- status changes
/// Ask what a new task status needs (Pending: what it waits for; Blocked: the blocker;
/// Completed: an optional note). Returns the body for the status call, or null if cancelled.
Future<Json?> askStatusDetails(BuildContext context, String status) async {
  final l = context.l10n;
  if (status == 'pending') {
    String? code;
    final reason = TextEditingController();
    return showDialog<Json>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.pmPendingWhy),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final r in ProjectTask.pendingReasons)
                  ChoiceChip(key: ValueKey('pending-$r'), label: Text(pendingReasonLabel(l, r)), selected: code == r, onSelected: (_) => setS(() => code = r)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: reason, maxLines: 2, decoration: InputDecoration(labelText: l.pmReason)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(
              onPressed: code == null || (code == 'other' && reason.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(ctx, {'status': 'pending', 'pending_reason': code, if (reason.text.trim().isNotEmpty) 'reason': reason.text.trim()}),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
  if (status == 'blocked') {
    final r = await promptText(context, title: l.pmBlockedWhy, label: l.pmReason, maxLines: 3, required: true);
    if (r == null || r.trim().isEmpty) return null;
    return {'status': 'blocked', 'reason': r.trim()};
  }
  if (status == 'completed') {
    final note = await promptText(context, title: l.pmMarkCompleted, label: l.pmCompletionNote, maxLines: 3);
    if (note == null) return null;
    return {'status': 'completed', if (note.trim().isNotEmpty) 'note': note.trim()};
  }
  return {'status': status};
}

/// Send a status / progress change through the offline queue: applied now when online, kept on
/// the phone and sent later when offline. The server re-checks who may do it and, with
/// base_version, refuses a change to a task someone else changed meanwhile (server wins).
Future<SyncOutcome> submitTaskChange(WidgetRef ref, ProjectTask task, Json change) =>
    ref.read(syncServiceProvider).submit(SyncOp.projectTaskUpdate, {'task_id': task.id, 'base_version': task.version, ...change});

/// Tell the person what happened to a status change.
void showTaskChangeOutcome(BuildContext context, SyncOutcome o) {
  final l = context.l10n;
  if (o.queued) {
    showSnack(context, l.pmOfflineQueued);
  } else if (o.conflict) {
    showInfo(context, l.pmSyncConflict);
  } else if (o.rejected) {
    showInfo(context, o.code == 'FORBIDDEN' || o.code == 'TASK_UPDATE_FORBIDDEN' ? l.errTaskUpdateForbidden : l.errorGeneric);
  } else {
    showSnack(context, l.saved);
  }
}

// ---------------------------------------------------------------------------- live updates
/// Polls the change feed while a Project Management screen is open and calls [onChange] when
/// something relevant happened (another person changed a task, a status came from the chat…).
/// One small request every few seconds per open screen — no socket or process per task.
class LiveProjectFeed {
  LiveProjectFeed(this._ref, {this.projectId, this.departmentId, required this.onChange, this.every = const Duration(seconds: 8)});
  final WidgetRef _ref;
  final int? projectId;
  final int? departmentId;
  final void Function(List<Json> events) onChange;
  final Duration every;
  Timer? _timer;
  int? _cursor;
  bool _busy = false;

  void start() {
    _tick();
    _timer = Timer.periodic(every, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final r = await _ref.read(projectRepositoryProvider).events(after: _cursor, projectId: projectId, departmentId: departmentId);
      final events = asJsonList(r['events']);
      final first = _cursor == null;
      _cursor = asInt(r['cursor']) ?? _cursor;
      if (!first && events.isNotEmpty) onChange(events);
    } catch (_) {
      // offline: keep the last data on screen
    } finally {
      _busy = false;
    }
  }
}

/// A labelled number for summary rows.
class PmStat extends StatelessWidget {
  const PmStat({super.key, required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: context.serif(20, color: color ?? context.palette.primary)),
        Text(label, textAlign: TextAlign.center, style: context.sans(11, color: context.palette.muted)),
      ]);
}
