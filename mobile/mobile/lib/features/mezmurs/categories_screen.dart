import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../models/content.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';
import '../guidance/tour_engine.dart';
import 'widgets.dart';

final mezmurCategoryTreeProvider = FutureProvider.autoDispose<List<CategoryNode>>((ref) => ref.watch(contentRepositoryProvider).categoryTree());

/// The Mezmur categories (top level), opened from the "Categories" button of the Mezmur bottom bar.
/// Each card opens the existing category page (sub-categories and Mezmurs).
class MezmurCategoriesScreen extends ConsumerWidget {
  const MezmurCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tree = ref.watch(mezmurCategoryTreeProvider);
    return PatternScaffold(
      body: AsyncView(
        value: tree,
        onRetry: () => ref.invalidate(mezmurCategoryTreeProvider),
        data: (roots) {
          final visible = roots.where((c) => c.isActive).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mezmurCategoryTreeProvider),
            child: visible.isEmpty
                ? ListView(children: [const SizedBox(height: 120), EmptyView(message: l.noResults)])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(child: SectionHeader(title: l.categories)),
                          const ContextualHelpButton(screenRoute: '/home/categories'),
                        ],
                      ),
                      for (var i = 0; i < visible.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CategoryCard(
                            key: i == 0 ? TourKeys.homeCategories : null,
                            category: visible[i],
                            onTap: () => context.push('/home/category/${visible[i].id}'),
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
