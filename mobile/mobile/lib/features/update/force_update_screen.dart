import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/update_service.dart';
import '../../widgets/brand.dart';

/// Shown instead of the app when the installed version is no longer supported.
/// "Update now" opens the download page (served by the backend) in the browser.
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final info = ref.watch(updateProvider);
    final p = context.palette;
    return PopScope(
      canPop: false,
      child: PatternScaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: AppLogo(size: 104)),
                  const SizedBox(height: 18),
                  Text(l.appName, textAlign: TextAlign.center, style: context.serif(24)),
                  const SizedBox(height: 22),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        const Icon(Icons.system_update_rounded, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l.updateRequiredTitle, style: context.serif(19))),
                      ]),
                      const SizedBox(height: 10),
                      Text(l.updateRequiredBody(info?.latestName ?? ''), style: context.sans(14, height: 1.6)),
                      if (info?.notes != null && info!.notes!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(12)),
                          child: Text(info.notes!, style: context.sans(13, color: p.muted, height: 1.6)),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text('${l.version}: ${info?.currentName ?? ''} → ${info?.latestName ?? ''}', style: context.sans(12, color: p.subtle)),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => ref.read(updateProvider.notifier).openDownloadPage(),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(l.updateNow),
                      ),
                      TextButton(onPressed: () => ref.read(updateProvider.notifier).check(), child: Text(l.checkAgain)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
