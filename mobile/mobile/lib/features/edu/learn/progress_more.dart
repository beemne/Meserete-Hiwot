import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart' show Perm;
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/states.dart';
import '../../auth/session.dart' show currentUserProvider;
import '../../guidance/contextual_help_sheet.dart';
import 'edu_widgets.dart';

final _progressProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(eduRepositoryProvider).progress());

String _n(Object? v) {
  final d = asDouble(v);
  return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
}

// =============================================================================
// Progress: lesson completion, attendance and published results per class, quizzes, bookmarks
// =============================================================================
class EduProgressScreen extends ConsumerWidget {
  const EduProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/edu');
      },
      child: PatternScaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l.elTabProgress),
          actions: [
            IconButton(tooltip: l.eaJourney, icon: const Icon(Icons.timeline_rounded), onPressed: () => context.push('/edu/services?tab=journey')),
            const ContextualHelpButton(screenRoute: '/edu/progress'),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async => ref.invalidate(_progressProvider),
          child: AsyncView(
            value: ref.watch(_progressProvider),
            onRetry: () => ref.invalidate(_progressProvider),
            data: (d) => _ProgressBody(data: d),
          ),
        ),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final subjects = asJsonList(data['subjects']);
    final classes = asJsonList(data['classes']);
    final quizzes = asJsonList(data['quizzes']);
    final bookmarks = asJsonList(data['bookmarks']);
    if (subjects.isEmpty && classes.isEmpty && quizzes.isEmpty && bookmarks.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 40),
        MessageView(icon: Icons.insights_rounded, message: l.elNoProgressYet, action: () => context.go('/edu/learn'), actionLabel: l.elTabLearn),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (subjects.isNotEmpty) ...[
          SectionHeader(title: l.elLessonProgress),
          for (final s in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => context.push('/edu/learn/subject/${s['id']}'),
                padding: const EdgeInsets.all(14),
                child: Builder(builder: (context) {
                  final pr = asJson(s['progress']);
                  final total = asIntOr(pr['total']);
                  final done = asIntOr(pr['completed']);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(eduNames(context, s).title, style: context.serif(14.5)),
                    const SizedBox(height: 8),
                    total == 0
                        ? Text(l.elNoLessonsYet, style: context.sans(12, color: p.muted))
                        : EduProgressBar(value: done / total, label: l.elDoneOf(eduNumber(context, done), eduNumber(context, total))),
                  ]);
                }),
              ),
            ),
        ],
        for (final c in classes) _ClassProgress(entry: c),
        if (quizzes.isNotEmpty) ...[
          SectionHeader(title: l.elQuizzes),
          for (final q in quizzes) Padding(padding: const EdgeInsets.only(bottom: 8), child: QuizCard(quiz: q)),
        ],
        if (bookmarks.isNotEmpty) ...[
          SectionHeader(title: l.elBookmarks),
          for (final b in bookmarks)
            TrackTile(
              title: asStr(b['title']) ?? '',
              subtitle: asStr(b['subject_name']),
              leading: ListThumb(icon: asBool(b['completed']) ? Icons.check_rounded : Icons.bookmark_rounded, active: true),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/edu/learn/lesson/${b['lesson_id']}'),
            ),
        ],
      ],
    );
  }
}

/// One class: attendance summary and the PUBLISHED marks of each subject (never drafts).
class _ClassProgress extends StatelessWidget {
  const _ClassProgress({required this.entry});
  final Json entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final c = asJson(entry['class']);
    final att = entry['attendance'] is Map ? asJson(entry['attendance']) : null;
    final courses = asJsonList(entry['courses']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(title: asStr(c['name']) ?? '', trailing: l.eduDetails, onTrailingTap: () => context.push('/edu/class/${c['id']}?tab=results')),
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (att != null) ...[
            Text(l.elAttendance, style: context.sans(12, weight: FontWeight.w700, color: p.accentText)),
            const SizedBox(height: 6),
            att['rate'] == null
                ? Text(l.elNoSessionsYet, style: context.sans(12.5, color: p.muted))
                : EduProgressBar(
                    value: asDouble(att['rate']) / 100,
                    label: l.elAttendanceSummary('${asDouble(att['rate']).toStringAsFixed(0)}%', asIntOr(att['present']) + asIntOr(att['late']), asIntOr(att['absent']), asIntOr(att['excused'])),
                  ),
            const SizedBox(height: 12),
          ],
          Text(l.elPublishedResults, style: context.sans(12, weight: FontWeight.w700, color: p.accentText)),
          const SizedBox(height: 6),
          if (courses.isEmpty) Text(l.elNoPublishedResults, style: context.sans(12.5, color: p.muted)),
          for (final co in courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(child: Text('${asJson(co['course'])['name']}', style: context.sans(13))),
                Text(co['total_percent'] == null ? l.elPending : '${_n(co['total_percent'])}%', style: context.sans(13, weight: FontWeight.w700, color: co['total_percent'] == null ? p.muted : AppColors.success)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

// =============================================================================
// More: the rest of ትምህርት and the way to the other sections
// =============================================================================
class EduMoreScreen extends ConsumerWidget {
  const EduMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final access = user?.moduleAccess;
    return PatternScaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(l.elTabMore), actions: const [ContextualHelpButton(screenRoute: '/edu/more')]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          SettingsGroup(title: l.hubEducation, children: [
            SettingsTile(key: const ValueKey('edu-more-library'), icon: Icons.local_library_rounded, label: l.libTitle, onTap: () => context.go('/edu/library')),
            SettingsTile(key: const ValueKey('edu-more-services'), icon: Icons.assignment_ind_outlined, label: l.eaSelfService, onTap: () => context.push('/edu/services')),
            SettingsTile(icon: Icons.timeline_rounded, label: l.eaJourney, onTap: () => context.push('/edu/services?tab=journey')),
            SettingsTile(icon: Icons.how_to_reg_rounded, label: l.eduRegister, onTap: () => context.push('/edu/register')),
            SettingsTile(icon: Icons.search_rounded, label: l.search, onTap: () => context.push('/edu/search')),
          ]),
          if (user != null && (user.isSuperAdmin || user.canAny([Perm.educationManage, Perm.educationRegister, Perm.educationContent, Perm.educationReports, Perm.educationCertify])))
            SettingsGroup(title: l.courseManagement, children: [
              SettingsTile(
                key: const ValueKey('edu-course-management'),
                icon: Icons.tune_rounded,
                label: l.courseManagement,
                onTap: () => context.push('/edu/manage'),
              ),
            ]),
          SettingsGroup(title: l.elOtherSections, children: [
            SettingsTile(key: const ValueKey('edu-more-programs'), icon: Icons.event_note_rounded, label: l.navPrograms, onTap: () => context.go('/programs')),
            if (access?.mezmur ?? true) SettingsTile(icon: Icons.music_note_rounded, label: l.hubMezmur, onTap: () => context.go('/home')),
            SettingsTile(key: const ValueKey('edu-more-settings'), icon: Icons.settings_rounded, label: l.navSettings, onTap: () => context.go('/settings?from=edu')),
            SettingsTile(icon: Icons.help_outline_rounded, label: l.elGuidanceCenter, onTap: () => context.push('/guidance')),
          ]),
        ],
      ),
    );
  }
}
