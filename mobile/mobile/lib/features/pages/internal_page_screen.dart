import 'dart:async';

import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/share_links.dart';
import '../../core/utils/formatters.dart';
import '../../models/content.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';

final pageProvider = FutureProvider.autoDispose.family<PageContent, int>((ref, id) => ref.watch(contentRepositoryProvider).page(id));

/// Internal advertisement/event page opened from a banner. Content is plain text; the only
/// action is an internal call-to-action (open/register program, open Mezmur or category).
class InternalPageScreen extends ConsumerWidget {
  const InternalPageScreen({super.key, required this.pageId});
  final int pageId;

  Future<void> _cta(BuildContext context, WidgetRef ref, PageContent page) async {
    // Targets without an id first.
    switch (page.ctaAction) {
      case 'open_library':
        context.go('/edu/library');
        return;
      case 'open_url':
        final uri = Uri.tryParse(page.ctaUrl ?? '');
        if (uri != null && uri.scheme == 'https') unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        return;
    }
    final target = page.ctaTargetId ?? page.programId;
    if (target == null) return;
    switch (page.ctaAction) {
      case 'open_class':
        context.push('/edu/class/$target');
      // A course / an assignment opens its class (the assignment on the assignments tab).
      case 'open_course':
        if (page.ctaClassId != null) context.push('/edu/class/${page.ctaClassId}');
      case 'open_assignment':
        if (page.ctaClassId != null) context.push('/edu/class/${page.ctaClassId}?tab=assignments');
      case 'open_page':
        context.push('/home/page/$target');
      // Self-registration was removed; older "register" buttons now just open the program.
      case 'open_program':
      case 'register_program':
        context.go('/programs/$target');
      case 'open_mezmur':
        context.push('/home/mezmur/$target');
      case 'open_category':
        context.push('/home/category/$target');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(pageProvider(pageId));
    return PatternScaffold(
      body: async.when(
        loading: () => const SafeArea(child: LoadingView()),
        error: (e, _) => SafeArea(
          child: Column(children: [
            Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.all(12), child: CircleAction(icon: Icons.chevron_left_rounded, onTap: () => context.pop()))),
            Expanded(child: ErrorView(error: e, onRetry: () => ref.invalidate(pageProvider(pageId)))),
          ]),
        ),
        data: (page) {
          final f = Formatters(l, Localizations.localeOf(context).languageCode);
          final top = MediaQuery.paddingOf(context).top;
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240 + top,
                child: Stack(fit: StackFit.expand, children: [
                  CoverImage(url: page.coverUrl, placeholderIcon: Icons.campaign_outlined),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x59280810), Color(0x00280810), Color(0xD1280810)], stops: [0, 0.4, 1]),
                    ),
                  ),
                  Positioned(top: top + 12, left: 12, child: CircleAction(icon: Icons.chevron_left_rounded, onImage: true, onTap: () => context.pop())),
                  Positioned(
                    top: top + 12,
                    right: 12,
                    child: CircleAction(
                      icon: Icons.share_outlined,
                      onImage: true,
                      tooltip: context.l10n.share,
                      onTap: () => shareLink(kind: 'pg', id: page.id, title: page.title, text: page.summary),
                    ),
                  ),
                  Positioned(left: 18, right: 18, bottom: 16, child: Text(page.title, style: context.serif(24, color: Colors.white))),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              sliver: SliverList.list(children: [
                if (page.eventDate != null || page.location != null)
                  SettingsGroup(children: [
                    if (page.eventDate != null) SettingsTile(icon: Icons.event_rounded, label: l.eventDate, value: f.dateTime(page.eventDate)),
                    if (page.location != null) SettingsTile(icon: Icons.place_outlined, label: l.location, value: page.location),
                  ]),
                if (page.summary != null) ...[
                  const SizedBox(height: 16),
                  Text(page.summary!, style: context.serif(16, weight: FontWeight.w600, color: context.palette.text)),
                ],
                const SizedBox(height: 12),
                Text(page.content, style: context.sans(15, height: 1.75)),
                for (final img in page.images) ...[
                  const SizedBox(height: 14),
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 16 / 10, child: CoverImage(url: img.url))),
                  if (img.caption != null)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text(img.caption!, style: context.sans(12, color: context.palette.muted))),
                ],
                if (page.ctaAction != null && page.ctaAction != 'none') ...[
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => _cta(context, ref, page),
                    child: Text(page.ctaLabel ?? l.open),
                  ),
                ] else if (page.programId != null) ...[
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/programs/${page.programId}'),
                    icon: const Icon(Icons.event_rounded, color: AppColors.gold),
                    label: Text(page.programTitle ?? l.moreInfo),
                  ),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
