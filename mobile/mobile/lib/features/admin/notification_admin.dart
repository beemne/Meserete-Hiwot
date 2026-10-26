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
import 'admin_widgets.dart';

final _broadcastProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) => ref.watch(adminRepositoryProvider).broadcast(id));
final _healthProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(adminRepositoryProvider).notificationHealth());

/// pending / sent / failed / skipped / none — the state of one delivery channel.
String deliveryLabel(AppLocalizations l, String? s) => switch (s) {
      'sent' => l.deliverySent,
      'failed' => l.deliveryFailed,
      'skipped' => l.deliverySkipped,
      'pending' => l.deliveryPending,
      _ => l.deliveryNone,
    };

Color deliveryColor(String? s) => switch (s) {
      'sent' => AppColors.success,
      'failed' => AppColors.danger,
      'pending' => AppColors.goldDark,
      _ => Colors.grey,
    };

String _counts(AppLocalizations l, Json m) {
  final parts = [for (final e in m.entries) if (asIntOr(e.value) > 0) '${deliveryLabel(l, e.key)} ${asIntOr(e.value)}'];
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// One sent notification: its text, who sent it to whom, delivery per channel (push / email),
/// who read it, and its resends. "Resend" opens the composer with the text to edit and new
/// receivers; it creates a NEW notification and leaves this one (and its history) unchanged.
class BroadcastDetailScreen extends ConsumerWidget {
  const BroadcastDetailScreen({super.key, required this.broadcastId});
  final int broadcastId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final value = ref.watch(_broadcastProvider(broadcastId));
    return AdminScaffold(
      title: l.notificationDetails,
      body: AsyncView<Json>(
        value: value,
        onRetry: () => ref.invalidate(_broadcastProvider(broadcastId)),
        data: (b) {
          final channels = asJsonList(b['channels']).map((e) => '$e').toList();
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b['title']}', style: context.serif(18)),
                const SizedBox(height: 8),
                SelectableText('${b['body']}', style: context.sans(14)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill(l.channelPush, icon: Icons.notifications_active_outlined),
                  if (channels.contains('email')) Pill(l.channelEmail, icon: Icons.alternate_email_rounded),
                  if (b['resent_from_id'] != null) Pill(l.resentFrom('${b['resent_from_id']}'), icon: Icons.replay_rounded),
                ]),
              ]),
            ),
            SettingsGroup(title: l.details, children: [
              SettingsTile(label: l.sender, value: '${b['sender_name'] ?? '—'}'),
              SettingsTile(label: l.sentAt, value: f.dateTime(asDate(b['created_at']))),
              SettingsTile(label: l.recipients, value: '${asIntOr(b['recipient_count'])}'),
              SettingsTile(label: l.readCount, value: '${asIntOr(b['read'])}'),
              SettingsTile(label: l.channelPush, value: _counts(l, asJson(b['push']))),
              if (channels.contains('email')) SettingsTile(label: l.channelEmail, value: _counts(l, asJson(b['email']))),
            ]),
            if (asJsonList(b['resends']).isNotEmpty)
              SettingsGroup(title: l.resends, children: [
                for (final r in asJsonList(b['resends']))
                  SettingsTile(
                    icon: Icons.replay_rounded,
                    label: '${r['title']}',
                    value: '${f.dateTime(asDate(r['created_at']))} · ${asIntOr(r['recipient_count'])}',
                    onTap: () => context.push('/admin/notify/${r['id']}'),
                  ),
              ]),
            SettingsGroup(title: l.recipients, children: [
              for (final r in asJsonList(b['recipients']))
                ListTile(
                  dense: true,
                  title: Text('${r['full_name']}'),
                  subtitle: Text([if (r['member_id'] != null) '${r['member_id']}', if (r['read_at'] != null) l.readAt(f.dateTime(asDate(r['read_at'])))].join(' · ')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Tooltip(message: '${l.channelPush}: ${deliveryLabel(l, '${r['push']}')}', child: Icon(Icons.notifications_rounded, size: 18, color: deliveryColor('${r['push']}'))),
                    if (channels.contains('email')) ...[
                      const SizedBox(width: 6),
                      Tooltip(message: '${l.channelEmail}: ${deliveryLabel(l, '${r['email']}')}', child: Icon(Icons.mail_rounded, size: 18, color: deliveryColor('${r['email']}'))),
                    ],
                  ]),
                ),
            ]),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('resend-notification'),
              icon: const Icon(Icons.replay_rounded),
              label: Text(l.resendNotification),
              onPressed: () async {
                final sent = await context.push<bool>('/admin/notify', extra: b);
                if (sent == true && context.mounted) {
                  ref.invalidate(_broadcastProvider(broadcastId));
                  context.pop(true);
                }
              },
            ),
          ]);
        },
      ),
    );
  }
}

/// Where the automatic notification chain stands: push / email results of the last 7 days,
/// whether Firebase and email are configured, registered devices and the background jobs that
/// deliver reminders (no cron — they run after requests).
class NotificationHealthScreen extends ConsumerWidget {
  const NotificationHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.notificationHealth,
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_healthProvider))],
      body: AsyncView<Json>(
        value: ref.watch(_healthProvider),
        onRetry: () => ref.invalidate(_healthProvider),
        data: (h) {
          final fcm = asJson(h['fcm']);
          Widget ok(bool v) => Icon(v ? Icons.check_circle_rounded : Icons.cancel_rounded, color: v ? AppColors.success : AppColors.danger, size: 20);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            SettingsGroup(title: l.providers, children: [
              ListTile(leading: ok(fcm['ready'] == true), title: Text(l.fcmReady), subtitle: fcm['error'] == null ? null : Text('${fcm['error']}')),
              ListTile(leading: ok(h['email_configured'] == true), title: Text(l.emailConfigured)),
              ListTile(leading: ok(h['jobs_enabled'] == true), title: Text(l.backgroundJobs)),
              SettingsTile(label: l.registeredDevices, value: '${asIntOr(h['devices'])}'),
            ]),
            SettingsGroup(title: l.last7Days, children: [
              SettingsTile(label: l.channelPush, value: _counts(l, asJson(h['push']))),
              SettingsTile(label: l.channelEmail, value: _counts(l, asJson(h['email']))),
              SettingsTile(label: l.oldestPending, value: h['oldest_pending'] == null ? '—' : f.dateTime(asDate(h['oldest_pending']))),
              SettingsTile(label: l.scheduledReminders, value: '${asIntOr(h['scheduled_pending'])}'),
            ]),
            SettingsGroup(title: l.backgroundJobs, children: [
              for (final j in asJsonList(h['jobs']))
                SettingsTile(label: '${j['name']}', value: j['last_run_at'] == null ? '—' : f.relative(asDate(j['last_run_at']))),
            ]),
          ]);
        },
      ),
    );
  }
}
