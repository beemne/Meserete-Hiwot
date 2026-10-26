import 'youtube_view.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/share_links.dart';
import '../../models/content.dart';
import '../../repositories/providers.dart';
import '../../services/audio_player_service.dart';
import '../../services/download_service.dart';
import '../../services/favorites_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';
import '../player/player_parts.dart';
import 'widgets.dart';

/// Loads a Mezmur from the server, falling back to the offline copy (and noting offline access).
/// Every Mezmur opened online is also kept offline automatically (lyrics).
final mezmurProvider = FutureProvider.autoDispose.family<({Mezmur mezmur, bool offline}), int>((ref, id) async {
  final downloads = ref.read(downloadsProvider.notifier);
  final offline = downloads.entry(id);
  try {
    final m = await ref.watch(contentRepositoryProvider).mezmur(id);
    unawaited(downloads.cacheLyrics(m));
    unawaited(downloads.autoDownloadAudio(m));
    return (mezmur: m, offline: false);
  } on ApiException catch (e) {
    final local = offline?.toMezmur();
    if (e.isNetwork && local != null) {
      unawaited(ref.read(syncServiceProvider).trackActivity('offline_access', entityType: 'mezmur', entityId: id));
      return (mezmur: local, offline: true);
    }
    rethrow;
  }
});

/// Opening a Mezmur goes straight to its player: the cover (tap → lyrics), playback controls,
/// and favorite / download / share / related actions. Mezmurs without audio open on the lyrics.
/// With [followPlayer], the page follows the queue when the player moves to the next track.
class MezmurScreen extends ConsumerStatefulWidget {
  const MezmurScreen({super.key, required this.mezmurId, this.followPlayer = false});
  final int mezmurId;
  final bool followPlayer;
  @override
  ConsumerState<MezmurScreen> createState() => _MezmurScreenState();
}

class _MezmurScreenState extends ConsumerState<MezmurScreen> {
  late int _id = widget.mezmurId;
  final _autoplayed = <int>{};
  bool _forward = true;
  ({Mezmur mezmur, bool offline})? _cachedData;

  void _autoplay(Mezmur m) {
    if (!_autoplayed.add(m.id)) return;
    if (ref.read(audioProvider).current?.id == m.id) return; // already playing (e.g. from the queue)
    final downloads = ref.read(downloadsProvider);
    final t = PlayerTrack.fromMezmur(m, offline: downloads[m.id]);
    // The queue is this Mezmur's category (and its subcategories) in folder order: next / previous
    // stay inside the category and never jump to unrelated Mezmurs.
    if (t == null) return;
    final queue = [for (final r in m.queue) if (r.id == m.id) t else ?PlayerTrack.fromSummary(r, offline: downloads[r.id])];
    final start = queue.indexWhere((x) => x.id == m.id);
    if (start < 0) {
      unawaited(ref.read(audioProvider.notifier).playWithQueue(t, const []));
    } else {
      unawaited(ref.read(audioProvider.notifier).playInQueue(queue, start));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Follow next / previous in the queue while this page shows the playing Mezmur.
    ref.listen(audioProvider.select((s) => s.current?.id), (prev, next) {
      if (next != null && next != _id && (widget.followPlayer || prev == _id)) {
        final q = ref.read(audioProvider).queue;
        final pIdx = q.indexWhere((x) => x.id == _id);
        final nIdx = q.indexWhere((x) => x.id == next);
        setState(() {
          _forward = nIdx >= pIdx;
          _id = next;
        });
      }
    });
    final async = ref.watch(mezmurProvider(_id));
    if (async.hasValue) {
      _cachedData = async.value;
      if (_cachedData!.mezmur.hasAudio) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _autoplay(_cachedData!.mezmur));
      }
    }

    Widget content;
    if (_cachedData != null) {
      final r = _cachedData!;
      content = AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isCurrent = (child.key as ValueKey<int>?)?.value == r.mezmur.id;
          final begin = _forward
              ? (isCurrent ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0))
              : (isCurrent ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0));
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero).animate(animation),
            child: child,
          );
        },
        child: _PlayerPage(key: ValueKey(r.mezmur.id), mezmur: r.mezmur, offline: r.offline),
      );
    } else if (async.hasError) {
      content = SafeArea(
        child: Column(children: [
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.all(12), child: CircleAction(icon: Icons.chevron_left_rounded, onTap: () => context.pop()))),
          Expanded(child: ErrorView(error: async.error!, onRetry: () => ref.invalidate(mezmurProvider(_id)))),
        ]),
      );
    } else {
      content = const SafeArea(child: LoadingView());
    }

    return PatternScaffold(body: content);
  }
}

class _PlayerPage extends ConsumerWidget {
  const _PlayerPage({super.key, required this.mezmur, required this.offline});
  final Mezmur mezmur;
  final bool offline;

  void _related(BuildContext context) {
    final l = context.l10n;
    final basePath = contentBasePath(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text(l.relatedMezmurs, style: ctx.serif(19))),
            Flexible(
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
                for (final m in mezmur.related)
                  ListTile(
                    leading: SizedBox(width: 44, height: 44, child: CoverImage(url: m.coverUrl, radius: 10, placeholderIcon: Icons.music_note_rounded)),
                    title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: m.categoryName == null ? null : Text(m.categoryName!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Icon(m.hasAudio ? Icons.play_circle_outline_rounded : Icons.menu_book_rounded, color: AppColors.gold),
                    onTap: () {
                      Navigator.pop(ctx);
                      // Straight to that Mezmur's player, replacing this one.
                      context.pushReplacement('$basePath/mezmur/${m.id}');
                    },
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final scale = ref.watch(appSettingsProvider.select((s) => s.lyricsScale));
    final isFav = ref.watch(favoritesProvider.select((s) => s.contains(mezmur.id)));
    final entry = ref.watch(downloadsProvider.select((s) => s[mezmur.id]));
    final track = PlayerTrack.fromMezmur(mezmur, offline: entry);
    final basePath = contentBasePath(context);
    final settings = ref.read(appSettingsProvider.notifier);

    // Layout: the (softened) cover fills the page; in the middle the cover card flips to the lyrics;
    // a rounded panel at the bottom holds the seek bar and download · previous · play · next · favorite.
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final vx = details.primaryVelocity ?? 0.0;
        if (vx < -200) {
          ref.read(audioProvider.notifier).next();
        } else if (vx > 200) {
          ref.read(audioProvider.notifier).previous();
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Stack(fit: StackFit.expand, children: [
      PlayerBackdrop(artUrl: mezmur.summary.coverUrl, localArtPath: mezmur.localCoverPath),
      SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
            child: Row(children: [
              CircleAction(icon: Icons.chevron_left_rounded, tooltip: l.back, onTap: () => context.pop()),
              // X: close the player (stops playback and leaves the page).
              if (ref.watch(audioProvider.select((s) => s.hasTrack)))
                IconButton(
                  key: const ValueKey('player-close'),
                  tooltip: l.closePlayer,
                  icon: Icon(Icons.close_rounded, color: p.primary),
                  onPressed: () async {
                    await ref.read(audioProvider.notifier).stop();
                    if (context.mounted && context.canPop()) context.pop();
                  },
                ),
              const Spacer(),
              if (offline) Tooltip(message: l.offlineCopy, child: const Icon(Icons.offline_pin_rounded, color: AppColors.gold)),
              // Lyrics text size: ሀ− smaller, ሀ+ larger.
              _TextSizeButton(label: 'ሀ−', tooltip: '${l.fontSize} −', onTap: () => settings.setLyricsScale(scale - 0.1)),
              _TextSizeButton(label: 'ሀ+', tooltip: '${l.fontSize} +', onTap: () => settings.setLyricsScale(scale + 0.1)),
              IconButton(
                tooltip: l.share,
                icon: Icon(Icons.share_outlined, color: p.primary),
                // Link opens this Mezmur in the app; the sheet offers recent chats and chat apps.
                onPressed: () => shareLink(kind: 'm', id: mezmur.id, title: mezmur.title, text: mezmur.lyrics.trim().split('\n').take(4).join('\n')),
              ),
              ContextualHelpButton(screenRoute: '/home/mezmur', color: p.primary),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: p.primary),
                onSelected: (v) {
                  switch (v) {
                    case 'related':
                      _related(context);
                    case 'category':
                      context.push('$basePath/category/${mezmur.summary.categoryId}');
                    case 'youtube':
                      // Played inside the app (never sent to the YouTube app / browser).
                      openYoutubeInApp(context, mezmur.youtubeUrl!, title: mezmur.title);
                  }
                },
                itemBuilder: (_) => [
                  if (mezmur.related.isNotEmpty) PopupMenuItem(value: 'related', child: ListTile(leading: const Icon(Icons.queue_music_rounded), title: Text(l.relatedMezmurs))),
                  if (mezmur.summary.categoryId != null)
                    PopupMenuItem(value: 'category', child: ListTile(leading: const Icon(Icons.category_outlined), title: Text(mezmur.summary.categoryName ?? ''))),
                  if (mezmur.youtubeUrl != null)
                    PopupMenuItem(value: 'youtube', child: ListTile(leading: const Icon(Icons.smart_display_rounded, color: Color(0xFFD32F2F)), title: Text(l.watchOnYoutube))),
                ],
              ),
            ]),
          ),
          // No audio but a YouTube link: the video plays right here, above the lyrics.
          if (!mezmur.hasAudio && youtubeIdOf(mezmur.youtubeUrl) != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: InAppYoutube(key: ValueKey('yt-${mezmur.id}'), videoId: youtubeIdOf(mezmur.youtubeUrl)!),
            ),
          // Tap the image to flip to the lyrics; the lyrics side grows to the full height.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: CoverLyricsFlip(
                artUrl: mezmur.summary.coverUrl,
                localArtPath: mezmur.localCoverPath,
                startOnLyrics: !mezmur.hasAudio,
                lyrics: LyricsCard(text: mezmur.lyrics, scale: scale, lrc: mezmur.lrc, trackId: mezmur.id),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
            child: Column(children: [
              Text(mezmur.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.serif(21, height: 1.3)),
              if (mezmur.summary.categoryName != null)
                Padding(padding: const EdgeInsets.only(top: 2), child: Text(mezmur.summary.categoryName!, style: context.sans(12, color: p.muted))),
            ]),
          ),
          PlayerPanel(
            track: track,
            leading: mezmur.hasAudio ? DownloadButton(mezmurId: mezmur.id, title: mezmur.title, hasAudio: true, compact: false) : const SizedBox(width: 48),
            trailing: IconButton(
              tooltip: isFav ? l.removeFavorite : l.addFavorite,
              icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? AppColors.maroon : p.primary),
              onPressed: () async {
                final added = await ref.read(favoritesProvider.notifier).toggle(mezmur.summary);
                if (context.mounted) showSnack(context, added ? l.addedToFavorites : l.removedFromFavorites);
              },
            ),
          ),
        ]),
      ),
    ]),
  );
  }
}

/// "ሀ−" / "ሀ+" — the lyrics text size buttons on the player page.
class _TextSizeButton extends StatelessWidget {
  const _TextSizeButton({required this.label, required this.tooltip, required this.onTap});
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(label, style: context.serif(18, color: context.palette.primary, height: 1)),
          ),
        ),
      );
}
