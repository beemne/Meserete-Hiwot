import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/l10n/l10n.dart';
import '../core/providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../services/sync_service.dart';
import '../services/sync_status.dart';

/// Visible sync and connectivity indicator chip.
/// Communicates online/offline state, pending operations count, and provides manual refresh.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key, this.compact = true});
  final bool compact;

  static void showSyncSheet(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isEn = l.isEn;
    final status = ref.read(syncStatusProvider);
    final online = ref.read(isOnlineProvider);
    final timeStr = status.lastSuccessfulSync != null
        ? DateFormat('HH:mm').format(status.lastSuccessfulSync!.toLocal())
        : (isEn ? 'Not yet' : 'እስካሁን አልተመሳሰለም');

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    color: online ? AppColors.success : AppColors.warning,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          online
                              ? (isEn ? 'Connected (Online)' : 'መስመር ላይ (ኢንተርኔት አለ)')
                              : (isEn ? 'Offline Mode' : 'ከመስመር ውጭ (ያለ ኢንተርኔት)'),
                          style: ctx.serif(18, weight: FontWeight.w600),
                        ),
                        Text(
                          online
                              ? (isEn ? 'Last synchronized at $timeStr' : 'የመጨረሻው ማመሳሰል፦ $timeStr')
                              : (isEn ? 'Showing saved data on device' : 'በስልክዎ ላይ የተቀመጠውን መረጃ እያሳየ ነው'),
                          style: ctx.sans(12, color: ctx.palette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (status.pendingCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_problem_rounded, color: AppColors.gold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isEn
                              ? '${status.pendingCount} change(s) waiting to sync'
                              : '${status.pendingCount} ያልተላኩ ለውጦች ተራ እየጠበቁ ነው',
                          style: ctx.sans(13, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                icon: status.isFlushing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync_rounded),
                label: Text(isEn ? 'Synchronize Now' : 'አሁን አመሳስል'),
                onPressed: status.isFlushing || !online
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await ref.read(syncServiceProvider).flush();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final online = ref.watch(isOnlineProvider);

    if (online && status.pendingCount == 0 && !status.isFlushing) {
      return const SizedBox.shrink();
    }

    final color = !online
        ? AppColors.warning
        : status.isFlushing
            ? AppColors.gold
            : AppColors.gold;

    final icon = !online
        ? Icons.cloud_off_rounded
        : status.isFlushing
            ? Icons.sync_rounded
            : Icons.cloud_upload_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showSyncSheet(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              if (status.pendingCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${status.pendingCount}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
