import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/org_admin.dart' show departmentName;

/// Ethiopian payable/participation period "YYYY-MM" (ጳጉሜ belongs to ነሐሴ).
String ethPeriod(DateTime d) {
  final e = EthiopianDate.fromGregorian(d);
  final m = e.month == 13 ? 12 : e.month;
  return '${e.year}-${m.toString().padLeft(2, '0')}';
}

String shiftPeriod(String p, int n) {
  final parts = p.split('-').map(int.parse).toList();
  final idx = parts[0] * 12 + (parts[1] - 1) + n;
  return '${idx ~/ 12}-${((idx % 12) + 1).toString().padLeft(2, '0')}';
}

/// "መስከረም 2019" in both languages (months are Ethiopian everywhere).
String periodLabel(BuildContext context, String p) {
  final f = Formatters(context.l10n, Localizations.localeOf(context).languageCode);
  final parts = p.split('-').map(int.parse).toList();
  return '${f.monthName(parts[1])} ${parts[0]}';
}

final ledDepartmentsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(orgRepositoryProvider).ledDepartments());

/// Department leader: record each member's participation for an (Ethiopian) month — 0 to 10
/// (the maximum is a setting). A member left unscored stays unscored (it is not a zero); holiday
/// selections average the months that were scored and list the others for review.
class DepartmentParticipationScreen extends ConsumerStatefulWidget {
  const DepartmentParticipationScreen({super.key, required this.department});
  final Json department;
  @override
  ConsumerState<DepartmentParticipationScreen> createState() => _DepartmentParticipationScreenState();
}

class _DepartmentParticipationScreenState extends ConsumerState<DepartmentParticipationScreen> {
  double _max = 10;
  late String _period = ethPeriod(DateTime.now());
  late final String _current = _period;
  Future<Json>? _future;
  final _scores = <int, double>{};
  final _notes = <int, String?>{};
  final _initial = <int>{};
  bool _dirty = false;
  bool _saving = false;

  int get _id => asIntOr(widget.department['id']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _scores.clear();
    _notes.clear();
    _initial.clear();
    _dirty = false;
    _future = ref.read(orgRepositoryProvider).participationSheet(_id, _period).then((d) {
      _max = asDouble(asJson(d['policy'])['max_score'], 10);
      for (final m in asJsonList(d['members'])) {
        final uid = asIntOr(m['user_id']);
        if (m['score'] != null) {
          _scores[uid] = asDouble(m['score']);
          _initial.add(uid);
        }
        _notes[uid] = asStr(m['note']);
      }
      return d;
    });
    setState(() {});
  }

  Future<void> _save(List<Json> members) async {
    final l = context.l10n;
    // Members left unscored stay unscored (not zero) — they are listed for review in selections.
    final missing = members.where((m) => !_scores.containsKey(asIntOr(m['user_id']))).length;
    if (missing > 0 && !await showConfirm(context, l.participationMissing('$missing'))) return;
    setState(() => _saving = true);
    try {
      final entries = [
        for (final m in members)
          if (_scores.containsKey(asIntOr(m['user_id'])) || _initial.contains(asIntOr(m['user_id'])))
            {'user_id': asIntOr(m['user_id']), 'score': _scores[asIntOr(m['user_id'])], 'note': _notes[asIntOr(m['user_id'])]},
      ];
      if (entries.isEmpty) return;
      await ref.read(orgRepositoryProvider).saveParticipation(_id, _period, entries);
      if (!mounted) return;
      showSnack(context, l.saved);
      _load();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return PatternScaffold(
      appBar: AppBar(title: Text(departmentName(context, widget.department))),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _load);
          if (!snap.hasData) return const LoadingView();
          final members = asJsonList(snap.data!['members']);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                IconButton(tooltip: l.previousMonth, icon: const Icon(Icons.chevron_left_rounded), onPressed: () {
                  _period = shiftPeriod(_period, -1);
                  _load();
                }),
                Expanded(child: Text(periodLabel(context, _period), textAlign: TextAlign.center, style: context.serif(18))),
                IconButton(
                  tooltip: l.nextMonth,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _period.compareTo(_current) >= 0
                      ? null
                      : () {
                          _period = shiftPeriod(_period, 1);
                          _load();
                        },
                ),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l.participationHint, style: context.sans(12, color: p.muted))),
            Expanded(
              child: members.isEmpty
                  ? EmptyView(message: l.noMembers, icon: Icons.groups_outlined)
                  : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
                      for (final m in members)
                        AppCard(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${m['full_name']}', style: context.serif(15, color: p.text))),
                              if (m['member_id'] != null) Padding(padding: const EdgeInsets.only(right: 6), child: Text('${m['member_id']}', style: context.sans(11, color: p.muted))),
                              if (m['role'] == 'leader') Pill(l.deptLeader, color: AppColors.goldDark),
                            ]),
                            const SizedBox(height: 6),
                            Wrap(spacing: 4, runSpacing: 4, children: [
                              for (var v = 0; v <= _max.round(); v++)
                                ChoiceChip(
                                  visualDensity: VisualDensity.compact,
                                  showCheckmark: false,
                                  label: Text('$v'),
                                  selected: _scores[asIntOr(m['user_id'])] == v,
                                  onSelected: (sel) => setState(() {
                                    if (sel) {
                                      _scores[asIntOr(m['user_id'])] = v.toDouble();
                                    } else {
                                      _scores.remove(asIntOr(m['user_id']));
                                    }
                                    _dirty = true;
                                  }),
                                ),
                            ]),
                            Row(children: [
                              Expanded(
                                child: Text(
                                  [
                                    if (_scores[asIntOr(m['user_id'])] == null) l.selNotScored,
                                    if (asStr(m['recorded_by_name']) != null) '${m['recorded_by_name']}',
                                    if ((_notes[asIntOr(m['user_id'])] ?? '').isNotEmpty) '${_notes[asIntOr(m['user_id'])]}',
                                  ].join(' · '),
                                  style: context.sans(11, color: p.muted),
                                ),
                              ),
                              IconButton(
                                tooltip: l.notes,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.edit_note_rounded, color: p.subtle),
                                onPressed: () async {
                                  final t = await promptText(context, title: l.notes, initial: _notes[asIntOr(m['user_id'])], maxLines: 2);
                                  if (t == null) return;
                                  setState(() {
                                    _notes[asIntOr(m['user_id'])] = t.trim().isEmpty ? null : t.trim();
                                    _dirty = true;
                                  });
                                },
                              ),
                            ]),
                          ]),
                        ),
                    ].expand((w) => [w, const SizedBox(height: 8)]).toList()),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving || members.isEmpty || !_dirty ? null : () => _save(members),
                    icon: const Icon(Icons.save_rounded),
                    label: Text(l.save),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
