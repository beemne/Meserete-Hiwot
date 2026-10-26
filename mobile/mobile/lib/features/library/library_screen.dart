import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/content.dart';
import '../../services/download_service.dart';
import '../../services/favorites_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';
import '../guidance/tour_engine.dart';
import '../mezmurs/widgets.dart';

/// "የእኔ" tab: favorites and offline downloads.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: PatternScaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: ScreenTitle(
                l.navLibrary,
                trailing: const ContextualHelpButton(screenRoute: '/library'),
              ),
            ),
            TabBar(tabs: [
              Tab(key: TourKeys.libraryFavoritesTab, text: l.favorites),
              Tab(key: TourKeys.libraryDownloadsTab, text: l.downloads),
            ]),
            const Expanded(child: TabBarView(children: [_FavoritesTab(), _DownloadsTab()])),
          ]),
        ),
      ),
    );
  }
}

final _favoritesListProvider = FutureProvider.autoDispose<List<MezmurSummary>>((ref) async {
  ref.watch(favoritesProvider); // refresh when favorites change
  final ctrl = ref.read(favoritesProvider.notifier);
  try {
    final r = await ref.read(apiClientProvider).getPage('/favorites', MezmurSummary.fromJson, limit: 100);
    return r.items;
  } on ApiException catch (e) {
    if (e.isNetwork) return ctrl.offlineList();
    rethrow;
  }
});

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final list = ref.watch(_favoritesListProvider);
    final favIds = ref.watch(favoritesProvider);
    return AsyncView(
      value: list,
      onRetry: () => ref.invalidate(_favoritesListProvider),
      data: (items) {
        final visible = items.where((m) => favIds.contains(m.id)).toList();
        if (visible.isEmpty) return EmptyView(message: l.noFavorites, icon: Icons.favorite_border_rounded);
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            await ref.read(favoritesProvider.notifier).pull().catchError((_) {});
            ref.invalidate(_favoritesListProvider);
          },
          child: ListView(padding: const EdgeInsets.fromLTRB(10, 8, 10, 24), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(downloadsProvider.notifier).downloadAll(visible, withAudio: true);
                  } on WifiOnlyException {
                    if (context.mounted) showSnack(context, l.wifiOnlyBlocked);
                  }
                },
                icon: const Icon(Icons.download_for_offline_outlined),
                label: Text(l.downloadAllFavorites),
              ),
            ),
            for (final m in visible) MezmurTile(mezmur: m, basePath: '/library'),
          ]),
        );
      },
    );
  }
}

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    // Lyrics are stored automatically for every Mezmur; this list shows the audio the user downloaded.
    final entries = ref.watch(downloadsProvider).values.where((e) => e.withAudio || e.isActive || e.status == DownloadStatus.failed).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    final bytes = ref.read(downloadsProvider.notifier).totalBytes;
    if (entries.isEmpty) return EmptyView(message: l.noDownloads, icon: Icons.download_for_offline_outlined);
    return ListView(padding: const EdgeInsets.fromLTRB(10, 12, 10, 24), children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.sd_storage_outlined, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(l.storageUsed(Formatters.fileSize(bytes)), style: context.sans(13))),
            TextButton(
              onPressed: () async {
                if (await showConfirm(context, l.confirmRemoveAllDownloads, destructive: true)) {
                  await ref.read(downloadsProvider.notifier).removeAll();
                }
              },
              child: Text(l.removeAllDownloads, style: const TextStyle(color: AppColors.danger)),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      for (final e in entries)
        TrackTile(
          title: e.title,
          subtitle: switch (e.status) {
            DownloadStatus.done => [
                if (e.categoryName != null) e.categoryName!,
                e.withAudio ? l.downloadWithAudio : l.lyricsOnly,
                Formatters.fileSize(e.sizeBytes),
                if (e.stale) l.staleDownload,
              ].join(' · '),
            DownloadStatus.failed => l.downloadFailed,
            DownloadStatus.queued => l.downloadQueued,
            DownloadStatus.downloading => '${l.downloading} ${(e.progress * 100).round()}%',
          },
          leading: ListThumb(icon: e.withAudio ? Icons.headphones_rounded : Icons.menu_book_rounded),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (e.status == DownloadStatus.failed || e.stale)
              IconButton(
                tooltip: l.retryDownload,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
                onPressed: () => ref.read(downloadsProvider.notifier).retry(e.id).catchError((Object err) {
                  if (context.mounted) showErrorSnack(context, err);
                }),
              ),
            if (e.isActive)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, value: e.progress > 0 ? e.progress : null))
            else
              IconButton(
                tooltip: l.removeDownload,
                icon: Icon(Icons.delete_outline_rounded, color: p.faint),
                onPressed: () async {
                  if (await showConfirm(context, l.confirmRemoveDownload, destructive: true)) {
                    await ref.read(downloadsProvider.notifier).remove(e.id);
                  }
                },
              ),
          ]),
          onTap: e.isDone ? () => context.push('/library/mezmur/${e.id}') : null,
        ),
    ]);
  }
}
