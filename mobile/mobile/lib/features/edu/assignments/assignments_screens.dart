import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../widgets/typed_picker.dart';
import '../../auth/session.dart';

final classroomAssignmentsProvider = FutureProvider.autoDispose.family<List<Json>, int?>(
  (ref, courseId) => ref.watch(eduRepositoryProvider).classroomAssignments(courseId: courseId),
);

final classroomAssignmentDetailProvider = FutureProvider.autoDispose.family<Json, int>(
  (ref, id) => ref.watch(eduRepositoryProvider).classroomAssignmentDetail(id),
);

final teacherAssignmentsProvider = FutureProvider.autoDispose.family<List<Json>, int?>(
  (ref, courseId) => ref.watch(eduRepositoryProvider).teacherClassroomAssignments(courseId: courseId),
);

final assignmentSubmissionsProvider = FutureProvider.autoDispose.family<List<Json>, int>(
  (ref, assignmentId) => ref.watch(eduRepositoryProvider).classroomSubmissions(assignmentId),
);

/// Main assignments screen providing student dashboard and teacher management.
class EduAssignmentsScreen extends ConsumerStatefulWidget {
  const EduAssignmentsScreen({super.key, this.courseId});
  final int? courseId;

  @override
  ConsumerState<EduAssignmentsScreen> createState() => _EduAssignmentsScreenState();
}

class _EduAssignmentsScreenState extends ConsumerState<EduAssignmentsScreen> with SingleTickerProviderStateMixin {
  String _statusFilter = 'all'; // 'all', 'assigned', 'due_soon', 'turned_in', 'graded', 'overdue'
  TabController? _tabController;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final session = ref.watch(sessionProvider);
    final canTeach = session is SignedIn &&
        (session.user.can(Perm.educationManage) ||
            session.user.can(Perm.educationContent) ||
            session.user.isSuperAdmin);

    if (canTeach && _tabController == null) {
      _tabController = TabController(length: 2, vsync: this);
    }

    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.elAssignments),
        bottom: canTeach && _tabController != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.gold,
                labelColor: AppColors.goldLight,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: isEn ? 'My Work' : 'የእኔ ሥራዎች', icon: const Icon(Icons.assignment_outlined, size: 18)),
                  Tab(text: isEn ? 'Teacher Desk' : 'የአስተማሪ ክፍል', icon: const Icon(Icons.rate_review_outlined, size: 18)),
                ],
              )
            : null,
      ),
      body: canTeach && _tabController != null
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildStudentView(context),
                _buildTeacherView(context),
              ],
            )
          : _buildStudentView(context),
    );
  }

  Widget _buildStudentView(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final listAsync = ref.watch(classroomAssignmentsProvider(widget.courseId));

    return Column(
      children: [
        // Filter chips inspired by Google Classroom
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _filterChip('all', isEn ? 'All' : 'ሁሉም'),
              const SizedBox(width: 6),
              _filterChip('assigned', l.elAssigned),
              const SizedBox(width: 6),
              _filterChip('due_soon', l.elDueSoon),
              const SizedBox(width: 6),
              _filterChip('turned_in', l.elTurnedIn),
              const SizedBox(width: 6),
              _filterChip('graded', l.elGraded),
              const SizedBox(width: 6),
              _filterChip('overdue', l.elOverdue),
            ],
          ),
        ),

        Expanded(
          child: AsyncView<List<Json>>(
            value: listAsync,
            onRetry: () => ref.invalidate(classroomAssignmentsProvider(widget.courseId)),
            data: (all) {
              final filtered = _statusFilter == 'all'
                  ? all
                  : all.where((a) => asStr(a['status_group']) == _statusFilter).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: EmptyView(
                    icon: Icons.assignment_outlined,
                    message: l.elNoAssignments,
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async => ref.invalidate(classroomAssignmentsProvider(widget.courseId)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = filtered[i];
                    final id = asIntOr(a['id']);
                    final title = asStr(a['title']) ?? 'Assignment';
                    final courseName = asStr(a['course_name']);
                    final grade = asInt(a['grade']);
                    final dueAt = asDate(a['due_at']);
                    final maxScore = asStr(a['max_score']) ?? '100';
                    final group = asStr(a['status_group']) ?? 'assigned';
                    final sub = a['my_submission'] is Map ? asJson(a['my_submission']) : null;
                    final score = sub?['score'] != null ? asStr(sub!['score']) : null;

                    return AppCard(
                      onTap: () => context.push('/edu/assignment/$id').then((_) {
                        ref.invalidate(classroomAssignmentsProvider(widget.courseId));
                      }),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.maroon.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.assignment_rounded, color: AppColors.maroon, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: context.sans(15, weight: FontWeight.w700, color: p.text),
                                    ),
                                    if (courseName != null || grade != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        [?courseName, if (grade != null) 'Grade $grade'].join(' · '),
                                        style: context.sans(12, color: p.muted),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              _statusPill(context, group, score, maxScore),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (dueAt != null) ...[
                                Icon(Icons.schedule_rounded, size: 14, color: group == 'overdue' ? AppColors.danger : p.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    l.elDueDate(f.date(dueAt, withWeekday: true)),
                                    style: context.sans(
                                      11.5,
                                      color: group == 'overdue' ? AppColors.danger : p.muted,
                                      weight: group == 'overdue' ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ] else ...[
                                Expanded(
                                  child: Text(
                                    isEn ? 'No due date' : 'የማስረከቢያ ቀን የለውም',
                                    style: context.sans(11.5, color: p.muted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Text(
                                '${isEn ? "Max" : "ከፍተኛ"}: $maxScore',
                                style: context.sans(11.5, color: p.faint),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String group, String label) {
    final isSelected = _statusFilter == group;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.maroon,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      onSelected: (_) => setState(() => _statusFilter = group),
    );
  }

  Widget _statusPill(BuildContext context, String group, String? score, String maxScore) {
    final l = context.l10n;
    final p = context.palette;
    Color bg;
    Color fg;
    String text;

    switch (group) {
      case 'graded':
        bg = const Color(0xFF2E7D32).withValues(alpha: 0.15);
        fg = const Color(0xFF2E7D32);
        text = score != null ? '$score/$maxScore' : l.elGraded;
        break;
      case 'turned_in':
        bg = const Color(0xFF1976D2).withValues(alpha: 0.15);
        fg = const Color(0xFF1976D2);
        text = l.elTurnedIn;
        break;
      case 'overdue':
        bg = AppColors.danger.withValues(alpha: 0.15);
        fg = AppColors.danger;
        text = l.elOverdue;
        break;
      case 'due_soon':
        bg = AppColors.gold.withValues(alpha: 0.2);
        fg = AppColors.goldDark;
        text = l.elDueSoon;
        break;
      default:
        bg = p.border;
        fg = p.muted;
        text = l.elAssigned;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: context.sans(11, weight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildTeacherView(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final listAsync = ref.watch(teacherAssignmentsProvider(widget.courseId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                isEn ? 'Created Assignments' : 'የተዘጋጁ የቤት ሥራዎች',
                style: context.serif(16, weight: FontWeight.w700),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: AppColors.goldLight,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l.elCreateAssignment),
                onPressed: () => _createAssignmentDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<Json>>(
            value: listAsync,
            onRetry: () => ref.invalidate(teacherAssignmentsProvider(widget.courseId)),
            data: (assignments) {
              if (assignments.isEmpty) {
                return Center(
                  child: EmptyView(
                    icon: Icons.assignment_turned_in_outlined,
                    message: isEn ? 'No assignments created yet.' : 'ምንም የተዘጋጀ የቤት ሥራ የለም።',
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.gold,
                onRefresh: () async => ref.invalidate(teacherAssignmentsProvider(widget.courseId)),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: assignments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = assignments[i];
                    final id = asIntOr(a['id']);
                    final title = asStr(a['title']) ?? '';
                    final isDraft = asStr(a['status']) == 'draft';

                    return AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title, style: context.sans(15, weight: FontWeight.w700)),
                              ),
                              if (isDraft)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(4)),
                                  child: Text(isEn ? 'Draft' : 'ረቂቅ', style: context.sans(11, color: p.muted)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.rate_review_rounded, size: 16),
                                label: Text(l.elSubmissions),
                                onPressed: () => _viewSubmissionsModal(context, id, title),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: l.delete,
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                onPressed: () async {
                                  final ok = await showConfirm(context, isEn ? 'Delete assignment "$title"?' : 'የቤት ሥራ "$title" ይሰረዝ?', destructive: true);
                                  if (ok && context.mounted) {
                                    await runWithProgress(context, () => ref.read(eduRepositoryProvider).deleteClassroomAssignment(id));
                                    ref.invalidate(teacherAssignmentsProvider(widget.courseId));
                                    ref.invalidate(classroomAssignmentsProvider(widget.courseId));
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createAssignmentDialog(BuildContext context) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final titleCtrl = TextEditingController();
    final instructionsCtrl = TextEditingController();
    final scoreCtrl = TextEditingController(text: '100');
    int selectedGrade = 1;
    bool publishNow = true;

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
                  Text(l.elCreateAssignment, style: ctx.serif(17, weight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: '${isEn ? "Title" : "ርእስ"} *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructionsCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.elInstructions,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedGrade,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Grade Level (1–12)' : 'የክፍል ደረጃ (1–12)',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: scoreCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${l.elMaxScore} *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: Text(isEn ? 'Publish Immediately' : 'ወዲያውኑ ይለቀቅ'),
                    subtitle: Text(isEn ? 'Students will be notified' : 'ለተማሪዎች ማሳወቂያ ይላካል'),
                    value: publishNow,
                    activeThumbColor: AppColors.maroon,
                    onChanged: (v) => setModalState(() => publishNow = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: AppColors.goldLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        showSnack(ctx, isEn ? 'Please enter a title' : 'እባክዎ ርእስ ያስገቡ');
                        return;
                      }
                      Navigator.pop(ctx);
                      await runWithProgress(
                        context,
                        () => ref.read(eduRepositoryProvider).createClassroomAssignment({
                          'title': title,
                          'instructions': instructionsCtrl.text.trim().isEmpty ? null : instructionsCtrl.text.trim(),
                          'grade': selectedGrade,
                          'max_score': double.tryParse(scoreCtrl.text.trim()) ?? 100.0,
                          'status': publishNow ? 'published' : 'draft',
                        }),
                      );
                      ref.invalidate(teacherAssignmentsProvider(widget.courseId));
                      ref.invalidate(classroomAssignmentsProvider(widget.courseId));
                    },
                    child: Text(isEn ? 'Create Assignment' : 'የቤት ሥራውን ፍጠር'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _viewSubmissionsModal(BuildContext context, int assignmentId, String title) async {
    final l = context.l10n;
    final isEn = l.isEn;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => FutureBuilder<List<Json>>(
        future: ref.read(eduRepositoryProvider).classroomSubmissions(assignmentId),
        builder: (ctx, snapshot) {
          final p = ctx.palette;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 300, child: LoadingView());
          }
          final subs = snapshot.data ?? [];

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (ctx, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: Text(title, style: ctx.serif(17, weight: FontWeight.w700))),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.maroon,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      onPressed: () async {
                        await runWithProgress(context, () => ref.read(eduRepositoryProvider).releaseClassroomGrades(assignmentId));
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(l.elReleaseGrade, style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (subs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(child: Text(isEn ? 'No student submissions yet.' : 'ምንም የተማሪ ምላሽ አልገባም።')),
                  )
                else
                  ...subs.map((s) {
                    final subId = asIntOr(s['id']);
                    final studentName = asStr(s['student_name']) ?? 'Student';
                    final score = s['score'] != null ? asStr(s['score']) : null;
                    final text = asStr(s['text_response']);

                    return AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.maroon),
                              const SizedBox(width: 8),
                              Expanded(child: Text(studentName, style: ctx.sans(14, weight: FontWeight.w700))),
                              if (score != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text('Score: $score', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700, fontSize: 11)),
                                ),
                            ],
                          ),
                          if (text != null && text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(text, style: ctx.sans(12.5)),
                          ],
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.grading_rounded, size: 16),
                              label: Text(l.elGradeSubmission),
                              onPressed: () => _gradeDialog(context, subId, score),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _gradeDialog(BuildContext context, int submissionId, String? currentScore) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final scoreCtrl = TextEditingController(text: currentScore ?? '');
    final feedbackCtrl = TextEditingController();
    bool releaseNow = true;

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
                  Text(l.elGradeSubmission, style: ctx.serif(17, weight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: scoreCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '${isEn ? "Score" : "ውጤት"} *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l.elTeacherFeedback,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: Text(l.elReleaseGrade),
                    value: releaseNow,
                    activeThumbColor: AppColors.maroon,
                    onChanged: (v) => setModalState(() => releaseNow = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: AppColors.goldLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final sc = double.tryParse(scoreCtrl.text.trim());
                      if (sc == null) {
                        showSnack(ctx, isEn ? 'Please enter a valid numeric score' : 'እባክዎ ትክክለኛ የቁጥር ውጤት ያስገቡ');
                        return;
                      }
                      Navigator.pop(ctx);
                      await runWithProgress(
                        context,
                        () => ref.read(eduRepositoryProvider).gradeClassroomSubmission(
                          submissionId,
                          score: sc,
                          feedback: feedbackCtrl.text.trim().isEmpty ? null : feedbackCtrl.text.trim(),
                          release: releaseNow,
                        ),
                      );
                      ref.invalidate(teacherAssignmentsProvider(widget.courseId));
                    },
                    child: Text(isEn ? 'Save Grade' : 'ውጤቱን መዝግብ'),
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

/// Detailed single assignment view for students to review and submit work.
class EduAssignmentDetailScreen extends ConsumerStatefulWidget {
  const EduAssignmentDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<EduAssignmentDetailScreen> createState() => _EduAssignmentDetailScreenState();
}

class _EduAssignmentDetailScreenState extends ConsumerState<EduAssignmentDetailScreen> {
  final _responseCtrl = TextEditingController();
  String? _pickedFilePath;
  String? _pickedFileName;

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final detailAsync = ref.watch(classroomAssignmentDetailProvider(widget.id));

    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.elAssignmentDetail),
      ),
      body: AsyncView<Json>(
        value: detailAsync,
        onRetry: () => ref.invalidate(classroomAssignmentDetailProvider(widget.id)),
        data: (a) {
          final title = asStr(a['title']) ?? 'Assignment';
          final instructions = asStr(a['instructions']);
          final maxScore = asStr(a['max_score']) ?? '100';
          final dueAt = asDate(a['due_at']);
          final sub = a['my_submission'] is Map ? asJson(a['my_submission']) : null;
          final isSubmitted = sub != null;
          final score = sub?['score'] != null ? asStr(sub!['score']) : null;
          final feedback = asStr(sub?['feedback']);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // Hero card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.maroon,
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.maroon, AppColors.maroonDark],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.serif(19, weight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (dueAt != null)
                          _badge(Icons.schedule_rounded, l.elDueDate(f.date(dueAt, withWeekday: true))),
                        _badge(Icons.military_tech_outlined, '${l.elMaxScore}: $maxScore'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Instructions
              if (instructions != null && instructions.isNotEmpty) ...[
                Text(l.elInstructions, style: context.serif(15, weight: FontWeight.w700, color: AppColors.maroon)),
                const SizedBox(height: 6),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(instructions, style: context.sans(13.5, height: 1.5)),
                ),
                const SizedBox(height: 16),
              ],

              // Student Submission Status or Form
              Text(l.elMySubmission, style: context.serif(15, weight: FontWeight.w700, color: AppColors.maroon)),
              const SizedBox(height: 6),

              if (isSubmitted) ...[
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20),
                          const SizedBox(width: 8),
                          Text(l.elTurnedIn, style: context.sans(14, weight: FontWeight.w700, color: const Color(0xFF2E7D32))),
                          const Spacer(),
                          if (sub['submitted_at'] != null)
                            Text(
                              f.date(asDate(sub['submitted_at'])!, withWeekday: false),
                              style: context.sans(11.5, color: p.muted),
                            ),
                        ],
                      ),
                      if (score != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.grade_rounded, color: Color(0xFF2E7D32), size: 20),
                              const SizedBox(width: 8),
                              Text(l.elGradeScore(score, maxScore), style: context.sans(14, weight: FontWeight.w700, color: const Color(0xFF2E7D32))),
                            ],
                          ),
                        ),
                      ],
                      if (feedback != null && feedback.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(l.elTeacherFeedback, style: context.sans(12.5, weight: FontWeight.w700, color: AppColors.maroon)),
                        const SizedBox(height: 2),
                        Text(feedback, style: context.sans(13, color: p.text)),
                      ],
                      if (sub['text_response'] != null) ...[
                        const SizedBox(height: 10),
                        Text(isEn ? 'Your text:' : 'የእርስዎ መልስ:', style: context.sans(12, color: p.muted)),
                        Text(asStr(sub['text_response']) ?? '', style: context.sans(13)),
                      ],
                      if (asJsonList(sub['attachments']).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(isEn ? 'Attached files:' : 'የተያያዙ ሰነዶች:', style: context.sans(12, color: p.muted)),
                        const SizedBox(height: 4),
                        ...asJsonList(sub['attachments']).map((att) {
                          final attName = asStr(att['name']) ?? 'Attachment';
                          final attPath = asStr(att['path']);
                          return InkWell(
                            onTap: () {
                              if (attPath != null) {
                                ref.read(fileOpeningServiceProvider).openFile(
                                  context,
                                  source: '/edu/files/$attPath',
                                  filename: attName,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.goldDark),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(attName, style: context.sans(12.5, color: AppColors.maroon, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
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
                ),
              ] else ...[
                // Submission Form
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _responseCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: l.elYourResponse,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(_pickedFileName ?? l.elAttachFile, overflow: TextOverflow.ellipsis),
                        onPressed: () async {
                          final file = await pickOfKind('document');
                          if (file != null && mounted) {
                            setState(() {
                              _pickedFilePath = file.path;
                              _pickedFileName = file.name;
                            });
                          }
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
                        label: Text(l.elSubmitAssignment),
                        onPressed: () => _submit(context),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final text = _responseCtrl.text.trim();
    if (text.isEmpty && _pickedFilePath == null) {
      showSnack(context, isEn ? 'Please provide a response or attach a file' : 'እባክዎ ጽሑፍ ያስገቡ ወይም ፋይል ያያይዙ');
      return;
    }

    final ok = await showConfirm(context, isEn ? 'Submit assignment response?' : 'የቤት ሥራውን ማስረከብ ይፈልጋሉ?');
    if (!ok || !context.mounted) return;

    await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).submitClassroomAssignment(
        widget.id,
        text: text.isEmpty ? null : text,
        filePath: _pickedFilePath,
      ),
    );

    ref.invalidate(classroomAssignmentDetailProvider(widget.id));
    ref.invalidate(classroomAssignmentsProvider(null));
  }

  Widget _badge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.goldLight),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
