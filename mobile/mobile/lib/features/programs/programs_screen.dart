import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../models/activity.dart';
import '../../repositories/providers.dart';
import '../../models/admin.dart';
import '../../widgets/brand.dart';
import '../admin/edit_mode.dart';
import '../../widgets/states.dart';
import '../mezmurs/widgets.dart';
import '../settings/attendance_calendar.dart' show programCategoriesProvider;
import '../guidance/contextual_help_sheet.dart';
import '../guidance/tour_engine.dart';

/// Programs tab: upcoming / past / mine.
class ProgramsScreen extends ConsumerStatefulWidget {
  const ProgramsScreen({super.key});
  @override
  ConsumerState<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends ConsumerState<ProgramsScreen> {
  String _scope = 'upcoming';
  int? _category;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(programRepositoryProvider);
    final revision = ref.watch(contentRevisionProvider);
    return PatternScaffold(
      floatingActionButton: EditModeAddButton(actions: [
        (label: l.newProgram, icon: Icons.event_rounded, permission: Perm.programsManage, run: () => openAdminEditor(context, ref, '/admin/programs/edit/new')),
      ]),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: ScreenTitle(
              l.programs,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month_rounded),
                    tooltip: 'የቀን መቁጠሪያ (Calendar)',
                    onPressed: () => context.push('/programs/calendar'),
                  ),
                  const EditModeToggle(),
                  const ContextualHelpButton(screenRoute: '/programs'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                key: TourKeys.programsFilter,
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'upcoming', label: Text(l.upcoming)),
                  ButtonSegment(value: 'past', label: Text(l.past)),
                  ButtonSegment(value: 'mine', label: Text(l.mine)),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
            ),
          ),
          Consumer(builder: (context, ref, _) {
            final cats = ref.watch(programCategoriesProvider).value ?? const [];
            if (cats.isEmpty) return const SizedBox(height: 4);
            final lang = Localizations.localeOf(context).languageCode;
            return SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(18, 8, 18, 0), children: [
                Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(l.allCategories), selected: _category == null, onSelected: (_) => setState(() => _category = null))),
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text(c.label(lang)), selected: _category == c.id, onSelected: (_) => setState(() => _category = c.id)),
                  ),
              ]),
            );
          }),
          Expanded(
            child: PagedListView<Program>(
              key: ValueKey('$_scope-$_category-$revision'),
              fetch: (page) => repo.list(scope: _scope == 'mine' ? 'all' : _scope, mine: _scope == 'mine', categoryId: _category, page: page),
              emptyMessage: l.noPrograms,
              emptyIcon: Icons.event_busy_outlined,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              separator: const SizedBox(height: 12),
              itemBuilder: (context, p, _) => ProgramCard(program: p, onTap: () => context.push('/programs/${p.id}')),
            ),
          ),
        ]),
      ),
    );
  }
}
