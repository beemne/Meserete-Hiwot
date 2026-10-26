import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/share_links.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../repositories/providers.dart';
import '../../services/program_alarms.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../admin/programs_admin.dart' show eventTypeLabel;
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';
import '../guidance/tour_engine.dart';
import '../settings/attendance_calendar.dart';
import 'program_text.dart';

final programProvider = FutureProvider.autoDispose.family<Program, int>((ref, id) => ref.watch(programRepositoryProvider).get(id));
final _myProgramAttendanceProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) => ref.watch(programRepositoryProvider).myProgramAttendance(id));

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});
  final int programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(programProvider(programId));
    return PatternScaffold(
      body: async.when(
        loading: () => const SafeArea(child: LoadingView()),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircleAction(icon: Icons.chevron_left_rounded, onTap: () => context.pop()),
                ),
              ),
              Expanded(
                child: ErrorView(error: e, onRetry: () => ref.invalidate(programProvider(programId))),
              ),
            ],
          ),
        ),
        data: (p) => _Body(program: p),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.program});
  final Program program;

  Future<void> _requestPermission(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final reason = await promptText(context, title: l.requestPermission, label: l.permissionReason, maxLines: 3);
    if (reason == null || !context.mounted) return;
    await runWithProgress(context, () async {
      await ref.read(programRepositoryProvider).requestPermission(program.id, reason: reason.trim().isEmpty ? null : reason.trim());
      ref.invalidate(programProvider(program.id));
    }, success: l.permissionRequested);
  }

  Future<void> _cancelPermission(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    if (!await showConfirm(context, '${l.cancelPermission}?') || !context.mounted) return;
    await runWithProgress(context, () async {
      await ref.read(programRepositoryProvider).cancelPermission(program.id);
      ref.invalidate(programProvider(program.id));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final top = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 230 + top,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(url: program.imageUrl, placeholderIcon: Icons.event_rounded),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x59280810), Color(0x00280810), Color(0xD1280810)],
                      stops: [0, 0.4, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: top + 12,
                  left: 12,
                  child: CircleAction(icon: Icons.chevron_left_rounded, onImage: true, onTap: () => context.pop()),
                ),
                Positioned(
                  top: top + 12,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAction(
                        icon: Icons.share_outlined,
                        onImage: true,
                        tooltip: context.l10n.share,
                        onTap: () => shareLink(kind: 'p', id: program.id, title: program.title, text: program.location),
                      ),
                      const SizedBox(width: 8),
                      const ContextualHelpButton(screenRoute: '/programs', color: Colors.white),
                    ],
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (program.status == 'cancelled') Pill(l.programCancelled, color: Colors.white, background: AppColors.danger),
                      if (program.status == 'completed') Pill(l.programCompleted),
                      if (program.isSpecial) Pill(eventTypeLabel(l, program.eventType), icon: Icons.celebration_rounded, color: Colors.white, background: AppColors.goldDark),
                      if (program.isMandatoryReminder) const Pill('አስገዳጅ ማንቂያ', icon: Icons.alarm_rounded, color: Colors.white, background: AppColors.maroon),
                      const SizedBox(height: 6),
                      Text(program.title, style: context.serif(24, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          sliver: SliverList.list(
            children: [
              SettingsGroup(
                children: [
                  if (program.category != null)
                    SettingsTile(icon: Icons.label_outline_rounded, label: l.programCategory, value: program.category!.label(Localizations.localeOf(context).languageCode)),
                  if (program.isRecurring) SettingsTile(icon: Icons.repeat_rounded, label: l.recurrence, value: programRecurrenceText(context, program)),
                  SettingsTile(
                    icon: Icons.event_rounded,
                    label: program.isRecurring ? l.nextOccurrenceLabel : l.date,
                    value: f.date(program.displayStart, withWeekday: true),
                  ),
                  SettingsTile(
                    icon: Icons.schedule_rounded,
                    label: l.time,
                    // A program without an end time shows its start only.
                    value: program.hasEndTime ? '${f.time(program.displayStart)} – ${f.time(program.displayEnd)}' : '${f.time(program.displayStart)} · ${l.noEndTime}',
                  ),
                  if (program.requiresAttendance && program.onTimeMinutes != null)
                    SettingsTile(
                      icon: Icons.how_to_reg_outlined,
                      label: l.attendanceWindow,
                      value: [
                        l.onTimeUntil(f.time(program.displayStart.add(Duration(minutes: program.onTimeMinutes!)))),
                        if (program.lateMinutes != null) l.lateUntil(f.time(program.displayStart.add(Duration(minutes: program.onTimeMinutes! + program.lateMinutes!)))),
                      ].join(' · '),
                    ),
                  if (program.location != null) SettingsTile(icon: Icons.place_outlined, label: l.location, value: program.location),
                  if (program.capacity != null)
                    SettingsTile(icon: Icons.groups_outlined, label: l.capacity(program.capacity!), value: l.participantsCount(program.participantCount)),
                  if (program.myAttendance != null)
                    SettingsTile(
                      icon: Icons.how_to_reg_rounded,
                      label: l.myAttendanceStatus,
                      value: switch (program.myAttendance) {
                        'present' => l.attPresent,
                        'late' => l.attLate,
                        'absent' => l.attAbsent,
                        _ => l.attExcused,
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (!program.isPast && program.status == 'published' && program.permission != null)
                _PermissionCard(
                  permission: program.permission!,
                  onRequest: () => _requestPermission(context, ref),
                  onCancel: () => _cancelPermission(context, ref),
                ),
              // Reminders are per program: 2 days / 1 day / 6 hours / 1 hour before, as alarms.
              if (!program.isPast && program.status == 'published' && ref.watch(currentUserProvider) != null) ...[
                const SizedBox(height: 10),
                _ProgramReminders(program: program),
              ],
              if (program.description != null && program.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(program.description!, style: context.sans(15, color: p.text, height: 1.7)),
              ],
              // Program ↔ attendance: my record at this program, and the roster for attendance admins.
              if (program.requiresAttendance) ...[
                const SizedBox(height: 18),
                _ProgramAttendance(programId: program.id),
              ],
              if (ref.watch(currentUserProvider)?.can(Perm.attendanceManage) ?? false) ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: Text(l.attendanceRoster),
                  onPressed: () => context.push('/admin/programs/${program.id}/attendance'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Absence permission: request / status / cancel, with the deadline and quota usage.
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.permission, required this.onRequest, required this.onCancel});
  final ProgramPermission permission;
  final VoidCallback onRequest;
  final VoidCallback onCancel;

  String? _blockedText(AppLocalizations l) => switch (permission.blockedReason) {
    'PERMISSION_DEADLINE_PASSED' => l.errPermissionDeadline,
    'PERMISSION_MONTHLY_LIMIT' => l.errPermissionMonthly,
    'PERMISSION_QUARTERLY_LIMIT' => l.errPermissionQuarterly,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final perm = permission;
    // Nothing to show for programs where permission does not apply and nothing was requested.
    if (!perm.enabled || (perm.status == null && !perm.canRequest && _blockedText(l) == null)) return const SizedBox.shrink();

    final (IconData icon, Color color, String? text) = switch (perm.status) {
      'pending' => (Icons.hourglass_top_rounded, AppColors.gold, l.permissionPending),
      'approved' => (Icons.verified_rounded, AppColors.success, l.permissionApproved),
      'rejected' => (Icons.block_rounded, AppColors.danger, l.permissionRejected),
      _ => (Icons.event_busy_rounded, p.muted, null),
    };
    final quota = [
      if (perm.monthlyLimit != null) l.permissionQuotaMonth(perm.monthUsed, perm.monthlyLimit!),
      if (perm.quarterlyLimit != null) l.permissionQuotaQuarter(perm.quarterUsed, perm.quarterlyLimit!),
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text ?? l.permissionTitle,
                  style: context.sans(14, weight: FontWeight.w600, color: text == null ? p.text : color),
                ),
              ),
            ],
          ),
          if (perm.reason != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(perm.reason!, style: context.sans(13, color: p.muted)),
            ),
          if (perm.reviewNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('— ${perm.reviewNote!}', style: context.sans(12, color: p.subtle)),
            ),
          if (perm.status == null && perm.deadlineAt != null && perm.canRequest)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.permissionDeadline(f.dateTime(perm.deadlineAt!)), style: context.sans(12, color: p.muted)),
            ),
          if (perm.status == null && _blockedText(l) != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_blockedText(l)!, style: context.sans(12, color: AppColors.danger)),
            ),
          if (quota.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(quota, style: context.sans(12, color: p.subtle)),
            ),
          if (perm.canRequest) ...[
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: onRequest, icon: const Icon(Icons.edit_calendar_rounded), label: Text(l.requestPermission)),
          ],
          // Only a pending request can be withdrawn; an approved one cannot be cancelled by the member.
          if (perm.canCancel && perm.status != 'approved') ...[const SizedBox(height: 10), OutlinedButton(onPressed: onCancel, child: Text(l.cancelPermission))],
        ],
      ),
    );
  }
}

/// My attendance at this program: totals and each date (a recurring program has many).
class _ProgramAttendance extends ConsumerWidget {
  const _ProgramAttendance({required this.programId});
  final int programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final data = ref.watch(_myProgramAttendanceProvider(programId)).value;
    if (data == null) return const SizedBox.shrink();
    final occ = asJsonList(data['occurrences']).where((o) => o['status'] != 'upcoming').take(8).toList();
    final stats = AttendanceStats.fromJson(asJson(data['stats']));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (stats.total > 0) AttendanceStatsCard(stats: stats),
      if (occ.isNotEmpty) ...[
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            for (final o in occ)
              Builder(builder: (context) {
                final st = attendanceStyle('${o['status']}');
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(radius: 14, backgroundColor: st.color, child: Icon(st.icon, size: 16, color: st.onColor)),
                  title: Text(f.date(asDate(o['starts_at']), withWeekday: true)),
                  trailing: Text(attendanceStateLabel(l, '${o['status']}'), style: context.sans(12, weight: FontWeight.w600)),
                );
              }),
          ]),
        ),
      ],
    ]);
  }
}

/// The member's reminders for this program: any of 2 days / 1 day / 6 hours / 1 hour before.
/// Saved on the server (so the server's reminder follows the same choice) and set as alarms on
/// this phone straight away.
class _ProgramReminders extends ConsumerStatefulWidget {
  const _ProgramReminders({required this.program});
  final Program program;
  @override
  ConsumerState<_ProgramReminders> createState() => _ProgramRemindersState();
}

class _ProgramRemindersState extends ConsumerState<_ProgramReminders> {
  bool _busy = false;

  Future<void> _save(List<int>? offsets) async {
    setState(() => _busy = true);
    try {
      await ref.read(programRepositoryProvider).setMyReminders(widget.program.id, offsets);
      ref.invalidate(programProvider(widget.program.id));
      await ref.read(programAlarmSyncProvider).run();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final program = widget.program;
    final own = program.myReminderOffsets != null;
    final current = program.effectiveReminderOffsets.toSet();
    return AppCard(
      key: TourKeys.programAlarm,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(current.isEmpty ? Icons.alarm_off_rounded : Icons.alarm_on_rounded, color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(l.myProgramReminders, style: context.sans(14, weight: FontWeight.w600))),
          if (_busy) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 4),
        Text(l.myProgramRemindersHint, style: context.sans(12, color: p.muted)),
        if (program.isMandatoryReminder) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.maroon.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.maroon.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.maroon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ለዚህ መርሐ ግብር ማንቂያ በአስተዳዳሪው አስገዳጅ ተደርጓል። ሙሉ ለሙሉ ማጥፋት አይቻልም።',
                    style: context.sans(12, color: AppColors.maroon, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final o in Program.reminderChoices)
            FilterChip(
              key: ValueKey('program-reminder-$o'),
              label: Text(remindBeforeText(l, o)),
              selected: current.contains(o),
              onSelected: _busy
                  ? null
                  : (on) {
                      final next = {...current};
                      if (on) {
                        next.add(o);
                      } else {
                        if (program.isMandatoryReminder && current.length <= 1) {
                          showErrorSnack(context, 'ይህ መርሐ ግብር አስገዳጅ ማንቂያ ስላለው ማንቂያውን ሙሉ ለሙሉ ማጥፋት አይቻልም');
                          return;
                        }
                        next.remove(o);
                      }
                      _save(next.toList()..sort((a, b) => b.compareTo(a)));
                    },
            ),
        ]),
        if (own)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _busy ? null : () => _save(null), child: Text(l.useProgramReminders)),
          ),
      ]),
    );
  }
}

