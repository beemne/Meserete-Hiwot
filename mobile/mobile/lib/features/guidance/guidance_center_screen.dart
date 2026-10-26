import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin.dart';
import '../../models/guidance.dart';
import '../../repositories/guidance_repository.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../auth/session.dart';
import 'guidance_navigator.dart';
import 'tour_engine.dart';

/// Guidance Center — Polish hub for help articles, FAQs, troubleshooting and interactive tours.
class GuidanceCenterScreen extends ConsumerStatefulWidget {
  const GuidanceCenterScreen({super.key});

  @override
  ConsumerState<GuidanceCenterScreen> createState() => _GuidanceCenterScreenState();
}

class _GuidanceCenterScreenState extends ConsumerState<GuidanceCenterScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _categories = [
    {'key': 'all', 'labelAm': 'ሁሉም', 'labelEn': 'All', 'icon': Icons.all_inclusive_rounded},
    {'key': 'getting_started', 'labelAm': 'መግቢያ', 'labelEn': 'Getting Started', 'icon': Icons.flag_rounded},
    {'key': 'mezmurs', 'labelAm': 'መዝሙራት', 'labelEn': 'Mezmurs', 'icon': Icons.music_note_rounded},
    {'key': 'programs', 'labelAm': 'መርሐ ግብሮች', 'labelEn': 'Programs', 'icon': Icons.event_rounded},
    {'key': 'attendance', 'labelAm': 'አቴንዳንስ', 'labelEn': 'Attendance', 'icon': Icons.qr_code_rounded},
    {'key': 'education', 'labelAm': 'ትምህርት', 'labelEn': 'Education', 'icon': Icons.school_rounded},
    {'key': 'projects', 'labelAm': 'ፕሮጀክቶች', 'labelEn': 'Projects', 'icon': Icons.assignment_rounded},
    {'key': 'library', 'labelAm': 'ቤተ-መጽሐፍት', 'labelEn': 'Library', 'icon': Icons.local_library_rounded},
    {'key': 'choir', 'labelAm': 'መረጣ', 'labelEn': 'Choir', 'icon': Icons.groups_rounded},
    {'key': 'admin', 'labelAm': 'አስተዳዳሪ', 'labelEn': 'Admin', 'icon': Icons.shield_outlined},
    {'key': 'troubleshooting', 'labelAm': 'መፍትሔዎች', 'labelEn': 'Troubleshoot', 'icon': Icons.build_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _restartWelcomeTour() async {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final confirmed = await showConfirm(
      context,
      isEn
          ? 'Would you like to restart the welcome tour? It will guide you through key app features step by step.'
          : 'የመግቢያ ጉብኝቱን እንደገና መጀመር ይፈልጋሉ? የመተግበሪያውን ዋና ገጽታዎች በዝርዝር ያሳይዎታል።',
      title: isEn ? 'Restart Tour' : 'የመግቢያ ጉብኝት',
      confirmLabel: isEn ? 'Start' : 'ጀምር',
    );

    if (confirmed && mounted) {
      await ref.read(guidanceRepositoryProvider).resetTourProgress(tourId: 'welcome_tour');
      ref.invalidate(tourProgressProvider);
      if (mounted) {
        context.go('/hub');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          TourController.instance.startTour(context, 'welcome_tour', ref: ref, force: true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final isEn = lang == 'en';
    final user = ref.watch(currentUserProvider);
    final canManage = user != null && (user.isAdmin || user.can(Perm.guidanceManage));

    final filter = GuidanceFilter(
      category: _selectedCategory != 'all' ? _selectedCategory : null,
      search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
    );

    final articlesAsync = ref.watch(guidanceArticlesProvider(filter));
    final progressAsync = ref.watch(tourProgressProvider);

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Guidance Center' : 'የመመሪያ ማዕከል'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded),
              tooltip: isEn ? 'Manage Guidance' : 'መመሪያዎችን አስተዳድር',
              onPressed: () => context.push('/admin/guidance'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(guidanceArticlesProvider);
          ref.invalidate(tourProgressProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isEn ? 'Search guidance articles or questions...' : 'መመሪያዎችን ወይም ጥያቄዎችን ፈልግ...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 14),

            // Category Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cat in _categories) ...[
                    if (cat['key'] != 'admin' || canManage)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(cat['icon'] as IconData, size: 16),
                          label: Text(isEn ? (cat['labelEn'] as String) : (cat['labelAm'] as String)),
                          selected: _selectedCategory == cat['key'],
                          onSelected: (sel) {
                            setState(() => _selectedCategory = sel ? (cat['key'] as String) : 'all');
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Interactive Tours Section
            if (_searchQuery.isEmpty && _selectedCategory == 'all') ...[
              _buildInteractiveToursSection(context, progressAsync),
              const SizedBox(height: 20),
            ],

            // Quick Troubleshooting Cards
            if (_searchQuery.isEmpty && (_selectedCategory == 'all' || _selectedCategory == 'troubleshooting')) ...[
              _buildQuickTroubleshooting(context),
              const SizedBox(height: 20),
            ],

            // Articles Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedCategory == 'all'
                        ? (isEn ? 'Help Articles' : 'የእገዛ ጽሑፎች')
                        : (isEn ? 'Selected Guides' : 'የተመረጡ መመሪያዎች'),
                    style: context.serif(18, weight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(isEn ? 'Start Tour' : 'ጉብኝት ጀምር'),
                  onPressed: _restartWelcomeTour,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Articles List
            articlesAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(isEn ? 'Failed to load guidance: $err' : 'መመሪያዎችን መጫን አልተቻለም: $err', style: context.sans(14, color: AppColors.danger)),
                ),
              ),
              data: (articles) {
                final visibleArticles = articles.where((a) {
                  if (a.targetRole == 'admin' && !canManage) return false;
                  if (a.requiredPermission != null && !canManage && !(user?.can(a.requiredPermission!) ?? false)) return false;
                  return true;
                }).toList();

                if (visibleArticles.isEmpty) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: context.palette.border)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: context.palette.muted),
                          const SizedBox(height: 12),
                          Text(isEn ? 'No guidance articles found' : 'ምንም መመሪያ አልተገኘም', style: context.sans(16, weight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            isEn ? 'Try changing your search query or selecting another category.' : 'የፍለጋ ቃሉን ይቀይሩ ወይም ሌላ ምድብ ይምረጡ።',
                            style: context.sans(13, color: context.palette.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final a in visibleArticles) ...[
                      _buildArticleCard(context, a),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveToursSection(BuildContext context, AsyncValue<Map<String, TourProgress>> progressAsync) {
    final progressMap = progressAsync.asData?.value ?? {};
    final user = ref.watch(currentUserProvider);
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final tourList = [
      {
        'id': 'welcome_tour',
        'titleAm': 'የመተግበሪያው መግቢያ',
        'titleEn': 'App Welcome Tour',
        'descAm': 'የመሠረተ ሕይወት መተግበሪያ ዋና ገጽታዎች አጭር ጉብኝት።',
        'descEn': 'A quick walkthrough of the core features and navigation.',
        'route': '/hub',
        'icon': Icons.explore_rounded,
      },
      {
        'id': 'mezmur_tour',
        'titleAm': 'የመዝሙር ክፍል',
        'titleEn': 'Mezmur & Audio',
        'descAm': 'መዝሙራትን መፈለግ፣ ማዳመጥ እና ከመስመር ውጭ ማውረድ።',
        'descEn': 'Search, playback, lyrics, and offline downloads.',
        'route': '/home',
        'icon': Icons.music_note_rounded,
      },
      {
        'id': 'programs_tour',
        'titleAm': 'መርሐ ግብር እና ማንቂያ',
        'titleEn': 'Programs & Alarms',
        'descAm': 'መርሐ ግብሮች እና የ30 ደቂቃ ማንቂያ (Alarm) ማብራት።',
        'descEn': 'Schedule viewing and 30-minute advance alarm setup.',
        'route': '/programs',
        'icon': Icons.alarm_rounded,
      },
      {
        'id': 'attendance_tour',
        'titleAm': 'የአባልነት ካርድ እና QR',
        'titleEn': 'Member Card & Attendance',
        'descAm': 'የግል ዲጂታል QR መታወቂያ እና የክትትል የቀን መቁጠሪያ።',
        'descEn': 'Your digital QR member badge and attendance calendar.',
        'route': '/settings/me',
        'icon': Icons.qr_code_rounded,
      },
      if (user?.isAdmin ?? false)
        {
          'id': 'admin_tour',
          'titleAm': 'የአስተዳዳሪ ማዕከል',
          'titleEn': 'Admin Workflows',
          'descAm': 'የአባላት አስተዳደር፣ አቴንዳንስ መዝጋት እና ሪፖርቶች።',
          'descEn': 'Member administration, attendance marking, and reports.',
          'route': '/admin',
          'icon': Icons.shield_rounded,
        },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.touch_app_rounded, color: AppColors.maroon, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEn ? 'Interactive Tours' : 'ቀጥታ በይነተገናኝ ጉብኝቶች',
                style: context.serif(18, weight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tourList.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              final t = tourList[i];
              final tid = t['id'] as String;
              final completed = progressMap[tid]?.completed ?? false;
              final title = isEn ? (t['titleEn'] as String) : (t['titleAm'] as String);
              final desc = isEn ? (t['descEn'] as String) : (t['descAm'] as String);

              return SizedBox(
                width: 240,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: completed ? AppColors.gold.withValues(alpha: 0.5) : context.palette.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final route = t['route'] as String;
                      GuidanceNavigator.navigateTo(context, ref, route, tourId: tid);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(t['icon'] as IconData, size: 22, color: AppColors.maroon),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: completed ? Colors.green.withValues(alpha: 0.15) : AppColors.maroon.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  completed ? (isEn ? 'Completed ✓' : 'ተጠናቋል ✓') : (isEn ? 'Start →' : 'ጀምር →'),
                                  style: context.sans(11, weight: FontWeight.bold, color: completed ? Colors.green.shade800 : AppColors.maroon),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(title, style: context.sans(14, weight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(desc, style: context.sans(12, color: context.palette.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTroubleshooting(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.help_center_rounded, color: AppColors.gold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEn ? 'Quick Troubleshooting & FAQs' : 'ፈጣን መፍትሔዎች እና ጥያቄዎች',
                style: context.serif(18, weight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: context.palette.border),
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.cloud_off_rounded, color: AppColors.maroon),
            title: Text(isEn ? 'Listening to Mezmurs Offline' : 'ያለ ኢንተርኔት መዝሙር ማዳመጥ', style: context.sans(14, weight: FontWeight.bold)),
            subtitle: Text(isEn ? 'How offline caching and storage works' : 'ከመስመር ውጭ ሙሉ በሙሉ እንዴት እንደሚሰራ', style: context.sans(12, color: context.palette.muted)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  isEn
                      ? 'When you download mezmurs to your phone, you can listen anytime without an internet connection in "Library" -> "Downloads". Lyrics are also cached offline automatically.'
                      : 'መዝሙራትን አስቀድመው ወደ ስልክዎ ካወረዱ ያለ ምንም ኢንተርኔት በ«የእኔ መዝሙራት» ገጽ «የወረዱ» ስር ማዳመጥ ይችላሉ። ግጥሞችም እንዲሁ አስቀድመው ተቀምጠው ያለ ኢንተርኔት ይሰራሉ።',
                  style: context.sans(13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: context.palette.border),
          ),
          child: ExpansionTile(
            leading: const Icon(Icons.alarm_off_rounded, color: AppColors.gold),
            title: Text(isEn ? 'If 30-Minute Alarm Does Not Ring' : 'የ30 ደቂቃ ማንቂያ በሰዓቱ ካልደወለ', style: context.sans(14, weight: FontWeight.bold)),
            subtitle: Text(isEn ? 'Permissions required on Android 12+' : 'በአዳዲስ Android 12/13/14+ ስልኮች ላይ አስፈላጊ ፈቃድ', style: context.sans(12, color: context.palette.muted)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  isEn
                      ? 'Go to phone Settings > Apps > Mezmur Zemseretee Hiwot and enable "Alarms & Reminders" permission. Also set Battery Usage to "Unrestricted" so background optimization does not silence it.'
                      : 'በስልክዎ Settings > Apps > መሠረተ ሕይወት ውስጥ ገብተው «Alarms & Reminders» ፈቃድን ያብሩ። በተጨማሪም ባትሪ ቆጣቢ እንዳይከለክለው የባትሪ አጠቃቀምን «Unrestricted» ያድርጉት።',
                  style: context.sans(13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArticleCard(BuildContext context, GuidanceArticle a) {
    final lang = Localizations.localeOf(context).languageCode;
    final isEn = lang == 'en';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.palette.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GuidanceArticleDetailScreen(article: a),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.maroon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.article_rounded, size: 20, color: AppColors.maroon),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.titleFor(lang), style: context.sans(15, weight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(a.category.toUpperCase(), style: context.sans(11, color: AppColors.maroon, weight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (a.hasTour)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 14, color: AppColors.gold),
                          SizedBox(width: 4),
                          Text('Tour', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gold)),
                        ],
                      ),
                    ),
                ],
              ),
              if (a.summaryFor(lang) != null) ...[
                const SizedBox(height: 10),
                Text(a.summaryFor(lang)!, style: context.sans(13, color: context.palette.text), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (a.steps.isNotEmpty)
                    Text(isEn ? '${a.steps.length} Steps · ' : '${a.steps.length} ደረጃዎች · ', style: context.sans(12, color: context.palette.muted)),
                  if (a.faqItems.isNotEmpty)
                    Text(isEn ? '${a.faqItems.length} FAQs · ' : '${a.faqItems.length} ጥያቄዎች · ', style: context.sans(12, color: context.palette.muted)),
                  Text(
                    a.targetRole == 'all'
                        ? (isEn ? 'For all members' : 'ለሁሉም አባላት')
                        : (isEn ? 'Role: ${a.targetRole.toUpperCase()}' : 'ደረጃ: ${a.targetRole.toUpperCase()}'),
                    style: context.sans(12, color: context.palette.muted),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.maroon),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full article reading screen with formatted steps, tips, FAQs and Show Me tour action.
class GuidanceArticleDetailScreen extends ConsumerWidget {
  const GuidanceArticleDetailScreen({super.key, required this.article});
  final GuidanceArticle article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Localizations.localeOf(context).languageCode;
    final isEn = lang == 'en';

    return PatternScaffold(
      appBar: AppBar(
        title: Text(article.category.toUpperCase()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          // Role Badge
          if (article.targetRole != 'all')
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Chip(
                avatar: const Icon(Icons.shield_outlined, size: 16),
                label: Text(isEn ? 'Role Required: ${article.targetRole.toUpperCase()}' : 'የሚፈለግ ደረጃ: ${article.targetRole.toUpperCase()}'),
                backgroundColor: AppColors.maroon.withValues(alpha: 0.1),
              ),
            ),

          // Title
          Text(article.titleFor(lang), style: context.serif(22, weight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Summary
          if (article.summaryFor(lang) != null) ...[
            Text(article.summaryFor(lang)!, style: context.sans(15, color: context.palette.text)),
            const SizedBox(height: 16),
          ],

          // Direct Feature Navigation & Interactive Tour Action Buttons
          if (article.targetScreen != null || (article.hasTour && TourCatalog.tours.containsKey(article.tourId))) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (article.targetScreen != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(isEn ? 'Open Feature' : 'ወደ አገልግሎቱ ሂድ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                if (article.hasTour && TourCatalog.tours.containsKey(article.tourId))
                  OutlinedButton.icon(
                    icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.maroon),
                    label: Text(isEn ? 'Show Me (Tour)' : 'አሳይኝ (ጉብኝት)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.maroon,
                      side: const BorderSide(color: AppColors.maroon),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final screen = article.targetScreen ?? '/hub';
                      GuidanceNavigator.navigateTo(
                        context,
                        ref,
                        screen,
                        requiredPermission: article.requiredPermission,
                        tourId: article.tourId,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Content body
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.palette.border),
            ),
            child: Text(article.contentFor(lang), style: context.sans(14, height: 1.6)),
          ),
          const SizedBox(height: 20),

          // Numbered Steps
          if (article.steps.isNotEmpty) ...[
            Text(isEn ? 'Step-by-Step Instructions' : 'የአጠቃቀም ቅደም ተከተል', style: context.sans(16, weight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (int i = 0; i < article.steps.length; i++) ...[
              _buildStepCard(context, ref, i + 1, article.steps[i], lang, isEn),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
          ],

          // Tips & Warnings
          if (article.tipsFor(lang).isNotEmpty) ...[
            Text(isEn ? 'Tips & Important Notes' : 'ጠቃሚ ምክሮች እና ጥንቃቄዎች', style: context.sans(16, weight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final tip in article.tipsFor(lang)) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded, size: 20, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tip, style: context.sans(13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // FAQs
          if (article.faqItems.isNotEmpty) ...[
            Text(isEn ? 'Frequently Asked Questions' : 'ተደጋጋሚ ጥያቄዎች', style: context.sans(16, weight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (final faq in article.faqItems) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.palette.border),
                ),
                child: ExpansionTile(
                  title: Text(faq.questionFor(lang), style: context.sans(14, weight: FontWeight.bold)),
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
          ],
        ],
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, WidgetRef ref, int index, GuidanceStep step, String lang, bool isEn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.maroon,
            child: Text('$index', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
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
}
