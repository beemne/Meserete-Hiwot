import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/brand.dart';

/// Mini player from the home design: maroon card, gold progress line along the top,
/// round art, serif title, gold subtitle and a white play/pause glyph.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(audioProvider);
    final t = s.current;
    if (t == null) return const SizedBox.shrink();
    final pos = ref.watch(positionProvider).value ?? Duration.zero;
    final dur = ref.watch(durationProvider).value ?? (t.durationSec != null ? Duration(seconds: t.durationSec!) : null);
    final progress = dur == null || dur.inMilliseconds == 0 ? 0.0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: AppColors.maroon,
        borderRadius: BorderRadius.circular(14),
        elevation: 6,
        shadowColor: AppColors.maroon.withValues(alpha: 0.35),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/player'),
          child: Stack(children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(value: progress, minHeight: 3, color: AppColors.gold, backgroundColor: Colors.transparent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(children: [
                SizedBox(width: 38, height: 38, child: ClipOval(child: t.artUrl != null ? CoverImage(url: t.artUrl) : const AppLogo(size: 38, ring: false))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.serif(14, weight: FontWeight.w600, color: Colors.white)),
                    if (t.subtitle != null) Text(t.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(11, color: AppColors.goldLight)),
                  ]),
                ),
                IconButton(
                  tooltip: s.playing ? context.l10n.pause : context.l10n.play,
                  onPressed: () => ref.read(audioProvider.notifier).toggle(),
                  icon: s.buffering
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(s.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
                ),
                IconButton(
                  tooltip: context.l10n.closePlayer,
                  onPressed: () => ref.read(audioProvider.notifier).stop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
