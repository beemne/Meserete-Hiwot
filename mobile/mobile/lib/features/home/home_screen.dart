import 'dart:async';

import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/content.dart';
import '../../repositories/content_repository.dart';
import '../../repositories/providers.dart';
import '../../services/unread_service.dart';
import '../../models/admin.dart';
import '../../app/chrome.dart';
import '../../widgets/brand.dart';
import '../admin/content_admin.dart' show showCategoryEditor;
import '../admin/edit_mode.dart';
import '../../widgets/states.dart';
import '../mezmurs/widgets.dart';
import '../guidance/contextual_help_sheet.dart';
import '../sinksar/holy_day_banner.dart';

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) {
  ref.watch(
    contentRevisionProvider,
  ); // reload after an admin edits from the front
  return ref.watch(contentRepositoryProvider).home();
});

/// Home — design screen "01 Home": branded header with search, category cards, plus banners,
/// featured Mezmurs, upcoming programs and recent / popular lists.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final l = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/hub');
      },
      child: PatternScaffold(
      floatingActionButton: EditModeAddButton(
        actions: [
          (
            label: l.newCategory,
            icon: Icons.category_rounded,
            permission: Perm.categoriesManage,
            run: () async {
              await showCategoryEditor(context);
              ref.read(contentRevisionProvider.notifier).bump();
            },
          ),
          (
            label: l.newMezmur,
            icon: Icons.library_music_rounded,
            permission: Perm.mezmursCreate,
            run: () => openAdminEditor(context, ref, '/admin/mezmurs/edit/new'),
          ),
          (
            label: l.newProgram,
            icon: Icons.event_rounded,
            permission: Perm.programsManage,
            run: () =>
                openAdminEditor(context, ref, '/admin/programs/edit/new'),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(homeProvider);
            unawaited(ref.read(unreadCountProvider.notifier).refresh());
            await ref
                .read(homeProvider.future)
                .catchError((_) => HomeData.fromJson(const {}));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              const SliverToBoxAdapter(child: EditModeBanner()),
              ...home.when(
                data: (d) => _content(context, d),
                loading: () => [const SliverToBoxAdapter(child: LoadingView())],
                error: (e, _) => [
                  SliverToBoxAdapter(
                    child: ErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(homeProvider),
                    ),
                  ),
                ],
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    ),
    );
  }

  List<Widget> _content(BuildContext context, HomeData d) {
    final l = context.l10n;
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    const pad = EdgeInsets.symmetric(horizontal: 18);
    return [
      const SliverToBoxAdapter(child: HolyDayBanner()),
      if (d.todayCategories.isNotEmpty || d.todayMezmurs.isNotEmpty) ...[
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(child: SectionHeader(title: l.todayStudy)),
        ),
        SliverPadding(
          padding: pad,
          sliver: SliverList.list(
            children: [
              for (final c in d.todayCategories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CategoryCard(
                    category: c,
                    onTap: () => context.push('/home/category/${c.id}'),
                  ),
                ),
              for (final m in d.todayMezmurs) MezmurTile(mezmur: m),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
      if (d.banners.isNotEmpty)
        SliverToBoxAdapter(child: BannerCarousel(banners: d.banners)),
      if (d.featured.isNotEmpty) ...[
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(child: SectionHeader(title: l.featured)),
        ),
        SliverToBoxAdapter(child: _FeaturedStrip(items: d.featured)),
      ],
      SliverPadding(
        padding: pad,
        sliver: SliverToBoxAdapter(
          // Only the first three categories here; "see all" opens the full list.
          child: SectionHeader(
            title: l.categories,
            trailing: d.categories.length > 3 ? l.seeAll : l.categoriesCount(isAm ? ethiopicNumeral(d.categories.length) : '${d.categories.length}'),
            onTrailingTap: d.categories.length > 3 ? () => context.push('/home/categories') : null,
          ),
        ),
      ),
      if (d.categories.isEmpty)
        SliverToBoxAdapter(
          child: EmptyView(
            message: l.emptyCategories,
            icon: Icons.category_outlined,
          ),
        )
      else
        SliverPadding(
          padding: pad,
          sliver: SliverList.separated(
            itemCount: d.categories.take(3).length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final c = d.categories[i];
              return CategoryCard(
                category: c,
                onTap: () => context.push('/home/category/${c.id}'),
              );
            },
          ),
        ),
      if (d.categories.length > 3)
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                key: const ValueKey('home-see-all-categories'),
                icon: const Icon(Icons.grid_view_rounded),
                label: Text(l.seeAllCategories(isAm ? ethiopicNumeral(d.categories.length) : '${d.categories.length}')),
                onPressed: () => context.push('/home/categories'),
              ),
            ),
          ),
        ),
      if (d.upcomingPrograms.isNotEmpty) ...[
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: l.upcomingPrograms,
              trailing: l.seeAll,
              onTrailingTap: () => context.go('/programs'),
            ),
          ),
        ),
        SliverPadding(
          padding: pad,
          sliver: SliverList.separated(
            itemCount: d.upcomingPrograms.take(3).length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = d.upcomingPrograms[i];
              return ProgramCard(
                program: p,
                onTap: () => context.go('/programs/${p.id}'),
              );
            },
          ),
        ),
      ],
      // Recently added and popular: three cards each, "see all" opens the full list.
      for (final (key, title, list, sort) in [
        ('recent', l.recentlyAdded, d.recent, 'recent'),
        ('popular', l.popular, d.popular, 'popular'),
      ])
        if (list.isNotEmpty) ...[
          SliverPadding(
            padding: pad,
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                key: ValueKey('home-$key'),
                title: title,
                trailing: l.seeAll,
                onTrailingTap: () => context.push('/home/mezmurs?sort=$sort'),
              ),
            ),
          ),
          SliverPadding(
            padding: pad,
            sliver: SliverToBoxAdapter(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: i < list.length ? MezmurMiniCard(mezmur: list[i]) : const SizedBox.shrink()),
                ],
              ]),
            ),
          ),
        ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      // Logo, search and notifications live in the shared top bar; this is the section title.
      child: Row(
        children: [
          const KeberoIcon(size: 30, color: AppColors.maroon, filled: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.hubMezmur,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.serif(22, height: 1.25),
            ),
          ),
          const EditModeToggle(),
          const ContextualHelpButton(screenRoute: '/home'),
        ],
      ),
    );
  }
}

/// Advertisement / event banners. Taps open internal pages or programs only.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners});
  final List<Banner> banners;
  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

/// Endless carousel: every 5 seconds it slides forward to the next banner, and after the last one
/// comes the first again (no jump back). Swiping by hand restarts the 5-second wait.
class _BannerCarouselState extends State<BannerCarousel> {
  static const _interval = Duration(seconds: 5);
  // Start far into an unbounded page list so the user can also swipe backwards from the first banner.
  static const _startPage = 10000;

  late final PageController _ctrl = PageController(
    viewportFraction: 0.92,
    initialPage: _looping ? _startPage * widget.banners.length : 0,
  );
  int _page = 0;
  Timer? _timer;

  bool get _looping => widget.banners.length > 1;
  int get _index => _page % widget.banners.length;

  @override
  void initState() {
    super.initState();
    if (_looping) _page = _startPage * widget.banners.length;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_looping) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!_ctrl.hasClients || !mounted) return;
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _open(Banner b) {
    // Banners with files / links open a details sheet; plain ones go straight to their page or program.
    if (b.attachments.isNotEmpty) {
      showBannerDetails(context, b);
      return;
    }
    if (b.targetType == 'page' && b.targetId != null) {
      context.push('/home/page/${b.targetId}');
    }
    if (b.targetType == 'program' && b.targetId != null) {
      context.go('/programs/${b.targetId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (n) {
                if (n.dragDetails != null) _restartTimer(); // swiped by hand
                return false;
              },
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _looping
                    ? null
                    : widget.banners.length, // null = endless
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final b = widget.banners[i % widget.banners.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Material(
                        color: AppColors.maroon,
                        child: InkWell(
                          onTap: b.targetType == null && b.attachments.isEmpty
                              ? null
                              : () => _open(b),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CoverImage(
                                url: b.imageUrl,
                                placeholderIcon: Icons.campaign_outlined,
                              ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x00280810),
                                      Color(0xD1280810),
                                    ],
                                    stops: [0.35, 1],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 14,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.serif(
                                        18,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (b.shortDescription != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: Text(
                                          b.shortDescription!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.sans(
                                            12,
                                            color: AppColors.goldLight,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.banners.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.banners.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppColors.gold
                            : context.palette.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FeaturedStrip extends StatelessWidget {
  const _FeaturedStrip({required this.items});
  final List<MezmurSummary> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final m = items[i];
          return SizedBox(
            width: 138,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/home/mezmur/${m.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.maroon.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 138,
                      height: 138,
                      child: CoverImage(url: m.coverUrl, radius: 16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.serif(
                      13,
                      weight: FontWeight.w600,
                      color: context.palette.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Banner details: picture, text, the linked program / page, and its files and links.
void showBannerDetails(BuildContext context, Banner b) {
  final l = context.l10n;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          children: [
            if (b.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CoverImage(url: b.imageUrl),
                ),
              ),
            const SizedBox(height: 12),
            Text(b.title, style: ctx.serif(20)),
            if (b.shortDescription != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  b.shortDescription!,
                  style: ctx.sans(14, color: ctx.palette.muted),
                ),
              ),
            if (b.targetType != null && b.targetId != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: Icon(
                  b.targetType == 'program'
                      ? Icons.event_rounded
                      : Icons.article_rounded,
                ),
                label: Text(l.open),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (b.targetType == 'page') {
                    context.push('/home/page/${b.targetId}');
                  }
                  if (b.targetType == 'program') {
                    context.go('/programs/${b.targetId}');
                  }
                },
              ),
            ],
            const SizedBox(height: 8),
            for (final a in b.attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  a.kind == 'link'
                      ? Icons.link_rounded
                      : (a.isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded),
                  color: AppColors.gold,
                ),
                title: Text(
                  a.title ?? (a.kind == 'link' ? a.url : l.open),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => launchUrl(
                  Uri.parse(a.url),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
