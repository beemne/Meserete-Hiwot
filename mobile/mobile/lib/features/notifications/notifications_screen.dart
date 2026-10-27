import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/deep_links.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../repositories/providers.dart';
import '../../services/local_notifications.dart';
import '../../services/unread_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';

/// In-app notification center.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _ctrl = PagedListController<AppNotification>();
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    // Seen here → no need to keep them in the phone's notification tray.
    ref.read(localNotificationsProvider).dismissAllMessages();
  }

  IconData _icon(String type) => switch (type) {
        'program' || 'program_reminder' => Icons.event_rounded,
        'borrowing' || 'borrowing_due' || 'borrowing_overdue' => Icons.inventory_2_outlined,
        'attendance' => Icons.how_to_reg_rounded,
        'mezmur' => Icons.music_note_rounded,
        'announcement' || 'advertisement' => Icons.campaign_outlined,
        'admin_message' => Icons.mail_outline_rounded,
        'chat' => Icons.forum_outlined,
        'project' => Icons.task_alt_rounded,
        _ => Icons.notifications_none_rounded,
      };

  Future<void> _open(AppNotification n) async {
    final repo = ref.read(notificationRepositoryProvider);
    if (!n.isRead) {
      _ctrl.updateWhere((x) => x.id == n.id, (x) => x.markRead());
      ref.read(unreadCountProvider.notifier).decrement();
      repo.markRead(n.id).catchError((_) {});
    }
    ref.read(localNotificationsProvider).dismissMessage(n.id);
    final effectiveType = (n.entityType != null && n.entityType!.isNotEmpty && n.entityType != 'education')
        ? n.entityType
        : n.type;
    final route = routeForEntity(effectiveType, n.entityId, data: n.data);
    if (route != '/notifications' && mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final repo = ref.read(notificationRepositoryProvider);
    return PatternScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
            child: ScreenTitle(
              l.notifications,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ContextualHelpButton(screenRoute: '/notifications'),
                  IconButton(
                    tooltip: l.markAllRead,
                    icon: Icon(Icons.done_all_rounded, color: p.primary),
                    onPressed: () async {
                      await runWithProgress(context, () async {
                        await repo.markAllRead();
                        await ref.read(localNotificationsProvider).dismissAllMessages();
                        ref.read(unreadCountProvider.notifier).set(0);
                        await _ctrl.refresh();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: FilterChip(
                label: Text(l.unreadOnly),
                selected: _unreadOnly,
                onSelected: (v) => setState(() => _unreadOnly = v),
              ),
            ),
          ),
          Expanded(
            child: PagedListView<AppNotification>(
              key: ValueKey(_unreadOnly),
              controller: _ctrl,
              fetch: (page) => repo.list(unreadOnly: _unreadOnly, page: page),
              emptyMessage: l.noNotifications,
              emptyIcon: Icons.notifications_off_outlined,
              onPageLoaded: (pg) => ref.read(unreadCountProvider.notifier).refresh(),
              itemBuilder: (context, n, _) => TrackTile(
                title: n.title,
                subtitle: n.body,
                selected: !n.isRead,
                leading: Stack(clipBehavior: Clip.none, children: [
                  ListThumb(icon: _icon(n.type), active: !n.isRead),
                  if (!n.isRead)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.gold, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
                    ),
                ]),
                trailing: Text(f.relative(n.createdAt), style: context.sans(11, color: p.subtle)),
                onTap: () => _open(n),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
