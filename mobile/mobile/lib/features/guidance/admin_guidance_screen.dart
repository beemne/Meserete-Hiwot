import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/guidance.dart';
import '../../repositories/guidance_repository.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold, SearchBox;
import 'contextual_help_sheet.dart';
import 'guidance_center_screen.dart' show GuidanceArticleDetailScreen;
import 'target_ui_keys.dart';

class AdminGuidanceScreen extends ConsumerStatefulWidget {
  const AdminGuidanceScreen({super.key});

  @override
  ConsumerState<AdminGuidanceScreen> createState() => _AdminGuidanceScreenState();
}

class _AdminGuidanceScreenState extends ConsumerState<AdminGuidanceScreen> {
  String _selectedStatus = '';
  String _selectedCategory = '';
  String _search = '';

  final _categories = const [
    'general',
    'mezmur',
    'programs',
    'attendance',
    'education',
    'contributions',
    'notifications',
    'departments',
    'tasks',
    'reports',
    'holiday_selection',
    'property',
    'borrowing',
    'settings',
    'admin',
  ];

  AdminGuidanceFilter get _filters => AdminGuidanceFilter(
        status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
        category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
        search: _search.isNotEmpty ? _search : null,
      );

  void _refresh() {
    ref.invalidate(adminGuidanceArticlesProvider);
    ref.invalidate(guidanceArticlesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final isEn = l.isEn;

    final articlesAsync = ref.watch(adminGuidanceArticlesProvider(_filters));

    return AdminScaffold(
      title: isEn ? 'Manage Guidance' : 'የመተግበሪያ መመሪያዎች',
      actions: const [
        ContextualHelpButton(screenRoute: '/admin/guidance'),
      ],
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(isEn ? 'New Article' : 'አዲስ መመሪያ'),
        onPressed: () => _openEditor(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBox(
              hint: isEn ? 'Search articles by title, screen, slug...' : 'መመሪያዎችን በስም ወይም በገጽ ፈልግ...',
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          // Status Chips & Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _StatusChip(
                  label: isEn ? 'All' : 'ሁሉም',
                  selected: _selectedStatus.isEmpty,
                  onSelected: () => setState(() => _selectedStatus = ''),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: isEn ? 'Published' : 'የታተሙ',
                  selected: _selectedStatus == 'published',
                  color: AppColors.success,
                  onSelected: () => setState(() => _selectedStatus = 'published'),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: isEn ? 'Drafts' : 'ረቂቆች',
                  selected: _selectedStatus == 'draft',
                  color: AppColors.warning,
                  onSelected: () => setState(() => _selectedStatus = 'draft'),
                ),
                const SizedBox(width: 6),
                _StatusChip(
                  label: isEn ? 'Retired' : 'የተዘጉ',
                  selected: _selectedStatus == 'retired',
                  color: Colors.grey,
                  onSelected: () => setState(() => _selectedStatus = 'retired'),
                ),
                const SizedBox(width: 12),
                // Category dropdown chip
                PopupMenuButton<String>(
                  initialValue: _selectedCategory,
                  onSelected: (cat) => setState(() => _selectedCategory = cat),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: '', child: Text(isEn ? 'All Categories' : 'ሁሉም ክፍሎች')),
                    ..._categories.map((c) => PopupMenuItem(value: c, child: Text(c.replaceAll('_', ' ').toUpperCase()))),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.filter_list_rounded, size: 16),
                    label: Text(_selectedCategory.isEmpty
                        ? (isEn ? 'Category: All' : 'ክፍል: ሁሉም')
                        : _selectedCategory.replaceAll('_', ' ')),
                    backgroundColor: _selectedCategory.isNotEmpty ? AppColors.gold.withAlpha(40) : null,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // List of Articles
          Expanded(
            child: articlesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                      const SizedBox(height: 12),
                      Text(e.toString(), textAlign: TextAlign.center, style: context.sans(13, color: p.muted)),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _refresh, child: Text(isEn ? 'Retry' : 'እንደገና ሞክር')),
                    ],
                  ),
                ),
              ),
              data: (articles) {
                if (articles.isEmpty) {
                  return EmptyView(
                    icon: Icons.menu_book_outlined,
                    message: isEn ? 'No Guidance Articles. Create your first guidance article using the + button.' : 'ምንም መመሪያ አልተገኘም፤ አዲስ መመሪያ የሚለውን በመጫን ይፍጠሩ።',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: articles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final a = articles[idx];
                    return _AdminArticleCard(
                      article: a,
                      onEdit: () => _openEditor(context, article: a),
                      onPreview: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => GuidanceArticleDetailScreen(article: a)),
                      ),
                      onPublish: () => _publishArticle(a),
                      onRetire: () => _retireArticle(a),
                      onDelete: () => _deleteArticle(a),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _publishArticle(GuidanceArticle a) async {
    final l = context.l10n;
    final confirm = await showConfirm(
      context,
      l.isEn ? 'Publish "${a.title}" for authorized users?' : '"${a.title}" ለተጠቃሚዎች ይፋ ይደረግ?',
      title: l.isEn ? 'Publish Guidance' : 'መመሪያውን አሳትም',
      confirmLabel: l.isEn ? 'Publish' : 'አሳትም',
    );
    if (!confirm || !mounted) return;

    try {
      await ref.read(guidanceRepositoryProvider).adminPublish(a.id);
      if (mounted) {
        showSnack(context, l.isEn ? 'Article published' : 'መመሪያው በተሳካ ሁኔታ ታትሟል');
        _refresh();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _retireArticle(GuidanceArticle a) async {
    final l = context.l10n;
    final confirm = await showConfirm(
      context,
      l.isEn ? 'Retire "${a.title}"? It will no longer be visible to regular users.' : '"${a.title}" ከመደበኛ ተጠቃሚዎች ይደበቅ?',
      title: l.isEn ? 'Retire Guidance' : 'መመሪያውን ዝጋ',
      confirmLabel: l.isEn ? 'Retire' : 'ዝጋ',
      destructive: true,
    );
    if (!confirm || !mounted) return;

    try {
      await ref.read(guidanceRepositoryProvider).adminRetire(a.id);
      if (mounted) {
        showSnack(context, l.isEn ? 'Article retired' : 'መመሪያው ተዘግቷል');
        _refresh();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _deleteArticle(GuidanceArticle a) async {
    final l = context.l10n;
    final confirm = await showConfirm(
      context,
      l.isEn ? 'Permanently delete "${a.title}"? This cannot be undone.' : '"${a.title}" በቋሚነት ይሰረዝ?',
      title: l.isEn ? 'Delete Article' : 'መመሪያውን ሰርዝ',
      confirmLabel: l.isEn ? 'Delete' : 'ሰርዝ',
      destructive: true,
    );
    if (!confirm || !mounted) return;

    try {
      await ref.read(guidanceRepositoryProvider).adminDelete(a.id);
      if (mounted) {
        showSnack(context, l.isEn ? 'Article deleted' : 'መመሪያው ተሰርዟል');
        _refresh();
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _openEditor(BuildContext context, {GuidanceArticle? article}) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GuidanceEditorScreen(article: article),
        fullscreenDialog: true,
      ),
    );
    if (updated == true && mounted) {
      _refresh();
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: (color ?? AppColors.gold).withAlpha(45),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? (color ?? AppColors.gold) : null,
      ),
    );
  }
}

class _AdminArticleCard extends StatelessWidget {
  const _AdminArticleCard({
    required this.article,
    required this.onEdit,
    required this.onPreview,
    required this.onPublish,
    required this.onRetire,
    required this.onDelete,
  });

  final GuidanceArticle article;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onPublish;
  final VoidCallback onRetire;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isEn = context.l10n.isEn;

    final statusColor = switch (article.status) {
      'published' => AppColors.success,
      'draft' => AppColors.warning,
      _ => Colors.grey,
    };

    final roleLabel = switch (article.targetRole) {
      'admin' => isEn ? 'Admins' : 'አስተዳዳሪዎች',
      'department_leader' => isEn ? 'Leaders' : 'የክፍል ኃላፊዎች',
      _ => isEn ? 'All Members' : 'ሁሉም አባላት',
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            article.status.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            roleLabel,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                        if (article.targetScreen != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              article.targetScreen!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.sans(11, color: p.muted),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      style: context.serif(15, weight: FontWeight.w600, color: p.text),
                    ),
                    if (article.overview != null && article.overview!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        article.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.sans(12, color: p.muted),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  switch (val) {
                    case 'edit':
                      onEdit();
                    case 'preview':
                      onPreview();
                    case 'publish':
                      onPublish();
                    case 'retire':
                      onRetire();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'preview',
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(isEn ? 'Preview' : 'ቅድመ እይታ'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(isEn ? 'Edit' : 'አስተካክል'),
                      ],
                    ),
                  ),
                  if (article.status != 'published')
                    PopupMenuItem(
                      value: 'publish',
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Text(isEn ? 'Publish' : 'አሳትም'),
                        ],
                      ),
                    ),
                  if (article.status == 'published')
                    PopupMenuItem(
                      value: 'retire',
                      child: Row(
                        children: [
                          const Icon(Icons.archive_outlined, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Text(isEn ? 'Retire' : 'ዝጋ'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 8),
                        Text(isEn ? 'Delete' : 'ሰርዝ', style: const TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.format_list_numbered_rounded, size: 14, color: p.muted),
              const SizedBox(width: 4),
              Text('${article.steps.length} ${isEn ? "steps" : "ደረጃዎች"}', style: context.sans(11, color: p.muted)),
              const SizedBox(width: 12),
              Icon(Icons.quiz_outlined, size: 14, color: p.muted),
              const SizedBox(width: 4),
              Text('${article.faqs.length} ${isEn ? "FAQs" : "ጥያቄዎች"}', style: context.sans(11, color: p.muted)),
              if (article.tourId != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.tour_outlined, size: 14, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(article.tourId!, style: context.sans(11, color: AppColors.gold)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GuidanceEditorScreen extends ConsumerStatefulWidget {
  const _GuidanceEditorScreen({this.article});
  final GuidanceArticle? article;

  @override
  ConsumerState<_GuidanceEditorScreen> createState() => _GuidanceEditorScreenState();
}

class _GuidanceEditorScreenState extends ConsumerState<_GuidanceEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _slugCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _targetScreenCtrl;
  late TextEditingController _targetRoleCtrl;
  late TextEditingController _requiredPermCtrl;
  late TextEditingController _tourIdCtrl;
  late TextEditingController _overviewCtrl;
  late TextEditingController _estMinutesCtrl;

  late List<GuidanceStep> _steps;
  late List<String> _tips;
  late List<GuidanceFaq> _faqs;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _titleCtrl = TextEditingController(text: a?.title ?? '');
    _slugCtrl = TextEditingController(text: a?.slug ?? '');
    _categoryCtrl = TextEditingController(text: a?.category ?? 'general');
    _targetScreenCtrl = TextEditingController(text: a?.targetScreen ?? '');
    _targetRoleCtrl = TextEditingController(text: a?.targetRole ?? 'member');
    _requiredPermCtrl = TextEditingController(text: a?.requiredPermission ?? '');
    _tourIdCtrl = TextEditingController(text: a?.tourId ?? '');
    _overviewCtrl = TextEditingController(text: a?.overview ?? '');
    _estMinutesCtrl = TextEditingController(text: (a?.estimatedReadMinutes ?? 3).toString());

    _steps = a != null ? List<GuidanceStep>.from(a.steps) : [];
    _tips = a != null ? List<String>.from(a.quickTips) : [];
    _faqs = a != null ? List<GuidanceFaq>.from(a.faqs) : [];
    _status = a?.status ?? 'published';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _slugCtrl.dispose();
    _categoryCtrl.dispose();
    _targetScreenCtrl.dispose();
    _targetRoleCtrl.dispose();
    _requiredPermCtrl.dispose();
    _tourIdCtrl.dispose();
    _overviewCtrl.dispose();
    _estMinutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final repo = ref.read(guidanceRepositoryProvider);

    final payload = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'slug': _slugCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
      'category': _categoryCtrl.text.trim(),
      'target_role': _targetRoleCtrl.text.trim(),
      'target_screen': _targetScreenCtrl.text.trim().isEmpty ? null : _targetScreenCtrl.text.trim(),
      'required_permission': _requiredPermCtrl.text.trim().isEmpty ? null : _requiredPermCtrl.text.trim(),
      'tour_id': _tourIdCtrl.text.trim().isEmpty ? null : _tourIdCtrl.text.trim(),
      'summary': _overviewCtrl.text.trim(),
      'overview': _overviewCtrl.text.trim(),
      'content': _overviewCtrl.text.trim(),
      'estimated_read_minutes': int.tryParse(_estMinutesCtrl.text.trim()) ?? 3,
      'status': _status,
      'steps': _steps.asMap().entries.map((e) => {
            'step': e.key + 1,
            'title': e.value.title,
            'description': e.value.instruction,
            'instruction': e.value.instruction,
            if (e.value.tip != null) 'tip': e.value.tip,
            if (e.value.targetKey != null) 'target_key': e.value.targetKey,
          }).toList(),
      'tips': _tips.where((t) => t.trim().isNotEmpty).toList(),
      'quick_tips': _tips.where((t) => t.trim().isNotEmpty).toList(),
      'faq_items': _faqs.map((f) => {'q': f.question, 'a': f.answer, 'question': f.question, 'answer': f.answer}).toList(),
      'faqs': _faqs.map((f) => {'q': f.question, 'a': f.answer, 'question': f.question, 'answer': f.answer}).toList(),
    };

    try {
      if (widget.article != null) {
        await repo.adminUpdate(widget.article!.id, payload);
      } else {
        await repo.adminCreate(payload);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final isEditing = widget.article != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? (isEn ? 'Edit Guidance Article' : 'መመሪያ አስተካክል') : (isEn ? 'New Guidance Article' : 'አዲስ መመሪያ ፍጠር')),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
            label: Text(isEn ? 'Save' : 'አስቀምጥ'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: isEn ? 'Title *' : 'አርዕስት *',
                hintText: isEn ? 'e.g. Programs & Events Guide' : 'ምሳሌ፡ የፕሮግራሞች አጠቃቀም መመሪያ',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? (isEn ? 'Title is required' : 'አርዕስት ያስፈልጋል') : null,
              onChanged: (v) {
                if (!isEditing && _slugCtrl.text.isEmpty) {
                  _slugCtrl.text = v.trim().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-');
                }
              },
            ),
            const SizedBox(height: 12),
            // Slug
            TextFormField(
              controller: _slugCtrl,
              decoration: InputDecoration(
                labelText: isEn ? 'Slug (unique identifier) *' : 'መለያ ቃል (Slug) *',
                hintText: 'programs-guide',
              ),
              validator: (v) => v == null || v.trim().isEmpty ? (isEn ? 'Slug is required' : 'Slug ያስፈልጋል') : null,
            ),
            const SizedBox(height: 12),
            // Overview
            TextFormField(
              controller: _overviewCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isEn ? 'Overview / Summary' : 'አጭር መግለጫ',
                hintText: isEn ? 'Brief explanation of what this guide covers...' : 'ይህ መመሪያ የሚያብራራውን በአጭሩ...',
              ),
            ),
            const SizedBox(height: 16),
            // Row: Category & Target Role
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _categoryCtrl.text.isEmpty ? 'general' : _categoryCtrl.text,
                    decoration: InputDecoration(labelText: isEn ? 'Category' : 'ክፍል'),
                    items: const [
                      DropdownMenuItem(value: 'general', child: Text('General')),
                      DropdownMenuItem(value: 'mezmur', child: Text('Mezmur')),
                      DropdownMenuItem(value: 'programs', child: Text('Programs')),
                      DropdownMenuItem(value: 'attendance', child: Text('Attendance')),
                      DropdownMenuItem(value: 'education', child: Text('Education')),
                      DropdownMenuItem(value: 'contributions', child: Text('Contributions')),
                      DropdownMenuItem(value: 'notifications', child: Text('Notifications')),
                      DropdownMenuItem(value: 'departments', child: Text('Departments')),
                      DropdownMenuItem(value: 'tasks', child: Text('Tasks')),
                      DropdownMenuItem(value: 'reports', child: Text('Reports')),
                      DropdownMenuItem(value: 'holiday_selection', child: Text('Holiday Selection')),
                      DropdownMenuItem(value: 'property', child: Text('Property')),
                      DropdownMenuItem(value: 'borrowing', child: Text('Borrowing')),
                      DropdownMenuItem(value: 'settings', child: Text('Settings')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin Workflows')),
                    ],
                    onChanged: (v) => setState(() => _categoryCtrl.text = v ?? 'general'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _targetRoleCtrl.text.isEmpty ? 'member' : _targetRoleCtrl.text,
                    decoration: InputDecoration(labelText: isEn ? 'Target Role' : 'የተጠቃሚ ደረጃ'),
                    items: [
                      DropdownMenuItem(value: 'member', child: Text(isEn ? 'All Members' : 'ሁሉም አባላት')),
                      DropdownMenuItem(value: 'department_leader', child: Text(isEn ? 'Dept Leaders' : 'የክፍል ኃላፊዎች')),
                      DropdownMenuItem(value: 'admin', child: Text(isEn ? 'Admins Only' : 'አስተዳዳሪዎች ብቻ')),
                    ],
                    onChanged: (v) => setState(() => _targetRoleCtrl.text = v ?? 'member'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row: Target Screen & Required Permission
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _targetScreenCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Target Screen Route' : 'የገጽ መገኛ (Screen Route)',
                      hintText: '/programs',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _requiredPermCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Required Permission' : 'የሚያስፈልገው ፈቃድ',
                      hintText: 'e.g. programs.manage',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row: Tour ID & Status
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tourIdCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Tour ID (optional)' : 'የጉብኝት መለያ (አማራጭ)',
                      hintText: 'programs_tour',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: InputDecoration(labelText: isEn ? 'Status' : 'ሁኔታ'),
                    items: const [
                      DropdownMenuItem(value: 'published', child: Text('Published')),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(value: 'retired', child: Text('Retired')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'published'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ---- Step by Step Builder ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? 'Interactive Steps (${_steps.length})' : 'የደረጃዎች ዝርዝር (${_steps.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(isEn ? 'Add Step' : 'ደረጃ ጨምር'),
                  onPressed: _addStepDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_steps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  isEn ? 'No steps added yet. Add steps to guide the user sequentially.' : 'ምንም ደረጃ አልተጨመረም። ተጠቃሚዎችን በቅደም ተከተል ለመምራት ደረጃዎችን ያክሉ።',
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._steps.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.gold,
                      child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${s.instruction}${s.targetKey != null ? "\nTarget UI: ${s.targetKey}" : ""}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editStepDialog(idx),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                          onPressed: () => setState(() => _steps.removeAt(idx)),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),
            // ---- Tips Builder ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? 'Helpful Tips (${_tips.length})' : 'ጠቃሚ ምክሮች (${_tips.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(isEn ? 'Add Tip' : 'ምክር ጨምር'),
                  onPressed: _addTipDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._tips.asMap().entries.map((entry) {
              final idx = entry.key;
              final tip = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 20),
                  title: Text(tip, style: const TextStyle(fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _tips.removeAt(idx)),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),
            // ---- FAQs Builder ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? 'Frequently Asked Questions (${_faqs.length})' : 'ተደጋጋሚ ጥያቄዎች (${_faqs.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(isEn ? 'Add FAQ' : 'ጥያቄ ጨምር'),
                  onPressed: _addFaqDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._faqs.asMap().entries.map((entry) {
              final idx = entry.key;
              final faq = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(faq.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(faq.answer, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _faqs.removeAt(idx)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  void _addStepDialog() {
    _showStepModal(
      onSave: (step) => setState(() => _steps.add(step)),
    );
  }

  void _editStepDialog(int idx) {
    _showStepModal(
      existing: _steps[idx],
      onSave: (step) => setState(() => _steps[idx] = step),
    );
  }

  void _showStepModal({GuidanceStep? existing, required ValueChanged<GuidanceStep> onSave}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final instCtrl = TextEditingController(text: existing?.instruction ?? '');
    final targetCtrl = TextEditingController(text: existing?.targetKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final l = ctx.l10n;
          final isEn = l.isEn;
          final selectedKey = targetCtrl.text.trim();
          final registeredTarget = TargetUiKeyRegistry.find(selectedKey);

          return AlertDialog(
            title: Text(existing == null ? (isEn ? 'Add Step' : 'ደረጃ ጨምር') : (isEn ? 'Edit Step' : 'ደረጃ አስተካክል')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Step Title *' : 'የደረጃው ርዕስ *',
                      hintText: isEn ? 'e.g. Choose Education Module' : 'ምሳሌ፡ የትምህርት ክፍሉን ይምረጡ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: instCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Instruction *' : 'የአሠራር መመሪያ *',
                      hintText: isEn ? 'Detailed explanation of what to do...' : 'ተጠቃሚው ምን ማድረግ እንዳለበት ዝርዝር መግለጫ...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: targetCtrl,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Target UI Key' : 'የተፈለገው መቆጣጠሪያ ቁልፍ (Target UI Key)',
                            hintText: 'e.g. education.home.books.shortcut',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.manage_search_rounded, color: AppColors.gold),
                              tooltip: isEn ? 'Browse Target UI Keys' : 'የUI መቆጣጠሪያዎችን ፈልግ',
                              onPressed: () async {
                                final chosen = await showDialog<String>(
                                  context: ctx,
                                  builder: (_) => TargetUiKeySelectorDialog(initialKey: targetCtrl.text.trim()),
                                );
                                if (chosen != null) {
                                  targetCtrl.text = chosen;
                                  setModalState(() {});
                                }
                              },
                            ),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.touch_app_outlined, size: 18),
                    label: Text(isEn ? 'Browse & Select Target Control' : 'የገጽ መቆጣጠሪያዎችን ፈልግና ምረጥ'),
                    onPressed: () async {
                      final chosen = await showDialog<String>(
                        context: ctx,
                        builder: (_) => TargetUiKeySelectorDialog(initialKey: targetCtrl.text.trim()),
                      );
                      if (chosen != null) {
                        targetCtrl.text = chosen;
                        setModalState(() {});
                      }
                    },
                  ),
                  if (registeredTarget != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.goldDark,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  registeredTarget.module.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                registeredTarget.localizedName(isEn),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            registeredTarget.localizedDescription(isEn),
                            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Route: ${registeredTarget.route} · Element: ${registeredTarget.element}',
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Cancel' : 'ይቅር')),
              FilledButton(
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty || instCtrl.text.trim().isEmpty) return;
                  onSave(GuidanceStep(
                    step: existing?.step ?? 1,
                    title: titleCtrl.text.trim(),
                    description: instCtrl.text.trim(),
                    targetKey: targetCtrl.text.trim().isEmpty ? null : targetCtrl.text.trim(),
                  ));
                  Navigator.pop(ctx);
                },
                child: Text(isEn ? 'Save' : 'አስቀምጥ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addTipDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Helpful Tip'),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Enter tip here...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _tips.add(ctrl.text.trim()));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addFaqDialog() {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add FAQ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'Question')),
            const SizedBox(height: 10),
            TextField(controller: aCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Answer')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (qCtrl.text.trim().isNotEmpty && aCtrl.text.trim().isNotEmpty) {
                setState(() => _faqs.add(GuidanceFaq(question: qCtrl.text.trim(), answer: aCtrl.text.trim())));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// Searchable modal dialog for picking an exact Target UI Key from the registry.
class TargetUiKeySelectorDialog extends StatefulWidget {
  const TargetUiKeySelectorDialog({super.key, this.initialKey});
  final String? initialKey;

  @override
  State<TargetUiKeySelectorDialog> createState() => _TargetUiKeySelectorDialogState();
}

class _TargetUiKeySelectorDialogState extends State<TargetUiKeySelectorDialog> {
  String _search = '';
  String _module = 'all';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isEn = l.isEn;
    final p = context.palette;
    final results = TargetUiKeyRegistry.search(_search, module: _module);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn ? 'Select Target UI Control' : 'የተፈለገውን የገጽ ክፍል (UI Key) ይምረጡ',
                      style: context.serif(17, weight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: isEn ? 'Search by name, key, page, element...' : 'በስም፣ በቁልፍ፣ በገጽ ፈልግ...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in [
                      ('all', isEn ? 'All' : 'ሁሉም'),
                      ('shared', isEn ? 'Shared' : 'የጋራ'),
                      ('mezmur', isEn ? 'Mezmur' : 'መዝሙር'),
                      ('education', isEn ? 'Education' : 'ትምህርት'),
                      ('admin', isEn ? 'Admin' : 'አስተዳዳሪ'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(m.$2),
                          selected: _module == m.$1,
                          onSelected: (_) => setState(() => _module = m.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          isEn ? 'No matching UI targets found.' : 'ምንም የተገኘ የገጽ ክፍል የለም።',
                          style: context.sans(13, color: p.muted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final item = results[i];
                          final isSelected = widget.initialKey == item.key;
                          return Material(
                            color: isSelected ? AppColors.gold.withValues(alpha: 0.12) : p.card,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.pop(context, item.key),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.module.toUpperCase(),
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.goldDark),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.elementType.name.toUpperCase(),
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(item.route, style: context.sans(11, color: p.muted)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.localizedName(isEn),
                                      style: context.serif(15, weight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.key,
                                      style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: p.muted),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.localizedDescription(isEn),
                                      style: context.sans(12, color: p.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
