import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/json.dart';
import '../../models/project.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../admin/admin_widgets.dart' show AdminScaffold;
import 'pm_common.dart';
import 'project_detail.dart' show openPmFile;
import '../../widgets/typed_picker.dart';

final projectBudgetProvider = FutureProvider.autoDispose.family<PmBudget, int>((ref, id) => ref.watch(projectRepositoryProvider).budget(id));
final _projectExpensesProvider = FutureProvider.autoDispose.family<List<PmExpense>, int>((ref, id) async => (await ref.watch(projectRepositoryProvider).expenses(projectId: id)).items);

/// Budget tab of a project: approved / spent / remaining, categories, expenses, adjustments.
class ProjectBudgetView extends ConsumerWidget {
  const ProjectBudgetView({super.key, required this.projectId});
  final int projectId;

  void _reload(WidgetRef ref) {
    ref.invalidate(projectBudgetProvider(projectId));
    ref.invalidate(_projectExpensesProvider(projectId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AsyncView(
      value: ref.watch(projectBudgetProvider(projectId)),
      onRetry: () => _reload(ref),
      data: (b) {
        String money(double? v) => v == null ? '—' : f.money(v, b.currency);
        final expenses = ref.watch(_projectExpensesProvider(projectId)).value ?? const <PmExpense>[];
        return RefreshIndicator(
          onRefresh: () async => _reload(ref),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  PmStat(label: l.pmBudgetApproved, value: money(b.approved)),
                  PmStat(label: l.pmBudgetSpent, value: money(b.spent), color: b.overBudget ? AppColors.danger : null),
                  PmStat(label: l.pmBudgetRemaining, value: money(b.remaining), color: (b.remaining ?? 0) < 0 ? AppColors.danger : AppColors.success),
                ]),
                const SizedBox(height: 10),
                if (b.utilization != null) ProgressLine(value: b.utilization!.round(), label: l.pmBudgetUsed('${b.utilization}')),
                if (b.approved == null) Text(l.pmBudgetNotApproved, style: context.sans(12, color: AppColors.goldDark, weight: FontWeight.w600)),
                if (b.overBudget) Text(l.pmBudgetOver, style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  ['${l.pmBudgetProposed}: ${money(b.proposed)}', if (b.pending > 0) '${l.pmBudgetPending}: ${money(b.pending)}'].join(' · '),
                  style: context.sans(12, color: context.palette.muted),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (b.canEdit) OutlinedButton.icon(icon: const Icon(Icons.edit_note_rounded), label: Text(l.pmEditBudget), onPressed: () => _editBudget(context, ref, b)),
              if (b.canApprove) FilledButton.tonalIcon(key: const ValueKey('pm-approve-budget'), icon: const Icon(Icons.verified_rounded), label: Text(l.pmApproveBudget), onPressed: () => _approveBudget(context, ref, b)),
              if (b.canSpend) FilledButton.icon(key: const ValueKey('pm-new-expense'), icon: const Icon(Icons.add_card_rounded), label: Text(l.pmNewExpense), onPressed: () => _newExpense(context, ref)),
              if (b.canEdit) OutlinedButton.icon(icon: const Icon(Icons.trending_up_rounded), label: Text(l.pmRequestAdjustment), onPressed: () => _requestAdjustment(context, ref)),
            ]),
            if (b.lines.any((x) => x.planned != null || x.spent > 0)) ...[
              SectionHeader(title: l.pmBudgetLines),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final line in b.lines.where((x) => x.planned != null || x.spent > 0))
                    ListTile(
                      dense: true,
                      title: Text(line.categoryName),
                      trailing: Text('${money(line.spent)} / ${money(line.planned)}', style: context.sans(12, weight: FontWeight.w600, color: line.planned != null && line.spent > line.planned! ? AppColors.danger : null)),
                    ),
                ]),
              ),
            ],
            SectionHeader(title: l.pmExpenses),
            if (expenses.isEmpty) EmptyView(message: l.pmNoExpenses, icon: Icons.receipt_long_outlined),
            for (final e in expenses) ExpenseTile(expense: e, canApprove: b.canApprove, onChanged: () => _reload(ref)),
            if (b.adjustments.isNotEmpty) ...[
              SectionHeader(title: l.pmAdjustments),
              for (final a in b.adjustments)
                TrackTile(
                  title: '+${money(a.amount)}',
                  subtitle: [a.reason, expenseStatusLabel(l, a.status), if (a.requestedBy != null) a.requestedBy!.fullName, ?a.reviewNote].join(' · '),
                  leading: Icon(Icons.trending_up_rounded, color: statusColor(a.status)),
                  trailing: a.status == 'pending' && b.canApprove
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(tooltip: l.pmReject, icon: const Icon(Icons.close_rounded, color: AppColors.danger), onPressed: () => _reviewAdjustment(context, ref, a, 'rejected')),
                          IconButton(tooltip: l.pmApprove, icon: const Icon(Icons.check_rounded, color: AppColors.success), onPressed: () => _reviewAdjustment(context, ref, a, 'approved')),
                        ])
                      : null,
                ),
            ],
          ]),
        );
      },
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref, PmBudget b) async {
    final l = context.l10n;
    final cats = await runWithProgress(context, () => ref.read(projectRepositoryProvider).budgetCategories());
    if (cats == null || !context.mounted) return;
    final proposed = TextEditingController(text: b.proposed?.toStringAsFixed(2) ?? '');
    final lines = {for (final c in cats) asIntOr(c['id']): TextEditingController(text: b.lines.where((x) => x.categoryId == asIntOr(c['id'])).firstOrNull?.planned?.toStringAsFixed(2) ?? '')};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pmEditBudget),
        content: SizedBox(
          width: 360,
          child: ListView(shrinkWrap: true, children: [
            TextField(controller: proposed, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.pmBudgetProposed, suffixText: b.currency)),
            const SizedBox(height: 8),
            Text(l.pmBudgetLines, style: context.sans(12, weight: FontWeight.w600)),
            for (final c in cats)
              TextField(controller: lines[asIntOr(c['id'])], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${c['name']}', isDense: true)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final body = <String, dynamic>{
      'proposed_budget': double.tryParse(proposed.text.trim()),
      'lines': [
        for (final e in lines.entries)
          if (double.tryParse(e.value.text.trim()) != null) {'category_id': e.key, 'amount': double.parse(e.value.text.trim())},
      ],
    };
    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).setBudget(projectId, body), success: l.saved);
    if (r != null) _reload(ref);
  }

  Future<void> _approveBudget(BuildContext context, WidgetRef ref, PmBudget b) async {
    final l = context.l10n;
    final v = await promptText(context, title: l.pmApproveBudget, label: '${l.pmAmount} (${b.currency})', initial: (b.approved ?? b.proposed)?.toStringAsFixed(2), required: true);
    final amount = double.tryParse(v?.trim() ?? '');
    if (amount == null || !context.mounted) return;
    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).approveBudget(projectId, amount), success: l.saved);
    if (r != null) _reload(ref);
  }

  Future<void> _requestAdjustment(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final amount = TextEditingController();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.pmRequestAdjustment),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l.pmAdditional)),
          TextField(controller: reason, maxLines: 3, decoration: InputDecoration(labelText: l.pmReason)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.send)),
        ],
      ),
    );
    final a = double.tryParse(amount.text.trim());
    if (ok != true || a == null || a <= 0 || reason.text.trim().length < 2 || !context.mounted) return;
    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).requestAdjustment(projectId, a, reason.text.trim()), success: l.saved);
    if (r != null) _reload(ref);
  }

  Future<void> _reviewAdjustment(BuildContext context, WidgetRef ref, PmAdjustment a, String status) async {
    final l = context.l10n;
    String? note;
    if (status == 'rejected') {
      note = await promptText(context, title: l.pmReject, label: l.pmReason, required: true);
      if (note == null || note.trim().isEmpty || !context.mounted) return;
    }
    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).reviewAdjustment(a.id, status, note: note), success: l.saved);
    if (r != null) _reload(ref);
  }

  Future<void> _newExpense(BuildContext context, WidgetRef ref) async {
    final ok = await showExpenseEditor(context, ref, projectId: projectId);
    if (ok) _reload(ref);
  }
}

/// New expense for a project (with an optional receipt).
Future<bool> showExpenseEditor(BuildContext context, WidgetRef ref, {required int projectId}) async {
  final l = context.l10n;
  final v = Validators(l);
  final cats = await runWithProgress(context, () => ref.read(projectRepositoryProvider).budgetCategories());
  if (cats == null || !context.mounted) return false;
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final desc = TextEditingController();
  final paidBy = TextEditingController();
  int? category;
  String? receipt;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(l.pmNewExpense),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(key: const ValueKey('expense-amount'), controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (s) => v.amount(s), decoration: InputDecoration(labelText: l.pmAmount)),
              DropdownButtonFormField<int>(
                initialValue: category,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.pmCategory),
                items: [for (final c in cats) DropdownMenuItem(value: asIntOr(c['id']), child: Text('${c['name']}'))],
                onChanged: (x) => setS(() => category = x),
              ),
              TextFormField(key: const ValueKey('expense-description'), controller: desc, validator: (s) => v.text(s, min: 2, max: 1000), decoration: InputDecoration(labelText: l.pmDescription)),
              TextFormField(controller: paidBy, decoration: InputDecoration(labelText: l.pmPaidBy)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(receipt == null ? Icons.attach_file_rounded : Icons.check_rounded),
                label: Text(receipt == null ? l.pmAttachReceipt : receipt!.split(RegExp(r'[\\/]')).last, overflow: TextOverflow.ellipsis),
                onPressed: () async {
                  final path = (await pickTypedFile(context, documents: const ['pdf']))?.path;
                  if (path != null) setS(() => receipt = path);
                },
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(ctx, true) : null, child: Text(l.send)),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return false;
  final fields = <String, dynamic>{
    'amount': double.parse(amount.text.trim()),
    'description': desc.text.trim(),
    'category_id': ?category,
    if (paidBy.text.trim().isNotEmpty) 'paid_by': paidBy.text.trim(),
  };
  final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).createExpense(projectId, fields, receiptPath: receipt), success: l.saved);
  return r != null;
}

class ExpenseTile extends ConsumerWidget {
  const ExpenseTile({super.key, required this.expense, required this.canApprove, required this.onChanged, this.showProject = false});
  final PmExpense expense;
  final bool canApprove;
  final VoidCallback onChanged;
  final bool showProject;

  Future<void> _review(BuildContext context, WidgetRef ref, String status) async {
    final l = context.l10n;
    String? note;
    var override = false;
    if (status == 'rejected') {
      note = await promptText(context, title: l.pmReject, label: l.pmReason, required: true);
      if (note == null || note.trim().isEmpty) return;
    }
    if (status == 'approved' && expense.overBudget) {
      if (!context.mounted) return;
      note = await promptText(context, title: l.pmOverride, label: l.pmReason, required: true);
      if (note == null || note.trim().isEmpty) return;
      override = true;
    }
    if (!context.mounted) return;
    final r = await runWithProgress(context, () => ref.read(projectRepositoryProvider).reviewExpense(expense.id, status, note: note, override: override), success: l.saved);
    if (r != null) onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final e = expense;
    return TrackTile(
      key: ValueKey('expense-${e.id}'),
      title: '${f.money(e.amount, e.currency)} · ${e.description}',
      subtitle: [
        if (showProject && e.projectTitle != null) e.projectTitle!,
        expenseStatusLabel(l, e.status),
        ?e.categoryName,
        if (e.requestedBy != null) e.requestedBy!.fullName,
        if (e.expenseDate != null) f.date(e.expenseDate),
        if (e.overBudget && e.status == 'pending') l.pmBudgetOver,
        ?e.reviewNote,
      ].join(' · '),
      leading: Icon(Icons.receipt_long_outlined, color: statusColor(e.status)),
      onTap: e.receiptUrl == null ? null : () => openPmFile(context, ref, e.receiptUrl!, name: 'receipt-${e.id}'),
      trailing: canApprove && (e.status == 'pending' || e.status == 'approved')
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              if (e.status == 'pending') IconButton(tooltip: l.pmReject, icon: const Icon(Icons.close_rounded, color: AppColors.danger), onPressed: () => _review(context, ref, 'rejected')),
              if (e.status == 'pending') IconButton(key: ValueKey('approve-expense-${e.id}'), tooltip: l.pmApprove, icon: const Icon(Icons.check_rounded, color: AppColors.success), onPressed: () => _review(context, ref, 'approved')),
              if (e.status == 'approved') IconButton(tooltip: l.pmRecord, icon: const Icon(Icons.inventory_rounded), onPressed: () => _review(context, ref, 'recorded')),
            ])
          : null,
    );
  }
}

final _approvalsProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(projectRepositoryProvider).approvals());

/// Finance: every pending expense and budget adjustment across departments.
class ProjectApprovalsScreen extends ConsumerWidget {
  const ProjectApprovalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.pmApprovals,
      body: AsyncView(
        value: ref.watch(_approvalsProvider),
        onRetry: () => ref.invalidate(_approvalsProvider),
        data: (d) {
          final expenses = asJsonList(d['expenses']).map(PmExpense.fromJson).toList();
          final adjustments = asJsonList(d['adjustments']).map(PmAdjustment.fromJson).toList();
          if (expenses.isEmpty && adjustments.isEmpty) return EmptyView(message: l.pmNoExpenses, icon: Icons.fact_check_outlined);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_approvalsProvider),
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 32), children: [
              if (expenses.isNotEmpty) SectionHeader(title: l.pmExpenses),
              for (final e in expenses) ExpenseTile(expense: e, canApprove: true, showProject: true, onChanged: () => ref.invalidate(_approvalsProvider)),
              if (adjustments.isNotEmpty) SectionHeader(title: l.pmAdjustments),
              for (final a in adjustments)
                TrackTile(
                  title: '${a.projectTitle ?? ''} · +${f.money(a.amount, a.currency ?? 'ETB')}',
                  subtitle: a.reason,
                  leading: const Icon(Icons.trending_up_rounded, color: AppColors.gold),
                  onTap: a.projectId == null ? null : () => context.push('/projects/${a.projectId}'),
                ),
            ]),
          );
        },
      ),
    );
  }
}
