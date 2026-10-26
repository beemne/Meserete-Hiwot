import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import 'admin_widgets.dart';

final _overviewProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(adminRepositoryProvider).systemOverview());

/// Internal system-authority console. Only reachable with a system-scope session;
/// the API answers 404 to everyone else. Regular admin screens remain available too
/// (with hidden entries visible to this account only).
class SystemConsoleScreen extends ConsumerWidget {
  const SystemConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final repo = ref.read(adminRepositoryProvider);
    return AdminScaffold(
      title: l.systemConsole,
      actions: [IconButton(icon: const Icon(Icons.admin_panel_settings_outlined), tooltip: l.adminPanel, onPressed: () => context.push('/admin'))],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        AsyncView(
          value: ref.watch(_overviewProvider),
          onRetry: () => ref.invalidate(_overviewProvider),
          data: (o) {
            final audit = asJson(o['audit_30d']);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                childAspectRatio: 1.05,
                children: [
                  StatTile(label: l.visibleEntries, value: '${asIntOr(audit['visible'])}', icon: Icons.visibility_outlined),
                  StatTile(label: l.hiddenEntries, value: '${asIntOr(audit['hidden'])}', icon: Icons.visibility_off_outlined),
                  StatTile(label: l.deniedAttempts, value: '${asIntOr(o['denied_attempts_7d'])}', icon: Icons.block_rounded, highlight: asIntOr(o['denied_attempts_7d']) > 0),
                ],
              ),
              SectionHeader(title: l.adminsByRole),
              SettingsGroup(children: [
                for (final r in asJsonList(o['admins_by_role'])) SettingsTile(label: '${r['name']} (${l.level} ${r['level']})', value: '${r['count']}'),
              ]),
            ]);
          },
        ),
        SectionHeader(title: l.allAdmins),
        SizedBox(
          height: 480,
          child: PagedListView<Json>(
            padding: EdgeInsets.zero,
            fetch: (page) => repo.systemAdmins(page: page),
            emptyMessage: l.noResults,
            itemBuilder: (context, a, _) => TrackTile(
              title: '${a['full_name']}',
              subtitle: '${a['role_name']} · ${a['phone']} · ${f.relative(asDate(a['last_login_at']))}',
              leading: ListThumb(icon: asBool(a['is_hidden']) ? Icons.shield_rounded : Icons.admin_panel_settings_outlined, active: asBool(a['is_hidden'])),
              trailing: IconButton(
                tooltip: l.forceLogout,
                icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                onPressed: () async {
                  if (!await showConfirm(context, l.forceLogoutConfirm, destructive: true) || !context.mounted) return;
                  await runWithProgress(context, () => repo.systemForceLogout(asIntOr(a['id'])), success: l.done);
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
