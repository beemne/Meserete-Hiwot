import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';

final adminGradesProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => ref.watch(eduRepositoryProvider).adminGrades(),
);

class EduAdminGradesScreen extends ConsumerWidget {
  const EduAdminGradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final gradesAsync = ref.watch(adminGradesProvider);

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Canonical Grades (1–12)' : 'ቀኖናዊ ክፍሎች (1–12)'),
        actions: [
          IconButton(
            tooltip: isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminGradesProvider),
          ),
        ],
      ),
      body: AsyncView<List<Json>>(
        value: gradesAsync,
        onRetry: () => ref.invalidate(adminGradesProvider),
        data: (grades) {
          if (grades.isEmpty) {
            return Center(
              child: EmptyView(
                icon: Icons.school_outlined,
                message: isEn ? 'No grades configured' : 'ምንም ክፍሎች አልተዋቀሩም',
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async => ref.invalidate(adminGradesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Info banner explaining canonical admin role
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.maroon,
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.maroon, AppColors.maroonDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.maroonDark.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 1.2),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.goldLight, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Admin Grade Management' : 'የአካዳሚክ ክፍሎች አስተዳደር',
                              style: context.serif(16, weight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isEn
                                  ? 'All 12 canonical grade levels are managed centrally here without affecting individual user assignments.'
                                  : 'ሁሉም 12ቱ ቀኖናዊ የክፍል ደረጃዎች የተጠቃሚውን የግል ክፍል ምደባ ሳይነኩ እዚህ ማስተዳደር ይቻላል።',
                              style: context.sans(11.5, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // List of 12 Canonical Grades
                ...grades.map((grade) {
                  final id = asIntOr(grade['id']);
                  final order = asInt(grade['sort_order']) ?? 0;
                  final nameAm = asStr(grade['name']) ?? '$orderኛ ክፍል';
                  final nameEn = asStr(grade['name_en']) ?? 'Grade $order';
                  final displayName = isEn ? nameEn : nameAm;
                  final secondaryName = isEn ? nameAm : nameEn;
                  final isActive = asBool(grade['is_active']);
                  final classCount = asIntOr(grade['class_count']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => _showGradeDetail(context, ref, id, displayName),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.maroon.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.gold, width: 1.4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$order',
                              style: context.serif(17, weight: FontWeight.w700, color: AppColors.maroon),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, style: context.sans(15, weight: FontWeight.w600, color: p.text)),
                                const SizedBox(height: 3),
                                Text(secondaryName, style: context.sans(12, color: p.muted)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                                            : p.border,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isActive
                                            ? (isEn ? 'Active' : 'ንቁ')
                                            : (isEn ? 'Inactive' : 'ቦዝኗል'),
                                        style: context.sans(
                                          11,
                                          weight: FontWeight.w600,
                                          color: isActive ? const Color(0xFF2E7D32) : p.muted,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isEn ? 'Canonical' : 'ቀኖናዊ',
                                        style: context.sans(11, weight: FontWeight.w600, color: AppColors.maroon),
                                      ),
                                    ),
                                    if (classCount > 0)
                                      Text(
                                        isEn ? '$classCount classes' : '$classCount ክፍሎች',
                                        style: context.sans(11.5, color: p.muted),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: isEn ? 'Edit Grade' : 'ክፍሉን አርትዕ',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _editGradeDialog(context, ref, grade),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
                        ],
                      ),
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

  static Future<void> _editGradeDialog(BuildContext context, WidgetRef ref, Json grade) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final id = asIntOr(grade['id']);
    final nameCtrl = TextEditingController(text: asStr(grade['name']) ?? '');
    final nameEnCtrl = TextEditingController(text: asStr(grade['name_en']) ?? '');
    bool isActive = asBool(grade['is_active']);

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
                      const Icon(Icons.edit_rounded, color: AppColors.maroon, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isEn ? 'Edit Grade Level' : 'የክፍል ደረጃውን አርትዕ',
                        style: ctx.serif(17, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: '${isEn ? "Name (Amharic)" : "ስም (አማርኛ)"} *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameEnCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Name (English)' : 'ስም (እንግሊዝኛ)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(isEn ? 'Active Grade' : 'ንቁ የክፍል ደረጃ'),
                    subtitle: Text(
                      isEn
                          ? 'Inactive grades are hidden from normal student registration'
                          : 'ቦዝኗል የሆኑ ክፍሎች ከአዳዲስ ተማሪዎች ምዝገባ ይደበቃሉ',
                    ),
                    value: isActive,
                    activeThumbColor: AppColors.maroon,
                    onChanged: (v) => setModalState(() => isActive = v),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: AppColors.goldLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        showSnack(ctx, isEn ? 'Please enter a name' : 'እባክዎ ስም ያስገቡ');
                        return;
                      }
                      Navigator.pop(ctx);
                      await runWithProgress(
                        context,
                        () => ref.read(eduRepositoryProvider).updateGradeLevel(id, {
                          'name': name,
                          'name_en': nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
                          'is_active': isActive ? 1 : 0,
                        }),
                      );
                      ref.invalidate(adminGradesProvider);
                    },
                    child: Text(isEn ? 'Save Changes' : 'ለውጦችን መዝግብ'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showGradeDetail(BuildContext context, WidgetRef ref, int id, String title) async {
    final l = context.l10n;
    final isEn = l.isEn;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => FutureBuilder<Json>(
        future: ref.read(eduRepositoryProvider).adminGradeDetail(id),
        builder: (ctx, snapshot) {
          final p = ctx.palette;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 250, child: LoadingView());
          }
          final detail = snapshot.data;
          if (detail == null) {
            return SizedBox(
              height: 200,
              child: Center(child: Text(isEn ? 'Could not load grade details' : 'ዝርዝሩን መጫን አልተቻለም')),
            );
          }

          final classes = asJsonList(detail['classes']);
          final directMaterials = asJsonList(detail['direct_materials']);

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.4,
            builder: (ctx, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(title, style: ctx.serif(19, weight: FontWeight.w700)),
                const SizedBox(height: 14),

                Text(
                  isEn ? 'Associated Classes (${classes.length})' : 'የተመደቡ ክፍሎች (${classes.length})',
                  style: ctx.sans(14, weight: FontWeight.w700, color: AppColors.maroon),
                ),
                const SizedBox(height: 6),
                if (classes.isEmpty)
                  Text(isEn ? 'No active classes associated.' : 'ምንም የተመደበ ክፍል የለም።', style: ctx.sans(12.5, color: p.muted))
                else
                  ...classes.map((c) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.group_rounded, color: AppColors.maroon),
                        title: Text(asStr(c['name']) ?? 'Class'),
                        subtitle: Text('${c['code'] ?? ''} · ${c['status'] ?? ''}'),
                      )),

                const SizedBox(height: 16),
                Text(
                  isEn ? 'Direct Materials (${directMaterials.length})' : 'ቀጥታ የትምህርት ግብዓቶች (${directMaterials.length})',
                  style: ctx.sans(14, weight: FontWeight.w700, color: AppColors.maroon),
                ),
                const SizedBox(height: 6),
                if (directMaterials.isEmpty)
                  Text(isEn ? 'No direct materials for this grade.' : 'ለዚህ ክፍል ምንም ቀጥታ ግብዓቶች አልተጫኑም።', style: ctx.sans(12.5, color: p.muted))
                else
                  ...directMaterials.map((m) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.maroon),
                        title: Text(asStr(m['title']) ?? asStr(m['name']) ?? 'Material'),
                        subtitle: Text(asStr(m['kind']) ?? 'file'),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}
