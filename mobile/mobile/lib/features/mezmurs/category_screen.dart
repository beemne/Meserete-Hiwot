import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/share_links.dart';
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
import 'widgets.dart';

final categoryProvider = FutureProvider.autoDispose.family<CategoryNode, int>((ref, id) {
  ref.watch(contentRevisionProvider); // reload after an admin edits from the front
  return ref.watch(contentRepositoryProvider).category(id);
});

/// Category — design screen "02 Category": hero image with title, play-all + shuffle,
/// subcategories (any depth) and the track list.
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final int categoryId;
  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final _items = <MezmurSummary>[];
  int _page = 0;
  int _pages = 1;
  int _total = 0;
  bool _loading = false;
  Object? _error;
  final _scroll = ScrollController();

  void _reload() {
    setState(() {
      _items.clear();
      _page = 0;
      _pages = 1;
    });
    _more();
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _more();
    });
    _more();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || _page >= _pages) return;
    setState(() => _loading = true);
    try {
      final r = await ref.read(contentRepositoryProvider).categoryMezmurs(widget.categoryId, page: _page + 1);
      setState(() {
        _items.addAll(r.items);
        _page = r.page;
        _pages = r.pages;
        _total = r.total;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playAll({bool shuffle = false}) async {
    final withAudio = _items.where((m) => m.hasAudio).toList();
    if (withAudio.isEmpty) {
      showSnack(context, context.l10n.noAudio);
      return;
    }
    // The category in its folder order (subcategories included); list items carry their audio.
    final downloads = ref.read(downloadsProvider);
    final tracks = [for (final m in withAudio) ?PlayerTrack.fromSummary(m, offline: downloads[m.id])];
    if (tracks.isNotEmpty) await ref.read(audioProvider.notifier).playQueue(tracks, shuffle: shuffle);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cat = ref.watch(categoryProvider(widget.categoryId));
    ref.listen(contentRevisionProvider, (_, _) => _reload());
    final basePath = contentBasePath(context);
    final totalMinutes = _items.fold<int>(0, (s, m) => s + (m.audioDurationSec ?? 0)) ~/ 60;

    return PatternScaffold(
      floatingActionButton: EditModeAddButton(actions: [
        (label: l.addSubcategory, icon: Icons.subdirectory_arrow_right_rounded, permission: Perm.categoriesManage, run: () async {
          await showCategoryEditor(context, parentId: widget.categoryId);
          ref.read(contentRevisionProvider.notifier).bump();
        }),
        (label: l.newMezmur, icon: Icons.library_music_rounded, permission: Perm.mezmursCreate, run: () => openAdminEditor(context, ref, '/admin/mezmurs/edit/new?category=${widget.categoryId}')),
      ]),
      body: cat.when(
        loading: () => const SafeArea(child: LoadingView()),
        error: (e, _) => SafeArea(child: ErrorView(error: e, onRetry: () => ref.invalidate(categoryProvider(widget.categoryId)))),
        data: (c) => CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: _Hero(category: c, count: _total, minutes: totalMinutes)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _items.any((m) => m.hasAudio) ? _playAll : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(l.playAll),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAction(icon: Icons.shuffle_rounded, size: 48, tooltip: l.shuffle, onTap: _items.any((m) => m.hasAudio) ? () => _playAll(shuffle: true) : null),
                ]),
              ),
            ),
            if (c.children.isNotEmpty) ...[
              SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 18), sliver: SliverToBoxAdapter(child: SectionHeader(title: l.subcategories))),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList.separated(
                  itemCount: c.children.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => CategoryCard(
                    category: c.children[i],
                    height: 104,
                    onTap: () => context.push('$basePath/category/${c.children[i].id}'),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
              sliver: SliverList.builder(
                itemCount: _items.length + 1,
                itemBuilder: (context, i) {
                  if (i < _items.length) return MezmurTile(mezmur: _items[i], basePath: basePath, showCategory: false);
                  if (_error != null) return ErrorView(error: _error!, onRetry: _more);
                  if (_loading) return const LoadingView(padding: EdgeInsets.all(20));
                  if (_items.isEmpty && c.children.isEmpty) return EmptyView(message: l.noMezmursInCategory);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.category, required this.count, required this.minutes});
  final CategoryNode category;
  final int count;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 250 + top,
      child: Stack(fit: StackFit.expand, children: [
        CoverImage(url: category.imageUrl),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x59280810), Color(0x00280810), Color(0x00280810), Color(0xD1280810)],
              stops: [0, 0.35, 0.45, 1],
            ),
          ),
        ),
        Positioned(
          top: top + 12,
          left: 12,
          child: CircleAction(icon: Icons.chevron_left_rounded, onImage: true, tooltip: l.back, onTap: () => context.pop()),
        ),
        Positioned(
          top: top + 12,
          right: 12,
          child: CircleAction(
            icon: Icons.share_outlined,
            onImage: true,
            tooltip: l.share,
            onTap: () => shareLink(kind: 'c', id: category.id, title: category.name, text: category.description),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 16,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (category.breadcrumb.length > 1)
              Text(category.breadcrumb.take(category.breadcrumb.length - 1).map((b) => b.name).join(' › '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(11, color: Colors.white70)),
            Text(
              category.name,
              style: context.serif(26, color: Colors.white).copyWith(shadows: const [Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))]),
            ),
            const SizedBox(height: 4),
            Text(
              [l.mezmurCount(count), if (minutes > 0) l.minutesShort(minutes)].join(' · '),
              style: context.sans(12, color: AppColors.goldLight),
            ),
          ]),
        ),
      ]),
    );
  }
}
