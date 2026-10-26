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
import '../../core/member_groups.dart';
import '../members/member_form.dart' show memberGroupLabel;
import 'admin_widgets.dart';

String _n(num? v) => v == null ? '—' : (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1));

String weddingMemberStatus(AppLocalizations l, String? s) => switch (s) {
      'participated' => l.wedParticipated,
      'absent' => l.wedAbsent,
      'withdrawn' => l.wedWithdrawn,
      _ => l.wedSelected,
    };

/// Wedding ceremony Mezmur services — "መዝሙር አገልግሎት (በመዝሙር እጀባ)" (Hymns and Arts Department).
class WeddingsScreen extends ConsumerStatefulWidget {
  const WeddingsScreen({super.key});
  @override
  ConsumerState<WeddingsScreen> createState() => _WeddingsScreenState();
}

class _WeddingsScreenState extends ConsumerState<WeddingsScreen> {
  final _ctrl = PagedListController<Json>();
  String _scope = 'upcoming';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.wedTitle,
      fab: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(l.wedNew),
        onPressed: () async {
          final saved = await Navigator.of(context).push<Json>(MaterialPageRoute(builder: (_) => const WeddingEditorScreen()));
          if (saved != null) await _ctrl.refresh();
        },
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            for (final s in const ['upcoming', 'all'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(s == 'upcoming' ? l.upcoming : l.all), selected: _scope == s, onSelected: (_) => setState(() => _scope = s)),
              ),
          ]),
        ),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey(_scope),
            controller: _ctrl,
            fetch: (page) => ref.read(stageRepositoryProvider).weddings(scope: _scope, page: page),
            emptyMessage: l.wedNone,
            emptyIcon: Icons.favorite_outline_rounded,
            itemBuilder: (context, w, _) => TrackTile(
              title: '${w['title']}',
              subtitle: [f.dateTime(asDate(w['service_at'])), if (asStr(w['location']) != null) '${w['location']}', l.wedMembers('${asIntOr(w['member_count'])}')].join(' · '),
              leading: const ListThumb(icon: Icons.favorite_outline_rounded),
              trailing: w['status'] == 'planned' ? null : Pill(w['status'] == 'completed' ? l.wedCompleted : l.selStatusCancelled),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WeddingDetailScreen(id: asIntOr(w['id']))));
                await _ctrl.refresh();
              },
            ),
            separator: const SizedBox(height: 8),
          ),
        ),
      ]),
    );
  }
}

class WeddingDetailScreen extends ConsumerStatefulWidget {
  const WeddingDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<WeddingDetailScreen> createState() => _WeddingDetailScreenState();
}

class _WeddingDetailScreenState extends ConsumerState<WeddingDetailScreen> {
  late Future<Json> _future = ref.read(stageRepositoryProvider).wedding(widget.id);
  void _reload() => setState(() => _future = ref.read(stageRepositoryProvider).wedding(widget.id));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.wedTitle,
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final w = snap.data!;
          final members = asJsonList(w['members']);
          final planned = w['status'] == 'planned';
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
            MaroonCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${w['title']}', style: context.serif(20, color: Colors.white)),
                const SizedBox(height: 4),
                Text([f.dateTime(asDate(w['service_at'])), if (asStr(w['location']) != null) '${w['location']}'].join(' · '), style: context.sans(13, color: Colors.white)),
                const SizedBox(height: 6),
                Text(l.wedManualSelectionHint, style: context.sans(12, color: AppColors.goldLight)),
                if (asStr(w['notes']) != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${w['notes']}', style: context.sans(12, color: Colors.white70))),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text(l.edit),
                onPressed: () async {
                  final saved = await Navigator.of(context).push<Json>(MaterialPageRoute(builder: (_) => WeddingEditorScreen(existing: w)));
                  if (saved != null) _reload();
                },
              ),
              if (planned) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.campaign_outlined, size: 18),
                  label: Text(Localizations.localeOf(context).languageCode == 'am' ? 'አገልግሎቱን አሳውቅ' : 'Announce Service'),
                  onPressed: () async {
                    final isAm = Localizations.localeOf(context).languageCode == 'am';
                    final confirmed = await showConfirm(
                      context,
                      isAm ? 'ለአባላት/ለመዘምራን የአገልግሎት ጥሪ ማስታወቂያ ይላክ?' : 'Announce this Mezmur service to members/choir via notification?',
                    );
                    if (confirmed && context.mounted) {
                      try {
                        final res = await ref.read(stageRepositoryProvider).announceWedding(widget.id);
                        if (context.mounted) {
                          showSnack(
                            context,
                            isAm ? 'ማስታወቂያ ተልኳል (${res['recipient_count']} አባላት)' : 'Service announced (${res['recipient_count']} recipients)',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) showErrorSnack(context, e);
                      }
                    }
                  },
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: Text(l.wedSelectMembers),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WeddingCandidatesScreen(id: widget.id, service: w)));
                    _reload();
                  },
                ),
              ],
            ]),
            SectionHeader(title: l.wedMembers('${members.length}')),
            if (members.isEmpty) Text(l.noMembers, style: context.sans(13, color: p.muted)),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TrackTile(
                  title: '${m['full_name']}',
                  subtitle: [
                    ?asStr(m['member_id']),
                    if (asStr(m['member_group']) != null) memberGroupLabel(l, asStr(m['member_group'])),
                    if (asJson(m['snapshot']).isNotEmpty)
                      '${l.eligAttendance} ${_n(asJson(asJson(m['snapshot'])['attendance'])['percent'] as num?)}% · ${l.selExam} ${_n(asJson(asJson(m['snapshot'])['exam'])['percent'] as num?)}%',
                    if (asStr(m['selected_by_name']) != null) '${m['selected_by_name']}',
                  ].join(' · '),
                  leading: const ListThumb(icon: Icons.person_outline_rounded),
                  trailing: PopupMenuButton<String>(
                    child: Pill(weddingMemberStatus(l, asStr(m['status'])), color: m['status'] == 'participated' ? AppColors.success : (m['status'] == 'selected' ? AppColors.goldDark : AppColors.danger)),
                    onSelected: (s) async {
                      final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).setWeddingMember(widget.id, asIntOr(m['user_id']), s), success: l.saved);
                      if (r != null) _reload();
                    },
                    itemBuilder: (_) => [
                      for (final s in const ['selected', 'participated', 'absent', 'withdrawn']) PopupMenuItem(value: s, child: Text(weddingMemberStatus(l, s))),
                    ],
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Eligible members (active, not children) chosen by hand: search by name, phone or member ID,
/// filter by member type or by whether they are already chosen, tick several, review, confirm.
/// No attendance or exam requirement decides who may be chosen.
class WeddingCandidatesScreen extends ConsumerStatefulWidget {
  const WeddingCandidatesScreen({super.key, required this.id, required this.service, this.initial = const {}});
  /// null: choosing participants for a service that is being created — the choice is returned
  /// (user id → name line) and saved together with the new service.
  final int? id;
  final Json service;
  final Map<int, String> initial;
  @override
  ConsumerState<WeddingCandidatesScreen> createState() => _WeddingCandidatesScreenState();
}

class _WeddingCandidatesScreenState extends ConsumerState<WeddingCandidatesScreen> {
  final _ctrl = PagedListController<Json>();
  /// user id → display line, kept for the review step across searches and pages.
  late final _picked = <int, String>{...widget.initial};
  String _q = '';
  String? _group;
  bool _hideChosen = false;

  Future<void> _review() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l.wedReviewTitle('${_picked.length}')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in _picked.entries)
            Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• ${e.value}', style: ctx.sans(13))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (widget.id == null) return Navigator.pop(context, Map<int, String>.of(_picked));
    final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).selectWeddingMembers(widget.id!, _picked.keys.toList()), success: l.saved);
    if (r != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final groups = [for (final g in MemberGroups.keys(activeOnly: false)) if (g != 'children') g];
    return AdminScaffold(
      title: l.wedSelectMembers,
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            // "Not yet chosen" only applies to an existing service.
            if (widget.id != null) ...[
              FilterChip(label: Text(l.wedHideChosen), selected: _hideChosen, onSelected: (v) => setState(() => _hideChosen = v)),
              const SizedBox(width: 6),
            ],
            for (final g in groups) ...[
              ChoiceChip(label: Text(memberGroupLabel(l, g)), selected: _group == g, onSelected: (v) => setState(() => _group = v ? g : null)),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey('$_q|$_group|$_hideChosen'),
            controller: _ctrl,
            fetch: (page) => widget.id == null
                ? ref.read(stageRepositoryProvider).weddingEligible(q: _q.isEmpty ? null : _q, group: _group, page: page)
                : ref.read(stageRepositoryProvider).weddingCandidates(widget.id!, q: _q.isEmpty ? null : _q, group: _group, hideChosen: _hideChosen, page: page),
            emptyMessage: l.noResults,
            itemBuilder: (context, c, _) {
              final id = asIntOr(c['user_id']);
              final chosen = c['selected'] == true;
              final line = [?asStr(c['member_id']), memberGroupLabel(l, asStr(c['member_group']))].join(' · ');
              return CheckboxListTile(
                value: chosen || _picked.containsKey(id),
                onChanged: chosen ? null : (v) => setState(() => v == true ? _picked[id] = '${c['full_name']} ($line)' : _picked.remove(id)),
                title: Text('${c['full_name']}'),
                subtitle: Text([line, if (chosen) '✓ ${l.wedSelected}'].join(' · '), style: context.sans(12, color: p.muted)),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _picked.isEmpty ? null : _review, child: Text(l.selectCount('${_picked.length}')))),
          ),
        ),
      ]),
    );
  }
}

class WeddingEditorScreen extends ConsumerStatefulWidget {
  const WeddingEditorScreen({super.key, this.existing});
  final Json? existing;
  @override
  ConsumerState<WeddingEditorScreen> createState() => _WeddingEditorScreenState();
}

class _WeddingEditorScreenState extends ConsumerState<WeddingEditorScreen> {
  late final _title = TextEditingController(text: asStr(widget.existing?['title']));
  late final _location = TextEditingController(text: asStr(widget.existing?['location']));
  late final _notes = TextEditingController(text: asStr(widget.existing?['notes']));
  late DateTime? _at = asDate(widget.existing?['service_at']);
  late String _status = asStr(widget.existing?['status']) ?? 'planned';
  /// New service: participants chosen in the same step (user id → name line).
  Map<int, String> _members = const {};

  Future<void> _chooseMembers() async {
    final r = await Navigator.of(context).push<Map<int, String>>(MaterialPageRoute(builder: (_) => WeddingCandidatesScreen(id: null, service: const {}, initial: _members)));
    if (r != null && mounted) setState(() => _members = r);
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (_title.text.trim().length < 2 || _at == null) return showSnack(context, l.vRequired);
    final body = {
      'title': _title.text.trim(),
      'service_at': _at!.toUtc().toIso8601String(),
      'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      if (widget.existing != null) 'status': _status,
      if (widget.existing == null && _members.isNotEmpty) 'user_ids': _members.keys.toList(),
    };
    final repo = ref.read(stageRepositoryProvider);
    final r = await runWithProgress(context, () => widget.existing == null ? repo.createWedding(body) : repo.updateWedding(asIntOr(widget.existing!['id']), body), success: l.saved);
    if (r != null && mounted) Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AdminScaffold(
      title: widget.existing == null ? l.wedNew : l.edit,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        TextField(controller: _title, decoration: InputDecoration(labelText: l.title)),
        const SizedBox(height: 10),
        DateTimeField(label: l.wedServiceAt, value: _at, onChanged: (d) => setState(() => _at = d)),
        const SizedBox(height: 10),
        TextField(controller: _location, decoration: InputDecoration(labelText: l.location)),
        const SizedBox(height: 10),
        TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: l.notes)),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.wedManualSelectionHint, style: context.sans(12, color: context.palette.muted))),
        if (widget.existing == null) ...[
          SectionHeader(title: l.wedMembers('${_members.length}')),
          if (_members.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _members.entries) InputChip(label: Text(e.value.split(' (').first), onDeleted: () => setState(() => _members = {..._members}..remove(e.key))),
            ]),
          const SizedBox(height: 6),
          OutlinedButton.icon(icon: const Icon(Icons.group_add_rounded, size: 18), label: Text(l.wedSelectMembers), onPressed: _chooseMembers),
        ],
        if (widget.existing != null) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(labelText: l.status),
            items: [
              DropdownMenuItem(value: 'planned', child: Text(l.wedPlanned)),
              DropdownMenuItem(value: 'completed', child: Text(l.wedCompleted)),
              DropdownMenuItem(value: 'cancelled', child: Text(l.selStatusCancelled)),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'planned'),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ]),
    );
  }
}
