import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin.dart';
import '../../models/content.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';
import 'admin_widgets.dart';
import 'content_admin.dart' show statusLabel;

/// Import templates (same formats the server parses — see backend services/importService.js).
const importTemplates = {
  'mezmurs': (
    file: 'mezmurs-template.txt',
    text: 'Title: የመስቀል መዝሙር\nCategory: የመስቀል መዝሙራት\nTags: መስቀል, በዓል\nStatus: published\n\nመስመር አንድ\nመስመር ሁለት\n===\nTitle: ሁለተኛ መዝሙር\nCategory: የመስቀል መዝሙራት > የጠዋት\nStatus: draft\n\nየመዝሙሩ ግጥም እዚህ ይገባል\n',
  ),
  'categories': (
    file: 'categories-template.csv',
    text: 'name,parent,description,order,active\nየመስቀል መዝሙራት,,የመስከረም 17 መዝሙራት,1,true\nየጠዋት,የመስቀል መዝሙራት,,1,true\nየዐቢይ ጾም መዝሙራት,,,2,true\n',
  ),
  'users': (
    file: 'users-template.csv',
    text: 'full_name,phone,email,pin\nአበበ በቀለ,0911223344,,\nሰላም ተስፋዬ,0922334455,selam@example.com,4826\n',
  ),
};

/// Bulk import of Mezmurs, categories and users. 1) download the Excel template (examples and the
/// allowed values inside); 2) add rows: upload the filled file (.xlsx / .csv / .txt), paste rows
/// copied from Excel or Google Sheets, or (Mezmurs) type them in the app; 3) every row is checked
/// first (✓ / ✗ with the reason) and nothing is saved until "Import".
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});
  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  String? _kind;
  String? _fileName;
  String? _content;
  String _format = 'auto';
  Json? _result;
  bool _busy = false;

  List<String> _kinds(AppUser u) => [
        if (u.can(Perm.mezmursCreate)) 'mezmurs',
        if (u.can(Perm.categoriesManage)) 'categories',
        if (u.can(Perm.usersCreate)) 'users',
      ];

  String _label(String k) => switch (k) {
        'mezmurs' => context.l10n.importMezmurs,
        'categories' => context.l10n.categories,
        _ => context.l10n.users,
      };

  String _help(String k) => switch (k) {
        'mezmurs' => context.l10n.importMezmursHelp2,
        'categories' => context.l10n.importCategoriesHelp,
        _ => context.l10n.importUsersHelp2,
      };

  /// The Excel template (examples + allowed values / existing categories), opened or shared.
  Future<void> _excelTemplate(String k) async {
    final bytes = await runWithProgress(context, () => ref.read(adminRepositoryProvider).importTemplateXlsx(k));
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, '$k-template.xlsx'));
    await f.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')], subject: '$k-template.xlsx'));
  }

  /// The plain text template (older .txt / .csv formats).
  Future<void> _shareTemplate(String k) async {
    final t = importTemplates[k]!;
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, t.file));
    // BOM so Excel opens the Amharic text as UTF-8.
    await f.writeAsString('${String.fromCharCode(0xFEFF)}${t.text}', encoding: utf8);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: t.file));
  }

  Future<void> _pick() async {
    final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'csv', 'txt', 'tsv']);
    final path = res.isEmpty ? null : res.first.path;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    final ext = p.extension(path).toLowerCase();
    setState(() {
      _fileName = p.basename(path);
      _format = switch (ext) { '.xlsx' => 'xlsx', '.txt' => 'auto', '.tsv' => 'tsv', _ => 'csv' };
      _content = ext == '.xlsx' ? base64Encode(bytes) : utf8.decode(bytes, allowMalformed: true);
      _result = null;
    });
    await _run(dryRun: true);
  }

  /// Rows copied from Excel / Google Sheets arrive tab separated (header row included).
  Future<void> _paste() async {
    final l = context.l10n;
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!mounted) return;
    final text = await promptText(context, title: l.importPaste, label: l.importPasteHint, initial: clip.contains('\t') ? clip : null, maxLines: 10);
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _fileName = l.importPasted;
      _format = text.contains('\t') ? 'tsv' : 'auto';
      _content = text;
      _result = null;
    });
    await _run(dryRun: true);
  }

  /// Mezmurs typed in the app, sent as a CSV table.
  Future<void> _typeRows() async {
    final rows = await Navigator.of(context).push<List<Map<String, String>>>(MaterialPageRoute(builder: (_) => const QuickMezmurRowsScreen()));
    if (rows == null || rows.isEmpty || !mounted) return;
    setState(() {
      _fileName = context.l10n.importTyped('${rows.length}');
      _format = 'csv';
      _content = toCsv(['title', 'category', 'lyrics', 'tags', 'status'], rows);
      _result = null;
    });
    await _run(dryRun: true);
  }

  Future<void> _run({required bool dryRun}) async {
    if (_content == null || _kind == null) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(adminRepositoryProvider).runImport(_kind!, _content!, dryRun: dryRun, format: _format);
      if (!mounted) return;
      setState(() => _result = r);
      if (!dryRun) showSnack(context, context.l10n.importDone(asIntOr(r['ok'])));
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _step(String n, String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(radius: 12, backgroundColor: AppColors.gold, child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: context.sans(14, weight: FontWeight.w700))),
            ]),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pal = context.palette;
    final user = ref.watch(currentUserProvider)!;
    final kinds = _kinds(user);
    _kind ??= kinds.isEmpty ? null : kinds.first;
    final r = _result;
    final rows = asJsonList(r?['rows']);
    final passwords = rows.where((x) => x['temporary_password'] != null).toList();

    return AdminScaffold(
      title: l.bulkImport,
      actions: const [
        ContextualHelpButton(screenRoute: '/admin/import'),
      ],
      body: _kind == null
          ? const SizedBox.shrink()
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [for (final k in kinds) ButtonSegment(value: k, label: Text(_label(k)))],
                selected: {_kind!},
                onSelectionChanged: (x) => setState(() {
                  _kind = x.first;
                  _content = null;
                  _fileName = null;
                  _result = null;
                }),
              ),
              _step('1', l.importStepTemplate, [
                Text(_help(_kind!), style: context.sans(12, color: pal.muted, height: 1.6)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('import-template-xlsx'),
                    onPressed: () => _excelTemplate(_kind!),
                    icon: const Icon(Icons.table_view_rounded),
                    label: Text(l.importExcelTemplate),
                  ),
                  TextButton.icon(onPressed: () => _shareTemplate(_kind!), icon: const Icon(Icons.description_outlined), label: Text(l.importTextTemplate)),
                ]),
              ]),
              _step('2', l.importStepRows, [
                FilledButton.icon(
                  key: const ValueKey('import-pick'),
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(l.importUploadFile),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  key: const ValueKey('import-paste'),
                  onPressed: _busy ? null : _paste,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: Text(l.importPaste),
                ),
                if (_kind == 'mezmurs') ...[
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    key: const ValueKey('import-type'),
                    onPressed: _busy ? null : _typeRows,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(l.importTypeRows),
                  ),
                ],
                if (_fileName != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_fileName!, style: context.sans(12, color: pal.muted))),
              ]),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
              if (r != null)
                _step('3', r['dry_run'] == true ? l.importStepCheck : l.importStepDone, [
                  if (r['error'] != null)
                    Text('${r['error']}', style: const TextStyle(color: AppColors.danger))
                  else
                    Pill(
                      l.importResult(asIntOr(r['ok']), asIntOr(r['skipped']), asIntOr(r['failed'])),
                      icon: r['dry_run'] == true ? Icons.fact_check_rounded : Icons.check_circle_rounded,
                      color: asIntOr(r['failed']) > 0 ? AppColors.danger : AppColors.success,
                    ),
                  const SizedBox(height: 6),
                  // Every row: ✓ ready / ⓘ skipped (already there) / ✗ with the reason.
                  for (final x in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        x['ok'] == true ? Icons.check_circle_rounded : (x['skipped'] == true ? Icons.info_outline_rounded : Icons.error_outline_rounded),
                        color: x['ok'] == true ? AppColors.success : (x['skipped'] == true ? AppColors.goldDark : AppColors.danger),
                      ),
                      title: Text('${l.lineN(asIntOr(x['line']))} · ${x['title'] ?? '—'}'),
                      subtitle: x['error'] == null ? null : Text('${x['error']}'),
                    ),
                  if (r['dry_run'] == true && asIntOr(r['ok']) > 0) ...[
                    const SizedBox(height: 10),
                    FilledButton(key: const ValueKey('import-now'), onPressed: _busy ? null : () => _run(dryRun: false), child: Text(l.importNow(asIntOr(r['ok'])))),
                  ],
                ]),
              if (passwords.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(l.tempPasswordsNote, style: context.sans(12, color: pal.muted)),
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    passwords.map((x) => '${x['title']} · ${x['phone']} · ${x['temporary_password']}').join('\n'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l.share),
                  onPressed: () => SharePlus.instance.share(ShareParams(text: passwords.map((x) => '${x['title']} · ${x['phone']} · ${x['temporary_password']}').join('\n'))),
                ),
              ],
            ]),
    );
  }
}

/// RFC-4180 CSV of [rows] with the [columns] header (quotes around cells with commas, quotes or
/// new lines — lyrics stay multi-line).
String toCsv(List<String> columns, List<Map<String, String>> rows) {
  String cell(String v) => v.contains(RegExp(r'[",\n\r]')) ? '"${v.replaceAll('"', '""')}"' : v;
  return [columns.join(','), for (final r in rows) columns.map((c) => cell(r[c] ?? '')).join(',')].join('\n');
}

/// Type several Mezmurs in a row (title, category, lyrics); they go through the same check.
class QuickMezmurRowsScreen extends ConsumerStatefulWidget {
  const QuickMezmurRowsScreen({super.key});
  @override
  ConsumerState<QuickMezmurRowsScreen> createState() => _QuickMezmurRowsScreenState();
}

class _QuickRow {
  final title = TextEditingController();
  final lyrics = TextEditingController();
  final tags = TextEditingController();
  String? category;
  String status = 'draft';
  void dispose() {
    title.dispose();
    lyrics.dispose();
    tags.dispose();
  }
}

class _QuickMezmurRowsScreenState extends ConsumerState<QuickMezmurRowsScreen> {
  final _rows = [_QuickRow()];
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cats = ref.watch(adminCategoryPathsProvider).value ?? const <String>[];
    return AdminScaffold(
      title: l.importTypeRows,
      actions: [
        TextButton(
          key: const ValueKey('quick-check'),
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop([
              for (final r in _rows)
                {'title': r.title.text.trim(), 'category': r.category ?? '', 'lyrics': r.lyrics.text.trim(), 'tags': r.tags.text.trim(), 'status': r.status},
            ]);
          },
          child: Text(l.importCheckRows),
        ),
      ],
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Text('#${i + 1}', style: context.sans(13, weight: FontWeight.w700, color: AppColors.goldDark)),
                    const Spacer(),
                    if (_rows.length > 1)
                      IconButton(
                        tooltip: l.remove,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _rows.removeAt(i).dispose()),
                      ),
                  ]),
                  TextFormField(
                    key: ValueKey('quick-title-$i'),
                    controller: _rows[i].title,
                    decoration: InputDecoration(labelText: l.title),
                    validator: (v) => (v ?? '').trim().isEmpty ? l.vRequired : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _rows[i].category,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.category),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.none)),
                      for (final c in cats) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _rows[i].category = v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('quick-lyrics-$i'),
                    controller: _rows[i].lyrics,
                    minLines: 4,
                    maxLines: 12,
                    decoration: InputDecoration(labelText: l.lyrics, alignLabelWithHint: true),
                    validator: (v) => (v ?? '').trim().isEmpty ? l.vRequired : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(controller: _rows[i].tags, decoration: InputDecoration(labelText: l.tagsHint)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'draft', label: Text(statusLabel(l, 'draft'))),
                      ButtonSegment(value: 'published', label: Text(statusLabel(l, 'published'))),
                    ],
                    selected: {_rows[i].status},
                    onSelectionChanged: (s) => setState(() => _rows[i].status = s.first),
                  ),
                ]),
              ),
            ),
          OutlinedButton.icon(
            key: const ValueKey('quick-add'),
            onPressed: () => setState(() => _rows.add(_QuickRow())),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.importAddRow),
          ),
        ]),
      ),
    );
  }
}

/// "Parent > Child" paths of the categories (for choosing one when typing Mezmurs).
final adminCategoryPathsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final tree = await ref.watch(contentRepositoryProvider).categoryTree();
  final out = <String>[];
  void walk(List<CategoryNode> cs, String prefix) {
    for (final c in cs) {
      final path = prefix.isEmpty ? c.name : '$prefix > ${c.name}';
      out.add(path);
      walk(c.children, path);
    }
  }

  walk(tree, '');
  return out;
});
