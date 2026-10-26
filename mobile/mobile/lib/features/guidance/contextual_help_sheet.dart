import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/guidance.dart';
import '../../repositories/guidance_repository.dart';
import 'guidance_navigator.dart';
import 'tour_engine.dart';

/// Reusable contextual help icon button for AppBars across screens.
class ContextualHelpButton extends ConsumerWidget {
  const ContextualHelpButton({
    super.key,
    required this.screenRoute,
    this.title,
    this.tourId,
    this.color,
  });

  final String screenRoute;
  final String? title;
  final String? tourId;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return IconButton(
      icon: Icon(Icons.help_outline_rounded, color: color),
      tooltip: isEn ? 'Help & Guidance' : 'መመሪያ እና እገዛ',
      onPressed: () => showContextualHelp(
        context,
        ref,
        screenRoute: screenRoute,
        title: title,
        tourId: tourId,
      ),
    );
  }
}

/// Show bottom sheet with contextual guidance for the current screen.
Future<void> showContextualHelp(
  BuildContext context,
  WidgetRef ref, {
  required String screenRoute,
  String? title,
  String? tourId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => ContextualHelpSheet(
      screenRoute: screenRoute,
      fallbackTitle: title,
      explicitTourId: tourId,
    ),
  );
}

class ContextualHelpSheet extends ConsumerWidget {
  const ContextualHelpSheet({
    super.key,
    required this.screenRoute,
    this.fallbackTitle,
    this.explicitTourId,
  });

  final String screenRoute;
  final String? fallbackTitle;
  final String? explicitTourId;

  static String _categoryLabel(String cat, bool isEn) {
    switch (cat.toLowerCase()) {
      case 'getting_started':
        return isEn ? 'Getting Started' : 'መግቢያ';
      case 'mezmurs':
        return isEn ? 'Mezmurs' : 'መዝሙራት';
      case 'programs':
        return isEn ? 'Programs' : 'መርሐ ግብሮች';
      case 'attendance':
        return isEn ? 'Attendance' : 'አቴንዳንስ';
      case 'education':
        return isEn ? 'Education' : 'ትምህርት';
      case 'projects':
        return isEn ? 'Projects' : 'ፕሮጀክቶች';
      case 'library':
        return isEn ? 'Library' : 'ቤተ-መጽሐፍት';
      case 'choir':
        return isEn ? 'Choir' : 'መረጣ';
      case 'admin':
        return isEn ? 'Admin' : 'አስተዳዳሪ';
      case 'troubleshooting':
        return isEn ? 'Troubleshooting' : 'መፍትሔዎች';
      default:
        return cat.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(contextualGuidanceProvider(screenRoute));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return articleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _buildFallbackContent(context, scrollController),
          data: (article) {
            if (article == null) {
              return _buildFallbackContent(context, scrollController);
            }
            return _buildArticleContent(context, ref, article, scrollController);
          },
        );
      },
    );
  }

  Widget _buildArticleContent(
    BuildContext context,
    WidgetRef ref,
    GuidanceArticle article,
    ScrollController scrollController,
  ) {
    final lang = Localizations.localeOf(context).languageCode;
    final isEn = lang == 'en';
    final tourId = explicitTourId ?? article.tourId;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: context.palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header Row: Title & Close
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.maroon.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _categoryLabel(article.category, isEn),
                          style: context.sans(11, weight: FontWeight.bold, color: AppColors.maroon),
                        ),
                      ),
                      if (article.targetRole != 'all') ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isEn ? 'ROLE: ${article.targetRole.toUpperCase()}' : 'ደረጃ: ${article.targetRole.toUpperCase()}',
                            style: context.sans(11, weight: FontWeight.bold, color: AppColors.gold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(article.titleFor(lang), style: context.serif(20, weight: FontWeight.bold)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Summary / Description
        if (article.summaryFor(lang) != null) ...[
          Text(article.summaryFor(lang)!, style: context.sans(14, color: context.palette.text)),
          const SizedBox(height: 14),
        ],

        // Actions Row: Direct navigation to feature & Interactive Tour
        if ((article.targetScreen != null && article.targetScreen != screenRoute) ||
            (tourId != null && TourCatalog.tours.containsKey(tourId))) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (article.targetScreen != null && article.targetScreen != screenRoute)
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(isEn ? 'Open Feature' : 'ወደ አገልግሎቱ ሂድ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.maroon,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    GuidanceNavigator.navigateTo(
                      context,
                      ref,
                      article.targetScreen!,
                      requiredPermission: article.requiredPermission,
                      tourId: article.tourId,
                    );
                  },
                ),
              if (tourId != null && TourCatalog.tours.containsKey(tourId))
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18, color: AppColors.maroon),
                  label: Text(isEn ? 'Interactive Tour' : 'አሳይኝ (ጉብኝት)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.maroon,
                    side: const BorderSide(color: AppColors.maroon),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final navContext = rootNavigatorKey.currentContext;
                      if (navContext != null) {
                        TourController.instance.startTour(navContext, tourId, ref: ref, force: true);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],

        // Numbered Steps
        if (article.steps.isNotEmpty) ...[
          Text(isEn ? 'Step-by-Step Instructions' : 'የአጠቃቀም ቅደም ተከተል', style: context.sans(15, weight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (int i = 0; i < article.steps.length; i++) ...[
            _buildStepTile(context, ref, i + 1, article.steps[i], lang, isEn),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
        ],

        // Tips & Best Practices
        if (article.tipsFor(lang).isNotEmpty) ...[
          Text(isEn ? 'Tips & Important Notes' : 'ጠቃሚ ምክሮች እና ማሳሰቢያዎች', style: context.sans(15, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final tip in article.tipsFor(lang)) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip, style: context.sans(13))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],

        // FAQs
        if (article.faqItems.isNotEmpty) ...[
          Text(isEn ? 'Frequently Asked Questions' : 'ተደጋጋሚ ጥያቄዎች', style: context.sans(15, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final faq in article.faqItems) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.palette.border),
              ),
              child: ExpansionTile(
                title: Text(faq.questionFor(lang), style: context.sans(13, weight: FontWeight.bold)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(faq.answerFor(lang), style: context.sans(13, color: context.palette.muted)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 16),
        ],

        // Link to full Guidance Center
        OutlinedButton.icon(
          icon: const Icon(Icons.menu_book_rounded),
          label: Text(isEn ? 'View All in Guidance Center' : 'ሁሉንም መመሪያዎች ተመልከት'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final navContext = rootNavigatorKey.currentContext;
            Navigator.of(context).pop();
            if (navContext != null) {
              navContext.push('/guidance');
            }
          },
        ),
      ],
    );
  }

  Widget _buildStepTile(BuildContext context, WidgetRef ref, int index, GuidanceStep step, String lang, bool isEn) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.maroon,
            child: Text('$index', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.titleFor(lang), style: context.sans(14, weight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(step.descriptionFor(lang), style: context.sans(13, color: context.palette.text)),
                if (step.tipFor(lang) != null) ...[
                  const SizedBox(height: 6),
                  Text('💡 ${step.tipFor(lang)}', style: context.sans(12, color: AppColors.gold)),
                ],
                if (step.actionRoute != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                      label: Text(isEn ? 'Open' : 'ክፈት'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        GuidanceNavigator.navigateTo(
                          context,
                          ref,
                          step.actionRoute!,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackContent(BuildContext context, ScrollController scrollController) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final resolvedTitle = fallbackTitle != null
        ? (isEn
            ? (RegExp(r'\(([^)]+)\)').firstMatch(fallbackTitle!)?.group(1)?.trim() ?? fallbackTitle!)
            : fallbackTitle!.split('(').first.trim())
        : (isEn ? 'Feature Guidance' : 'የአገልግሎቱ መመሪያ');

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: context.palette.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(resolvedTitle, style: context.serif(18, weight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.maroon.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.maroon.withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.maroon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEn
                      ? 'Detailed walkthroughs, field descriptions, business rules, and troubleshooting for this module are available in the Guidance Center.'
                      : 'የዚህ አገልግሎት ዝርዝር የደረጃ መመሪያዎች፣ የሜዳዎች ማብራሪያ፣ ህጎች እና መፍትሔዎች በመመሪያ ማዕከል ውስጥ ተደራጅተው ይገኛሉ።',
                  style: context.sans(14, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(Icons.menu_book_rounded),
          label: Text(isEn ? 'Open Guidance Center' : 'ወደ መመሪያ ማዕከል ሂድ'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.maroon, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () {
            final navContext = rootNavigatorKey.currentContext;
            Navigator.of(context).pop();
            if (navContext != null) {
              navContext.push('/guidance');
            }
          },
        ),
      ],
    );
  }
}
