import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sinksar.dart';
import '../../repositories/sinksar_repository.dart';

/// Branded Daily Holy-Day Banner — Phase 5
/// Integrates the automated Ethiopian Orthodox Sinksar commemoration into the home page.
class HolyDayBanner extends ConsumerWidget {
  const HolyDayBanner({super.key, this.margin, this.padding});
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinksarAsync = ref.watch(sinksarTodayProvider);
    final l = context.l10n;
    final isEn = l.localeName.startsWith('en');

    return sinksarAsync.when(
      data: (day) => _buildBanner(context, day, isEn),
      loading: () => _buildLoading(context),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.maroon.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, SinksarDay day, bool isEn) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shadowColor: AppColors.maroon.withValues(alpha: 0.25),
        child: InkWell(
          onTap: () => context.push('/sinksar'),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B111D), Color(0xFF380B12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Stack(
              children: [
                // Subtle Orthodox cross watermark
                Positioned(
                  right: -10,
                  bottom: -15,
                  child: Opacity(
                    opacity: 0.12,
                    child: const Icon(Icons.church_rounded, size: 140, color: AppColors.gold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Date & Fasting Status
                      Row(
                        children: [
                          const Icon(Icons.auto_stories_rounded, color: AppColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              day.formattedFull,
                              style: context.sans(13, color: AppColors.goldLight, weight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (day.isFasting) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.gold, width: 0.8),
                              ),
                              child: Text(
                                day.fastingReason ?? (isEn ? 'Fasting' : 'ጾም'),
                                style: context.sans(11, color: AppColors.goldLight, weight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Middle: Featured Saint / Commemoration
                      Text(
                        day.featuredTitle,
                        style: context.serif(17, weight: FontWeight.bold, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (day.summary != null && day.summary!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          day.summary!,
                          style: context.sans(12, color: AppColors.faint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Bottom Action Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEn ? 'Read Today’s Sinksar' : 'የዕለቱን ስንክሳር አንብብ',
                            style: context.sans(13, color: AppColors.gold, weight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: AppColors.gold, size: 16),
                          ),
                        ],
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
  }
}
