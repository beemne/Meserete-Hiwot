import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/chrome.dart' show EduIcon;
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/states.dart';
import '../../admin/edit_mode.dart' show EditModeToggle, EditModeBanner;
import '../../auth/session.dart';
import '../../guidance/contextual_help_sheet.dart';
import '../../../services/file_opening_service.dart';
import '../edu_screens.dart' show eduOverviewProvider;
import 'edu_widgets.dart';
import 'magazine_screens.dart';

/// Everything the ትምህርት home shows, in one request (blocks per real responsibility).
final eduDashboardProvider = FutureProvider.autoDispose<Json>(
  (ref) => ref.watch(eduRepositoryProvider).dashboard(),
);

// =============================================================================
// ትምህርት home
// =============================================================================
class EduHomeScreen extends ConsumerWidget {
  const EduHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void refresh() {
      ref.invalidate(eduDashboardProvider);
      ref.invalidate(eduOverviewProvider);
      ref.invalidate(latestMagazineProvider);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/hub');
      },
      child: PatternScaffold(
        body: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async => refresh(),
          child: AsyncView(
            value: ref.watch(eduDashboardProvider),
            onRetry: refresh,
            data: (d) => _HomeBody(data: d, refresh: refresh),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data, required this.refresh});
  final Json data;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final featured = asJsonList(data['featured']);
    final cont = data['continue'] is Map ? asJson(data['continue']) : null;
    final student = data['student'] is Map ? asJson(data['student']) : null;
    final teaching = data['teaching'] is Map ? asJson(data['teaching']) : null;
    final sessions = asJsonList(data['next_sessions']);
    final classes = asJsonList(data['classes']);
    final open = asIntOr(data['open_registration']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        // 1. Education heading and short description
        const _Header(),

        // 2. Compact welcome/progress card
        _WelcomeCard(student: student),

        // 3. Education Admin Panel entry (only for authorized users)
        const EditModeBanner(module: 'edu'),
        const _AdminBanner(),

        // 4. Featured lesson or Continue Learning card
        if (featured.isNotEmpty) ...[
          const SizedBox(height: 12),
          FeaturedCarousel(items: featured),
        ],
        if (cont != null) ...[
          const SizedBox(height: 12),
          ContinueLearningCard(data: cont),
        ],

        // 5. Canonical 7 Categories in exact order 1..7
        _CanonicalCategoriesSection(
          apiCategories: asJsonList(data['categories']),
          refresh: refresh,
        ),

        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppCard(
                onTap: () => context.push('/edu/assignments'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.maroon.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_outlined, color: AppColors.maroon, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.elAssignments, style: context.sans(13, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(l.isEn ? 'Homework & tasks' : 'ሥራዎችና ፈተናዎች', style: context.sans(10.5, color: context.palette.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppCard(
                onTap: () => context.push('/edu/announcements'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign_outlined, color: AppColors.goldDark, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.elClassFeed, style: context.sans(13, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(l.isEn ? 'Teacher updates' : 'የአስተማሪ መልእክቶች', style: context.sans(10.5, color: context.palette.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 6. This week: quizzes and assignments due
        if (student != null) _ThisWeek(student: student),

        // 7. My Studies and upcoming class information
        if (classes.isEmpty && student == null) ...[
          EduSectionHeader(
            title: l.elMyStudies,
            subtitle: l.isEn
                ? 'Your enrolled classes and schedule'
                : 'የተመዘገቡባቸው ክፍሎች እና የጊዜ ሰሌዳ',
          ),
          EduEmptyCard(
            icon: Icons.how_to_reg_rounded,
            message: open > 0
                ? l.elNotEnrolledOpen(open)
                : l.elNotEnrolledNoOpen,
            actionLabel: open > 0 ? l.eduRegister : null,
            onAction: open > 0 ? () => context.push('/edu/register') : null,
          ),
        ] else
          _Overview(sessions: sessions, student: student),

        // 8. Other role-specific sections (Teaching, Seleda Magazine banner at bottom)
        if (teaching != null) _Teaching(teaching: teaching),
        const SizedBox(height: 12),
        const SeledaMagazineBanner(),
      ],
    );
  }
}

class _WelcomeCard extends ConsumerWidget {
  const _WelcomeCard({this.student});
  final Json? student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final name = user?.fullName.split(' ').firstOrNull ?? user?.fullName ?? '';
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    final attendance = asJsonList(student?['attendance']);
    final totalClasses = attendance.length;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.eduBurgundy,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.eduBurgundy, AppColors.eduBurgundyDark],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.eduGold.withValues(alpha: 0.45),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.eduBurgundyDark.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.eduGold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.eduGoldLight, width: 1.2),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AppColors.eduGoldLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty
                      ? (isEn ? 'Welcome, $name' : 'እንኳን ደህና መጡ፣ $name')
                      : (isEn ? 'Spiritual Education' : 'መንፈሳዊ ትምህርት'),
                  style: context.serif(
                    15.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isEn
                      ? 'Grow in faith, wisdom, and knowledge'
                      : 'በሃይማኖት፣ በጥበብ እና በመንፈሳዊ ዕውቀት ያድጉ',
                  style: context.sans(11.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (totalClasses > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.eduGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.eduGoldLight.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.class_rounded,
                    size: 12,
                    color: AppColors.eduGoldLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalClasses',
                    style: context.sans(
                      11,
                      weight: FontWeight.w700,
                      color: AppColors.eduGoldLight,
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : AppColors.eduBurgundy;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          tooltip: l.isEn ? 'Back to Hub' : 'ወደ ዋና ገጽ ተመለስ',
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.maroon),
          onPressed: () => context.go('/hub'),
        ),
        const EduIcon(size: 38),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.hubEducation,
                style: context.serif(
                  22,
                  color: headingColor,
                  height: 1.15,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(l.elHomeSubtitle, style: context.sans(12, color: p.muted)),
            ],
          ),
        ),
        const EditModeToggle(module: 'edu'),
        const ContextualHelpButton(screenRoute: '/edu'),
      ],
    );
  }
}

class _CanonicalCategoryItem {
  const _CanonicalCategoryItem({
    required this.order,
    required this.id,
    required this.name,
    required this.nameEn,
    required this.desc,
    required this.icon,
  });

  final int order;
  final int id;
  final String name;
  final String nameEn;
  final String desc;
  final IconData icon;
}

const canonicalCategoriesList = [
  _CanonicalCategoryItem(
    order: 1,
    id: 1,
    name: 'ትምህርተ ሃይማኖት',
    nameEn: 'Theology & Doctrine',
    desc: 'የኦርቶዶክስ ተዋሕዶ ሃይማኖት መሠረተ እምነትና ዶግማ',
    icon: Icons.church_rounded,
  ),
  _CanonicalCategoryItem(
    order: 2,
    id: 4,
    name: 'የመጽሐፍ ቅዱስ ጥናት',
    nameEn: 'Bible Study',
    desc: 'የብሉይና የሐዲስ ኪዳን መጻሕፍት ጥናትና ትርጓሜ',
    icon: Icons.menu_book_rounded,
  ),
  _CanonicalCategoryItem(
    order: 3,
    id: 5,
    name: 'ክርስቲያናዊ ሥነምግባር',
    nameEn: 'Christian Ethics',
    desc: 'የክርስቲያን አኗኗር፣ ምግባርና ማኅበራዊ ሕይወት',
    icon: Icons.favorite_rounded,
  ),
  _CanonicalCategoryItem(
    order: 4,
    id: 6,
    name: 'ሥርዓተ ቤተ ክርስቲያን',
    nameEn: 'Church Order & Rites',
    desc: 'የቤተ ክርስቲያን ሥርዓት፣ አምልኮና ሰባቱ ምሥጢራት',
    icon: Icons.account_balance_rounded,
  ),
  _CanonicalCategoryItem(
    order: 5,
    id: 3,
    name: 'የቤተክርስትያን ታሪክ',
    nameEn: 'Church History',
    desc: 'የኢትዮጵያና የዓለም አብያተ ክርስቲያናት ታሪክ',
    icon: Icons.history_edu_rounded,
  ),
  _CanonicalCategoryItem(
    order: 6,
    id: 7,
    name: 'ልሳነ ግእዝ',
    nameEn: 'Geez Language',
    desc: 'የግእዝ ቋንቋ ሰዋስው፣ ንባብና የዜማ ምልክቶች',
    icon: Icons.translate_rounded,
  ),
  _CanonicalCategoryItem(
    order: 7,
    id: 8,
    name: 'ዜማ',
    nameEn: 'Zema (Sacred Chants)',
    desc: 'የቅዱስ ያሬድ ዜማ፣ ጾመ ድጓ፣ ዝማሬና ማሕሌት',
    icon: Icons.music_note_rounded,
  ),
];

const canonicalSubjectsList = canonicalCategoriesList;

class _CanonicalCategoriesSection extends StatelessWidget {
  const _CanonicalCategoriesSection({
    this.apiCategories = const [],
    required this.refresh,
  });
  final List<Json> apiCategories;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EduSectionHeader(
          title: isEn ? 'Curriculum Categories' : 'የካሪኩለም ዘርፎች',
          subtitle: isEn
              ? 'Select a category to browse grade curriculum (1 - 12)'
              : 'ከ1ኛ እስከ 12ኛ ክፍል ያሉትን ትምህርቶች ለመመልከት ምድብ ይምረጡ',
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: canonicalCategoriesList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final spec = canonicalCategoriesList[index];
            final apiMatch = apiCategories.firstWhere(
              (s) =>
                  asIntOr(s['sort_order']) == spec.order ||
                  asStr(s['name'])?.trim() == spec.name.trim() ||
                  asIntOr(s['id']) == spec.id,
              orElse: () => <String, dynamic>{},
            );
            final realId = asInt(apiMatch['id']) ?? spec.id;
            final canonicalAmharicName = spec.name;
            final secondaryEnglishName = isEn && spec.nameEn.isNotEmpty ? spec.nameEn : null;
            final displayDesc = asStr(apiMatch['description']) ?? spec.desc;

            return AppCard(
              onTap: () {
                context.push('/edu/subject/$realId/grades');
              },
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              radius: 14,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.maroon.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${spec.order}',
                      style: context.serif(
                        17,
                        weight: FontWeight.w800,
                        color: AppColors.maroon,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    canonicalAmharicName,
                                    style: context.serif(
                                      15.5,
                                      weight: FontWeight.w700,
                                      color: AppColors.maroon,
                                    ),
                                  ),
                                  if (secondaryEnglishName != null)
                                    Text(
                                      secondaryEnglishName,
                                      style: context.sans(
                                        11,
                                        weight: FontWeight.w600,
                                        color: AppColors.goldDark,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isEn ? '12 Grades' : '12 ክፍሎች',
                                style: context.sans(
                                  10.5,
                                  weight: FontWeight.w600,
                                  color: AppColors.goldDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displayDesc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(11.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.gold,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AdminBanner extends ConsumerWidget {
  const _AdminBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final canAdmin =
        session is SignedIn &&
        (session.user.can(Perm.educationManage) ||
            session.user.can(Perm.educationContent) ||
            session.user.isSuperAdmin);
    if (!canAdmin) return const SizedBox.shrink();

    final l = context.l10n;
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/edu/admin'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppColors.goldDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.isEn ? 'Education Admin Panel' : 'የትምህርት ክፍል አስተዳደር',
                        style: context.serif(14, color: p.primary),
                      ),
                      Text(
                        l.isEn
                            ? 'Academics, classes, authoring, reviews & library'
                            : 'አካዳሚክ፣ ክፍሎች፣ ይዘት ማዘጋጀት፣ ግምገማ እና ቤተ መጻሕፍት',
                        style: context.sans(11.5, color: p.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.student});
  final Json student;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final quizzes = asJsonList(student['quizzes']);
    final due = asJsonList(student['assignments_due']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EduSectionHeader(
          title: l.elThisWeek,
          subtitle: l.isEn
              ? 'Pending quizzes and submissions'
              : 'የሳምንቱ ፈተናዎች እና የቤት ሥራዎች',
        ),
        if (quizzes.isNotEmpty) ...[
          // The design's maroon "Weekly quizzes" banner — with antique gold border and trophy icon.
          Container(
            decoration: BoxDecoration(
              color: AppColors.eduBurgundy,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.eduBurgundy, AppColors.eduBurgundyDark],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.eduGold.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.eduBurgundyDark.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push('/edu/quiz/${quizzes.first['id']}'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AppColors.eduGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l.isEn ? 'WEEKLY ASSESSMENT' : 'ሳምንታዊ ፈተና',
                                style: context.sans(
                                  10.5,
                                  weight: FontWeight.w700,
                                  color: AppColors.eduGoldLight,
                                ),
                              ),
                            ),
                            Text(
                              l.elWeeklyQuizzes,
                              style: context.serif(
                                18,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.elQuizzesWaiting(quizzes.length),
                              style: context.sans(
                                12.5,
                                color: AppColors.eduGoldLight,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.eduGold,
                                foregroundColor: AppColors.eduBurgundyDark,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => context.push(
                                '/edu/quiz/${quizzes.first['id']}',
                              ),
                              child: Text(
                                l.elTakePart,
                                style: context.sans(
                                  12.5,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.eduGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.eduGoldLight.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in_rounded,
                          color: AppColors.eduGoldLight,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final q in quizzes.skip(1).take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QuizCard(quiz: q, compact: true),
            ),
        ],
        for (final a in due.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              onTap: () =>
                  context.push('/edu/class/${a['class_id']}?tab=assignments'),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    color: asBool(a['overdue'])
                        ? AppColors.danger
                        : AppColors.goldDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asStr(a['title']) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(14, weight: FontWeight.w600),
                        ),
                        Text(
                          [
                            asStr(a['course_name']) ?? '',
                            if (asDate(a['due_at']) != null)
                              (asBool(a['overdue'])
                                  ? l.elOverdue
                                  : l.elDue(
                                      f.date(
                                        asDate(a['due_at']),
                                        withWeekday: true,
                                      ),
                                    )),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.sans(
                            12,
                            color: asBool(a['overdue'])
                                ? AppColors.danger
                                : p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.faint),
                ],
              ),
            ),
          ),
        if (quizzes.isEmpty && due.isEmpty)
          EduEmptyCard(
            icon: Icons.event_available_rounded,
            message: l.elNothingThisWeek,
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
class _Overview extends ConsumerWidget {
  const _Overview({required this.sessions, required this.student});
  final List<Json> sessions;
  final Json? student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final attendance = asJsonList(student?['attendance']);
    final results = asJsonList(student?['results']);
    final period = student?['academic_period'] is Map
        ? asJson(student?['academic_period'])
        : null;
    final certs = asJsonList(student?['certificates']);
    final outcomes = asJsonList(student?['outcomes']);
    final retakes = asJsonList(student?['retakes']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (period != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.eduBurgundy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.eduGold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.eduBurgundy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asStr(period['year_name']) ??
                              '${period['eth_year']} ዓ.ም.',
                          style: context.serif(
                            14,
                            weight: FontWeight.w700,
                            color: AppColors.eduBurgundy,
                          ),
                        ),
                        Text(
                          [
                            asStr(period['term_name']),
                            asStr(period['level_name']),
                          ].whereType<String>().join(' · '),
                          style: context.sans(11.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  if (asBool(period['is_current']))
                    Pill(
                      l.eduCurrentYear,
                      color: AppColors.success,
                      background: AppColors.success.withValues(alpha: 0.12),
                    ),
                ],
              ),
            ),
          ),

        if (certs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.maroon.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.goldDark,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.eduMyCertificates,
                          style: context.sans(
                            13.5,
                            weight: FontWeight.w700,
                            color: p.accentText,
                          ),
                        ),
                      ),
                      Pill('${certs.length}', color: AppColors.goldDark),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final cert in certs)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showCertificateDialog(context, ref, cert),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              cert['status'] == 'valid'
                                  ? Icons.verified_rounded
                                  : (cert['status'] == 'revoked'
                                        ? Icons.cancel_rounded
                                        : Icons.sync_problem_rounded),
                              color: cert['status'] == 'valid'
                                  ? AppColors.success
                                  : (cert['status'] == 'revoked'
                                        ? AppColors.danger
                                        : AppColors.warning),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    asStr(cert['course_name']) ??
                                        asStr(cert['number']) ??
                                        'Certificate',
                                    style: context.sans(
                                      13,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${cert['number']} · ${l.eduVerificationCode}: ${cert['verify_code']}',
                                    style: context.sans(11.5, color: p.muted),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        EduSectionHeader(
          title: l.elMyStudies,
          subtitle: l.isEn
              ? 'Upcoming sessions and classes'
              : 'የሚመጡ የክፍል ጊዜዎች እና ትምህርቶች',
          actionLabel: l.elTabClasses,
          onAction: () => context.go('/edu/classes'),
        ),
        if (sessions.isEmpty)
          EduEmptyCard(
            icon: Icons.event_busy_rounded,
            message: l.elNoUpcomingClasses,
          )
        else
          for (final s in sessions.take(3))
            TimetableScheduleRow(
              time: '${s['starts'] ?? ''} - ${s['ends'] ?? ''}',
              title: [
                asStr(s['class_name']),
                asStr(s['course_name']),
              ].whereType<String>().join(' · '),
              room: asStr(s['location']),
              status: 'upcoming',
              onTap: () => context.push('/edu/class/${s['class_id']}'),
            ),
        if (attendance.isNotEmpty || results.isNotEmpty) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 560;
              final att = AppCard(
                onTap: () => context.go('/edu/progress'),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.how_to_reg_rounded,
                          size: 16,
                          color: AppColors.eduBurgundy,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l.elAttendance,
                            style: context.sans(
                              12.5,
                              weight: FontWeight.w700,
                              color: AppColors.eduBurgundy,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: p.faint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (attendance.isEmpty)
                      Text(
                        l.elNoSessionsYet,
                        style: context.sans(12.5, color: p.muted),
                      ),
                    for (final a in attendance)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: a['rate'] == null
                            ? Text(
                                '${a['class_name']} · ${l.elNoSessionsYet}',
                                style: context.sans(12.5, color: p.muted),
                              )
                            : EduProgressBar(
                                value: asDouble(a['rate']) / 100,
                                height: 6,
                                label:
                                    '${a['class_name']} · ${asDouble(a['rate']).toStringAsFixed(0)}% (${a['total']})',
                              ),
                      ),
                  ],
                ),
              );
              final res = AppCard(
                onTap: () => context.go('/edu/progress'),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          size: 16,
                          color: AppColors.eduGold,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l.elLatestResults,
                            style: context.sans(
                              12.5,
                              weight: FontWeight.w700,
                              color: AppColors.eduBurgundy,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: p.faint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (results.isEmpty)
                      Text(
                        l.elNoPublishedResults,
                        style: context.sans(12.5, color: p.muted),
                      ),
                    for (final r in results.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${r['course_name']} · ${r['title']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.sans(12.5),
                              ),
                            ),
                            Text(
                              '${_n(r['score'])}/${_n(r['max_score'])}',
                              style: context.sans(
                                12.5,
                                weight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
              return wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: att),
                          const SizedBox(width: 10),
                          Expanded(child: res),
                        ],
                      ),
                    )
                  : Column(children: [att, const SizedBox(height: 10), res]);
            },
          ),
        ],
        if (outcomes.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l.eduOutcomes,
                      style: context.sans(
                        12,
                        weight: FontWeight.w600,
                        color: p.accentText,
                      ),
                    ),
                    const Spacer(),
                    if (retakes.isNotEmpty)
                      Pill(
                        '${retakes.length} ${l.eduRetake}',
                        color: AppColors.goldDark,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final o in outcomes.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            asStr(o['course_name']) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.sans(12.5),
                          ),
                        ),
                        Text(
                          '${_n(o['percent'])}%',
                          style: context.sans(
                            12.5,
                            weight: FontWeight.w700,
                            color: o['result'] == 'passed'
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          o['result'] == 'passed' ? l.eduPassed : l.eduFailed,
                          style: context.sans(11.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

void _showCertificateDialog(BuildContext context, WidgetRef ref, Json cert) {
  final l = context.l10n;
  final snapshot = asJson(cert['snapshot']);
  final number = asStr(cert['number']) ?? '—';
  final code = asStr(cert['verify_code']) ?? '—';
  final status = asStr(cert['status']) ?? 'valid';

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.gold,
            size: 26,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(l.eduCertificates)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  number,
                  style: ctx.sans(
                    16,
                    weight: FontWeight.w800,
                    color: AppColors.goldDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _certRow(ctx, l.eduVerificationCode, code, isCode: true),
            _certRow(
              ctx,
              'Course',
              asStr(snapshot['course_name']) ??
                  asStr(cert['course_name']) ??
                  '—',
            ),
            _certRow(ctx, 'Class', asStr(snapshot['class_name']) ?? '—'),
            _certRow(ctx, l.fullName, asStr(snapshot['student_name']) ?? '—'),
            if (asStr(snapshot['member_id']) != null)
              _certRow(ctx, 'Member ID', asStr(snapshot['member_id'])!),
            _certRow(ctx, 'Score', '${_n(snapshot['score_percent'])}%'),
            _certRow(ctx, l.eduCertificateStatus, switch (status) {
              'revoked' => l.eduCertificateRevoked,
              'replaced' => l.eduCertificateReplaced,
              _ => l.eduCertificateValid,
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l.cancel),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l.download),
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ref.read(fileOpeningServiceProvider).openFile(
              context,
              source: '/edu/certificates/${cert['id']}/pdf',
              filename: '$number.pdf',
              mime: 'application/pdf',
            );
          },
        ),
      ],
    ),
  );
}

Widget _certRow(
  BuildContext ctx,
  String label,
  String value, {
  bool isCode = false,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ', style: ctx.sans(12.5, color: ctx.palette.muted)),
      Expanded(
        child: Text(
          value,
          style: isCode
              ? ctx.sans(13, weight: FontWeight.w700)
              : ctx.sans(12.5, weight: FontWeight.w600),
        ),
      ),
    ],
  ),
);

String _n(Object? v) {
  final d = asDouble(v);
  return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
}

// -----------------------------------------------------------------------------
/// A real count that opens the page where it is dealt with (hidden when zero is meaningless).
class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.route,
  });
  final IconData icon;
  final String label;
  final int count;
  final String route;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: () => context.push(route),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: count > 0 ? AppColors.maroon : p.faint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              style: context.sans(12.5, height: 1.3),
            ),
          ),
          Text(
            '$count',
            style: context.serif(
              20,
              color: count > 0 ? AppColors.maroon : p.faint,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountGrid extends StatelessWidget {
  const _CountGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 3 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: c.maxWidth / cols / 64,
        children: children,
      );
    },
  );
}

class _Teaching extends StatelessWidget {
  const _Teaching({required this.teaching});
  final Json teaching;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final courses = asJsonList(teaching['courses']);
    final first = courses.isNotEmpty ? courses.first['id'] : null;
    String course(String tab) =>
        first == null ? '/edu/classes' : '/edu/course/$first?tab=$tab';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.eduTeaching),
        _CountGrid(
          children: [
            _CountTile(
              icon: Icons.grading_rounded,
              label: l.elToGrade,
              count: asIntOr(teaching['submissions_to_grade']),
              route: course('assignments'),
            ),
            _CountTile(
              icon: Icons.assignment_return_outlined,
              label: l.elMarksRejected,
              count: asIntOr(teaching['marks_rejected']),
              route: course('assessments'),
            ),
            _CountTile(
              icon: Icons.edit_note_rounded,
              label: l.elMarksDraft,
              count: asIntOr(teaching['marks_draft']),
              route: course('assessments'),
            ),
            _CountTile(
              icon: Icons.quiz_outlined,
              label: l.elQuizAnswersToGrade,
              count: asIntOr(teaching['quiz_answers_to_grade']),
              route: course('quizzes'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final c in courses)
          TrackTile(
            title: '${c['name']}',
            subtitle:
                '${c['class_name']} · ${l.eduStudentCount(asIntOr(c['student_count']))}',
            leading: const ListThumb(icon: Icons.co_present_rounded),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/edu/course/${c['id']}'),
          ),
      ],
    );
  }
}
