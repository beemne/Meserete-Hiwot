import 'report_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../choir/eligibility_screen.dart';
import '../guidance/contextual_help_sheet.dart';
import '../members/member_form.dart' show memberGroupLabel;
import 'admin_widgets.dart';
import '../../core/member_groups.dart';

String _n(num? v) => v == null ? '—' : (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1));

Color _statusColor(String? s) => switch (s) {
      'open' => AppColors.success,
      'review' => AppColors.goldDark,
      'finalized' => AppColors.maroon,
      'cancelled' => AppColors.danger,
      _ => Colors.grey,
    };

/// Holiday Mezmur service selections: each holiday has its own period, weights and result.
class SelectionsScreen extends ConsumerStatefulWidget {
  const SelectionsScreen({super.key});
  @override
  ConsumerState<SelectionsScreen> createState() => _SelectionsScreenState();
}

class _SelectionsScreenState extends ConsumerState<SelectionsScreen> {
  final _ctrl = PagedListController<Json>();
  String? _status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final me = ref.watch(currentUserProvider)!;
    final online = ref.watch(isOnlineProvider);
    return AdminScaffold(
      title: l.selTitle,
      actions: const [ContextualHelpButton(screenRoute: '/admin/selections')],
      fab: me.can(Perm.selectionConfigure)
          ? Tooltip(
              message: online ? '' : l.needsConnection,
              child: FloatingActionButton.extended(
                icon: const Icon(Icons.add_rounded),
                label: Text(online ? l.selNew : '${l.selNew} · ${l.needsConnection}'),
                onPressed: online
                    ? () async {
                        final saved = await Navigator.of(context).push<Json>(MaterialPageRoute(builder: (_) => const SelectionEditorScreen()));
                        if (saved != null) await _ctrl.refresh();
                      }
                    : null,
              ),
            )
          : null,
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            for (final s in [null, 'draft', 'open', 'review', 'finalized', 'cancelled'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(s == null ? l.all : selectionStatusText(l, s)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
              ),
          ]),
        ),
        Expanded(
          child: PagedListView<Json>(
            key: ValueKey(_status),
            controller: _ctrl,
            fetch: (page) => ref.read(stageRepositoryProvider).selections(status: _status, page: page),
            emptyMessage: l.selNone,
            emptyIcon: Icons.how_to_vote_outlined,
            itemBuilder: (context, s, _) {
              final c = asJson(s['counts']);
              return TrackTile(
                title: '${s['name']}',
                subtitle: [
                  '${f.date(Formatters.parseDateOnly(asStr(s['from'])))} – ${f.date(Formatters.parseDateOnly(asStr(s['to'])))}',
                  if (asIntOr(c['total']) > 0) l.selCounts('${asIntOr(c['qualified'])}', '${asIntOr(c['total'])}'),
                ].join(' · '),
                leading: const ListThumb(icon: Icons.how_to_vote_outlined),
                trailing: Pill(selectionStatusText(l, asStr(s['status'])), color: _statusColor(asStr(s['status']))),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SelectionDetailScreen(selectionId: asIntOr(s['id']))));
                  await _ctrl.refresh();
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// One selection: its configuration and formula, workflow actions and the members' results
/// (alphabetical — never ranked).
class SelectionDetailScreen extends ConsumerStatefulWidget {
  const SelectionDetailScreen({super.key, required this.selectionId});
  final int selectionId;
  @override
  ConsumerState<SelectionDetailScreen> createState() => _SelectionDetailScreenState();
}

class _SelectionDetailScreenState extends ConsumerState<SelectionDetailScreen> {
  final _ctrl = PagedListController<Json>();
  late Future<Json> _future = _load();
  String? _result;
  bool _missing = false;
  String _q = '';

  Future<Json> _load() => ref.read(stageRepositoryProvider).selection(widget.selectionId);
  void _reload() {
    setState(() => _future = _load());
    _ctrl.refresh();
  }

  Future<void> _status(String status, {bool askReason = false}) async {
    final l = context.l10n;
    String? reason;
    if (askReason) {
      reason = await promptText(context, title: selectionStatusText(l, status), label: l.reason, maxLines: 2);
      if (reason == null || !mounted) return;
    } else if (!await showConfirm(context, l.selConfirmStatus(selectionStatusText(l, status))) || !mounted) {
      return;
    }
    final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).selectionStatus(widget.selectionId, status, reason: reason), success: l.saved);
    if (r != null) _reload();
  }

  Future<void> _publish() async {
    final confirmed = await showConfirm(
      context,
      'የምርጫውን ውጤት ይፋ ማድረግ ይፈልጋሉ? ብቁ ለሆኑና ላልሆኑ አባላት ማሳወቂያ ይላካል።',
    );
    if (!confirmed || !mounted) return;
    final r = await runWithProgress(
      context,
      () => ref.read(stageRepositoryProvider).publishSelection(widget.selectionId),
      success: 'ውጤቱ ይፋ ሆኗል',
    );
    if (r != null) _reload();
  }

  Future<void> _openReviewsSheet(Json s) async {
    final l = context.l10n;
    final me = ref.read(currentUserProvider)!;
    final repo = ref.read(stageRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => FutureBuilder<List<Json>>(
          future: repo.selectionReviews(widget.selectionId),
          builder: (context, snap) {
            if (snap.hasError) return Padding(padding: const EdgeInsets.all(24), child: ErrorView(error: snap.error!));
            if (!snap.hasData) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
            final reviews = snap.data!;
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.95,
              builder: (_, scrollController) => ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('የክፍሎች ግምገማ (Reviews)', style: context.serif(18, weight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  for (final r in reviews)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          r['status'] == 'approved'
                              ? Icons.check_circle_rounded
                              : r['status'] == 'rejected'
                                  ? Icons.cancel_rounded
                                  : Icons.hourglass_top_rounded,
                          color: r['status'] == 'approved'
                              ? AppColors.success
                              : r['status'] == 'rejected'
                                  ? AppColors.danger
                                  : AppColors.goldDark,
                        ),
                        title: Text('${r['department_name'] ?? r['department']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (r['reviewed_by_name'] != null)
                              Text('ገምጋሚ፡ ${r['reviewed_by_name']} · ${r['status']}', style: context.sans(12)),
                            if (asStr(r['comments'])?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('ማስታወሻ፡ ${r['comments']}', style: context.sans(12, color: context.palette.muted)),
                              ),
                          ],
                        ),
                        trailing: Pill(
                          r['status'] == 'approved'
                              ? 'ጸድቋል'
                              : r['status'] == 'rejected'
                                  ? 'ተቀባይነት አላገኘም'
                                  : 'በመጠባበቅ ላይ',
                          color: r['status'] == 'approved'
                              ? AppColors.success
                              : r['status'] == 'rejected'
                                  ? AppColors.danger
                                  : AppColors.goldDark,
                        ),
                      ),
                    ),
                  if (me.canAny([Perm.selectionReview, Perm.selectionConfigure, Perm.selectionFinalize])) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.rate_review_rounded),
                      label: const Text('አስተያየትና ውሳኔ ስጥ (Submit Review)'),
                      onPressed: () async {
                        final dept = await showDialog<String>(
                          context: ctx,
                          builder: (dCtx) => SimpleDialog(
                            title: const Text('ክፍል ይምረጡ'),
                            children: [
                              for (final d in ['choir', 'education', 'hr'])
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(dCtx, d),
                                  child: Text(d == 'choir' ? 'መዝሙርና ሥነጥበብ (Hymns & Arts)' : d == 'education' ? 'ትምህርትና ሥልጠና (Education)' : 'ሰው ኃይል (Human Resources)'),
                                ),
                            ],
                          ),
                        );
                        if (dept == null || !mounted || !ctx.mounted) return;
                        final decision = await showDialog<String>(
                          context: ctx,
                          builder: (dCtx) => SimpleDialog(
                            title: const Text('ውሳኔ (Decision)'),
                            children: [
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(dCtx, 'approved'),
                                child: const Text('አጽድቅ (Approve)', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                              ),
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(dCtx, 'rejected'),
                                child: const Text('ውድቅ አድርግ (Reject)', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (decision == null || !mounted || !ctx.mounted) return;
                        final comments = await promptText(ctx, title: 'ማስታወሻ / አስተያየት (Comments)', label: l.reason, maxLines: 3);
                        if (!mounted || !ctx.mounted) return;
                        final res = await runWithProgress(
                          ctx,
                          () => repo.submitSelectionReview(widget.selectionId, {
                            'department': dept,
                            'decision': decision,
                            'comments': comments ?? '',
                          }),
                          success: l.saved,
                        );
                        if (res != null) {
                          setSheetState(() {});
                          _reload();
                        }
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCategoryAssignment(Json s) async {
    final l = context.l10n;
    final repo = ref.read(stageRepositoryProvider);
    final page = await runWithProgress(context, () => repo.selectionResults(widget.selectionId, result: 'qualified', limit: 100));
    if (page == null || !mounted) return;
    final items = page.items;
    if (items.isEmpty) {
      showSnack(context, 'ምንም ብቁ የሆኑ አባላት አልተገኙም');
      return;
    }
    final assignments = <int, String?>{
      for (final it in items) asIntOr(it['user_id']): asStr(it['service_category']),
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('የአገልግሎት ምድቦች መድብ', style: context.serif(18, weight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 8),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final uid = asIntOr(it['user_id']);
                    final currentCat = assignments[uid];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${it['full_name']}'),
                      subtitle: Text('${_n(asDouble(it['total']))} ነጥብ · ${it['member_id'] ?? ''}'),
                      trailing: DropdownButton<String?>(
                        value: currentCat,
                        hint: const Text('ምድብ ይምረጡ'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('ያልተመደበ')),
                          DropdownMenuItem(value: 'ለወረብ አገልግሎት የተመረጡ', child: Text('ለወረብ አገልግሎት የተመረጡ')),
                          DropdownMenuItem(value: 'ለመዝሙር አገልግሎት የተመረጡ', child: Text('ለመዝሙር አገልግሎት የተመረጡ')),
                        ],
                        onChanged: (val) {
                          setSheetState(() => assignments[uid] = val);
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final payload = [
                        for (final e in assignments.entries)
                          {'user_id': e.key, 'category': e.value},
                      ];
                      final res = await runWithProgress(
                        ctx,
                        () => repo.assignServiceCategories(widget.selectionId, payload),
                        success: l.saved,
                      );
                      if (res != null && mounted) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        _reload();
                      }
                    },
                    child: const Text('ምድቦችን አስቀምጥ (Save Assignments)'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRankedCategories() async {
    final repo = ref.read(stageRepositoryProvider);
    final ranked = await runWithProgress(context, () => repo.rankedServiceCategories(widget.selectionId));
    if (ranked == null || !mounted) return;
    final cats = asJson(ranked['categories']);
    final wereb = asJsonList(cats['ለወረብ አገልግሎት የተመረጡ']);
    final mezmur = asJsonList(cats['ለመዝሙር አገልግሎት የተመረጡ']);
    final unassigned = asJsonList(ranked['unassigned']);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (_, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('የተመደቡ አባላት ደረጃ (Category Rankings)', style: context.serif(16, weight: FontWeight.w700)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'ለወረብ አገልግሎት'),
                  Tab(text: 'ለመዝሙር አገልግሎት'),
                  Tab(text: 'ያልተመደቡ'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildRankedList(wereb),
                    _buildRankedList(mezmur),
                    _buildRankedList(unassigned, isRanked: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankedList(List<Json> members, {bool isRanked = true}) {
    if (members.isEmpty) {
      return const Center(child: Text('ምንም አባላት የሉም'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final m = members[i];
        final rank = m['service_rank'] ?? (i + 1);
        return ListTile(
          leading: isRanked
              ? CircleAvatar(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                )
              : const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
          title: Text('${m['full_name']}'),
          subtitle: Text('${_n(asDouble(m['total']))} ነጥብ · ${m['member_id'] ?? ''}'),
          trailing: Pill(
            resultText(context.l10n, asStr(m['result'])),
            color: resultColor(asStr(m['result'])),
          ),
        );
      },
    );
  }

  Future<void> _openFeedbackList() async {
    final repo = ref.read(stageRepositoryProvider);
    final items = await runWithProgress(context, () => repo.selectionFeedback(widget.selectionId));
    if (items == null || !mounted) return;
    final f = Formatters(context.l10n, Localizations.localeOf(context).languageCode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('የአባላት አስተያየቶች (Member Feedback)', style: context.serif(18, weight: FontWeight.w700)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('ምንም አስተያየት አልተላከም (No feedback received)'))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final fb = items[i];
                        return AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${fb['full_name'] ?? 'አባል'}', style: context.sans(14, weight: FontWeight.w700)),
                                  if (fb['created_at'] != null)
                                    Text(f.dateTime(DateTime.tryParse('${fb['created_at']}')), style: context.sans(11, color: context.palette.muted)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('${fb['comments']}', style: context.sans(13)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final me = ref.watch(currentUserProvider)!;
    final online = ref.watch(isOnlineProvider);
    return AdminScaffold(
      title: l.selTitle,
      actions: [
        // One download button: the selection report and, for Mezmur administrators (checked by the
        // server), the Mezmur report — applicant ID, participation per Mezmur category, pass / fail.
        ReportExportButton(
          kind: 'selection',
          label: l.selTitle,
          filters: () => {'selection_id': widget.selectionId},
          extra: [
            if (me.can(Perm.choirManage)) ExtraReport(kind: 'mezmur-selection', label: l.scMezmurExport, filters: () => {'selection_id': widget.selectionId}),
          ],
        ),
      ],
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final s = snap.data!;
          final status = asStr(s['status']);
          final cfg = asJson(s['config']);
          final w = asJson(cfg['weights']);
          final m = asJson(cfg['minimums']);
          final c = asJson(s['counts']);
          final editable = status == 'draft' || status == 'open';
          final actions = <Widget>[
            if (editable && me.canAny([Perm.selectionConfigure, Perm.selectionExams]))
              OutlinedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(l.selConfigure),
                onPressed: () async {
                  final saved = await Navigator.of(context).push<Json>(MaterialPageRoute(builder: (_) => SelectionEditorScreen(existing: s)));
                  if (saved != null) _reload();
                },
              ),
            if (editable && me.canAny([Perm.selectionConfigure, Perm.selectionReview]))
              OutlinedButton.icon(
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: Text(online ? l.choirRefresh : '${l.choirRefresh} · ${l.needsConnection}'),
                onPressed: online
                    ? () async {
                        final r = await runWithProgress(context, () => ref.read(stageRepositoryProvider).computeSelection(widget.selectionId), success: l.saved);
                        if (r != null) _reload();
                      }
                    : null,
              ),
            if (status == 'draft' && me.can(Perm.selectionConfigure))
              FilledButton(
                onPressed: online ? () => _status('open') : null,
                child: Text(online ? l.selOpen : '${l.selOpen} · ${l.needsConnection}'),
              ),
            if (status == 'open' && me.canAny([Perm.selectionReview, Perm.selectionConfigure]))
              FilledButton(
                onPressed: online ? () => _status('review') : null,
                child: Text(online ? l.selToReview : '${l.selToReview} · ${l.needsConnection}'),
              ),
            if (status == 'review' && me.can(Perm.selectionConfigure))
              OutlinedButton(
                onPressed: online ? () => _status('open', askReason: true) : null,
                child: Text(online ? l.selBackToOpen : '${l.selBackToOpen} · ${l.needsConnection}'),
              ),
            if (['review', 'finalized'].contains(status))
              OutlinedButton.icon(
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('የክፍሎች ግምገማ (Reviews)'),
                onPressed: () => _openReviewsSheet(s),
              ),
            if (status == 'review' && me.can(Perm.selectionFinalize))
              FilledButton(
                onPressed: online ? () => _status('finalized') : null,
                child: Text(online ? l.selFinalize : '${l.selFinalize} · ${l.needsConnection}'),
              ),
            if (status == 'finalized' && s['is_published'] != true && me.canAny([Perm.selectionFinalize, Perm.selectionConfigure]))
              FilledButton.icon(
                icon: const Icon(Icons.campaign_outlined, size: 18),
                label: Text(online ? 'አጽድቅና አትም (Publish)' : 'አጽድቅና አትም · ${l.needsConnection}'),
                onPressed: online ? _publish : null,
              ),
            if (status == 'finalized' && me.canAny([Perm.selectionConfigure, Perm.selectionFinalize, Perm.choirManage]))
              OutlinedButton.icon(
                icon: const Icon(Icons.category_outlined, size: 18),
                label: const Text('ምድቦች መድብ (Categories)'),
                onPressed: () => _openCategoryAssignment(s),
              ),
            if (status == 'finalized')
              OutlinedButton.icon(
                icon: const Icon(Icons.leaderboard_outlined, size: 18),
                label: const Text('የምድብ ደረጃዎች (Rankings)'),
                onPressed: _openRankedCategories,
              ),
            if (status == 'finalized' && s['is_published'] == true)
              OutlinedButton.icon(
                icon: const Icon(Icons.feedback_outlined, size: 18),
                label: const Text('አስተያየቶች (Feedback)'),
                onPressed: _openFeedbackList,
              ),
            if (['draft', 'open', 'review'].contains(status) && me.can(Perm.selectionConfigure))
              TextButton(onPressed: () => _status('cancelled', askReason: true), child: Text(l.selCancel, style: const TextStyle(color: AppColors.danger))),
          ];
          final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MaroonCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${s['name']}', style: context.serif(20, color: Colors.white))),
                  Pill(selectionStatusText(l, status), color: AppColors.goldLight),
                  if (s['is_published'] == true) ...[
                    const SizedBox(width: 6),
                    const Pill('የታተመ (Published)', color: AppColors.success),
                  ],
                ]),
                const SizedBox(height: 6),
                Text('${f.date(Formatters.parseDateOnly(asStr(s['from'])))} – ${f.date(Formatters.parseDateOnly(asStr(s['to'])))}', style: context.sans(13, color: Colors.white)),
                Text(asValues(s['member_groups'], (g) => memberGroupLabel(l, '$g')).join(', '), style: context.sans(12, color: AppColors.goldLight)),
                if (asIntOr(c['total']) > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Pill('${l.selQualified}: ${asIntOr(c['qualified'])}', color: AppColors.goldLight),
                    Pill('${l.selNotQualified}: ${asIntOr(c['not_qualified'])}', color: AppColors.goldLight),
                    if (asIntOr(c['with_missing']) > 0) Pill('${l.selMissingTitle}: ${asIntOr(c['with_missing'])}', color: AppColors.goldLight),
                    if (asIntOr(c['overridden']) > 0) Pill('${l.selException}: ${asIntOr(c['overridden'])}', color: AppColors.goldLight),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 10),
            // The configuration and the formula, shown before finalization.
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.selConfiguration, style: context.sans(14, weight: FontWeight.w700)),
                for (final k in selectionComponents)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Expanded(child: Text(componentName(l, k), style: context.sans(13))),
                      Text('${_n(asDouble(w[k]))}  (${l.polMinimum}: ${m[k] == null ? '—' : _n(asDouble(m[k]))})', style: context.sans(13, weight: FontWeight.w600)),
                    ]),
                  ),
                const Divider(height: 16),
                Text('${l.polTotalMinimum}: ${_n(asDouble(cfg['total_minimum']))} · ${componentName(l, 'bonus')}: ${_n(asDouble(asJson(cfg['bonus'])['max']))}', style: context.sans(13)),
                Text(cfg['exams_required'] == true ? l.selExamsRequired : l.selExamsNotRequired, style: context.sans(13)),
                const SizedBox(height: 6),
                Text(l.selFormula, style: context.sans(11, color: p.muted)),
              ]),
            ),
            if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
            const SizedBox(height: 10),
          ]);
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBox(onChanged: (v) => setState(() => _q = v))),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                for (final r in [null, 'qualified', 'not_qualified'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(r == null ? l.all : resultText(l, r)),
                      selected: _result == r && !_missing,
                      onSelected: (_) => setState(() {
                        _result = r;
                        _missing = false;
                      }),
                    ),
                  ),
                ChoiceChip(label: Text(l.selMissingTitle), selected: _missing, onSelected: (v) => setState(() => _missing = v)),
              ]),
            ),
            Expanded(
              child: PagedListView<Json>(
                key: ValueKey('$_result|$_missing|$_q|${s['computed_at']}|${s['status']}'),
                controller: _ctrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                header: header,
                fetch: (page) => ref.read(stageRepositoryProvider).selectionResults(widget.selectionId, result: _result, missing: _missing, q: _q.isEmpty ? null : _q, page: page),
                emptyMessage: status == 'draft' ? l.selDraftNoResults : l.noResults,
                itemBuilder: (context, r, _) => TrackTile(
                  title: '${r['full_name']}',
                  subtitle: [
                    if (r['member_id'] != null) '${r['member_id']}',
                    '${_n(asDouble(r['total']))} ${l.selPoints}',
                    for (final x in asJsonList(r['failed']).take(2)) '${componentName(l, '${x['component']}')} −${_n(asDouble(x['shortfall']))}',
                    if (asJsonList(r['missing']).isNotEmpty) '⚠ ${l.selMissingTitle}',
                    if (r['override'] != null) '✎ ${l.selException}',
                    if (r['service_category'] != null) '🏷 ${r['service_category']}${r['service_rank'] != null ? ' (#${r['service_rank']})' : ''}',
                  ].join(' · '),
                  leading: const ListThumb(icon: Icons.person_outline_rounded),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r['config_version'] != null) ...[
                        Pill('${r['config_version']}', color: AppColors.goldDark),
                        const SizedBox(width: 4),
                      ],
                      Pill(resultText(l, asStr(r['result'])), color: resultColor(asStr(r['result']))),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SelectionResultScreen(selection: s, userId: asIntOr(r['user_id']), name: '${r['full_name']}')));
                    _reload();
                  },
                ),
                separator: const SizedBox(height: 8),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// One member's result, with the exception (override) actions during review / after finalization.
class SelectionResultScreen extends ConsumerStatefulWidget {
  const SelectionResultScreen({super.key, required this.selection, required this.userId, required this.name});
  final Json selection;
  final int userId;
  final String name;
  @override
  ConsumerState<SelectionResultScreen> createState() => _SelectionResultScreenState();
}

class _SelectionResultScreenState extends ConsumerState<SelectionResultScreen> {
  late Future<Json> _future = _load();
  Future<Json> _load() => ref.read(stageRepositoryProvider).selectionResult(asIntOr(widget.selection['id']), widget.userId);

  Future<void> _override(String decision) async {
    final l = context.l10n;
    final reason = await promptText(context, title: l.selException, label: l.reason, maxLines: 3, required: true);
    if (reason == null || reason.trim().length < 3 || !mounted) return;
    final r = await runWithProgress(
      context,
      () => ref.read(stageRepositoryProvider).overrideResult(asIntOr(widget.selection['id']), widget.userId, decision: decision, reason: reason.trim()),
      success: l.saved,
    );
    if (r != null) setState(() => _future = _load());
  }

  Future<void> _assignCategory(String? cat) async {
    final l = context.l10n;
    final r = await runWithProgress(
      context,
      () => ref.read(stageRepositoryProvider).assignServiceCategories(
        asIntOr(widget.selection['id']),
        [{'user_id': widget.userId, 'category': cat}],
      ),
      success: l.saved,
    );
    if (r != null) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    final status = asStr(widget.selection['status']);
    final canOverride = (status == 'review' && me.canAny([Perm.selectionReview, Perm.selectionFinalize])) || (status == 'finalized' && me.can(Perm.selectionFinalize));
    return AdminScaffold(
      title: widget.name,
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _load()));
          if (!snap.hasData) return const LoadingView();
          final d = {...snap.data!, 'selection': {...widget.selection, ...asJson(snap.data!['selection'])}};
          return EligibilityView(
            data: d,
            forMember: false,
            footer: [
              if (canOverride) ...[
                const SizedBox(height: 12),
                Text(l.selExceptionHint, style: context.sans(12, color: context.palette.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton(onPressed: () => _override('qualified'), child: Text(l.selMarkQualified)),
                  OutlinedButton(onPressed: () => _override('not_qualified'), child: Text(l.selMarkNotQualified)),
                  if (d['override'] != null) TextButton(onPressed: () => _override('clear'), child: Text(l.selClearException)),
                ]),
              ],
              if (status == 'finalized' && d['result'] == 'qualified' && me.canAny([Perm.selectionConfigure, Perm.selectionFinalize, Perm.choirManage])) ...[
                const SizedBox(height: 12),
                Text('የአገልግሎት ምድብ መድብ (Assign Service Category)', style: context.sans(12, color: context.palette.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton(
                    onPressed: () => _assignCategory('ለወረብ አገልግሎት የተመረጡ'),
                    child: Text('ለወረብ አገልግሎት የተመረጡ${d['service_category'] == 'ለወረብ አገልግሎት የተመረጡ' ? ' ✓' : ''}'),
                  ),
                  OutlinedButton(
                    onPressed: () => _assignCategory('ለመዝሙር አገልግሎት የተመረጡ'),
                    child: Text('ለመዝሙር አገልግሎት የተመረጡ${d['service_category'] == 'ለመዝሙር አገልግሎት የተመረጡ' ? ' ✓' : ''}'),
                  ),
                  if (d['service_category'] != null)
                    TextButton(onPressed: () => _assignCategory(null), child: const Text('ምድብ አንሳ (Clear)')),
                ]),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Create / configure a selection. Holders of selection.exams alone may only change whether
/// exams are required.
class SelectionEditorScreen extends ConsumerStatefulWidget {
  const SelectionEditorScreen({super.key, this.existing});
  final Json? existing;
  @override
  ConsumerState<SelectionEditorScreen> createState() => _SelectionEditorScreenState();
}

class _SelectionEditorScreenState extends ConsumerState<SelectionEditorScreen> {
  final _name = TextEditingController();
  final _w = {for (final k in selectionComponents) k: TextEditingController()};
  final _min = {for (final k in selectionComponents) k: TextEditingController()};
  final _totalMin = TextEditingController();
  final _lateCredit = TextEditingController();
  bool _contribUseRange = false;
  int? _contribYear;
  int? _contribStartMonth;
  int? _contribEndMonth;
  final _bonusMax = TextEditingController();
  // Points each program attendance earns (% of a full attendance) and per-program weights.
  final _ptPresent = TextEditingController();
  final _ptExcused = TextEditingController();
  final _ptAbsent = TextEditingController();
  final _programWeights = <int, double>{};
  final List<_IntervalRow> _mezIntervals = [];
  final _mezAfterLastPercent = TextEditingController(text: '0');
  final List<_IntervalRow> _eduIntervals = [];
  final _eduAfterLastPercent = TextEditingController(text: '0');
  DateTime? _from;
  DateTime? _to;
  Set<String> _groups = {'youth_adult', 'married'};
  bool _exams = true;
  Set<int> _classes = {};
  Set<int> _courses = {};
  Set<int> _mezCats = {};
  Set<int> _included = {};
  Set<int> _excluded = {};
  Set<int> _bonusCats = {};
  Set<int> _bonusPrograms = {};
  Json _options = const {};
  bool _loading = true;
  Object? _error;

  bool get _full => ref.read(currentUserProvider)?.can(Perm.selectionConfigure) ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _w.values) {
      c.dispose();
    }
    for (final c in _min.values) {
      c.dispose();
    }
    _totalMin.dispose();
    _lateCredit.dispose();
    _bonusMax.dispose();
    _ptPresent.dispose();
    _ptExcused.dispose();
    _ptAbsent.dispose();
    for (final r in _mezIntervals) {
      r.dispose();
    }
    for (final r in _eduIntervals) {
      r.dispose();
    }
    _mezAfterLastPercent.dispose();
    _eduAfterLastPercent.dispose();
    super.dispose();
  }

  Set<int> _ids(Object? v) => asValues(v, (e) => asIntOr(e)).toSet();

  Future<void> _load() async {
    try {
      _options = await ref.read(stageRepositoryProvider).selectionOptions();
      final s = widget.existing;
      final cfg = s == null ? asJson(_options['defaults']) : asJson(s['config']);
      final w = asJson(cfg['weights']), m = asJson(cfg['minimums']);
      for (final k in selectionComponents) {
        _w[k]!.text = _n(asDouble(w[k]));
        _min[k]!.text = m[k] == null ? '' : _n(asDouble(m[k]));
      }
      _totalMin.text = _n(asDouble(cfg['total_minimum'], 43));
      _exams = cfg['exams_required'] != false;
      final edu = asJson(cfg['education']), mez = asJson(cfg['mezmur']), bonus = asJson(cfg['bonus']);
      _classes = _ids(edu['class_ids']);
      _courses = _ids(edu['course_ids']);
      _mezCats = _ids(mez['category_ids']);
      _included = _ids(mez['included_program_ids']);
      _excluded = _ids(mez['excluded_program_ids']);
      final contrib = asJson(cfg['contribution']);
      _lateCredit.text = _n(asDouble(contrib['late_credit'], 1) * 100);
      final sm = contrib['start_month'] as int?;
      final em = contrib['end_month'] as int?;
      final yr = contrib['year'] as int?;
      if (sm != null && em != null) {
        _contribUseRange = true;
        _contribStartMonth = sm;
        _contribEndMonth = em;
        _contribYear = yr ?? EthiopianDate.fromGregorian(DateTime.now()).year;
      } else {
        _contribUseRange = false;
        _contribYear = EthiopianDate.fromGregorian(DateTime.now()).year;
        _contribStartMonth = 1;
        _contribEndMonth = 5;
      }
      _bonusMax.text = _n(asDouble(bonus['max'], 30));
      _bonusCats = _ids(bonus['category_ids']);
      _bonusPrograms = _ids(bonus['program_ids']);
      final att = {...asJson(asJson(_options['defaults'])['attendance']), ...asJson(cfg['attendance'])};
      _ptPresent.text = _n(asDouble(att['present'], 100));
      _ptExcused.text = att['excused'] == null ? '' : _n(asDouble(att['excused']));
      _ptAbsent.text = _n(asDouble(att['absent']));
      for (final w in asJsonList(att['program_weights'])) {
        _programWeights[asIntOr(w['program_id'])] = asDouble(w['weight'], 1);
      }
      final attRules = asJson(cfg['attendance_rules']);
      final mezRules = asJson(attRules['mezmur']);
      final eduRules = asJson(attRules['education']);
      _mezAfterLastPercent.text = _n(asDouble(mezRules['after_last_percent'], 0));
      _eduAfterLastPercent.text = _n(asDouble(eduRules['after_last_percent'], 0));
      for (final r in _mezIntervals) {
        r.dispose();
      }
      _mezIntervals.clear();
      for (final it in asJsonList(mezRules['intervals'])) {
        _mezIntervals.add(_IntervalRow(from: asDouble(it['from']), to: asDouble(it['to']), percent: asDouble(it['percent'])));
      }
      for (final r in _eduIntervals) {
        r.dispose();
      }
      _eduIntervals.clear();
      for (final it in asJsonList(eduRules['intervals'])) {
        _eduIntervals.add(_IntervalRow(from: asDouble(it['from']), to: asDouble(it['to']), percent: asDouble(it['percent'])));
      }
      if (s != null) {
        _name.text = '${s['name']}';
        _from = Formatters.parseDateOnly(asStr(s['from']));
        _to = Formatters.parseDateOnly(asStr(s['to']));
        _groups = asValues(s['member_groups'], (g) => '$g').toSet();
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  double get _total => selectionComponents.fold(0.0, (s, k) => s + _v(_w[k]!));

  Json _config() => {
        'weights': {for (final k in selectionComponents) k: _v(_w[k]!)},
        'minimums': {for (final k in selectionComponents) k: _min[k]!.text.trim().isEmpty ? null : _v(_min[k]!)},
        'total_minimum': _v(_totalMin),
        'exams_required': _exams,
        'education': {'class_ids': _classes.toList(), 'course_ids': _courses.toList()},
        'mezmur': {'category_ids': _mezCats.toList(), 'included_program_ids': _included.toList(), 'excluded_program_ids': _excluded.toList()},
        'contribution': {
          'late_credit': (_v(_lateCredit) / 100).clamp(0, 1),
          'year': _contribUseRange ? _contribYear : null,
          'start_month': _contribUseRange ? _contribStartMonth : null,
          'end_month': _contribUseRange ? _contribEndMonth : null,
        },
        'bonus': {'max': _v(_bonusMax).clamp(0, 30), 'category_ids': _bonusCats.toList(), 'program_ids': _bonusPrograms.toList()},
        'attendance': {
          'present': _v(_ptPresent).clamp(0, 100),
          // Kept equal to attended (no late status; the server still checks late <= present).
          'late': _v(_ptPresent).clamp(0, 100),
          'excused': _ptExcused.text.trim().isEmpty ? null : _v(_ptExcused).clamp(0, 100),
          'absent': _v(_ptAbsent).clamp(0, 100),
          'program_weights': [
            for (final e in _programWeights.entries)
              if (e.value != 1) {'program_id': e.key, 'weight': e.value},
          ],
        },
        'attendance_rules': {
          'mezmur': {
            'category_ids': _mezCats.toList(),
            'intervals': [
              for (final r in _mezIntervals)
                {'from': r.from, 'to': r.to, 'percent': r.percent},
            ],
            'after_last_percent': _v(_mezAfterLastPercent).clamp(0, 100),
          },
          'education': {
            'class_ids': _classes.toList(),
            'course_ids': _courses.toList(),
            'intervals': [
              for (final r in _eduIntervals)
                {'from': r.from, 'to': r.to, 'percent': r.percent},
            ],
            'after_last_percent': _v(_eduAfterLastPercent).clamp(0, 100),
          },
        },
      };

  Future<void> _save() async {
    final l = context.l10n;
    final repo = ref.read(stageRepositoryProvider);
    if (!_full) {
      final r = await runWithProgress(context, () => repo.updateSelection(asIntOr(widget.existing!['id']), {'config': {'exams_required': _exams}}), success: l.saved);
      if (r != null && mounted) Navigator.pop(context, r);
      return;
    }
    if (_name.text.trim().length < 2 || _from == null || _to == null) return showSnack(context, l.vRequired);
    if (_total != 100) return showSnack(context, l.choirWeightsMust100);
    final mezErr = _validateIntervals(_mezIntervals);
    if (mezErr != null) return showSnack(context, mezErr);
    final eduErr = _validateIntervals(_eduIntervals);
    if (eduErr != null) return showSnack(context, eduErr);
    final body = {
      'name': _name.text.trim(),
      'from': Formatters.isoDate(_from!),
      'to': Formatters.isoDate(_to!),
      'member_groups': _groups.toList(),
      'config': _config(),
    };
    final r = await runWithProgress(
      context,
      () => widget.existing == null ? repo.createSelection(body) : repo.updateSelection(asIntOr(widget.existing!['id']), body),
      success: l.saved,
    );
    if (r != null && mounted) Navigator.pop(context, r);
  }

  Widget _num(TextEditingController c, String label, {String? suffix, String? helper}) => TextField(
        controller: c,
        enabled: _full,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper, helperMaxLines: 3),
      );

  Widget _chips(List<Json> items, Set<int> sel, String Function(Json) label) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final it in items)
          FilterChip(
            label: Text(label(it)),
            selected: sel.contains(asIntOr(it['id'])),
            onSelected: _full ? (v) => setState(() => v ? sel.add(asIntOr(it['id'])) : sel.remove(asIntOr(it['id']))) : null,
          ),
      ]);

  void _addMezInterval() {
    setState(() {
      final double from = _mezIntervals.isEmpty ? 0 : _mezIntervals.last.to;
      final double to = from + 15;
      final double pct = _mezIntervals.isEmpty ? 100 : 70;
      _mezIntervals.add(_IntervalRow(from: from, to: to, percent: pct));
    });
  }

  void _removeMezInterval(int index) {
    setState(() {
      _mezIntervals.removeAt(index).dispose();
    });
  }

  void _addEduInterval() {
    setState(() {
      final double from = _eduIntervals.isEmpty ? 0 : _eduIntervals.last.to;
      final double to = from + 15;
      final double pct = _eduIntervals.isEmpty ? 100 : 70;
      _eduIntervals.add(_IntervalRow(from: from, to: to, percent: pct));
    });
  }

  void _removeEduInterval(int index) {
    setState(() {
      _eduIntervals.removeAt(index).dispose();
    });
  }

  Widget _buildIntervalEditor({
    required String title,
    required String subtitle,
    required List<_IntervalRow> intervals,
    required TextEditingController afterLastCtrl,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
  }) {
    final l = context.l10n;
    final p = context.palette;
    final err = _validateIntervals(intervals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: context.sans(13, weight: FontWeight.w700)),
        Text(subtitle, style: context.sans(12, color: p.muted)),
        const SizedBox(height: 8),
        if (intervals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('ምንም የጊዜ ክፍተት አልተዘጋጀም (መደበኛ 100% ውጤት ይሰጣል)', style: context.sans(12, color: p.muted).copyWith(fontStyle: FontStyle.italic)),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('ከ (ደቂቃ)', style: context.sans(11, weight: FontWeight.w600, color: p.muted))),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: Text('እስከ (ደቂቃ)', style: context.sans(11, weight: FontWeight.w600, color: p.muted))),
                const SizedBox(width: 6),
                Expanded(flex: 3, child: Text('ውጤት %', style: context.sans(11, weight: FontWeight.w600, color: p.muted))),
                if (_full) const SizedBox(width: 40),
              ],
            ),
          ),
          for (int i = 0; i < intervals.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: intervals[i].fromCtrl,
                      enabled: _full,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: intervals[i].toCtrl,
                      enabled: _full,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: intervals[i].percentCtrl,
                      enabled: _full,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), suffixText: '%'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_full)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                      onPressed: () => onRemove(i),
                      tooltip: l.remove,
                    ),
                ],
              ),
            ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 4),
                  Expanded(child: Text(err, style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600))),
                ],
              ),
            ),
        ],
        if (_full) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('ክፍተት ጨምር (Add Interval)'),
            onPressed: onAdd,
          ),
        ],
        const SizedBox(height: 8),
        _num(afterLastCtrl, 'ከመጨረሻው ክፍተት በኋላ (After Last Interval)', suffix: '%', helper: 'ከመጨረሻው የደቂቃ ገደብ በኋላ ለሚመጣ የሚሰጥ ውጤት (ነባሪ 0%)'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final online = ref.watch(isOnlineProvider);
    final p = context.palette;
    final lang = Localizations.localeOf(context).languageCode;
    final f = Formatters(l, lang);
    final cats = asJsonList(_options['categories']);
    final courses = asJsonList(_options['courses']).where((c) => _classes.isEmpty || _classes.contains(asIntOr(c['class_id']))).toList();
    final additional = asJsonList(_options['programs']).where((x) => x['is_additional'] == true).toList();
    String catLabel(Json c) => ProgramCategory.fromJson(c).label(lang);
    return AdminScaffold(
      title: widget.existing == null ? l.selNew : l.selConfigure,
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _load)
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                  if (!_full) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.selExamsOnlyHint, style: context.sans(12, color: p.muted))),
                  TextField(controller: _name, enabled: _full, decoration: InputDecoration(labelText: l.selName, hintText: l.selNameHint)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: IgnorePointer(ignoring: !_full, child: DateTimeField(label: l.from, value: _from, withTime: false, onChanged: (d) => setState(() => _from = d)))),
                    const SizedBox(width: 8),
                    Expanded(child: IgnorePointer(ignoring: !_full, child: DateTimeField(label: l.to, value: _to, withTime: false, onChanged: (d) => setState(() => _to = d)))),
                  ]),
                  const SizedBox(height: 10),
                  Text(l.memberGroup, style: context.sans(13, weight: FontWeight.w600)),
                  Wrap(spacing: 6, children: [
                    for (final g in {...MemberGroups.keys(), ..._groups})
                      FilterChip(label: Text(memberGroupLabel(l, g)), selected: _groups.contains(g), onSelected: _full ? (v) => setState(() => v ? _groups.add(g) : _groups.remove(g)) : null),
                  ]),
                  SectionHeader(title: l.polWeightsMinimums),
                  for (final k in selectionComponents)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(top: 16), child: Text(componentName(l, k), style: context.sans(14, weight: FontWeight.w600)))),
                        Expanded(flex: 2, child: _num(_w[k]!, l.polWeight)),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: _num(_min[k]!, l.polMinimum)),
                      ]),
                    ),
                  Text(l.choirWeightsTotal(_n(_total)), style: context.sans(13, weight: FontWeight.w700, color: _total == 100 ? AppColors.success : AppColors.danger)),
                  const SizedBox(height: 10),
                  _num(_totalMin, l.polTotalMinimum, helper: l.polAllMinimumsHint),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.selExamsRequiredSwitch),
                    subtitle: Text(l.selExamsRequiredHint),
                    value: _exams,
                    onChanged: (v) => setState(() => _exams = v),
                  ),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(componentName(l, 'course_attendance'), style: context.sans(15, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(l.polClassesHint, style: context.sans(12, color: p.muted)),
                      const SizedBox(height: 6),
                      _chips(asJsonList(_options['classes']), _classes, (c) => [c['name'], if (asStr(c['term']) != null) c['term']].join(' · ')),
                      const SizedBox(height: 8),
                      Text(l.polCoursesHint, style: context.sans(12, color: p.muted)),
                      const SizedBox(height: 6),
                      _chips(courses, _courses, (c) => '${c['name']} (${c['class_name']})'),
                      _buildIntervalEditor(
                        title: 'የትምህርት ጊዜ ክፍተቶች (Education Intervals)',
                        subtitle: 'ለትምህርት ክፍለ-ጊዜዎች በደቂቃ [from, to) የሚሰጥ ውጤት',
                        intervals: _eduIntervals,
                        afterLastCtrl: _eduAfterLastPercent,
                        onAdd: _addEduInterval,
                        onRemove: _removeEduInterval,
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(componentName(l, 'mezmur_attendance'), style: context.sans(15, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(l.choirMezmurCats, style: context.sans(13, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _chips(cats, _mezCats, catLabel),
                      if (additional.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(l.selAdditionalSessions, style: context.sans(13, weight: FontWeight.w600)),
                        Text(l.selAdditionalHint, style: context.sans(12, color: p.muted)),
                        for (final a in additional)
                          Row(children: [
                            Expanded(child: Text('${a['title']}', style: context.sans(13))),
                            SegmentedButton<String>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(value: 'default', label: Text(a['counts_for_selection'] == true ? l.selDefaultIn : l.selDefaultOut)),
                                ButtonSegment(value: 'in', label: Text(l.selInclude)),
                                ButtonSegment(value: 'out', label: Text(l.selExclude)),
                              ],
                              selected: {_included.contains(asIntOr(a['id'])) ? 'in' : _excluded.contains(asIntOr(a['id'])) ? 'out' : 'default'},
                              onSelectionChanged: _full
                                  ? (v) => setState(() {
                                        final id = asIntOr(a['id']);
                                        _included.remove(id);
                                        _excluded.remove(id);
                                        if (v.first == 'in') _included.add(id);
                                        if (v.first == 'out') _excluded.add(id);
                                      })
                                  : null,
                            ),
                          ]),
                      ],
                      _buildIntervalEditor(
                        title: 'የመዝሙር ጊዜ ክፍተቶች (Elapsed-Time Intervals)',
                        subtitle: 'ከፕሮግራሙ መጀመሪያ አንስቶ እስከ መዝገብ ጊዜ ባለው ደቂቃ [from, to) የሚሰጥ ውጤት',
                        intervals: _mezIntervals,
                        afterLastCtrl: _mezAfterLastPercent,
                        onAdd: _addMezInterval,
                        onRemove: _removeMezInterval,
                      ),
                    ]),
                  ),
                  // How many points each attendance earns — the admin's choice for this selection.
                  SectionHeader(title: l.selAttendancePoints),
                  Text(l.selAttendancePointsHint, style: context.sans(12, color: p.muted)),
                  const SizedBox(height: 6),
                  // There is no late status: attended is one value.
                  Row(children: [
                    Expanded(child: _num(_ptPresent, l.attPresent, suffix: '%')),
                    const SizedBox(width: 8),
                    Expanded(child: _num(_ptAbsent, l.attAbsent, suffix: '%')),
                  ]),
                  _num(_ptExcused, l.attExcused, suffix: '%', helper: l.selExcusedPolicyHint),
                  ExpansionTile(
                    key: const ValueKey('sel-program-weights'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(l.selProgramWeights, style: context.sans(13, weight: FontWeight.w600)),
                    subtitle: Text(l.selProgramWeightsHint, style: context.sans(11, color: p.muted)),
                    children: [
                      for (final pr in asJsonList(_options['programs']))
                        Row(children: [
                          Expanded(child: Text('${pr['title']}', style: context.sans(13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          DropdownButton<double>(
                            value: _programWeights[asIntOr(pr['id'])] ?? 1,
                            items: [for (final w in const [0.0, 0.5, 1.0, 1.5, 2.0, 3.0]) DropdownMenuItem(value: w, child: Text('×${_n(w)}'))],
                            onChanged: _full ? (w) => setState(() => _programWeights[asIntOr(pr['id'])] = w ?? 1) : null,
                          ),
                        ]),
                    ],
                  ),
                  SectionHeader(title: componentName(l, 'contribution')),
                  _num(_lateCredit, l.polLateCredit, suffix: '%', helper: l.selLateCreditHint),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.selContribUseCustomRange),
                    subtitle: Text(l.selContribUseCustomRangeHint),
                    value: _contribUseRange,
                    onChanged: _full
                        ? (v) => setState(() {
                              _contribUseRange = v;
                              if (v) {
                                _contribYear ??= EthiopianDate.fromGregorian(_from ?? DateTime.now()).year;
                                _contribStartMonth ??= 1;
                                _contribEndMonth ??= 5;
                              }
                            })
                        : null,
                  ),
                  if (_contribUseRange) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          decoration: InputDecoration(labelText: l.selContribEthYear),
                          initialValue: _contribYear,
                          items: [
                            for (var y = (_contribYear ?? 2019) - 4; y <= (_contribYear ?? 2019) + 4; y++)
                              DropdownMenuItem(value: y, child: Text('$y ዓ.ም')),
                          ],
                          onChanged: _full ? (y) => setState(() => _contribYear = y) : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          decoration: InputDecoration(labelText: l.selContribStartMonth),
                          initialValue: _contribStartMonth,
                          items: [
                            for (var m = 1; m <= 13; m++)
                              DropdownMenuItem(value: m, child: Text(f.monthName(m))),
                          ],
                          onChanged: _full
                              ? (m) => setState(() {
                                    _contribStartMonth = m;
                                    if (_contribEndMonth != null && m != null && _contribEndMonth! < m) {
                                      _contribEndMonth = m;
                                    }
                                  })
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          decoration: InputDecoration(labelText: l.selContribEndMonth),
                          initialValue: _contribEndMonth,
                          items: [
                            for (var m = (_contribStartMonth ?? 1); m <= 13; m++)
                              DropdownMenuItem(value: m, child: Text(f.monthName(m))),
                          ],
                          onChanged: _full ? (m) => setState(() => _contribEndMonth = m) : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (_contribStartMonth != null && _contribEndMonth != null && _contribYear != null)
                      Text(
                        l.selContribCountsRange(
                          f.monthName(_contribStartMonth!),
                          f.monthName(_contribEndMonth!),
                          _contribYear!,
                          _contribEndMonth! - _contribStartMonth! + 1,
                        ),
                        style: context.sans(13, color: AppColors.goldDark, weight: FontWeight.w600),
                      ),
                  ],
                  SectionHeader(title: componentName(l, 'bonus')),
                  _num(_bonusMax, l.selBonusMax, helper: l.selBonusHint),
                  const SizedBox(height: 8),
                  Text(l.selBonusSources, style: context.sans(13, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  _chips(cats, _bonusCats, catLabel),
                  const SizedBox(height: 6),
                  _chips(asJsonList(_options['programs']), _bonusPrograms, (x) => '${x['title']}'),
                  const SizedBox(height: 16),
                  Text(l.selFormula, style: context.sans(11, color: p.muted)),
                  const SizedBox(height: 16),
                  Tooltip(
                    message: online ? '' : l.needsConnection,
                    child: FilledButton(
                      onPressed: online ? _save : null,
                      child: Text(online ? l.save : '${l.save} · ${l.needsConnection}'),
                    ),
                  ),
                ]),
    );
  }
}

class _IntervalRow {
  _IntervalRow({required double from, required double to, required double percent})
      : fromCtrl = TextEditingController(text: _n(from)),
        toCtrl = TextEditingController(text: _n(to)),
        percentCtrl = TextEditingController(text: _n(percent));

  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final TextEditingController percentCtrl;

  double get from => double.tryParse(fromCtrl.text.trim()) ?? 0;
  double get to => double.tryParse(toCtrl.text.trim()) ?? 0;
  double get percent => double.tryParse(percentCtrl.text.trim()) ?? 0;

  void dispose() {
    fromCtrl.dispose();
    toCtrl.dispose();
    percentCtrl.dispose();
  }
}

String? _validateIntervals(List<_IntervalRow> rows) {
  if (rows.isEmpty) return null;
  if (rows.first.from != 0) {
    return 'የመጀመሪያው ክፍተት ከ 0 ደቂቃ መጀመር አለበት (INTERVAL_START_NOT_ZERO)';
  }
  double? prevTo;
  for (int i = 0; i < rows.length; i++) {
    final r = rows[i];
    if (r.to <= r.from) {
      return 'ክፍተት #${i + 1} ትክክል አይደለም (To must be > From)';
    }
    if (r.percent < 0 || r.percent > 100) {
      return 'መቶኛ ከ 0 እስከ 100 መሆን አለበት (0–100%)';
    }
    if (prevTo != null) {
      if (r.from < prevTo) {
        return 'ክፍተት #${i + 1} ከቀዳሚው ጋር ይደራረባል (INTERVAL_OVERLAP)';
      }
      if (r.from > prevTo) {
        return 'በክፍተቶች መካከል ክፍተት አለ (INTERVAL_GAP: ${prevTo.toInt()}–${r.from.toInt()} min)';
      }
    }
    prevTo = r.to;
  }
  return null;
}

