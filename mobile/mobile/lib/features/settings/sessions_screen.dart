import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../features/auth/session.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';
import 'account_screens.dart' show SubPage;

final _sessionsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(accountRepositoryProvider).sessions());

/// The account's sign-in sessions: sign one out, all the others, or everywhere. "Deleting" a
/// session revokes it — the account is never deleted.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final repo = ref.read(accountRepositoryProvider);
    final async = ref.watch(_sessionsProvider);
    return SubPage(
      title: l.sessTitle,
      actions: const [
        ContextualHelpButton(screenRoute: '/settings/sessions'),
      ],
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(_sessionsProvider),
        data: (list) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          Text(l.sessHint, style: context.sans(12, color: p.muted)),
          const SizedBox(height: 12),
          for (final s in list)
            Card(
              child: ListTile(
                leading: Icon(s['current'] == true ? Icons.smartphone_rounded : Icons.devices_other_rounded, color: s['current'] == true ? AppColors.gold : p.subtle),
                title: Text(s['current'] == true ? l.sessCurrent : (asStr(s['user_agent']) ?? asStr(s['device_id']) ?? '—'), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text([
                  if (asDate(s['signed_in_at']) != null) l.sessSignedIn(f.dateTime(asDate(s['signed_in_at'])!)),
                  if (asDate(s['last_active_at']) != null) l.sessLastActive(f.dateTime(asDate(s['last_active_at'])!)),
                  ?asStr(s['ip']),
                ].join('\n')),
                isThreeLine: true,
                trailing: s['current'] == true
                    ? null
                    : TextButton(
                        onPressed: () async {
                          final ok = await runWithProgress(context, () async {
                            await repo.revokeSession(asStr(s['id'])!);
                            return true;
                          }, success: l.saved);
                          if (ok == true) ref.invalidate(_sessionsProvider);
                        },
                        child: Text(l.sessRevoke),
                      ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: list.length < 2
                ? null
                : () async {
                    final n = await runWithProgress(context, repo.revokeOtherSessions);
                    if (n != null && context.mounted) {
                      showSnack(context, l.sessRevokedCount('$n'));
                      ref.invalidate(_sessionsProvider);
                    }
                  },
            icon: const Icon(Icons.logout_rounded),
            label: Text(l.sessRevokeOthers),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              if (!await showConfirm(context, l.sessRevokeAllConfirm, destructive: true) || !context.mounted) return;
              final ok = await runWithProgress(context, () async {
                await repo.revokeAllSessions();
                return true;
              });
              // This phone was signed out too: clear it like a normal sign-out.
              if (ok == true) await ref.read(sessionProvider.notifier).expire();
            },
            icon: const Icon(Icons.phonelink_erase_rounded),
            label: Text(l.sessRevokeAll),
          ),
        ]),
      ),
    );
  }
}
