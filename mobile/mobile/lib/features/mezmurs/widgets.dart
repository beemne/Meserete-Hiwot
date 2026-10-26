import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/content.dart';
import '../../repositories/providers.dart';
import '../../services/audio_player_service.dart';
import '../../services/download_service.dart';
import '../../models/admin.dart';
import '../../widgets/brand.dart';
import '../admin/content_admin.dart' show showCategoryEditor;
import '../admin/edit_mode.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../programs/program_text.dart';

/// Which tab a content screen was opened from ('/home' or '/library'), so nested links stay in that tab.
String contentBasePath(BuildContext context) {
  try {
    return GoRouterState.of(context).matchedLocation.startsWith('/library') ? '/library' : '/home';
  } catch (_) {
    return '/home';
  }
}

/// Animated equaliser glyph shown on the track that is currently playing.
class EqualizerIcon extends StatelessWidget {
  const EqualizerIcon({super.key, this.color = AppColors.goldLight});
  final Color color;
  @override
  Widget build(BuildContext context) => Icon(Icons.graphic_eq_rounded, color: color, size: 20);
}

/// A Mezmur row (category / search / favorites / home lists).
class MezmurTile extends ConsumerWidget {
  const MezmurTile({super.key, required this.mezmur, this.onTap, this.basePath = '/home', this.showCategory = true});
  final MezmurSummary mezmur;
  final VoidCallback? onTap;
  final String basePath;
  final bool showCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final playingId = ref.watch(audioProvider.select((s) => s.current?.id));
    final active = playingId == mezmur.id;
    final subtitle = showCategory && mezmur.categoryName != null ? l.mezmurResult(mezmur.categoryName!) : (mezmur.hasAudio ? l.mezmurLabel : l.lyricsOnly);
    return EditOverlay(
      permission: Perm.mezmursUpdate,
      onEdit: () => openAdminEditor(context, ref, '/admin/mezmurs/edit/${mezmur.id}'),
      child: TrackTile(
        title: mezmur.title,
        subtitle: subtitle,
        active: active,
        leading: active
            ? Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(12)),
                child: const EqualizerIcon(),
              )
            : ListThumb(icon: mezmur.hasAudio ? Icons.music_note_rounded : Icons.menu_book_rounded),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mezmur.audioDurationSec != null) Text(Formatters.durationSec(mezmur.audioDurationSec), style: context.sans(12, color: context.palette.subtle)),
            DownloadButton(mezmurId: mezmur.id, title: mezmur.title, hasAudio: mezmur.hasAudio),
          ],
        ),
        elevated: true,
        onTap: onTap ?? () => context.push('$basePath/mezmur/${mezmur.id}'),
      ),
    );
  }
}

/// Download state + action for one Mezmur.
class DownloadButton extends ConsumerWidget {
  const DownloadButton({super.key, required this.mezmurId, required this.title, required this.hasAudio, this.compact = true});
  final int mezmurId;
  final String title;
  final bool hasAudio;
  final bool compact;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    try {
      await ref.read(downloadsProvider.notifier).download(mezmurId, title: title, withAudio: true);
    } on WifiOnlyException {
      if (context.mounted) showSnack(context, l.wifiOnlyBlocked);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    // Lyrics are saved automatically — this button downloads the audio, so it only exists when there is audio.
    if (!hasAudio) return const SizedBox.shrink();
    final stored = ref.watch(downloadsProvider.select((m) => m[mezmurId]));
    final e = (stored != null && stored.isDone && !stored.withAudio) ? null : stored;
    Widget icon;
    VoidCallback? onTap;
    String tip;
    if (e == null) {
      icon = Icon(Icons.download_rounded, size: 19, color: p.faint);
      onTap = () => _start(context, ref);
      tip = l.downloadAudio;
    } else if (e.isActive) {
      icon = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, value: e.progress > 0 ? e.progress : null));
      tip = l.downloading;
    } else if (e.status == DownloadStatus.failed) {
      icon = const Icon(Icons.refresh_rounded, size: 19, color: AppColors.danger);
      onTap = () => ref.read(downloadsProvider.notifier).retry(mezmurId).catchError((Object err) {
        if (context.mounted) showErrorSnack(context, err);
      });
      tip = l.retryDownload;
    } else {
      icon = Icon(e.stale ? Icons.sync_problem_rounded : Icons.download_done_rounded, size: 19, color: AppColors.gold);
      onTap = () async {
        if (await showConfirm(context, l.confirmRemoveDownload, destructive: true)) {
          await ref.read(downloadsProvider.notifier).remove(mezmurId);
        }
      };
      tip = e.stale ? l.staleDownload : l.downloaded;
    }
    return IconButton(tooltip: tip, onPressed: onTap, icon: icon, visualDensity: VisualDensity.compact);
  }
}

/// Category card from the home design: text on the left, image on the right 45%.
class CategoryCard extends ConsumerWidget {
  const CategoryCard({super.key, required this.category, required this.onTap, this.height = 128});
  final CategoryNode category;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    return EditOverlay(
      permission: Perm.categoriesManage,
      onEdit: () async {
        await showCategoryEditor(context, existing: category);
        ref.read(contentRevisionProvider.notifier).bump();
      },
      child: AppCard(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.serif(17)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.music_note_rounded, size: 13, color: AppColors.gold),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    l.mezmurCount(category.totalMezmurCount),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.sans(12, color: p.muted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              l.open,
                              style: context.sans(12, weight: FontWeight.w600, color: AppColors.goldDark),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.goldDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: box.maxWidth * 0.45,
                  child: CoverImage(url: category.imageUrl),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Program card (home "upcoming programs" and the programs tab).
class ProgramCard extends ConsumerWidget {
  const ProgramCard({super.key, required this.program, required this.onTap});
  final Program program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    String? badge;
    Color? badgeColor;
    if (program.status == 'cancelled') {
      badge = l.programCancelled;
      badgeColor = AppColors.danger;
    } else if (program.myAttendance == 'present' || program.myAttendance == 'late') {
      badge = l.attPresent;
      badgeColor = AppColors.success;
    } else if (program.isSpecial) {
      badge = switch (program.eventType) {
        'wedding' => l.eventWedding,
        'holiday' => l.eventHoliday,
        'memorial' => l.eventMemorial,
        'celebration' => l.eventCelebration,
        _ => l.programSpecial.split(' — ').first,
      };
      badgeColor = AppColors.goldDark;
    }
    return EditOverlay(
      permission: Perm.programsManage,
      onEdit: () => openAdminEditor(context, ref, '/admin/programs/edit/${program.id}'),
      child: AppCard(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (badge != null || program.category != null) ...[
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          if (badge != null) Pill(badge, color: badgeColor),
                          if (program.category != null)
                            Pill(program.category!.label(Localizations.localeOf(context).languageCode), color: hexColor(program.category!.color)),
                        ]),
                        const SizedBox(height: 8),
                      ],
                      Text(program.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.serif(16)),
                      const SizedBox(height: 8),
                      _IconLine(icon: Icons.event_rounded, text: f.date(program.displayStart, withWeekday: true)),
                      const SizedBox(height: 3),
                      _IconLine(icon: Icons.schedule_rounded, text: '${f.time(program.displayStart)} – ${f.time(program.displayEnd)}'),
                      if (program.isRecurring) ...[const SizedBox(height: 3), _IconLine(icon: Icons.repeat_rounded, text: programRecurrenceText(context, program))],
                      if (program.location != null) ...[const SizedBox(height: 3), _IconLine(icon: Icons.place_outlined, text: program.location!)],
                      if (program.requiresRegistration && program.capacity != null) ...[
                        const SizedBox(height: 6),
                        Text(l.participantsCount(program.participantCount), style: context.sans(11, color: p.subtle)),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: CoverImage(url: program.imageUrl, placeholderIcon: Icons.event_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 14, color: AppColors.gold),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text, style: context.sans(12, color: context.palette.muted)),
      ),
    ],
  );
}

/// A small square card (cover, title, category) — three side by side on the Mezmur home.
class MezmurMiniCard extends StatelessWidget {
  const MezmurMiniCard({super.key, required this.mezmur});
  final MezmurSummary mezmur;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      key: ValueKey('mezmur-card-${mezmur.id}'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('${contentBasePath(context)}/mezmur/${mezmur.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(fit: StackFit.expand, children: [
            CoverImage(url: mezmur.coverUrl, radius: 14, placeholderIcon: Icons.music_note_rounded),
            if (mezmur.hasAudio)
              const Positioned(right: 6, bottom: 6, child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26, shadows: [Shadow(blurRadius: 6, color: Colors.black45)])),
          ]),
        ),
        const SizedBox(height: 6),
        Text(mezmur.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.serif(13, weight: FontWeight.w600, height: 1.3)),
        if (mezmur.categoryName != null) Text(mezmur.categoryName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(11, color: p.muted)),
      ]),
    );
  }
}

/// Every Mezmur, newest first or most popular first ("see all" on the Mezmur home).
class MezmurListScreen extends ConsumerWidget {
  const MezmurListScreen({super.key, this.sort = 'recent'});
  final String sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return PatternScaffold(
      appBar: AppBar(title: Text(sort == 'popular' ? l.popular : l.recentlyAdded)),
      body: PagedListView<MezmurSummary>(
        fetch: (page) => ref.read(contentRepositoryProvider).mezmurs(sort: sort, page: page),
        emptyMessage: l.noResults,
        itemBuilder: (context, m, _) => MezmurTile(mezmur: m),
      ),
    );
  }
}
