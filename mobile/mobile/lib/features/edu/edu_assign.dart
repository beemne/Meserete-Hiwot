import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/network/api_client.dart' show Paged;
import '../../core/theme/app_colors.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show SearchBox;
import '../guidance/contextual_help_sheet.dart';

/// Screen for assigning students to a class (F2).
/// Queries only eligible students not active in another exclusive class for this academic year.
class EduAssignStudentsScreen extends ConsumerStatefulWidget {
  const EduAssignStudentsScreen({super.key, required this.classId, this.className});
  final int classId;
  final String? className;

  @override
  ConsumerState<EduAssignStudentsScreen> createState() => _EduAssignStudentsScreenState();
}

class _EduAssignStudentsScreenState extends ConsumerState<EduAssignStudentsScreen> {
  String? _query;
  String? _group;
  String _program = 'regular';
  int _page = 1;
  final Set<int> _selected = <int>{};
  bool _loading = false;
  Paged<Json>? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(eduRepositoryProvider).assignableStudents(
        widget.classId,
        q: _query,
        group: _group,
        page: _page,
      );
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _assign() async {
    if (_selected.isEmpty) return;
    final l = context.l10n;
    final res = await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).assignStudents(
        widget.classId,
        _selected.toList(),
        program: _program,
      ),
    );
    if (res == null || !mounted) return;

    final results = asJsonList(res['results']);
    final assignedCount = asIntOr(res['assigned_count']);
    final conflicts = results.where((r) => r['status'] == 'in_other_class').toList();

    _selected.clear();
    _load();

    if (conflicts.isNotEmpty && mounted) {
      final conflictNames = {for (final c in conflicts) c['class_name'] ?? 'another class'}.join(', ');
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.eduAssignStudents),
          content: Text(
            '${l.eduAssignedSuccess(assignedCount)}.\n\n${conflicts.length} student(s) could not be assigned because they are active in exclusive classes ($conflictNames).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
          ],
        ),
      );
    } else if (mounted) {
      showSnack(context, l.eduAssignedSuccess(assignedCount));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _data?.items ?? const [];

    return PatternScaffold(
      appBar: AppBar(
        title: Text(widget.className != null ? '${l.eduAssignStudents} · ${widget.className}' : l.eduAssignStudents),
        actions: const [
          ContextualHelpButton(screenRoute: '/edu'),
        ],
      ),
      bottomNavigationBar: items.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4))),
                ),
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: _program,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(value: 'regular', child: Text(l.programRegular)),
                        DropdownMenuItem(value: 'distance', child: Text(l.programDistance)),
                      ],
                      onChanged: (v) => setState(() => _program = v ?? 'regular'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _selected.isEmpty ? null : _assign,
                      icon: const Icon(Icons.person_add_rounded),
                      label: Text('${l.eduAssignStudents} (${_selected.length})'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBox(
              hint: l.search,
              onChanged: (v) {
                _query = v.trim().isEmpty ? null : v.trim();
                _page = 1;
                _load();
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: Text(l.all),
                  selected: _group == null,
                  onSelected: (v) {
                    setState(() => _group = null);
                    _page = 1;
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Youth & Adult / ወጣት እና አዋቂ'),
                  selected: _group == 'youth_adult',
                  onSelected: (v) {
                    setState(() => _group = v ? 'youth_adult' : null);
                    _page = 1;
                    _load();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Children / ሕፃናት'),
                  selected: _group == 'children',
                  onSelected: (v) {
                    setState(() => _group = v ? 'children' : null);
                    _page = 1;
                    _load();
                  },
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Expanded(child: ErrorView(error: _error!, onRetry: _load))
          else if (!_loading && items.isEmpty)
            Expanded(child: EmptyView(message: l.eduNoStudents, icon: Icons.person_off_rounded))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (ctx, idx) {
                  final s = items[idx];
                  final id = asIntOr(s['id']);
                  final isSel = _selected.contains(id);
                  final name = asStr(s['full_name']) ?? '#$id';
                  final memberId = asStr(s['member_id']);
                  final phone = asStr(s['phone']);
                  final group = asStr(s['member_group']);

                  return CheckboxListTile(
                    value: isSel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSel ? AppColors.gold : Theme.of(ctx).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    activeColor: AppColors.gold,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      });
                    },
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      ?memberId,
                      ?phone,
                      ?group,
                    ].join(' · ')),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper dialog to transfer an enrolled student to another class (F2).
Future<bool> showTransferDialog(
  BuildContext context,
  WidgetRef ref, {
  required int enrollmentId,
  required String studentName,
  required int currentClassId,
}) async {
  final l = context.l10n;
  final reasonController = TextEditingController();
  int? targetClassId;
  List<Json> classes = const [];

  try {
    classes = await ref.read(eduRepositoryProvider).adminClasses(status: 'active');
  } catch (_) {}

  final eligibleClasses = classes.where((c) => asInt(c['id']) != currentClassId).toList();
  if (eligibleClasses.isNotEmpty) {
    targetClassId = asInt(eligibleClasses.first['id']);
  }

  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text('${l.eduTransferStudent} · $studentName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eligibleClasses.isEmpty)
              Text(l.eduNoClasses)
            else
              DropdownButtonFormField<int>(
                initialValue: targetClassId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.eduTransferTargetClass),
                items: [
                  for (final c in eligibleClasses)
                    DropdownMenuItem(
                      value: asInt(c['id']),
                      child: Text('${c['name']}'),
                    ),
                ],
                onChanged: (v) => setS(() => targetClassId = v),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: l.eduTransferReason,
                hintText: 'e.g. Schedule change, level advancement',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            onPressed: targetClassId == null || reasonController.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    ),
  );

  if (ok != true || targetClassId == null || !context.mounted) return false;
  try {
    await runWithProgress(
      context,
      () => ref.read(eduRepositoryProvider).transferEnrollment(
        enrollmentId,
        targetClassId!,
        reasonController.text.trim(),
      ),
    );
    if (context.mounted) showSnack(context, l.eduTransferSuccess);
    return true;
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
    return false;
  }
}
