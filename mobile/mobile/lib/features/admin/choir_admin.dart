import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/activity.dart';
import '../../repositories/providers.dart';
import '../../services/program_alarms.dart' show remindBeforeText;
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../programs/program_text.dart';
import 'admin_widgets.dart';

/// Program categories (General, Education, Mezmur …): used for filters, attendance statistics,
/// the calendar and choir scoring. Categories in use are deactivated instead of deleted.
class ProgramCategoriesAdminScreen extends ConsumerStatefulWidget {
  const ProgramCategoriesAdminScreen({super.key});
  @override
  ConsumerState<ProgramCategoriesAdminScreen> createState() => _ProgramCategoriesAdminScreenState();
}

class _ProgramCategoriesAdminScreenState extends ConsumerState<ProgramCategoriesAdminScreen> {
  late Future<List<ProgramCategory>> _list = ref.read(adminRepositoryProvider).programCategories();
  static const _palette = ['#8A7A7D', '#1F5F8B', '#6E1423', '#C8961E', '#2E7D32', '#6A1B9A', '#00838F', '#EF6C00'];

  void _reload() => setState(() => _list = ref.read(adminRepositoryProvider).programCategories());

  Future<void> _edit([ProgramCategory? c]) async {
    final l = context.l10n;
    final name = TextEditingController(text: c?.name);
    final nameEn = TextEditingController(text: c?.nameEn);
    var color = c?.color ?? _palette.first;
    var active = c?.isActive ?? true;
    // Reminder rules of this program type (what new programs of the type start with).
    final offsets = {...?c?.reminderOffsets};
    var every15 = c?.reminderIntervalDays != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          title: Text(c == null ? l.newProgramCategory : l.editProgramCategory),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: l.categoryNameAm)),
            TextField(controller: nameEn, decoration: InputDecoration(labelText: l.categoryNameEn)),
            const SizedBox(height: 12),
            Text(l.categoryColor, style: ctx.sans(13, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final hex in _palette)
                InkWell(
                  onTap: () => setS(() => color = hex),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: hexColor(hex),
                    child: color == hex ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                  ),
                ),
            ]),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.active), value: active, onChanged: (v) => setS(() => active = v)),
            const SizedBox(height: 8),
            Text(l.programTypeReminders, style: ctx.sans(13, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in Program.reminderChoices)
                FilterChip(label: Text(remindBeforeText(l, o)), selected: offsets.contains(o), onSelected: (v) => setS(() => v ? offsets.add(o) : offsets.remove(o))),
            ]),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.remindEvery15Days), value: every15, onChanged: (v) => setS(() => every15 = v)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || !mounted) return;
    final body = {
      'name': name.text.trim(),
      'name_en': nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
      'color': color,
      'is_active': active,
      'reminder_offsets': offsets.isEmpty ? null : (offsets.toList()..sort((a, b) => b.compareTo(a))),
      'reminder_interval_days': every15 ? 15 : null,
    };
    final repo = ref.read(adminRepositoryProvider);
    await runWithProgress(context, () => c == null ? repo.createProgramCategory(body) : repo.updateProgramCategory(c.id, body), success: l.saved);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    return AdminScaffold(
      title: l.programCategories,
      fab: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add_rounded), label: Text(l.newProgramCategory)),
      body: FutureBuilder<List<ProgramCategory>>(
        future: _list,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          return ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
            for (final c in snap.data!)
              TrackTile(
                title: c.label(lang),
                subtitle: [if (lang != 'en' && c.nameEn != null) c.nameEn!, if (!c.isActive) l.inactive].join(' · '),
                leading: CircleAvatar(backgroundColor: hexColor(c.color), radius: 14),
                onTap: () => _edit(c),
                trailing: IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  onPressed: () async {
                    if (!await showConfirm(context, l.deleteCategoryConfirm, destructive: true) || !context.mounted) return;
                    await runWithProgress(context, () => ref.read(adminRepositoryProvider).deleteProgramCategory(c.id), success: l.saved);
                    _reload();
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}
