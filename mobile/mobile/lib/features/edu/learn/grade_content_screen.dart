import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../../widgets/typed_picker.dart';
import '../../auth/session.dart';
import 'edu_widgets.dart';

class SubjectGradeKey {
  const SubjectGradeKey({required this.subjectId, required this.gradeNumber});
  final int subjectId;
  final int gradeNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubjectGradeKey &&
          runtimeType == other.runtimeType &&
          subjectId == other.subjectId &&
          gradeNumber == other.gradeNumber;

  @override
  int get hashCode => Object.hash(subjectId, gradeNumber);
}

final subjectGradeContentProvider =
    FutureProvider.autoDispose.family<Json, SubjectGradeKey>((ref, key) {
  return ref.watch(eduRepositoryProvider).subjectGradeContent(key.subjectId, key.gradeNumber);
});

class EduGradeContentScreen extends ConsumerWidget {
  const EduGradeContentScreen({
    super.key,
    required this.subjectId,
    required this.gradeNumber,
  });

  final int subjectId;
  final int gradeNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final key = SubjectGradeKey(subjectId: subjectId, gradeNumber: gradeNumber);
    final asyncData = ref.watch(subjectGradeContentProvider(key));

    final session = ref.watch(sessionProvider);
    final hasAdminRights = session is SignedIn &&
        (session.user.can(Perm.educationContent) ||
            session.user.can(Perm.educationManage) ||
            session.user.isSuperAdmin);

    void handleBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/edu/subject/$subjectId/grades');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        handleBack();
      },
      child: PatternScaffold(
        appBar: AppBar(
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: l.isEn ? 'Back to grades' : 'ወደ ክፍሎች ተመለስ',
            onPressed: handleBack,
          ),
          title: Text(
            isEn ? 'Grade $gradeNumber Content' : '$gradeNumberኛ ክፍል ይዘት',
            style: context.serif(18, weight: FontWeight.w700, color: Colors.white),
          ),
          actions: [
            if (hasAdminRights)
              IconButton(
                tooltip: l.elAddDirectMaterial,
                icon: const Icon(Icons.note_add_outlined),
                onPressed: () => _showAddDirectMaterialModal(context, ref, subjectId, gradeNumber, key),
              ),
          ],
        ),
        body: AsyncView<Json>(
          value: asyncData,
          onRetry: () => ref.invalidate(subjectGradeContentProvider(key)),
          data: (data) {
            final subject = data['subject'] is Map ? asJson(data['subject']) : <String, dynamic>{};
            final grade = data['grade'] is Map ? asJson(data['grade']) : <String, dynamic>{};
            final subjectName = asStr(subject['name']) ?? (isEn ? 'Subject' : 'የትምህርት ዓይነት');
            final gradeName = asStr(grade['grade_name']) ?? '$gradeNumberኛ ክፍል';
            final courses = asJsonList(data['courses']);
            final lessons = asJsonList(data['lessons']);
            final materials = asJsonList(data['materials']);
            final quizzes = asJsonList(data['quizzes']);
            final hasContent = asBool(data['has_content']) ||
                courses.isNotEmpty ||
                lessons.isNotEmpty ||
                materials.isNotEmpty ||
                quizzes.isNotEmpty;
            final canManage = asBool(data['can_manage']);

            final session = ref.watch(sessionProvider);
            final userCanEdit = canManage ||
                (session is SignedIn &&
                    (session.user.can(Perm.educationContent) ||
                        session.user.can(Perm.educationManage) ||
                        session.user.isSuperAdmin));

            return RefreshIndicator(
              color: AppColors.gold,
              onRefresh: () async => ref.invalidate(subjectGradeContentProvider(key)),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  // Title Hero Header: Both subject and grade remain clearly identifiable
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.maroon,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.maroon, AppColors.maroonDark],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.maroonDark.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.goldLight.withValues(alpha: 0.6),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                gradeName,
                                style: context.sans(
                                  11,
                                  weight: FontWeight.w700,
                                  color: AppColors.goldLight,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (hasContent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isEn ? 'Active Content' : 'ይዘት ያለው',
                                  style: context.sans(
                                    10.5,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$subjectName — $gradeName',
                          style: context.serif(
                            20,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn
                              ? 'Lessons, reference documents, and quizzes'
                              : 'ክፍለ ትምህርቶች፣ የማንበቢያ ሰነዶች እና ፈተናዎች',
                          style: context.sans(12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // If empty: Show informative Church-styled empty state
                  if (!hasContent) ...[
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                      radius: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_stories_outlined,
                              size: 32,
                              color: AppColors.maroon,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isEn
                                ? 'No content added for this grade yet'
                                : 'ለዚህ ክፍል እስካሁን የተጨመረ ይዘት የለም',
                            textAlign: TextAlign.center,
                            style: context.serif(
                              16.5,
                              weight: FontWeight.w700,
                              color: AppColors.maroon,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isEn
                                ? 'Lessons, reference materials, and quizzes will appear here when added by educators.'
                                : 'አስተዳዳሪዎች ወይም መምህራን ለዚህ ክፍል ትምህርቶችን፣ ማጣቀሻዎችን ወይም ፈተናዎችን ሲጨምሩ እዚህ ይታያሉ።',
                            textAlign: TextAlign.center,
                            style: context.sans(12.5, color: context.palette.muted),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 1. Courses Section (if any courses are attached to this grade level)
                    if (courses.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.school_rounded,
                        title: isEn ? 'Courses' : 'ኮርሶች',
                        count: courses.length,
                      ),
                      const SizedBox(height: 8),
                      ...courses.map((c) {
                        final courseName = asStr(c['name']) ?? 'Course';
                        final code = asStr(c['code']);
                        final instructor = asStr(c['instructor_name']);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.maroon.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.class_rounded, color: AppColors.maroon),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        courseName,
                                        style: context.serif(14.5, weight: FontWeight.w700),
                                      ),
                                      if (instructor != null || code != null)
                                        Text(
                                          [?code, ?instructor].join(' · '),
                                          style: context.sans(11.5, color: context.palette.muted),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // 2. Lessons Section
                    if (lessons.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.menu_book_rounded,
                        title: isEn ? 'Lessons' : 'ክፍለ ትምህርቶች',
                        count: lessons.length,
                      ),
                      const SizedBox(height: 8),
                      ...lessons.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final lesson = entry.value;
                        return LessonTile(
                          lesson: lesson,
                          number: idx + 1,
                          onTap: () {
                            final id = asIntOr(lesson['id']);
                            if (id > 0) {
                              context.push('/edu/learn/lesson/$id');
                            }
                          },
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // 3. Materials & Documents Section
                    if (materials.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _SectionHeader(
                              icon: Icons.picture_as_pdf_rounded,
                              title: isEn ? 'Reference Documents & Materials' : 'የማንበቢያ ሰነዶች እና ማጣቀሻዎች',
                              count: materials.length,
                            ),
                          ),
                          if (userCanEdit)
                            TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: AppColors.maroon),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(l.elAddDirectMaterial, style: const TextStyle(fontSize: 12)),
                              onPressed: () => _showAddDirectMaterialModal(context, ref, subjectId, gradeNumber, key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...materials.map((m) => MaterialTile(material: m)),
                      const SizedBox(height: 16),
                    ] else if (userCanEdit) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(l.elAddDirectMaterial),
                        onPressed: () => _showAddDirectMaterialModal(context, ref, subjectId, gradeNumber, key),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. Quizzes Section
                    if (quizzes.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.fact_check_rounded,
                        title: isEn ? 'Quizzes & Assessments' : 'ፈተናዎች እና ጥያቄዎች',
                        count: quizzes.length,
                      ),
                      const SizedBox(height: 8),
                      ...quizzes.map((q) => QuizCard(quiz: q)),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.maroon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: context.serif(15.5, weight: FontWeight.w700, color: AppColors.maroon),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: context.sans(
              11,
              weight: FontWeight.w700,
              color: AppColors.maroon,
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showAddDirectMaterialModal(
  BuildContext context,
  WidgetRef ref,
  int subjectId,
  int gradeNumber,
  SubjectGradeKey key,
) async {
  final l = context.l10n;
  final isEn = l.isEn;
  final repo = ref.read(eduRepositoryProvider);
  String uploadType = 'file';
  final titleCtrl = TextEditingController();
  final urlCtrl = TextEditingController();
  String? pickedFilePath;
  String? pickedFileName;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final p = ctx.palette;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.note_add_outlined, color: AppColors.maroon, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEn ? 'Add Grade $gradeNumber Material' : 'ለ$gradeNumberኛ ክፍል ግብዓት አክል',
                        style: ctx.serif(17, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text(isEn ? 'Document / PDF' : 'ሰነድ / ፒዲኤፍ')),
                        selected: uploadType == 'file',
                        selectedColor: AppColors.maroon,
                        labelStyle: TextStyle(color: uploadType == 'file' ? Colors.white : p.text, fontWeight: FontWeight.w600),
                        onSelected: (_) => setModalState(() => uploadType = 'file'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text(isEn ? 'Web / Video Link' : 'የድረ-ገጽ ማስፈንጠሪያ')),
                        selected: uploadType == 'link',
                        selectedColor: AppColors.maroon,
                        labelStyle: TextStyle(color: uploadType == 'link' ? Colors.white : p.text, fontWeight: FontWeight.w600),
                        onSelected: (_) => setModalState(() => uploadType = 'link'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: '${isEn ? "Material Title" : "የግብዓቱ ርእስ"} *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                if (uploadType == 'file') ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      pickedFileName != null ? pickedFileName! : (isEn ? 'Choose PDF or Document' : 'ፒዲኤፍ ወይም ሰነድ ይምረጡ'),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () async {
                      final file = await pickOfKind('document');
                      if (file != null) {
                        setModalState(() {
                          pickedFilePath = file.path;
                          pickedFileName = file.name;
                          if (titleCtrl.text.isEmpty) titleCtrl.text = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                        });
                      }
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: '${isEn ? "URL / Link" : "የድረ-ገጽ አድራሻ (URL)"} *',
                      hintText: 'https://...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
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
                    if (uploadType == 'file') {
                      if (pickedFilePath == null) {
                        showSnack(ctx, isEn ? 'Please select a file' : 'እባክዎ ፋይል ይምረጡ');
                        return;
                      }
                      Navigator.pop(ctx);
                      await runWithProgress(context, () => repo.addDirectMaterialFile(subjectId, gradeNumber, pickedFilePath!, title: title));
                    } else {
                      final url = urlCtrl.text.trim();
                      if (url.isEmpty || !url.startsWith('http')) {
                        showSnack(ctx, isEn ? 'Please enter a valid URL' : 'እባክዎ ትክክለኛ የድረ-ገጽ አድራሻ ያስገቡ');
                        return;
                      }
                      Navigator.pop(ctx);
                      final kind = url.contains('youtube') || url.contains('youtu.be') ? 'video' : 'link';
                      await runWithProgress(context, () => repo.addDirectMaterialLink(subjectId, gradeNumber, kind: kind, title: title, url: url));
                    }
                    ref.invalidate(subjectGradeContentProvider(key));
                  },
                  child: Text(isEn ? 'Save Material' : 'ግብዓቱን መዝግብ'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
