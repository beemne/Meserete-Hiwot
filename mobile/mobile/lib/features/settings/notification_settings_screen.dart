import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';
import 'account_screens.dart' show SubPage;

final _notificationPrefsProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(accountRepositoryProvider).notificationPreferences());

String notificationTopicLabel(AppLocalizations l, String t) => switch (t) {
      'program' => l.topicProgram,
      'attendance' => l.topicAttendance,
      'project' => l.topicProject,
      'department' => l.topicDepartment,
      'education' => l.topicEducation,
      'property' => l.topicProperty,
      'mezmur' => l.topicMezmur,
      'sinksar' => l.isEn ? 'Daily Sinksar' : 'የዕለቱ ስንክሳር',
      _ => l.topicSystem,
    };

IconData notificationTopicIcon(String t) => switch (t) {
      'program' => Icons.event_rounded,
      'attendance' => Icons.how_to_reg_rounded,
      'project' => Icons.task_alt_rounded,
      'department' => Icons.groups_rounded,
      'education' => Icons.school_rounded,
      'property' => Icons.inventory_2_outlined,
      'mezmur' => Icons.library_music_rounded,
      'sinksar' => Icons.auto_stories_rounded,
      _ => Icons.admin_panel_settings_outlined,
    };

/// Which notifications reach this member, per topic and channel (push / email). Every
/// notification is still kept in the app's notification list; administrative messages are always
/// delivered. The server enforces these choices.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    Future<void> save(Json body) async {
      final r = await runWithProgress(context, () => ref.read(accountRepositoryProvider).updateNotificationPreferences(body));
      if (r != null) ref.invalidate(_notificationPrefsProvider);
    }

    return SubPage(
      title: l.notificationSettings,
      actions: const [
        ContextualHelpButton(screenRoute: '/settings/notifications'),
      ],
      body: AsyncView<Json>(
        value: ref.watch(_notificationPrefsProvider),
        onRetry: () => ref.invalidate(_notificationPrefsProvider),
        data: (d) {
          final emailPossible = d['has_email'] == true && d['email_available'] == true;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            Text(l.notificationSettingsHint, style: context.sans(12, color: p.muted)),
            SettingsGroup(children: [
              SettingsTile(icon: Icons.notifications_active_outlined, label: l.notificationsAll, switchValue: d['enabled'] != false, onSwitch: (v) => save({'enabled': v})),
            ]),
            if (d['has_email'] != true)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text(l.noEmailForNotifications, style: context.sans(12, color: p.muted))),
            const SizedBox(height: 6),
            for (final t in asJsonList(d['topics']))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppCard(
                  key: ValueKey('topic-${t['topic']}'),
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(notificationTopicIcon('${t['topic']}'), color: p.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(notificationTopicLabel(l, '${t['topic']}'), style: context.sans(14, weight: FontWeight.w700))),
                      if (t['mandatory'] == true) Pill(l.isEn ? 'Mandatory' : 'ግዴታ', icon: Icons.lock_outline_rounded, color: AppColors.goldDark),
                    ]),
                    if (t['mandatory'] == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.isEn ? 'Mandatory church operational category (always active)' : 'የአገልግሎት ግዴታ (ሁልጊዜ ንቁ)',
                              style: context.sans(12.5, color: p.muted),
                            ),
                          ),
                        ]),
                      )
                    else ...[
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.channelPush),
                        value: t['push'] == true && d['enabled'] != false,
                        onChanged: d['enabled'] == false ? null : (v) => save({'topics': [{'topic': t['topic'], 'push': v}]}),
                      ),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.channelEmail),
                        value: emailPossible && t['email'] == true && d['enabled'] != false,
                        onChanged: !emailPossible || d['enabled'] == false ? null : (v) => save({'topics': [{'topic': t['topic'], 'email': v}]}),
                      ),
                    ],
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
