import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../services/sync_service.dart';
import '../services/sync_status.dart';
import 'brand.dart';

class SyncStatusSheet extends ConsumerStatefulWidget {
  const SyncStatusSheet({super.key});

  @override
  ConsumerState<SyncStatusSheet> createState() => _SyncStatusSheetState();
}

class _SyncStatusSheetState extends ConsumerState<SyncStatusSheet> {
  bool _syncing = false;

  String _opLabel(AppLocalizations l, String type) => switch (type) {
        SyncOp.attendanceRecord ||
        SyncOp.attendanceSessionStart ||
        SyncOp.attendanceSessionEnd ||
        SyncOp.attendanceSet ||
        SyncOp.attendanceClear ||
        SyncOp.attendanceBulk =>
          l.syncWhatAttendance,
        SyncOp.eduAttendanceSet || SyncOp.eduAttendanceScan => l.syncWhatClassAttendance,
        SyncOp.borrowingCreate => l.syncWhatBorrowing,
        SyncOp.borrowingReturn => l.syncWhatReturn,
        SyncOp.projectTaskUpdate => l.syncWhatTask,
        SyncOp.eduLessonComplete => l.syncWhatLesson,
        SyncOp.libraryCheckout || SyncOp.libraryReturn => l.syncWhatLibrary,
        SyncOp.reminderCreate || SyncOp.reminderUpdate || SyncOp.reminderDelete => l.syncWhatReminder,
        _ => type,
      };

  IconData _opIcon(String type) => switch (type) {
        SyncOp.attendanceRecord ||
        SyncOp.attendanceSessionStart ||
        SyncOp.attendanceSessionEnd ||
        SyncOp.attendanceSet ||
        SyncOp.attendanceClear ||
        SyncOp.attendanceBulk =>
          Icons.how_to_reg_rounded,
        SyncOp.eduAttendanceSet || SyncOp.eduAttendanceScan => Icons.school_rounded,
        SyncOp.borrowingCreate || SyncOp.borrowingReturn => Icons.inventory_2_outlined,
        SyncOp.projectTaskUpdate => Icons.task_alt_outlined,
        SyncOp.eduLessonComplete => Icons.menu_book_rounded,
        SyncOp.libraryCheckout || SyncOp.libraryReturn => Icons.local_library_rounded,
        SyncOp.reminderCreate || SyncOp.reminderUpdate || SyncOp.reminderDelete => Icons.alarm_rounded,
        _ => Icons.sync_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final lang = Localizations.localeOf(context).languageCode;
    final f = Formatters(l, lang);
    final status = ref.watch(syncStatusProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: p.faint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.sync_rounded, color: AppColors.maroon, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.syncStatusTitle, style: context.serif(18, color: p.text)),
              ),
              Pill(
                isOnline ? 'Online' : 'Offline',
                color: isOnline ? AppColors.success : AppColors.maroon,
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 16),
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      status.lastSuccessfulSync != null ? Icons.check_circle_outline_rounded : Icons.history_rounded,
                      size: 16,
                      color: p.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status.lastSuccessfulSync != null
                            ? '${l.lastSync}: ${f.date(status.lastSuccessfulSync!)} ${f.time(status.lastSuccessfulSync!)}'
                            : '${l.lastSync}: —',
                        style: context.sans(12, color: p.muted),
                      ),
                    ),
                  ],
                ),
                if (status.lastError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l.syncStatusLastError}: ${status.lastError}',
                            style: context.sans(12, color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status.pendingOps.isNotEmpty ? l.syncStatusPending(status.pendingOps.length) : l.syncStatusNoPending,
            style: context.sans(13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (status.pendingOps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(l.syncStatusNoPending, style: context.sans(13, color: p.muted)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: status.pendingOps.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final op = status.pendingOps[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: p.pill,
                      child: Icon(_opIcon(op.type), size: 16, color: AppColors.maroon),
                    ),
                    title: Text(_opLabel(l, op.type), style: context.sans(13, weight: FontWeight.w600)),
                    subtitle: Text(
                      l.syncStatusCaptured(f.time(op.clientTs)),
                      style: context.sans(11, color: p.muted),
                    ),
                    trailing: Pill(l.pendingSync, color: AppColors.goldDark),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            icon: _syncing || status.isFlushing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l.syncNow),
            onPressed: (!isOnline || _syncing || status.isFlushing)
                ? null
                : () async {
                    setState(() => _syncing = true);
                    try {
                      await ref.read(syncServiceProvider).flush();
                      await ref.read(syncStatusProvider.notifier).refresh();
                    } finally {
                      if (mounted) setState(() => _syncing = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
