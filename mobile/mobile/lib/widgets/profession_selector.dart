import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/profession.dart';
import '../repositories/providers.dart';

final professionsListProvider = FutureProvider.autoDispose<List<Profession>>((ref) async {
  try {
    return await ref.watch(professionRepositoryProvider).list();
  } catch (_) {
    return _fallbackProfessions;
  }
});

const _fallbackProfessions = [
  Profession(id: 1, category: 'ቴክኖሎጂ እና ኢንጂነሪንግ (Technology & Engineering)', name: 'የሶፍትዌር ኢንጂነር (Software Engineer)'),
  Profession(id: 2, category: 'ቴክኖሎጂ እና ኢንጂነሪንግ (Technology & Engineering)', name: 'የኢንፎርሜሽን ቴክኖሎጂ ባለሙያ (IT Specialist)'),
  Profession(id: 3, category: 'ቴክኖሎጂ እና ኢንጂነሪንግ (Technology & Engineering)', name: 'የሲቪል ኢንጂነር (Civil Engineer)'),
  Profession(id: 4, category: 'ጤና እና ሕክምና (Health & Medicine)', name: 'ሐኪም / ሜዲካል ዶክተር (Medical Doctor)'),
  Profession(id: 5, category: 'ጤና እና ሕክምና (Health & Medicine)', name: 'ነርስ (Nurse)'),
  Profession(id: 6, category: 'ጤና እና ሕክምና (Health & Medicine)', name: 'ፋርማሲስት (Pharmacist)'),
  Profession(id: 7, category: 'ትምህርት እና አካዳሚክ (Education & Academia)', name: 'የመጀመሪያ/ሁለተኛ ደረጃ መምህር (School Teacher)'),
  Profession(id: 8, category: 'ትምህርት እና አካዳሚክ (Education & Academia)', name: 'የዩኒቨርሲቲ/ኮሌጅ መምህር (University Lecturer)'),
  Profession(id: 9, category: 'ንግድ እና ፋይናንስ (Business & Finance)', name: 'አካውንታንት / የሒሳብ ባለሙያ (Accountant)'),
  Profession(id: 10, category: 'ንግድ እና ፋይናንስ (Business & Finance)', name: 'የባንክ ባለሙያ (Banker)'),
  Profession(id: 11, category: 'ሕግ እና አስተዳደር (Law & Governance)', name: 'ጠበቃ (Lawyer / Attorney)'),
  Profession(id: 12, category: 'እደ-ጥበብ እና ቴክኒክ (Trades & Craftsmanship)', name: 'የኤሌክትሪክ ቴክኒሻን (Electrician)'),
  Profession(id: 13, category: 'እደ-ጥበብ እና ቴክኒክ (Trades & Craftsmanship)', name: 'ሾፌር (Driver)'),
  Profession(id: 14, category: 'ስነ-መለኮት እና መንፈሳዊ አገልግሎት (Theology & Clergy)', name: 'ቀሲስ / ካህን (Priest)'),
  Profession(id: 15, category: 'ስነ-መለኮት እና መንፈሳዊ አገልግሎት (Theology & Clergy)', name: 'ዲያቆን (Deacon)'),
  Profession(id: 16, category: 'ሌላ ሙያ (Other)', name: 'ሌላ (Other)'),
];

class ProfessionSelectorField extends ConsumerStatefulWidget {
  const ProfessionSelectorField({
    super.key,
    required this.selectedProfession,
    required this.selectedProfessionOther,
    required this.onChanged,
    this.initialProfessionId,
    this.initialCategory,
  });

  final String? selectedProfession;
  final TextEditingController selectedProfessionOther;
  final void Function({required String name, required String category, int? id}) onChanged;
  final int? initialProfessionId;
  final String? initialCategory;

  @override
  ConsumerState<ProfessionSelectorField> createState() => _ProfessionSelectorFieldState();
}

class _ProfessionSelectorFieldState extends ConsumerState<ProfessionSelectorField> {
  String? _currentName;
  String? _currentCategory;
  int? _currentId;

  @override
  void initState() {
    super.initState();
    _currentName = widget.selectedProfession;
    _currentCategory = widget.initialCategory;
    _currentId = widget.initialProfessionId;
  }

  @override
  void didUpdateWidget(covariant ProfessionSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedProfession != oldWidget.selectedProfession) {
      _currentName = widget.selectedProfession;
    }
  }

  bool get _isOther {
    final n = (_currentName ?? '').toLowerCase();
    return n.contains('other') || n.contains('ሌላ');
  }

  Future<void> _pickProfession() async {
    final list = ref.read(professionsListProvider).value ?? _fallbackProfessions;
    final selected = await showModalBottomSheet<Profession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ProfessionPickerSheet(
        professions: list,
        currentlySelectedId: _currentId,
        currentlySelectedName: _currentName,
      ),
    );

    if (selected != null) {
      setState(() {
        _currentName = selected.name;
        _currentCategory = selected.category;
        _currentId = selected.id;
      });
      widget.onChanged(name: selected.name, category: selected.category, id: selected.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _pickProfession,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: p.divider),
              borderRadius: BorderRadius.circular(10),
              color: p.fill,
            ),
            child: Row(
              children: [
                Icon(Icons.work_outline_rounded, size: 20, color: p.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'የሙያ ዘርፍ / ሙያ *',
                        style: context.sans(11, color: p.muted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentName ?? 'ሙያ ይምረጡ (Select Profession)',
                        style: context.sans(
                          14,
                          weight: _currentName == null ? FontWeight.normal : FontWeight.w600,
                          color: _currentName == null ? p.muted : p.text,
                        ),
                      ),
                      if (_currentCategory != null && _currentCategory!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _currentCategory!,
                          style: context.sans(11, color: AppColors.maroon),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: p.muted),
              ],
            ),
          ),
        ),
        if (_isOther) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.selectedProfessionOther,
            decoration: InputDecoration(
              labelText: 'የሙያው ዝርዝር መግለጫ (Custom Description) *',
              hintText: 'እባክዎ ትክክለኛውን የሙያዎን ስም እዚህ ይግለጹ...',
              prefixIcon: const Icon(Icons.edit_note_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return '«ሌላ» ሲመረጥ የሙያው ዝርዝር መግለጫ መሞላት አለበት';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
}

class _ProfessionPickerSheet extends StatefulWidget {
  const _ProfessionPickerSheet({
    required this.professions,
    this.currentlySelectedId,
    this.currentlySelectedName,
  });

  final List<Profession> professions;
  final int? currentlySelectedId;
  final String? currentlySelectedName;

  @override
  State<_ProfessionPickerSheet> createState() => _ProfessionPickerSheetState();
}

class _ProfessionPickerSheetState extends State<_ProfessionPickerSheet> {
  final _search = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final query = _search.text.trim().toLowerCase();

    final categories = <String>{};
    for (final prof in widget.professions) {
      categories.add(prof.category);
    }
    final catList = categories.toList()..sort();

    final filtered = widget.professions.where((prof) {
      if (_selectedCategory != null && prof.category != _selectedCategory) {
        return false;
      }
      if (query.isNotEmpty) {
        final inName = prof.name.toLowerCase().contains(query);
        final inCat = prof.category.toLowerCase().contains(query);
        return inName || inCat;
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('ሙያ ይምረጡ', style: context.serif(18, weight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _search.clear()),
                      )
                    : null,
                hintText: 'በሙያ ስም ወይም በዘርፍ ይፈልጉ...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('ሁሉም (All)'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 6),
                for (final cat in catList) ...[
                  FilterChip(
                    label: Text(cat.split(' (').first),
                    selected: _selectedCategory == cat,
                    onSelected: (sel) => setState(() => _selectedCategory = sel ? cat : null),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('ምንም ሙያ አልተገኘም', style: context.sans(14, color: p.muted)),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final prof = filtered[i];
                      final isSelected = widget.currentlySelectedId == prof.id ||
                          widget.currentlySelectedName == prof.name;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isSelected ? AppColors.maroon : p.fill,
                          child: Icon(
                            prof.isOther ? Icons.more_horiz_rounded : Icons.work_outline_rounded,
                            size: 16,
                            color: isSelected ? Colors.white : p.muted,
                          ),
                        ),
                        title: Text(
                          prof.name,
                          style: context.sans(14, weight: isSelected ? FontWeight.w600 : FontWeight.normal),
                        ),
                        subtitle: Text(prof.category, style: context.sans(11, color: p.muted)),
                        trailing: !prof.isActive
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('የቀድሞ ሙያ', style: context.sans(10, color: p.muted)),
                              )
                            : isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.maroon)
                                : null,
                        onTap: () {
                          if (!prof.isActive && widget.currentlySelectedId != prof.id) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ይህ ሙያ ተዘግቷል፤ አዲስ መምረጥ አይቻልም')),
                            );
                            return;
                          }
                          Navigator.pop(context, prof);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
