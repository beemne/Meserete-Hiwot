import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show DateTimeField;
import '../guidance/contextual_help_sheet.dart';

final _academicYearsProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => ref.watch(eduRepositoryProvider).academicYears(),
);

final _levelsProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => ref.watch(eduRepositoryProvider).levels(),
);

/// Academic calendar management: Ethiopian calendar academic years, configurable terms, and grade levels.
/// Part of Release 1.5.3+18 (F1).
class EduAcademicCalendarScreen extends ConsumerStatefulWidget {
  const EduAcademicCalendarScreen({super.key});

  @override
  ConsumerState<EduAcademicCalendarScreen> createState() => _EduAcademicCalendarScreenState();
}

class _EduAcademicCalendarScreenState extends ConsumerState<EduAcademicCalendarScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.eduAcademicCalendar),
        actions: const [
          ContextualHelpButton(screenRoute: '/edu'),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(icon: const Icon(Icons.calendar_month_rounded), text: l.eduAcademicYears),
            Tab(icon: const Icon(Icons.stairs_rounded), text: l.eduLevels),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AcademicYearsTab(onChanged: () => ref.invalidate(_academicYearsProvider)),
          _LevelsTab(onChanged: () => ref.invalidate(_levelsProvider)),
        ],
      ),
    );
  }
}

class _AcademicYearsTab extends ConsumerWidget {
  const _AcademicYearsTab({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final asyncYears = ref.watch(_academicYearsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showYearDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.add),
      ),
      body: AsyncView(
        value: asyncYears,
        onRetry: () => ref.invalidate(_academicYearsProvider),
        data: (years) {
          if (years.isEmpty) {
            return EmptyView(
              message: l.eduAcademicYears,
              icon: Icons.calendar_today_rounded,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: years.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final y = years[idx];
              final id = asIntOr(y['id']);
              final ethYear = asIntOr(y['eth_year']);
              final name = asStr(y['name']) ?? '$ethYear ዓ.ም';
              final isCurrent = y['is_current'] == true || y['is_current'] == 1;
              final status = asStr(y['status']) ?? 'planned';
              final classCount = asIntOr(y['class_count']);
              final terms = asJsonList(y['terms']);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isCurrent ? AppColors.gold : Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                                            const SizedBox(width: 2),
                                            Text(
                                              l.eduCurrentYear,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(status)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l.eduStudentCount(classCount).replaceAll('ተማሪዎች', 'ክፍሎች').replaceAll('students', 'classes'),
                                      style: Theme.of(ctx).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded),
                            onSelected: (val) async {
                              final repo = ref.read(eduRepositoryProvider);
                              if (val == 'current') {
                                final ok = await runWithProgress(ctx, () => repo.setCurrentAcademicYear(id));
                                if (ok != null) {
                                  onChanged();
                                  if (ctx.mounted) showSnack(ctx, l.saved);
                                }
                              } else if (val == 'close') {
                                final conf = await showConfirm(
                                  ctx,
                                  l.eduCloseYearConfirm,
                                  title: l.eduCloseYear,
                                  confirmLabel: l.eduCloseYear,
                                  destructive: true,
                                );
                                if (conf != true) return;
                                try {
                                  if (!ctx.mounted) return;
                                  final ok = await runWithProgress(ctx, () => repo.closeAcademicYear(id));
                                  if (ok != null) {
                                    onChanged();
                                    if (ctx.mounted) showSnack(ctx, l.saved);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) showErrorSnack(ctx, e);
                                }
                              } else if (val == 'add_term') {
                                _showTermDialog(ctx, ref, yearId: id, onSaved: onChanged);
                              } else if (val == 'edit') {
                                _showYearDialog(ctx, ref, existing: y, onSaved: onChanged);
                              } else if (val == 'delete') {
                                final conf = await showConfirm(
                                  ctx,
                                  l.deleteConfirm,
                                  title: l.delete,
                                  confirmLabel: l.delete,
                                  destructive: true,
                                );
                                if (conf != true) return;
                                try {
                                  if (!ctx.mounted) return;
                                  await runWithProgress(ctx, () => repo.deleteAcademicYear(id));
                                  onChanged();
                                  if (ctx.mounted) showSnack(ctx, l.saved);
                                } catch (e) {
                                  if (ctx.mounted) showErrorSnack(ctx, e);
                                }
                              }
                            },
                            itemBuilder: (popCtx) => [
                              if (!isCurrent)
                                PopupMenuItem(value: 'current', child: ListTile(leading: const Icon(Icons.star_outline_rounded), title: Text(l.eduSetCurrent))),
                              if (status != 'closed')
                                PopupMenuItem(value: 'close', child: ListTile(leading: const Icon(Icons.lock_clock_rounded), title: Text(l.eduCloseYear))),
                              PopupMenuItem(value: 'add_term', child: ListTile(leading: const Icon(Icons.playlist_add_rounded), title: Text(l.eduNewTerm))),
                              PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l.edit))),
                              if (classCount == 0)
                                PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Colors.red), title: Text(l.delete, style: const TextStyle(color: Colors.red)))),
                            ],
                          ),
                        ],
                      ),
                      if (terms.isNotEmpty) ...[
                        const Divider(height: 16),
                        Text(l.eduTerms, style: Theme.of(ctx).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tm in terms)
                              InputChip(
                                label: Text('${tm['name']}'),
                                onDeleted: () async {
                                  final tid = asIntOr(tm['id']);
                                  final conf = await showConfirm(ctx, l.deleteConfirm, title: l.delete, confirmLabel: l.delete, destructive: true);
                                  if (conf != true) return;
                                  try {
                                    if (!ctx.mounted) return;
                                    await runWithProgress(ctx, () => ref.read(eduRepositoryProvider).deleteTerm(tid));
                                    onChanged();
                                  } catch (e) {
                                    if (ctx.mounted) showErrorSnack(ctx, e);
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  void _showYearDialog(BuildContext context, WidgetRef ref, {Json? existing, VoidCallback? onSaved}) async {
    final l = context.l10n;
    final isEdit = existing != null;
    final yearController = TextEditingController(text: existing != null ? '${existing['eth_year']}' : '');
    final nameController = TextEditingController(text: existing != null ? '${existing['name']}' : '');
    var status = asStr(existing?['status']) ?? 'active';
    var isCurrent = existing?['is_current'] == true || existing?['is_current'] == 1;
    DateTime? startsOn = asDate(existing?['starts_on']);
    DateTime? endsOn = asDate(existing?['ends_on']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(isEdit ? l.edit : l.add),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.eduEthYear, hintText: '2019'),
                ),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l.title, hintText: '2019 ዓ.ም'),
                ),
                const SizedBox(height: 8),
                DateTimeField(
                  label: l.startsAt,
                  withTime: false,
                  value: startsOn,
                  onChanged: (d) => setS(() => startsOn = d),
                ),
                DateTimeField(
                  label: l.endsAt,
                  withTime: false,
                  value: endsOn,
                  onChanged: (d) => setS(() => endsOn = d),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: l.status),
                  items: const [
                    DropdownMenuItem(value: 'planned', child: Text('PLANNED')),
                    DropdownMenuItem(value: 'active', child: Text('ACTIVE')),
                    DropdownMenuItem(value: 'closed', child: Text('CLOSED')),
                  ],
                  onChanged: (v) => setS(() => status = v ?? 'planned'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.eduCurrentYear),
                  value: isCurrent,
                  onChanged: (v) => setS(() => isCurrent = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: () {
                final ethY = int.tryParse(yearController.text.trim());
                if (ethY == null) return;
                Navigator.pop(ctx, true);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final ethY = int.tryParse(yearController.text.trim())!;
    final name = nameController.text.trim().isEmpty ? '$ethY ዓ.ም' : nameController.text.trim();
    final body = <String, dynamic>{
      'eth_year': ethY,
      'name': name,
      'status': status,
      'is_current': isCurrent,
      'starts_on': startsOn?.toIso8601String().substring(0, 10),
      'ends_on': endsOn?.toIso8601String().substring(0, 10),
    };

    try {
      if (!context.mounted) return;
      final repo = ref.read(eduRepositoryProvider);
      if (isEdit) {
        await runWithProgress(context, () => repo.updateAcademicYear(asIntOr(existing['id']), body));
      } else {
        await runWithProgress(context, () => repo.createAcademicYear(body));
      }
      onSaved?.call();
      onChanged();
      if (context.mounted) showSnack(context, l.saved);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  void _showTermDialog(BuildContext context, WidgetRef ref, {required int yearId, VoidCallback? onSaved}) async {
    final l = context.l10n;
    final nameController = TextEditingController();
    final sortController = TextEditingController(text: '1');
    DateTime? startsOn;
    DateTime? endsOn;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.eduNewTerm),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: l.title, hintText: 'Term I / 1ኛ ወሰነ-ትምህርት'),
                ),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort Order', hintText: '1'),
                ),
                const SizedBox(height: 8),
                DateTimeField(label: l.startsAt, withTime: false, value: startsOn, onChanged: (d) => setS(() => startsOn = d)),
                DateTimeField(label: l.endsAt, withTime: false, value: endsOn, onChanged: (d) => setS(() => endsOn = d)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final body = <String, dynamic>{
      'name': nameController.text.trim(),
      'sort_order': int.tryParse(sortController.text.trim()) ?? 0,
      'starts_on': startsOn?.toIso8601String().substring(0, 10),
      'ends_on': endsOn?.toIso8601String().substring(0, 10),
    };

    try {
      if (!context.mounted) return;
      await runWithProgress(context, () => ref.read(eduRepositoryProvider).createTerm(yearId, body));
      onSaved?.call();
      onChanged();
      if (context.mounted) showSnack(context, l.saved);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }
}

class _LevelsTab extends ConsumerWidget {
  const _LevelsTab({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final asyncLevels = ref.watch(_levelsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLevelDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.eduNewLevel),
      ),
      body: AsyncView(
        value: asyncLevels,
        onRetry: () => ref.invalidate(_levelsProvider),
        data: (levels) {
          if (levels.isEmpty) {
            return EmptyView(message: l.eduLevels, icon: Icons.stairs_rounded);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: levels.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final lvl = levels[idx];
              final id = asIntOr(lvl['id']);
              final code = asStr(lvl['code']) ?? '';
              final name = asStr(lvl['name']) ?? '';
              final nameEn = asStr(lvl['name_en']);
              final builtIn = lvl['built_in'] == true || lvl['built_in'] == 1;
              final kind = asStr(lvl['kind']) ?? 'grade';
              final classCount = asIntOr(lvl['class_count']);

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.4)),
                ),
                leading: CircleAvatar(
                  backgroundColor: builtIn ? AppColors.gold.withValues(alpha: 0.2) : Theme.of(ctx).colorScheme.primaryContainer,
                  child: Text(
                    code.length > 3 ? code.substring(0, 3) : code,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: builtIn ? AppColors.gold : Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                ),
                title: Text('$name ${nameEn != null ? '($nameEn)' : ''}'),
                subtitle: Text('Kind: $kind · $classCount classes'),
                trailing: builtIn
                    ? Chip(label: Text(l.eduBuiltIn), visualDensity: VisualDensity.compact)
                    : IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () async {
                          final conf = await showConfirm(ctx, l.deleteConfirm, title: l.delete, confirmLabel: l.delete, destructive: true);
                          if (conf != true) return;
                          try {
                            if (!ctx.mounted) return;
                            await runWithProgress(ctx, () => ref.read(eduRepositoryProvider).deleteLevel(id));
                            onChanged();
                          } catch (e) {
                            if (ctx.mounted) showErrorSnack(ctx, e);
                          }
                        },
                      ),
              );
            },
          );
        },
      ),
    );
  }

  void _showLevelDialog(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final nameEnController = TextEditingController();
    final sortController = TextEditingController(text: '10');
    var kind = 'extra';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(l.eduNewLevel),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Code', hintText: 'ADULT')),
                TextField(controller: nameController, decoration: InputDecoration(labelText: l.title, hintText: 'የአዋቂዎች ትምህርት')),
                TextField(controller: nameEnController, decoration: const InputDecoration(labelText: 'English Name', hintText: 'Adult Catechism')),
                TextField(controller: sortController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sort Order')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Kind'),
                  items: const [
                    DropdownMenuItem(value: 'grade', child: Text('Grade')),
                    DropdownMenuItem(value: 'extra', child: Text('Extra / Custom')),
                  ],
                  onChanged: (v) => setS(() => kind = v ?? 'extra'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: () {
                if (codeController.text.trim().isEmpty || nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final body = <String, dynamic>{
      'code': codeController.text.trim().toUpperCase(),
      'name': nameController.text.trim(),
      'name_en': nameEnController.text.trim().isEmpty ? null : nameEnController.text.trim(),
      'sort_order': int.tryParse(sortController.text.trim()) ?? 0,
      'kind': kind,
    };

    try {
      if (!context.mounted) return;
      await runWithProgress(context, () => ref.read(eduRepositoryProvider).createLevel(body));
      onChanged();
      if (context.mounted) showSnack(context, l.saved);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }
}
