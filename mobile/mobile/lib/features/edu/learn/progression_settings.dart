import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/admin.dart' show Perm;
import '../../../models/json.dart';
import '../../../repositories/providers.dart';
import '../../../widgets/brand.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/states.dart';
import '../../admin/edit_mode.dart' show contentRevisionProvider;
import '../../auth/session.dart' show currentUserProvider;
import 'edu_widgets.dart';
import 'learn_screens.dart' show eduCategoriesProvider;

/// Dedicated Progression & Course Settings screen for Education Admin Panel.
/// Allows administrators to configure sequential lesson unlocking policies,
/// passing thresholds, and study rules across curriculum subjects.
class EduProgressionSettingsScreen extends ConsumerStatefulWidget {
  const EduProgressionSettingsScreen({super.key});

  @override
  ConsumerState<EduProgressionSettingsScreen> createState() => _EduProgressionSettingsScreenState();
}

class _EduProgressionSettingsScreenState extends ConsumerState<EduProgressionSettingsScreen> {
  bool _loading = false;
  List<Json> _subjects = [];
  String _searchQuery = '';
  String _filterMode = 'all'; // 'all', 'sequential', 'open'

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _loading = true);
    final repo = ref.read(eduRepositoryProvider);
    try {
      final list = await repo.subjects(all: true);
      if (mounted) {
        setState(() {
          _subjects = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSequential(Json subject, bool newValue) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final subjectId = asInt(subject['id']);
    if (subjectId == null) return;

    final repo = ref.read(eduRepositoryProvider);
    final updated = await runWithProgress(
      context,
      () => repo.updateSubject(subjectId, {'sequential': newValue}),
      success: isEn
          ? (newValue ? 'Sequential progression enabled' : 'Flexible progression enabled')
          : (newValue ? 'ቅደም-ተከተላዊ ትምህርት ነቅቷል' : 'ክፍት የመማር ሂደት ተመርጧል'),
    );

    if (updated != null && mounted) {
      ref.invalidate(eduCategoriesProvider);
      ref.read(contentRevisionProvider.notifier).bump();
      setState(() {
        final index = _subjects.indexWhere((s) => asInt(s['id']) == subjectId);
        if (index != -1) {
          _subjects[index] = {
            ..._subjects[index],
            'sequential': newValue,
          };
        }
      });
    }
  }

  Future<void> _applyBulk(bool sequential) async {
    final l = context.l10n;
    final isEn = l.isEn;
    final confirmed = await showConfirm(
      context,
      isEn
          ? (sequential
              ? 'Apply sequential progression to ALL ${_subjects.length} subjects? Students will be required to finish each lesson in strict order.'
              : 'Set ALL ${_subjects.length} subjects to open/flexible? Students will be able to access any lesson freely.')
          : (sequential
              ? 'ለሁሉም ${_subjects.length} የትምህርት ዓይነቶች ቅደም-ተከተላዊ መመሪያ ይተገበር? ተማሪዎች እያንዳንዱን ትምህርት በቅደም-ተከተል ማጠናቀቅ ይኖርባቸዋል።'
              : 'ለሁሉም ${_subjects.length} የትምህርት ዓይነቶች ክፍት የመማር ሂደት ይተገበር?'),
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    final repo = ref.read(eduRepositoryProvider);
    await runWithProgress(context, () async {
      for (final s in _subjects) {
        final id = asInt(s['id']);
        if (id != null) {
          try {
            await repo.updateSubject(id, {'sequential': sequential});
          } catch (_) {}
        }
      }
    }, success: isEn ? 'Bulk settings updated' : 'ሁሉም ቅንብሮች ተዘምነዋል');

    if (mounted) {
      ref.invalidate(eduCategoriesProvider);
      ref.read(contentRevisionProvider.notifier).bump();
      _loadSubjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final user = ref.watch(currentUserProvider);

    final isAuthorized = user != null &&
        (user.isSuperAdmin ||
            user.canAny([
              Perm.educationManage,
              Perm.educationContent,
            ]));

    if (!isAuthorized) {
      return PatternScaffold(
        appBar: AppBar(title: Text(isEn ? 'Progression Settings' : 'የመማር ቅደም-ተከተል ደንቦች')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyView(
              icon: Icons.lock_outline_rounded,
              message: isEn
                  ? 'Access restricted. Academic management privileges required.'
                  : 'ይህን ገጽ ለመመልከት የአካዳሚክ አስተዳዳሪ ፈቃድ ያስፈልጋል።',
            ),
          ),
        ),
      );
    }

    final filtered = _subjects.where((s) {
      final isSeq = asBool(s['sequential']);
      if (_filterMode == 'sequential' && !isSeq) return false;
      if (_filterMode == 'open' && isSeq) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final name = (asStr(s['name']) ?? '').toLowerCase();
        final nameEn = (asStr(s['name_en']) ?? '').toLowerCase();
        final desc = (asStr(s['description']) ?? '').toLowerCase();
        if (!name.contains(q) && !nameEn.contains(q) && !desc.contains(q)) return false;
      }
      return true;
    }).toList();

    final seqCount = _subjects.where((s) => asBool(s['sequential'])).length;
    final openCount = _subjects.length - seqCount;

    return PatternScaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Progression & Course Settings' : 'የመማር ቅደም-ተከተል ደንቦች'),
        actions: [
          IconButton(
            tooltip: isEn ? 'Refresh' : 'አድስ',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSubjects,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSubjects,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5D4037),
                    AppColors.maroon,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Sequential Unlocking Rules' : 'ቅደም-ተከተላዊ የትምህርት ደንቦች',
                          style: context.serif(17, color: Colors.white, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn
                              ? 'Control whether students must complete preceding lessons before unlocking the next'
                              : 'ተማሪዎች ቀጣዩን ትምህርት ከመክፈታቸው በፊት የቀደመውን በግዴታ ማጠናቀቅ እንዳለባቸው ይወስኑ',
                          style: context.sans(12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rule Explainer Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border.withValues(alpha: 0.8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.maroon),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'How Progression Works' : 'የመማር ሂደቱ እንዴት ይሰራል?',
                        style: context.sans(14, weight: FontWeight.bold, color: p.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEn
                        ? '• Strict Order (Active): Students open a lesson only after reading and completing the previous one.\n• Flexible Access: Students may browse, read, and review any lesson in the curriculum freely.'
                        : '• በቅደም-ተከተል (ንቁ)፦ ተማሪዎች ቀዳሚውን ትምህርት ሳያጠናቅቁ ቀጣዩን መክፈት አይችሉም።\n• ክፍት ሂደት፦ ተማሪዎች እንደፈለጉ በማንኛውም ጊዜ ማንኛውንም ትምህርት መክፈት ይችላሉ።',
                    style: context.sans(12.5, color: p.muted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _applyBulk(true),
                          icon: const Icon(Icons.lock_clock_rounded, size: 16),
                          label: Text(
                            isEn ? 'Strict All' : 'ሁሉንም በቅደም-ተከተል',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _applyBulk(false),
                          icon: const Icon(Icons.lock_open_rounded, size: 16),
                          label: Text(
                            isEn ? 'Open All' : 'ሁሉንም ክፍት አድርግ',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Row
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    count: _subjects.length,
                    label: isEn ? 'All Subjects' : 'የትምህርት ዓይነቶች',
                    color: AppColors.maroon,
                    icon: Icons.menu_book_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    count: seqCount,
                    label: isEn ? 'Strict Sequential' : 'በቅደም-ተከተል',
                    color: const Color(0xFF2E7D32),
                    icon: Icons.lock_outline_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    count: openCount,
                    label: isEn ? 'Flexible Access' : 'ክፍት መማር',
                    color: const Color(0xFF1F5F8B),
                    icon: Icons.lock_open_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: isEn ? 'Search subject by name...' : 'የትምህርት ዓይነት ይፈልጉ...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: p.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),

            // Filter Chips
            Row(
              children: [
                ChoiceChip(
                  label: Text(isEn ? 'All' : 'ሁሉም'),
                  selected: _filterMode == 'all',
                  onSelected: (_) => setState(() => _filterMode = 'all'),
                  selectedColor: AppColors.maroon,
                  labelStyle: TextStyle(
                    color: _filterMode == 'all' ? Colors.white : null,
                    fontWeight: _filterMode == 'all' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(isEn ? 'Sequential Only ($seqCount)' : 'በቅደም-ተከተል ብቻ ($seqCount)'),
                  selected: _filterMode == 'sequential',
                  onSelected: (_) => setState(() => _filterMode = 'sequential'),
                  selectedColor: AppColors.maroon,
                  labelStyle: TextStyle(
                    color: _filterMode == 'sequential' ? Colors.white : null,
                    fontWeight: _filterMode == 'sequential' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(isEn ? 'Flexible Only ($openCount)' : 'ክፍት ብቻ ($openCount)'),
                  selected: _filterMode == 'open',
                  onSelected: (_) => setState(() => _filterMode = 'open'),
                  selectedColor: AppColors.maroon,
                  labelStyle: TextStyle(
                    color: _filterMode == 'open' ? Colors.white : null,
                    fontWeight: _filterMode == 'open' ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Subjects List
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: LoadingView()))
            else if (filtered.isEmpty)
              EmptyView(
                icon: Icons.tune_rounded,
                message: isEn ? 'No subjects found matching criteria.' : 'በዚህ መስፈርት የተዘጋጀ የትምህርት ዓይነት የለም።',
              )
            else
              for (final s in filtered) ...[
                _SubjectProgressionTile(
                  subject: s,
                  onToggle: (v) => _toggleSequential(s, v),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int count;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: context.serif(18, weight: FontWeight.w700, color: color),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.sans(10.5, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _SubjectProgressionTile extends StatelessWidget {
  const _SubjectProgressionTile({
    required this.subject,
    required this.onToggle,
  });

  final Json subject;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;

    final names = eduNames(context, subject);
    final isSequential = asBool(subject['sequential']);
    final lessonCount = asIntOr(subject['lesson_count']);
    final unitCount = asIntOr(subject['unit_count']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSequential
              ? AppColors.maroon.withValues(alpha: 0.4)
              : p.border.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (isSequential ? AppColors.maroon : const Color(0xFF1F5F8B))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSequential ? Icons.lock_clock_rounded : Icons.lock_open_rounded,
              color: isSequential ? AppColors.maroon : const Color(0xFF1F5F8B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  names.title,
                  style: context.serif(15, weight: FontWeight.w700, color: p.text),
                ),
                if (names.subtitle != null)
                  Text(
                    names.subtitle!,
                    style: context.sans(11.5, color: p.muted),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (unitCount > 0)
                      Pill(isEn ? '$unitCount Units' : '$unitCount ምዕራፎች', icon: Icons.folder_outlined),
                    Pill(isEn ? '$lessonCount Lessons' : '$lessonCount ትምህርቶች', icon: Icons.menu_book_outlined),
                    Pill(
                      isSequential
                          ? (isEn ? 'Strict Order' : 'በቅደም-ተከተል')
                          : (isEn ? 'Flexible' : 'ክፍት'),
                      color: isSequential ? AppColors.maroon : const Color(0xFF1F5F8B),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Switch.adaptive(
                value: isSequential,
                activeTrackColor: AppColors.maroon,
                onChanged: onToggle,
              ),
              Text(
                isSequential
                    ? (isEn ? 'Locked' : 'የተቆለፈ')
                    : (isEn ? 'Open' : 'ክፍት'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSequential ? AppColors.maroon : p.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
