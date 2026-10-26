import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/error_text.dart';
import '../../core/network/api_exception.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/activity.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../services/sync_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../guidance/contextual_help_sheet.dart';
import '../settings/account_screens.dart' show BorrowingDetailBody, deadlineInfo;
import '../../widgets/ethiopian_date_picker.dart';
import 'admin_widgets.dart';
import 'org_admin.dart' show departmentName;

// =============================================================================
// Items
// =============================================================================
final _itemDepartmentsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(orgRepositoryProvider).departments());

class ItemsAdminScreen extends ConsumerStatefulWidget {
  const ItemsAdminScreen({super.key});
  @override
  ConsumerState<ItemsAdminScreen> createState() => _ItemsAdminScreenState();
}

class _ItemsAdminScreenState extends ConsumerState<ItemsAdminScreen> {
  final _ctrl = PagedListController<ItemModel>();
  String _q = '';

  Future<void> _edit([ItemModel? item]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: _ItemEditor(existing: item)),
    );
    if (saved == true) await _ctrl.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    return AdminScaffold(
      title: l.items,
      actions: [
        const ContextualHelpButton(screenRoute: '/admin/library'),
        IconButton(
          tooltip: l.itemCategoriesConfig,
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => _openItemCategoriesConfig(context, ref),
        ),
      ],
      fab: FloatingActionButton.extended(onPressed: _edit, icon: const Icon(Icons.add_rounded), label: Text(l.newItem)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        Expanded(
          child: PagedListView<ItemModel>(
            key: ValueKey(_q),
            controller: _ctrl,
            fetch: (page) => ref.read(adminRepositoryProvider).items(q: _q.isEmpty ? null : _q, page: page),
            emptyMessage: l.noResults,
            emptyIcon: Icons.inventory_2_outlined,
            itemBuilder: (context, it, _) => TrackTile(
              title: it.name,
              subtitle: [
                it.code,
                if (it.author != null) it.author!,
                ?it.categoryLabel(lang),
                if (it.kind == 'digital') l.libKindDigital else l.availableOf(it.available, it.quantity),
                if (it.status != 'active') itemStatusLabel(l, it.status),
              ].join(' · '),
              leading: ListThumb(icon: it.kind == 'digital' ? Icons.picture_as_pdf_rounded : Icons.inventory_2_outlined, imageUrl: it.imageUrl),
              trailing: IconButton(tooltip: l.itemHistory, icon: const Icon(Icons.history_rounded), onPressed: () => showItemHistory(context, ref, it)),
              onTap: () => _edit(it),
            ),
          ),
        ),
      ]),
    );
  }
}

final _itemCategoriesProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(adminRepositoryProvider).itemCategories(all: true));

Future<void> _openItemCategoriesConfig(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => const _ItemCategoriesConfigSheet(),
  );
  ref.invalidate(_itemCategoriesProvider);
}

class _ItemCategoriesConfigSheet extends ConsumerStatefulWidget {
  const _ItemCategoriesConfigSheet();
  @override
  ConsumerState<_ItemCategoriesConfigSheet> createState() => _ItemCategoriesConfigSheetState();
}

class _ItemCategoriesConfigSheetState extends ConsumerState<_ItemCategoriesConfigSheet> {
  Future<void> _addOrEdit([Json? cat]) async {
    final l = context.l10n;
    final nameCtrl = TextEditingController(text: cat?['name']?.toString() ?? '');
    final nameEnCtrl = TextEditingController(text: cat?['name_en']?.toString() ?? '');
    final codeCtrl = TextEditingController(text: cat?['code']?.toString() ?? '');
    final keyCtrl = TextEditingController(text: cat?['key']?.toString() ?? '');
    final isEdit = cat != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text(isEdit ? l.itemCategoryEdit : l.itemCategoryNew),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l.itemCategoryNameAm),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameEnCtrl,
                decoration: InputDecoration(labelText: l.itemCategoryNameEn),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(labelText: l.itemCategoryCode),
              ),
              if (!isEdit) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: keyCtrl,
                  decoration: InputDecoration(labelText: l.itemCategoryKey, helperText: l.itemCategoryKeyHint),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l.save),
          ),
        ],
      ),
    );

    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      final repo = ref.read(adminRepositoryProvider);
      final body = {
        'name': nameCtrl.text.trim(),
        if (nameEnCtrl.text.trim().isNotEmpty) 'name_en': nameEnCtrl.text.trim(),
        if (codeCtrl.text.trim().isNotEmpty) 'code': codeCtrl.text.trim().toUpperCase(),
        if (!isEdit && keyCtrl.text.trim().isNotEmpty) 'key': keyCtrl.text.trim().toLowerCase(),
      };
      try {
        await repo.saveItemCategory(cat?['key']?.toString(), body);
        ref.invalidate(_itemCategoriesProvider);
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) showErrorSnack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final catsAsync = ref.watch(_itemCategoriesProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.itemCategoriesConfig, style: context.serif(19)),
                  IconButton(
                    tooltip: l.itemCategoryNew,
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _addOrEdit(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: catsAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(error: e),
                data: (cats) {
                  if (cats.isEmpty) {
                    return Center(child: Text(l.noResults));
                  }
                  return ListView.builder(
                    itemCount: cats.length,
                    itemBuilder: (ctx, i) {
                      final c = cats[i];
                      final name = isEn && c['name_en'] != null ? '${c['name_en']}' : '${c['name']}';
                      final code = c['code'] != null ? '[${c['code']}] ' : '';
                      final isBuiltIn = c['built_in'] == true;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${c['code'] ?? 'IT'}'),
                        ),
                        title: Text('$code$name'),
                        subtitle: Text('${l.itemCategoryKey}: ${c['key']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _addOrEdit(c),
                            ),
                            if (!isBuiltIn)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                onPressed: () async {
                                  final ok = await showConfirm(context, l.itemCategoryDeleteConfirm);
                                  if (!mounted || !ok) return;
                                  try {
                                    await ref.read(adminRepositoryProvider).deleteItemCategory('${c['key']}');
                                    ref.invalidate(_itemCategoriesProvider);
                                    if (mounted) setState(() {});
                                  } catch (e) {
                                    if (!mounted) return;
                                    showErrorSnack(this.context, e);
                                  }
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemEditor extends ConsumerStatefulWidget {
  const _ItemEditor({this.existing});
  final ItemModel? existing;
  @override
  ConsumerState<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends ConsumerState<_ItemEditor> {
  final _form = GlobalKey<FormState>();
  late ItemModel? _item = widget.existing;
  late final _name = TextEditingController(text: _item?.name);
  late final _author = TextEditingController(text: _item?.author);
  late String _kind = _item?.kind ?? 'physical';
  late final _code = TextEditingController(text: _item?.code);
  late String? _category = _item?.category;
  String? _suggestedCode;
  late final _desc = TextEditingController(text: _item?.description);
  late final _qty = TextEditingController(text: '${_item?.quantity ?? 1}');
  late final _condition = TextEditingController(text: _item?.condition);
  late final _location = TextEditingController(text: _item?.location);
  late final _notes = TextEditingController(text: _item?.notes);
  late String _status = _item?.status ?? 'active';
  late String _domain = _item?.domain ?? 'mezmur';
  late int? _department = _item?.departmentId;
  late bool _direct = _item?.directBorrowable ?? false;
  late bool _renewable = _item?.renewable ?? false;
  late final _maxQty = TextEditingController(text: _item?.maxQuantity?.toString());
  late final _maxDays = TextEditingController(text: _item?.maxDays?.toString());
  Object? _error;

  bool _isHymnsDepartment(int? deptId, List<Json> depts) {
    if (deptId == null) return false;
    final d = depts.firstWhere((x) => asIntOr(x['id']) == deptId, orElse: () => {});
    final nameEn = (d['name_en'] ?? '').toString().toLowerCase();
    final name = (d['name'] ?? '').toString();
    return deptId == 1 || nameEn.contains('hymn') || name.contains('ዝማሬ');
  }

  bool _isEducationDepartment(int? deptId, List<Json> depts) {
    if (deptId == null) return false;
    final d = depts.firstWhere((x) => asIntOr(x['id']) == deptId, orElse: () => {});
    final nameEn = (d['name_en'] ?? '').toString().toLowerCase();
    final name = (d['name'] ?? '').toString();
    return deptId == 2 || nameEn.contains('education') || name.contains('ትምህርት');
  }

  @override
  void initState() {
    super.initState();
    if (_item == null) {
      _suggestCode();
    }
  }

  /// The code a new item would get (department + category); shown as the code field's hint.
  Future<void> _suggestCode() async {
    if (_item != null) return;
    try {
      final c = await ref.read(adminRepositoryProvider).nextItemCode(departmentId: _department, category: _category);
      if (mounted) setState(() => _suggestedCode = c);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final body = {
      'name': _name.text.trim(),
      'author': opt(_author),
      'kind': _kind,
      // Empty: the server gives the next department-based code (e.g. FIN-EQ-0004).
      if (_code.text.trim().isNotEmpty || _item == null) 'code': _code.text.trim(),
      'category': _category,
      'domain': _domain,
      'description': opt(_desc),
      // A digital book has no copies to lend.
      'quantity': _kind == 'digital' ? 0 : int.parse(_qty.text.trim()),
      'condition': opt(_condition),
      'location': opt(_location),
      'notes': opt(_notes),
      'status': _status,
      'department_id': _department,
      'direct_borrowable': _direct,
      'max_quantity': int.tryParse(_maxQty.text.trim()),
      'max_days': int.tryParse(_maxDays.text.trim()),
      'renewable': _renewable,
    };
    final repo = ref.read(adminRepositoryProvider);
    try {
      final it = _item == null ? await repo.createItem(body) : await repo.updateItem(_item!.id, body);
      setState(() {
        _item = it;
        _error = null;
      });
      if (mounted) showSnack(context, context.l10n.saved);
    } catch (e) {
      setState(() => _error = e);
      _form.currentState!.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final repo = ref.read(adminRepositoryProvider);
    return SafeArea(
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_item == null ? l.newItem : l.editItem, style: context.serif(19)),
              IconButton(
                tooltip: Localizations.localeOf(context).languageCode == 'am' ? 'የእቃዎች ምድብ ቅንብር' : 'Configuration',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => _openItemCategoriesConfig(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _name, validator: (s) => v.text(s, max: 200), decoration: InputDecoration(labelText: l.itemName)),
          const SizedBox(height: 12),
          // Books: printed (lent with a signature) or digital (a PDF members download).
          // Property of every kind: books, equipment, electronics, furniture, instruments, office
          // materials, department resources… (configurable categories).
          DropdownButtonFormField<String?>(
            key: const ValueKey('item-category'),
            isExpanded: true,
            initialValue: _category,
            decoration: InputDecoration(labelText: l.itemCategory),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(l.none)),
              for (final c in ref.watch(_itemCategoriesProvider).value ?? const <Json>[])
                DropdownMenuItem<String?>(value: '${c['key']}', child: Text(Localizations.localeOf(context).languageCode == 'en' && c['name_en'] != null ? '${c['name_en']}' : '${c['name']}', overflow: TextOverflow.ellipsis)),
              if (_category != null && !(ref.watch(_itemCategoriesProvider).value ?? const <Json>[]).any((c) => c['key'] == _category))
                DropdownMenuItem<String?>(value: _category, child: Text(_category!)),
            ],
            onChanged: (x) {
              setState(() => _category = x);
              _suggestCode();
            },
          ),
          const SizedBox(height: 12),
          // Books only: printed (lent with a signature) or digital (a PDF members download), and the author.
          if (_category == null || _category == 'books' || _kind == 'digital') ...[
            Text(l.libBookKind, style: context.sans(12, color: context.palette.muted, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              key: const ValueKey('item-kind'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'physical', icon: const Icon(Icons.menu_book_rounded), label: Text(l.libKindPhysical)),
                ButtonSegment(value: 'digital', icon: const Icon(Icons.picture_as_pdf_rounded), label: Text(l.libKindDigital)),
              ],
              selected: {_kind},
              onSelectionChanged: (x) => setState(() => _kind = x.first),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _author, validator: (s) => v.text(s, max: 200, optional: true), decoration: InputDecoration(labelText: l.libAuthor)),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _code,
            validator: (s) => RegExp(r'^[A-Za-z0-9_./-]{0,60}$').hasMatch(s?.trim() ?? '') && (_item == null || (s?.trim() ?? '').isNotEmpty) ? null : l.vInvalidValue,
            decoration: InputDecoration(
              labelText: l.itemCode,
              hintText: _suggestedCode,
              helperText: _item == null ? l.itemCodeAuto : null,
              errorText: serverFieldError(l, _error, 'code'),
            ),
          ),

          if (_kind == 'physical') ...[
            TextFormField(
              controller: _qty,
              keyboardType: TextInputType.number,
              validator: (s) => v.intRange(s, max: 100000),
              decoration: InputDecoration(labelText: l.quantity, errorText: serverFieldError(l, _error, 'quantity')),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(controller: _condition, validator: (s) => v.text(s, max: 100, optional: true), decoration: InputDecoration(labelText: l.condition)),
          const SizedBox(height: 12),
          TextFormField(controller: _location, validator: (s) => v.text(s, max: 200, optional: true), decoration: InputDecoration(labelText: l.storageLocation)),
          const SizedBox(height: 12),
          // Owning / responsible department (the Finance and Property Department sees every department's items).
          DropdownButtonFormField<int?>(
            isExpanded: true,
            initialValue: _department,
            decoration: InputDecoration(labelText: l.itemDepartment),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l.noDepartment)),
              for (final d in ref.watch(_itemDepartmentsProvider).value ?? const <Json>[])
                DropdownMenuItem<int?>(value: asIntOr(d['id']), child: Text(departmentName(context, d), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (x) {
              setState(() {
                _department = x;
                final depts = ref.read(_itemDepartmentsProvider).value ?? const <Json>[];
                if (_isHymnsDepartment(x, depts)) {
                  _domain = 'mezmur';
                } else if (_isEducationDepartment(x, depts)) {
                  _domain = 'timhirt';
                }
              });
              _suggestCode();
            },
          ),
          Builder(builder: (context) {
            final depts = ref.watch(_itemDepartmentsProvider).value ?? const <Json>[];
            final isHymns = _isHymnsDepartment(_department, depts);
            final isEdu = _isEducationDepartment(_department, depts);
            if (isHymns || isEdu) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(Localizations.localeOf(context).languageCode == 'am' ? 'የእቃው ክፍል / ሞጁል (Module / Library)' : 'Module / Library', style: context.sans(12, color: context.palette.muted, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  key: const ValueKey('item-domain'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'mezmur', icon: const Icon(Icons.music_note_rounded), label: Text(l.hubMezmur)),
                    ButtonSegment(value: 'timhirt', icon: const Icon(Icons.school_rounded), label: Text(l.hubEducation)),
                  ],
                  selected: {_domain},
                  onSelectionChanged: (x) => setState(() => _domain = x.first),
                ),
              ],
            );
          }),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.itemDirectBorrowable), subtitle: Text(l.itemDirectBorrowableHint), value: _direct, onChanged: (x) => setState(() => _direct = x)),
          if (_direct) ...[
            Row(children: [
              Expanded(child: TextFormField(controller: _maxQty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.borrowMaxQuantity))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _maxDays, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.borrowMaxDays))),
            ]),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.itemRenewable), value: _renewable, onChanged: (x) => setState(() => _renewable = x)),
          ],
          const SizedBox(height: 12),
          TextFormField(controller: _desc, maxLines: 2, validator: (s) => v.text(s, max: 1000, optional: true), decoration: InputDecoration(labelText: l.description)),
          const SizedBox(height: 12),
          TextFormField(controller: _notes, maxLines: 2, validator: (s) => v.text(s, max: 1000, optional: true), decoration: InputDecoration(labelText: l.notes)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(labelText: l.status),
            items: [
              DropdownMenuItem(value: 'active', child: Text(l.active)),
              DropdownMenuItem(value: 'inactive', child: Text(l.inactive)),
              DropdownMenuItem(value: 'retired', child: Text(l.itemStatusRetired)),
            ],
            onChanged: (x) => setState(() => _status = x!),
          ),
          if (_error != null && (serverFieldError(l, _error, 'code') == null)) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
          const SizedBox(height: 12),
          Row(children: [
            if (_item != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: () async {
                  if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !context.mounted) return;
                  final ok = await runWithProgress(context, () async {
                    await repo.deleteItem(_item!.id);
                    return true;
                  }, success: l.deleted);
                  if (ok == true && context.mounted) Navigator.pop(context, true);
                },
              ),
            Expanded(child: FilledButton(onPressed: _save, child: Text(l.save))),
          ]),
          const SizedBox(height: 14),
          ImageUploadTile(
            label: l.coverImage,
            url: _item?.imageUrl,
            enabled: _item != null,
            onUpload: (p) async {
              final it = await repo.uploadItemImage(_item!.id, p);
              setState(() => _item = it);
            },
          ),
          if (_kind == 'digital')
            ListTile(
              key: const ValueKey('item-pdf'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.picture_as_pdf_rounded, color: _item?.hasFile ?? false ? AppColors.success : AppColors.danger),
              title: Text(_item?.hasFile ?? false ? l.libPdfUploaded : l.libUploadPdf),
              subtitle: _item == null ? Text(l.libSaveFirst) : (_item!.hasFile ? Text(l.libDownloads('${_item!.downloads}')) : null),
              trailing: const Icon(Icons.upload_file_rounded),
              enabled: _item != null,
              onTap: () async {
                final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
                final path = res.isEmpty ? null : res.first.path;
                if (path == null || !context.mounted) return;
                final it = await runWithProgress(context, () => ref.read(libraryRepositoryProvider).uploadBookPdf(_item!.id, path), success: l.libPdfUploaded);
                if (it != null) setState(() => _item = it);
              },
            ),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.close)),
        ]),
      ),
    );
  }
}

// =============================================================================
// Borrowings
// =============================================================================
class BorrowingsAdminScreen extends ConsumerStatefulWidget {
  const BorrowingsAdminScreen({super.key, this.initialFilter});
  final Map<String, dynamic>? initialFilter;
  @override
  ConsumerState<BorrowingsAdminScreen> createState() => _BorrowingsAdminScreenState();
}

class _BorrowingsAdminScreenState extends ConsumerState<BorrowingsAdminScreen> {
  final _ctrl = PagedListController<Borrowing>();
  String _q = '';
  String? _status = 'open';
  String? _domain;
  int? _deptId;
  String? _catKey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final filter = {
      ...?widget.initialFilter,
      'q': _q.isEmpty ? null : _q,
      'status': _status,
      'domain': _domain,
      if (_deptId != null) 'department_id': _deptId,
      if (_catKey != null) 'category': _catKey,
    };
    return AdminScaffold(
      title: l.borrowing,
      actions: [
        IconButton(tooltip: l.bulkBorrowing, icon: const Icon(Icons.group_work_outlined), onPressed: () => context.push('/admin/borrowings/bulk').then((_) => _ctrl.refresh())),
        IconButton(tooltip: l.borrowDirectPolicy, icon: const Icon(Icons.rule_folder_outlined), onPressed: () => context.push('/admin/borrowings/direct-policy')),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/borrowings/new').then((_) => _ctrl.refresh()),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.issueBorrowing),
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 6), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final s in [('open', l.openBorrowings), ('pending', l.bStatusPending), ('overdue', l.overdueFilter), ('returned', l.bStatusReturned), ('lost', l.bStatusLost), ('rejected', l.rejected), (null, l.all)])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(s.$2), selected: _status == s.$1, onSelected: (_) => setState(() => _status = s.$1)),
              ),
            const SizedBox(width: 8),
            for (final d in [('mezmur', l.hubMezmur), ('timhirt', l.hubEducation)])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(label: Text(d.$2), selected: _domain == d.$1, onSelected: (v) => setState(() => _domain = v ? d.$1 : null)),
              ),
            const SizedBox(width: 8),
            if (ref.watch(_itemDepartmentsProvider).value != null)
              PopupMenuButton<int?>(
                child: Chip(
                  avatar: const Icon(Icons.corporate_fare_rounded, size: 16),
                  label: Text(_deptId == null
                      ? (Localizations.localeOf(context).languageCode == 'am' ? 'ክፍል' : 'Department')
                      : (ref.watch(_itemDepartmentsProvider).value!.firstWhere((d) => asIntOr(d['id']) == _deptId, orElse: () => {})['name']?.toString() ?? '$_deptId')),
                ),
                onSelected: (d) => setState(() => _deptId = d),
                itemBuilder: (_) => [
                  PopupMenuItem<int?>(value: null, child: Text(l.all)),
                  for (final d in ref.watch(_itemDepartmentsProvider).value!)
                    PopupMenuItem<int?>(value: asIntOr(d['id']), child: Text(departmentName(context, d))),
                ],
              ),
            const SizedBox(width: 6),
            if (ref.watch(_itemCategoriesProvider).value != null)
              PopupMenuButton<String?>(
                child: Chip(
                  avatar: const Icon(Icons.category_outlined, size: 16),
                  label: Text(_catKey == null
                      ? (Localizations.localeOf(context).languageCode == 'am' ? 'ምድብ' : 'Category')
                      : (ref.watch(_itemCategoriesProvider).value!.firstWhere((c) => c['key'] == _catKey, orElse: () => {})['name']?.toString() ?? _catKey!)),
                ),
                onSelected: (c) => setState(() => _catKey = c),
                itemBuilder: (_) => [
                  PopupMenuItem<String?>(value: null, child: Text(l.all)),
                  for (final c in ref.watch(_itemCategoriesProvider).value!)
                    PopupMenuItem<String?>(value: '${c['key']}', child: Text(Localizations.localeOf(context).languageCode == 'en' && c['name_en'] != null ? '${c['name_en']}' : '${c['name']}')),
                ],
              ),
          ]),
        ),
        Expanded(
          child: PagedListView<Borrowing>(
            key: ValueKey(filter.toString()),
            controller: _ctrl,
            fetch: (page) => ref.read(adminRepositoryProvider).borrowings(filter: filter, page: page),
            emptyMessage: l.noBorrowings,
            emptyIcon: Icons.inventory_2_outlined,
            itemBuilder: (context, b, _) {
              final d = deadlineInfo(context, b);
              return TrackTile(
                title: '${b.userName ?? ''} — ${b.item.name} × ${b.quantity}',
                subtitle: [
                  '${l.dueOn}: ${f.shortDate(Formatters.parseDateOnly(b.dueOn))}',
                  if (b.fineAmount > 0) f.money(b.fineAmount, b.fineCurrency),
                  if (!b.signed) l.notSigned,
                ].join(' · '),
                leading: ListThumb(icon: Icons.inventory_2_outlined, imageUrl: b.item.imageUrl),
                trailing: Pill(d.text, color: d.color),
                onTap: () => context.push('/admin/borrowings/${b.id}').then((_) => _ctrl.refresh()),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Single issue: user → item → quantity → dates → borrower signs on this screen → record.
class IssueBorrowingScreen extends ConsumerStatefulWidget {
  const IssueBorrowingScreen({super.key});
  @override
  ConsumerState<IssueBorrowingScreen> createState() => _IssueBorrowingScreenState();
}

class _IssueBorrowingScreenState extends ConsumerState<IssueBorrowingScreen> {
  UserSelection? _user;
  ItemModel? _item;
  final _qty = TextEditingController(text: '1');
  final _notes = TextEditingController();
  // Condition when handed over (empty = the item's current condition).
  final _condition = TextEditingController();
  DateTime _borrowed = DateTime.now();
  late DateTime _due = DateTime.now().add(const Duration(days: 14));
  String? _signature;
  bool _busy = false;

  bool get _datesOk => !DateUtils.dateOnly(_due).isBefore(DateUtils.dateOnly(_borrowed));

  Future<void> _submit() async {
    final l = context.l10n;
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (_user == null || _item == null || qty < 1 || !_datesOk) {
      showSnack(context, l.errorValidation);
      return;
    }
    _signature ??= await captureSignature(context, name: _user!.names.values.first, allowSkip: true);
    if (!mounted || _signature == null) return;
    setState(() => _busy = true);
    try {
      // Through the offline queue: issued at once when online (exactly once, even on a dropped
      // connection); saved on the phone with its signature and synced later when offline.
      final out = await ref.read(syncServiceProvider).submit(SyncOp.borrowingCreate, {
        'user_id': _user!.ids.first,
        'item_id': _item!.id,
        'quantity': qty,
        'borrowed_on': Formatters.isoDate(_borrowed),
        'due_on': Formatters.isoDate(_due),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (_condition.text.trim().isNotEmpty) 'issue_condition': _condition.text.trim(),
        if (_signature!.isNotEmpty) 'signature': _signature,
      });
      if (!mounted) return;
      if (out.rejected) {
        showSnack(context, errorText(l, ApiException(code: out.code ?? ApiException.unknown)));
        _signature = null;
        return;
      }
      if (out.queued) {
        showSnack(context, l.borrowingSavedOffline);
        context.pop();
        return;
      }
      showSnack(context, l.borrowingCreated);
      final id = asInt(asJson(out.server)['id']);
      if (id != null) {
        context.pushReplacement('/admin/borrowings/$id');
      } else {
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return AdminScaffold(
      title: l.issueBorrowing,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.person_outline_rounded,
            label: l.borrower,
            value: _user?.names.values.first ?? l.selectUser,
            onTap: () async {
              final u = await pickUsers(context, multiple: false);
              if (u != null) setState(() => _user = u);
            },
          ),
          SettingsTile(
            icon: Icons.inventory_2_outlined,
            label: l.item,
            value: _item == null ? l.selectItem : '${_item!.name}\n${l.availableOf(_item!.available, _item!.quantity)}',
            onTap: () async {
              final it = await pickItem(context);
              if (it != null) setState(() => _item = it);
            },
          ),
        ]),
        const SizedBox(height: 14),
        TextFormField(
          controller: _qty,
          keyboardType: TextInputType.number,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (s) => v.intRange(s, min: 1, max: _item?.available ?? 1000),
          decoration: InputDecoration(labelText: l.quantity),
        ),
        const SizedBox(height: 12),
        DateTimeField(pastOnly: true, label: l.borrowedOn, value: _borrowed, withTime: false, onChanged: (d) => setState(() => _borrowed = d ?? _borrowed)),
        const SizedBox(height: 12),
        DateTimeField(label: l.dueOn, value: _due, withTime: false, errorText: _datesOk ? null : l.vDeadlineBeforeBorrow, onChanged: (d) => setState(() => _due = d ?? _due)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final days in [7, 14, 30]) ActionChip(label: Text('$days ${l.loanDays}'), onPressed: () => setState(() => _due = _borrowed.add(Duration(days: days)))),
        ]),
        const SizedBox(height: 12),
        TextFormField(controller: _condition, validator: (s) => v.text(s, max: 100, optional: true), decoration: InputDecoration(labelText: l.issueCondition, hintText: _item?.condition)),
        const SizedBox(height: 12),
        TextFormField(controller: _notes, maxLines: 2, validator: (s) => v.text(s, max: 500, optional: true), decoration: InputDecoration(labelText: l.notes)),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _busy ? null : _submit, icon: const Icon(Icons.draw_rounded), label: Text('${l.signNow} → ${l.issueBorrowing}')),
      ]),
    );
  }
}

/// Bulk issue: several users × items; each user gets an individual record and may sign in turn.
class BulkBorrowingScreen extends ConsumerStatefulWidget {
  const BulkBorrowingScreen({super.key, this.initial});
  final UserSelection? initial;
  @override
  ConsumerState<BulkBorrowingScreen> createState() => _BulkBorrowingScreenState();
}

class _BulkBorrowingScreenState extends ConsumerState<BulkBorrowingScreen> {
  late UserSelection? _users = widget.initial;
  final _lines = <({ItemModel item, int qty})>[];
  DateTime _borrowed = DateTime.now();
  late DateTime _due = DateTime.now().add(const Duration(days: 14));
  bool _collectSignatures = true;
  bool _busy = false;

  bool get _datesOk => !DateUtils.dateOnly(_due).isBefore(DateUtils.dateOnly(_borrowed));

  Future<void> _submit() async {
    final l = context.l10n;
    final users = _users;
    if (users == null || users.isEmpty || _lines.isEmpty || !_datesOk) {
      showSnack(context, l.errorValidation);
      return;
    }
    if (!await showConfirm(context, l.bulkConfirm(users.count)) || !mounted) return;
    final signatures = <String, String>{};
    if (_collectSignatures && !users.allMatching) {
      for (final id in users.ids) {
        final sig = await captureSignature(context, name: users.names[id] ?? '#$id', allowSkip: true);
        if (!mounted) return;
        if (sig == null) return; // cancelled the whole flow
        if (sig.isNotEmpty) signatures['$id'] = sig;
      }
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(adminRepositoryProvider).bulkBorrow({
        'target': users.toTarget().toJson(),
        'items': [for (final ln in _lines) {'item_id': ln.item.id, 'quantity': ln.qty}],
        'borrowed_on': Formatters.isoDate(_borrowed),
        'due_on': Formatters.isoDate(_due),
        if (signatures.isNotEmpty) 'signatures': signatures,
      });
      if (!mounted) return;
      showSnack(context, l.bulkCreated(asJsonList(r['borrowings']).length));
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AdminScaffold(
      title: l.bulkBorrowing,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        SettingsGroup(children: [
          SettingsTile(
            icon: Icons.groups_outlined,
            label: l.selectUsers,
            value: _users == null ? l.none : l.selectedCount(_users!.count),
            onTap: () async {
              final u = await pickUsers(context);
              if (u != null) setState(() => _users = u);
            },
          ),
        ]),
        SectionHeader(title: l.items, trailing: l.addItem, onTrailingTap: () async {
          final it = await pickItem(context);
          if (it != null && !_lines.any((x) => x.item.id == it.id)) setState(() => _lines.add((item: it, qty: 1)));
        }),
        for (var i = 0; i < _lines.length; i++)
          TrackTile(
            title: _lines[i].item.name,
            subtitle: l.availableOf(_lines[i].item.available, _lines[i].item.quantity),
            leading: ListThumb(icon: Icons.inventory_2_outlined, imageUrl: _lines[i].item.imageUrl),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: _lines[i].qty > 1 ? () => setState(() => _lines[i] = (item: _lines[i].item, qty: _lines[i].qty - 1)) : null),
              Text('${_lines[i].qty}'),
              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _lines[i] = (item: _lines[i].item, qty: _lines[i].qty + 1))),
              IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => setState(() => _lines.removeAt(i))),
            ]),
          ),
        const SizedBox(height: 12),
        DateTimeField(pastOnly: true, label: l.borrowedOn, value: _borrowed, withTime: false, onChanged: (d) => setState(() => _borrowed = d ?? _borrowed)),
        const SizedBox(height: 12),
        DateTimeField(label: l.dueOn, value: _due, withTime: false, errorText: _datesOk ? null : l.vDeadlineBeforeBorrow, onChanged: (d) => setState(() => _due = d ?? _due)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.signature),
          subtitle: Text(l.signatureRequiredHint),
          value: _collectSignatures && !(_users?.allMatching ?? false),
          onChanged: (_users?.allMatching ?? false) ? null : (v) => setState(() => _collectSignatures = v),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(l.bulkBorrowing)),
      ]),
    );
  }
}

final _borrowingProvider = FutureProvider.autoDispose.family<Borrowing, int>((ref, id) => ref.watch(adminRepositoryProvider).borrowing(id));
final _sigProvider = FutureProvider.autoDispose.family<Uint8List?, int>((ref, id) async {
  try {
    return Uint8List.fromList(await ref.watch(adminRepositoryProvider).signatureBytes(id));
  } catch (_) {
    return null;
  }
});

class BorrowingAdminDetailScreen extends ConsumerWidget {
  const BorrowingAdminDetailScreen({super.key, required this.borrowingId});
  final int borrowingId;

  Future<void> _return(BuildContext context, WidgetRef ref, Borrowing b) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: _ReturnSheet(borrowing: b)),
    );
    if (done == true) ref.invalidate(_borrowingProvider(borrowingId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    final repo = ref.read(adminRepositoryProvider);
    void refresh() {
      ref.invalidate(_borrowingProvider(borrowingId));
      ref.invalidate(_sigProvider(borrowingId));
    }

    return AdminScaffold(
      title: l.details,
      body: AsyncView(
        value: ref.watch(_borrowingProvider(borrowingId)),
        onRetry: refresh,
        data: (b) => BorrowingDetailBody(
          borrowing: b,
          admin: true,
          signature: b.signed ? ref.watch(_sigProvider(borrowingId)).value : null,
          actions: [
            if (b.status == 'pending_approval' && me.can(Perm.borrowingApprove)) ...[
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: Text(l.approve),
                onPressed: () async {
                  await runWithProgress(context, () => ref.read(stageRepositoryProvider).approveBorrowing(b.id), success: l.saved);
                  refresh();
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, color: AppColors.danger),
                label: Text(l.reject),
                onPressed: () async {
                  final reason = await promptText(context, title: l.reject, label: l.reason, required: true);
                  if (reason == null || reason.trim().length < 3 || !context.mounted) return;
                  await runWithProgress(context, () => ref.read(stageRepositoryProvider).rejectBorrowing(b.id, reason.trim()), success: l.saved);
                  refresh();
                },
              ),
              const SizedBox(height: 8),
            ],
            if (b.isOpen) FilledButton.icon(onPressed: () => _return(context, ref, b), icon: const Icon(Icons.assignment_return_rounded), label: Text(l.processReturn)),
            if (b.isOpen) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.update_rounded),
                label: Text(l.borrowRenew),
                onPressed: () async {
                  final due = await showEthiopianDatePicker(
                    context: context,
                    initialDate: (Formatters.parseDateOnly(b.dueOn) ?? DateTime.now()).add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (due == null || !context.mounted) return;
                  await runWithProgress(context, () => ref.read(stageRepositoryProvider).renewBorrowing(b.id, Formatters.isoDate(due)), success: l.saved);
                  refresh();
                },
              ),
            ],
            if (!b.signed) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.draw_rounded),
                label: Text(l.signNow),
                onPressed: () async {
                  final sig = await captureSignature(context, name: b.userName ?? '');
                  if (sig == null || sig.isEmpty || !context.mounted) return;
                  await runWithProgress(context, () => repo.sign(b.id, sig), success: l.saved);
                  refresh();
                },
              ),
            ],
            if (me.can(Perm.finesManage)) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton(
                  onPressed: () async {
                    final amount = await promptText(context, title: l.fineOverride, label: l.fineAmount, initial: b.fineAmount.toStringAsFixed(2));
                    final parsed = double.tryParse(amount ?? '');
                    if (parsed == null || parsed < 0 || !context.mounted) return;
                    final reason = await promptText(context, title: l.overrideReason, label: l.overrideReason, required: true);
                    if (reason == null || reason.length < 3 || !context.mounted) return;
                    await runWithProgress(context, () => repo.overrideFine(b.id, parsed, reason), success: l.saved);
                    refresh();
                  },
                  child: Text(l.fineOverride),
                ),
                if (b.fineOverridden)
                  OutlinedButton(
                    onPressed: () async {
                      await runWithProgress(context, () => repo.clearFineOverride(b.id), success: l.saved);
                      refresh();
                    },
                    child: Text(l.clearOverride),
                  ),
                if (b.fineAmount > 0 && b.fineStatus != 'paid')
                  OutlinedButton(
                    onPressed: () async {
                      await runWithProgress(context, () => repo.setFineStatus(b.id, 'paid'), success: l.saved);
                      refresh();
                    },
                    child: Text(l.markPaid),
                  ),
                if (b.fineAmount > 0 && b.fineStatus != 'waived')
                  OutlinedButton(
                    onPressed: () async {
                      if (!await showConfirm(context, l.waiveFine) || !context.mounted) return;
                      await runWithProgress(context, () => repo.setFineStatus(b.id, 'waived'), success: l.saved);
                      refresh();
                    },
                    child: Text(l.waiveFine),
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet({required this.borrowing});
  final Borrowing borrowing;
  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  late final _qty = TextEditingController(text: '${widget.borrowing.outstanding}');
  final _notes = TextEditingController();
  DateTime _returnedOn = DateTime.now();
  String? _condition;
  List<Json> _conditions = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    ref.read(adminRepositoryProvider).returnConditions().then((c) {
      if (mounted) setState(() => _conditions = c);
    });
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final qty = int.tryParse(_qty.text.trim());
    if (_condition == null || qty == null || qty < 1 || qty > widget.borrowing.outstanding) {
      setState(() => _error = null);
      showSnack(context, _condition == null ? l.vInvalidCondition : l.vInvalidReturnQuantity);
      return;
    }
    final out = await ref.read(syncServiceProvider).submit(SyncOp.borrowingReturn, {
      'borrowing_id': widget.borrowing.id,
      'returned_on': Formatters.isoDate(_returnedOn),
      'returned_quantity': qty,
      'return_condition': _condition,
      if (_notes.text.trim().isNotEmpty) 'return_notes': _notes.text.trim(),
    });
    if (!mounted) return;
    if (out.rejected) {
      setState(() => _error = ApiException(code: out.code ?? ApiException.unknown));
      return;
    }
    if (out.queued) showSnack(context, context.l10n.savedOffline);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final borrowedOn = Formatters.parseDateOnly(widget.borrowing.borrowedOn);
    final dateOk = borrowedOn == null || !DateUtils.dateOnly(_returnedOn).isBefore(borrowedOn);
    return SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
        Text(l.processReturn, style: context.serif(19)),
        const SizedBox(height: 14),
        DateTimeField(pastOnly: true, label: l.returnedOn, value: _returnedOn, withTime: false, errorText: dateOk ? null : l.vReturnBeforeBorrow, onChanged: (d) => setState(() => _returnedOn = d ?? _returnedOn)),
        const SizedBox(height: 12),
        TextField(controller: _qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '${l.returnedQuantity} (≤ ${widget.borrowing.outstanding})')),
        const SizedBox(height: 12),
        Text(l.returnCondition, style: context.sans(13, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in _conditions) ChoiceChip(label: Text('${c['label']}'), selected: _condition == c['label'], onSelected: (_) => setState(() => _condition = '${c['label']}')),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _notes, maxLines: 2, decoration: InputDecoration(labelText: l.returnNotes)),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger))),
        const SizedBox(height: 16),
        FilledButton(onPressed: dateOk ? _submit : null, child: Text(l.processReturn)),
      ]),
    );
  }
}

// =============================================================================
// Fine policy + return conditions
// =============================================================================
final _policyProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(adminRepositoryProvider).finePolicy());
final _conditionsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(adminRepositoryProvider).returnConditions(all: true));

class FinesAdminScreen extends ConsumerWidget {
  const FinesAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    return AdminScaffold(
      title: l.fines,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        if (me.can(Perm.finesManage))
          AsyncView(
            value: ref.watch(_policyProvider),
            onRetry: () => ref.invalidate(_policyProvider),
            data: (p) => _PolicyForm(policy: p, onSaved: () => ref.invalidate(_policyProvider)),
          ),
        if (me.can(Perm.borrowingManage)) ...[
          SectionHeader(
            title: l.returnConditions,
            trailing: l.add,
            onTrailingTap: () async {
              final label = await promptText(context, title: l.returnConditions, label: l.title, required: true);
              if (label == null || label.isEmpty || !context.mounted) return;
              await runWithProgress(context, () => ref.read(adminRepositoryProvider).saveReturnCondition(null, {'label': label}), success: l.saved);
              ref.invalidate(_conditionsProvider);
            },
          ),
          AsyncView(
            value: ref.watch(_conditionsProvider),
            onRetry: () => ref.invalidate(_conditionsProvider),
            data: (list) => SettingsGroup(children: [
              for (final c in list)
                ExpansionTile(
                  title: Text('${c['label']}'),
                  subtitle: Text([if (asBool(c['marks_lost'])) l.marksLost, if (asBool(c['restock'])) l.restock, if (!asBool(c['is_active'])) l.inactive].join(' · ')),
                  children: [
                    for (final flag in [('marks_lost', l.marksLost), ('restock', l.restock), ('is_active', l.active)])
                      SwitchListTile(
                        title: Text(flag.$2),
                        value: asBool(c[flag.$1]),
                        onChanged: (v) async {
                          await runWithProgress(context, () => ref.read(adminRepositoryProvider).saveReturnCondition(asIntOr(c['id']), {flag.$1: v}));
                          ref.invalidate(_conditionsProvider);
                        },
                      ),
                  ],
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _PolicyForm extends ConsumerStatefulWidget {
  const _PolicyForm({required this.policy, required this.onSaved});
  final Json policy;
  final VoidCallback onSaved;
  @override
  ConsumerState<_PolicyForm> createState() => _PolicyFormState();
}

class _PolicyFormState extends ConsumerState<_PolicyForm> {
  final _form = GlobalKey<FormState>();
  late bool _enabled = asBool(widget.policy['enabled']);
  late String _period = asStr(widget.policy['period']) ?? 'day';
  late final _amount = TextEditingController(text: '${widget.policy['amount'] ?? 0}');
  late final _grace = TextEditingController(text: '${widget.policy['grace_days'] ?? 0}');
  late final _max = TextEditingController(text: widget.policy['max_amount'] == null ? '' : '${widget.policy['max_amount']}');

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await runWithProgress(context, () async {
      await ref.read(adminRepositoryProvider).saveFinePolicy({
        'enabled': _enabled,
        'amount': double.parse(_amount.text.trim()),
        'period': _period,
        'grace_days': int.parse(_grace.text.trim()),
        'max_amount': _max.text.trim().isEmpty ? null : double.parse(_max.text.trim()),
        'currency': asStr(widget.policy['currency']) ?? 'ETB',
      });
      widget.onSaved();
    }, success: context.l10n.saved);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(title: l.finePolicy),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.fineEnabled), value: _enabled, onChanged: (x) => setState(() => _enabled = x)),
        TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (s) => v.amount(s), decoration: InputDecoration(labelText: l.fineAmount)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: 'day', label: Text(l.perDay)), ButtonSegment(value: 'week', label: Text(l.perWeek))],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.first),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _grace, keyboardType: TextInputType.number, validator: (s) => v.intRange(s, max: 365), decoration: InputDecoration(labelText: l.graceDays)),
        const SizedBox(height: 12),
        TextFormField(controller: _max, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (s) => v.amount(s, optional: true), decoration: InputDecoration(labelText: l.maxFine)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ]),
    );
  }
}


/// Inventory history of an item: changes, borrowings (issued / returned with their condition) and
/// department requests issued / returned — newest first.
Future<void> showItemHistory(BuildContext context, WidgetRef ref, ItemModel item) async {
  final l = context.l10n;
  final rows = await runWithProgress(context, () => ref.read(adminRepositoryProvider).itemHistory(item.id));
  if (rows == null || !context.mounted) return;
  final f = Formatters(l, Localizations.localeOf(context).languageCode);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.75,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('${l.itemHistory} · ${item.name}', style: ctx.serif(17))),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text(l.noResults))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final d = asJson(r['details']);
                      final icon = switch ('${r['kind']}:${r['action']}') {
                        'borrowing:issue' => Icons.call_made_rounded,
                        'borrowing:return' => Icons.call_received_rounded,
                        'property_request:issue' => Icons.outbox_rounded,
                        'property_request:return' => Icons.move_to_inbox_rounded,
                        _ => Icons.edit_note_rounded,
                      };
                      return ListTile(
                        dense: true,
                        leading: Icon(icon, color: AppColors.gold),
                        title: Text([
                          '${r['action']}',
                          if (d['recipient'] != null) '${d['recipient']}',
                          if (d['department'] != null) '${d['department']}',
                          if (d['quantity'] != null) '× ${d['quantity']}',
                        ].join(' · ')),
                        subtitle: Text([
                          if (asDate(r['at']) != null) f.dateTime(asDate(r['at'])!),
                          if (r['by'] != null) '${r['by']}',
                          if (d['condition'] != null) '${l.condition}: ${d['condition']}',
                          if (r['kind'] == 'item' && d['fields'] != null) (d['fields'] as List).join(', '),
                        ].join(' · ')),
                        // The borrowing / request behind the entry, with all its details.
                        onTap: d['borrowing_id'] != null
                            ? () => GoRouter.of(context).push('/admin/borrowings/${d['borrowing_id']}')
                            : d['request_id'] != null
                                ? () => GoRouter.of(context).push('/admin/property-requests')
                                : null,
                        trailing: d['borrowing_id'] != null || d['request_id'] != null ? const Icon(Icons.chevron_right_rounded) : null,
                      );
                    },
                  ),
          ),
        ]),
      ),
    ),
  );
}

/// Item status as shown (active / inactive / retired).
String itemStatusLabel(AppLocalizations l, String status) => switch (status) {
      'active' => l.active,
      'inactive' => l.inactive,
      'retired' => l.itemRetired,
      _ => status,
    };
