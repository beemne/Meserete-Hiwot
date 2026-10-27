import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../services/file_opening_service.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../auth/session.dart';

final announcementsFeedProvider = FutureProvider.autoDispose.family<List<Json>, ({int? courseId, int? classId})>(
  (ref, params) => ref.watch(eduRepositoryProvider).announcementsFeed(courseId: params.courseId, classId: params.classId),
);

final teacherAnnouncementsProvider = FutureProvider.autoDispose.family<List<Json>, int?>(
  (ref, courseId) => ref.watch(eduRepositoryProvider).teacherAnnouncements(courseId: courseId),
);

/// Google Classroom-inspired class announcements screen and stream.
class EduAnnouncementsScreen extends ConsumerWidget {
  const EduAnnouncementsScreen({super.key, this.courseId, this.classId});
  final int? courseId;
  final int? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final session = ref.watch(sessionProvider);
    final canPost = session is SignedIn &&
        (session.user.can(Perm.educationManage) ||
            session.user.can(Perm.educationContent) ||
            session.user.isSuperAdmin);

    final params = (courseId: courseId, classId: classId);
    final feedAsync = ref.watch(announcementsFeedProvider(params));

    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.elAnnouncements),
        actions: [
          IconButton(
            tooltip: isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(announcementsFeedProvider(params)),
          ),
        ],
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.maroon,
              foregroundColor: AppColors.goldLight,
              icon: const Icon(Icons.campaign_rounded),
              label: Text(l.elNewAnnouncement),
              onPressed: () => _postAnnouncementDialog(context, ref, params),
            )
          : null,
      body: AsyncView<List<Json>>(
        value: feedAsync,
        onRetry: () => ref.invalidate(announcementsFeedProvider(params)),
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: EmptyView(
                icon: Icons.campaign_outlined,
                message: l.elNoAnnouncements,
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async => ref.invalidate(announcementsFeedProvider(params)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: announcements.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final ann = announcements[i];
                final id = asIntOr(ann['id']);
                final title = asStr(ann['title']) ?? '';
                final body = asStr(ann['body']) ?? '';
                final teacherName = asStr(ann['teacher_name']) ?? 'Teacher';
                final courseName = asStr(ann['course_name']);
                final publishedAt = asDate(ann['published_at']) ?? asDate(ann['created_at']);
                final attachments = asJsonList(ann['attachments']);
                final canManage = asBool(ann['can_manage']);

                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Teacher name, class, date, manage action
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.maroon.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.campaign_rounded, color: AppColors.maroon, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.elTeacherPosted(teacherName),
                                  style: context.sans(14, weight: FontWeight.w700, color: p.text),
                                ),
                                if (courseName != null || publishedAt != null)
                                  Text(
                                    [?courseName, if (publishedAt != null) f.date(publishedAt, withWeekday: true)].join(' · '),
                                    style: context.sans(11.5, color: p.muted),
                                  ),
                              ],
                            ),
                          ),
                          if (canManage)
                            IconButton(
                              tooltip: l.delete,
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                              onPressed: () async {
                                final ok = await showConfirm(context, isEn ? 'Delete this announcement?' : 'ይህ ማስታወቂያ ይሰረዝ?', destructive: true);
                                if (ok && context.mounted) {
                                  await runWithProgress(context, () => ref.read(eduRepositoryProvider).deleteAnnouncement(id));
                                  ref.invalidate(announcementsFeedProvider(params));
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Title
                      if (title.isNotEmpty) ...[
                        Text(
                          title,
                          style: context.serif(15.5, weight: FontWeight.w700, color: AppColors.maroon),
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Body text
                      Text(
                        body,
                        style: context.sans(13.5, height: 1.5, color: p.text),
                      ),

                      // Attachments
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        ...attachments.map((att) {
                          final attName = asStr(att['name']) ?? 'Resource';
                          final attPath = asStr(att['path']);
                          final attUrl = asStr(att['url']);
                          final mime = asStr(att['mime']);
                          final source = attPath != null ? '/edu/files/$attPath' : (attUrl ?? '');

                          return InkWell(
                            onTap: () {
                              if (source.isNotEmpty) {
                                ref.read(fileOpeningServiceProvider).openFile(
                                  context,
                                  source: source,
                                  filename: attName,
                                  mime: mime,
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.goldDark),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      attName,
                                      style: context.sans(12.5, color: AppColors.maroon, weight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.goldDark),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static Future<void> _postAnnouncementDialog(
    BuildContext context,
    WidgetRef ref,
    ({int? courseId, int? classId}) params,
  ) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    int selectedGrade = 1;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: AppColors.maroon, size: 24),
                      const SizedBox(width: 10),
                      Text(l.elNewAnnouncement, style: ctx.serif(17, weight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Title (Optional)' : 'ርእስ (አማራጭ)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: '${l.elAnnouncementBody} *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedGrade,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Target Grade Level' : 'ዒላማ ክፍል ደረጃ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      for (int g = 1; g <= 12; g++)
                        DropdownMenuItem<int>(
                          value: g,
                          child: Text(isEn ? 'Grade $g' : '$gኛ ክፍል'),
                        ),
                    ],
                    onChanged: (g) {
                      if (g != null) setModalState(() => selectedGrade = g);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: AppColors.goldLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(l.elPostAnnouncement),
                    onPressed: () async {
                      final body = bodyCtrl.text.trim();
                      if (body.isEmpty) {
                        showSnack(ctx, isEn ? 'Please enter a message' : 'እባክዎ መልእክት ያስገቡ');
                        return;
                      }
                      Navigator.pop(ctx);
                      await runWithProgress(
                        context,
                        () => ref.read(eduRepositoryProvider).postAnnouncement({
                          'title': titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
                          'body': body,
                          'grade': selectedGrade,
                          'status': 'published',
                        }),
                      );
                      ref.invalidate(announcementsFeedProvider(params));
                    },
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
