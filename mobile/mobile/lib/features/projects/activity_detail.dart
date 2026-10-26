import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold;
import '../admin/notification_admin.dart' show deliveryLabel;
import 'pm_common.dart';

final _activityDetailProvider = FutureProvider.autoDispose.family<Json, (int, int)>((ref, k) => ref.watch(projectRepositoryProvider).activityDetail(k.$1, k.$2));

/// One project activity with the real data behind it: who did it (role, department), the project,
/// the task / problem as it is now, what changed (before → after), the people involved and what
/// the event caused (notifications with their delivery, Task Bot messages).
class ProjectActivityDetailScreen extends ConsumerWidget {
  const ProjectActivityDetailScreen({super.key, required this.projectId, required this.activityId, required this.title});
  final int projectId;
  final int activityId;
  final String title;

  String _value(Object? v) {
    if (v == null) return '—';
    if (v is List) return v.isEmpty ? '—' : v.join(', ');
    if (v is Map) return v.entries.map((e) => '${e.key}: ${_value(e.value)}').join('\n');
    return '$v';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final key = (projectId, activityId);
    return AdminScaffold(
      title: l.pmActivityDetail,
      body: AsyncView<Json>(
        value: ref.watch(_activityDetailProvider(key)),
        onRetry: () => ref.invalidate(_activityDetailProvider(key)),
        data: (a) {
          final actor = asJson(a['actor']);
          final project = asJson(a['project']);
          final task = a['task'] == null ? null : asJson(a['task']);
          final issue = a['issue'] == null ? null : asJson(a['issue']);
          final before = a['before'];
          final after = a['after'];
          final changed = <String>{if (before is Map) ...before.keys.map((k) => '$k'), if (after is Map) ...after.keys.map((k) => '$k')};
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.serif(18)),
                const SizedBox(height: 6),
                Text(f.dateTime(asDate(a['created_at'])), style: context.sans(12, color: p.muted)),
                if (a['source'] == 'chat_bot') ...[const SizedBox(height: 6), Pill(l.pmViaBot, icon: Icons.smart_toy_outlined)],
                if ('${a['reason'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 8), Text('${l.reason}: ${a['reason']}', style: context.sans(13))],
              ]),
            ),
            SettingsGroup(title: l.pmActor, children: [
              SettingsTile(label: l.pmActName, value: '${actor['full_name'] ?? '—'}'),
              if (actor['member_id'] != null) SettingsTile(label: l.memberIdLabel('').trim(), value: '${actor['member_id']}'),
              SettingsTile(label: l.role, value: '${actor['role'] ?? '—'}'),
              for (final d in asJsonList(actor['departments'])) SettingsTile(label: l.department, value: '${d['name']} (${d['role'] == 'leader' ? l.pmActLeaderRole : l.pmActMemberRole})'),
              for (final d in asJsonList(actor['department_admin'])) SettingsTile(label: l.pmActDeptAdmin, value: '${d['department']} · ${d['role']}'),
            ]),
            SettingsGroup(title: l.pmProject, children: [
              SettingsTile(label: l.title, value: '${project['title']}', onTap: () => context.pop()),
              SettingsTile(label: l.department, value: '${asJson(project['department'])['name'] ?? '—'}'),
              SettingsTile(label: l.pmLeader, value: '${asJson(project['leader'])['full_name'] ?? '—'}'),
            ]),
            if (task != null)
              SettingsGroup(title: l.pmTask, children: [
                SettingsTile(label: l.title, value: '${task['title']}', onTap: () => context.push('/projects/tasks/${task['id']}')),
                SettingsTile(label: l.status, value: taskStatusLabel(l, '${task['status']}') + ('${task['status_reason'] ?? ''}'.isEmpty ? '' : ' — ${task['status_reason']}')),
                SettingsTile(label: l.pmPriority, value: priorityLabel(l, '${task['priority']}')),
                SettingsTile(label: l.pmDeadline, value: task['deadline'] == null ? '—' : f.dateTime(asDate(task['deadline']))),
                SettingsTile(label: l.pmProgress, value: '${asIntOr(task['progress'])}%'),
                SettingsTile(label: l.pmAssignees, value: asJsonList(task['assignees']).map((u) => '${u['full_name']}').join(', ')),
                if (task['program'] != null) SettingsTile(label: l.pmActProgram, value: '${asJson(task['program'])['title']}', onTap: () => context.push('/programs/${asJson(task['program'])['id']}')),
                if ('${task['completion_note'] ?? ''}'.isNotEmpty) SettingsTile(label: l.pmCompletionNote, value: '${task['completion_note']}'),
              ]),
            if (issue != null)
              SettingsGroup(title: l.pmProblem, children: [
                SettingsTile(label: l.title, value: '${issue['title']}'),
                if ('${issue['description'] ?? ''}'.isNotEmpty) SettingsTile(label: l.description, value: '${issue['description']}'),
                SettingsTile(label: l.status, value: '${issue['status']}'),
                SettingsTile(label: l.pmReporter, value: '${asJson(issue['reporter'])['full_name'] ?? '—'}'),
                if (issue['assignee'] != null) SettingsTile(label: l.pmAssignees, value: '${asJson(issue['assignee'])['full_name']}'),
                if ('${issue['resolution'] ?? ''}'.isNotEmpty) SettingsTile(label: l.pmSolution, value: '${issue['resolution']}'),
              ]),
            if (changed.isNotEmpty || a['added'] != null || a['removed'] != null)
              SettingsGroup(title: l.pmChanges, children: [
                for (final k in changed)
                  ListTile(
                    dense: true,
                    title: Text(k.replaceAll('_', ' '), style: context.sans(13, weight: FontWeight.w600)),
                    subtitle: Text('${_value(before is Map ? before[k] : null)}  →  ${_value(after is Map ? after[k] : null)}'),
                  ),
                if (before is List || after is List) ListTile(dense: true, title: Text(l.pmAssignees), subtitle: Text('${_value(before)}  →  ${_value(after)}')),
                if (a['added'] != null) SettingsTile(label: l.pmAdded, value: _value(a['added'])),
                if (a['removed'] != null) SettingsTile(label: l.pmRemoved, value: _value(a['removed'])),
              ]),
            if (asJsonList(a['related_users']).isNotEmpty)
              SettingsGroup(title: l.pmRelatedPeople, children: [
                for (final u in asJsonList(a['related_users'])) SettingsTile(label: '${u['full_name']}', value: '${u['member_id'] ?? ''}'),
              ]),
            if (asJsonList(a['notifications']).isNotEmpty)
              SettingsGroup(title: l.pmNotificationsSent, children: [
                for (final n in asJsonList(a['notifications']))
                  ListTile(
                    dense: true,
                    leading: Icon(n['read'] == true ? Icons.mark_email_read_outlined : Icons.notifications_outlined, color: AppColors.gold),
                    title: Text('${asJson(n['user'])['full_name']}'),
                    subtitle: Text('${n['title']}\n${l.channelPush}: ${deliveryLabel(l, '${n['push']}')} · ${l.channelEmail}: ${deliveryLabel(l, '${n['email']}')}'),
                  ),
              ]),
            if (asJsonList(a['bot_messages']).isNotEmpty)
              SettingsGroup(title: l.pmBotMessages, children: [
                for (final m in asJsonList(a['bot_messages'])) ListTile(dense: true, leading: const Icon(Icons.smart_toy_outlined), title: Text('${m['body']}')),
              ]),
          ]);
        },
      ),
    );
  }
}
