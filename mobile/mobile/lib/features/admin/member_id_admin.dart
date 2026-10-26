import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/member_groups.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../members/member_form.dart' show memberGroupLabel;
import '../settings/account_screens.dart' show SubPage;

/// Member ID display style (Super Admin and the Human Resources admin: member_id.configure).
/// Only the prefix per member group and the style change; the numbers are permanent.
class MemberIdFormatScreen extends ConsumerStatefulWidget {
  const MemberIdFormatScreen({super.key});
  @override
  ConsumerState<MemberIdFormatScreen> createState() => _MemberIdFormatScreenState();
}

class _MemberIdFormatScreenState extends ConsumerState<MemberIdFormatScreen> {
  // Every member type (administrator-created ones too); youth / adult first: its prefix is the
  // default of a type left blank.
  final groups = ['youth_adult', for (final g in MemberGroups.keys(activeOnly: false)) if (g != 'youth_adult') g];
  late final _prefix = {for (final g in groups) g: TextEditingController()};
  String _separator = '/';
  int _digits = 0;
  bool _loaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _prefix.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f = await ref.read(chatRepositoryProvider).memberIdFormat();
      final prefixes = asJson(f['prefixes']);
      if (!mounted) return;
      setState(() {
        for (final g in groups) {
          _prefix[g]!.text = asStr(prefixes[g]) ?? '';
        }
        _separator = asStr(f['separator']) ?? '/';
        _digits = asIntOr(f['min_digits']);
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _example(String g) {
    var p = _prefix[g]!.text.trim();
    if (p.isEmpty && !MemberGroups.builtIn.contains(g)) p = _prefix['youth_adult']!.text.trim();
    final n = '17'.padLeft(_digits, '0');
    return p.isEmpty ? n : '$p$_separator$n';
  }

  Future<void> _save() async {
    final l = context.l10n;
    final body = {
      'prefixes': {
        for (final g in groups)
          if (MemberGroups.builtIn.contains(g) || _prefix[g]!.text.trim().isNotEmpty) g: _prefix[g]!.text.trim(),
      },
      'separator': _separator,
      'min_digits': _digits,
    };
    await runWithProgress(context, () => ref.read(chatRepositoryProvider).saveMemberIdFormat(body), success: l.saved);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    if (_error != null) return SubPage(title: l.midTitle, body: ErrorView(error: _error!, onRetry: _load));
    if (!_loaded) return SubPage(title: l.midTitle, body: const LoadingView());
    final seps = {'/': '/', '-': '-', '.': '.', ' ': l.midSpace, '': l.midNone};
    return SubPage(
      title: l.midTitle,
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text(l.midHint, style: context.sans(13, color: p.muted)),
        const SizedBox(height: 16),
        for (final g in groups) ...[
          TextField(
            key: ValueKey('mid-prefix-$g'),
            controller: _prefix[g],
            maxLength: 30,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: memberGroupLabel(l, g), helperText: '${l.midPreview}: ${_example(g)}'),
          ),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<String>(
          initialValue: _separator,
          decoration: InputDecoration(labelText: l.midSeparator),
          items: [for (final e in seps.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _separator = v ?? '/'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _digits,
          decoration: InputDecoration(labelText: l.midDigits),
          items: [for (var i = 0; i <= 6; i++) DropdownMenuItem(value: i, child: Text('$i'))],
          onChanged: (v) => setState(() => _digits = v ?? 0),
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final g in groups) Pill(_example(g), icon: Icons.badge_outlined)]),
        const SizedBox(height: 24),
        FilledButton(key: const ValueKey('mid-save'), onPressed: _save, child: Text(l.save)),
      ]),
    );
  }
}

/// Member types (member_groups.manage): the built-in three plus administrator-created ones such as
/// distance members. Programs, attendance, member IDs and filters offer every active type.
class MemberGroupsScreen extends ConsumerStatefulWidget {
  const MemberGroupsScreen({super.key});
  @override
  ConsumerState<MemberGroupsScreen> createState() => _MemberGroupsScreenState();
}

class _MemberGroupsScreenState extends ConsumerState<MemberGroupsScreen> {
  Future<void> _edit(MemberGroupInfo? g) async {
    final l = context.l10n;
    final name = TextEditingController(text: g?.name);
    final nameEn = TextEditingController(text: g?.nameEn);
    final desc = TextEditingController(text: g?.description);
    var active = g?.active ?? true;
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(g == null ? l.mgAdd : l.mgEdit),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  key: const ValueKey('mg-name'),
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l.mgName),
                  validator: (s) => (s ?? '').trim().length < 2 ? l.vRequired : null,
                ),
                TextFormField(controller: nameEn, decoration: InputDecoration(labelText: l.mgNameEn)),
                TextFormField(controller: desc, maxLines: 2, decoration: InputDecoration(labelText: l.description)),
                if (g != null && !g.builtIn)
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.mgActive), value: active, onChanged: (v) => set(() => active = v)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(ctx, true) : null, child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final body = <String, dynamic>{
      'name': name.text.trim(),
      'name_en': nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
      'description': desc.text.trim().isEmpty ? null : desc.text.trim(),
      if (g != null && !g.builtIn) 'is_active': active,
    };
    final repo = ref.read(stageRepositoryProvider);
    final r = await runWithProgress(context, () => g == null ? repo.createMemberGroup(body) : repo.updateMemberGroup(g.key, body), success: l.saved);
    if (r != null) ref.invalidate(memberGroupsProvider);
  }

  Future<void> _delete(MemberGroupInfo g) async {
    final l = context.l10n;
    if (!await showConfirm(context, l.mgDeleteConfirm, destructive: true) || !mounted) return;
    final r = await runWithProgress(context, () async {
      await ref.read(stageRepositoryProvider).deleteMemberGroup(g.key);
      return true;
    }, success: l.deleted);
    if (r == true) ref.invalidate(memberGroupsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final async = ref.watch(memberGroupsProvider);
    return SubPage(
      title: l.mgTitle,
      fab: FloatingActionButton.extended(key: const ValueKey('mg-add'), onPressed: () => _edit(null), icon: const Icon(Icons.add_rounded), label: Text(l.mgAdd)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(memberGroupsProvider)),
        data: (groups) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
          Text(l.mgHint, style: context.sans(12, color: p.muted)),
          const SizedBox(height: 12),
          for (final g in groups)
            Card(
              child: ListTile(
                leading: Icon(g.builtIn ? Icons.lock_outline_rounded : Icons.groups_2_outlined, color: g.active ? AppColors.maroon : p.subtle),
                title: Text(memberGroupLabel(l, g.key), style: TextStyle(color: g.active ? null : p.subtle)),
                subtitle: Text([
                  if (g.builtIn) l.mgBuiltIn,
                  if (!g.active) l.mgInactive,
                  if (g.memberCount != null) l.mgMembers('${g.memberCount}'),
                  if ((g.description ?? '').isNotEmpty) g.description!,
                ].join(' · ')),
                onTap: () => _edit(g),
                trailing: g.builtIn ? null : IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(g)),
              ),
            ),
        ]),
      ),
    );
  }
}
