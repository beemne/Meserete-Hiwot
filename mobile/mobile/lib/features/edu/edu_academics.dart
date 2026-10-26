import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../../widgets/typed_picker.dart';
import '../admin/admin_widgets.dart' show pickUsers;
import '../admin/report_export.dart';
import '../guidance/contextual_help_sheet.dart';
import '../auth/session.dart' show currentUserProvider;

// =============================================================================
// Labels shared by the student and administrator screens
// =============================================================================
String eduRequestTypeLabel(AppLocalizations l, String? t) => switch (t) {
      'class_change' => l.eaReqClassChange,
      'stream_change' => l.eaReqStreamChange,
      'study_mode_change' => l.eaReqStudyMode,
      'add_class' => l.eaReqAddClass,
      'drop_class' => l.eaReqDropClass,
      'add_subject' => l.eaReqAddSubject,
      'drop_subject' => l.eaReqDropSubject,
      _ => l.eaReqOther,
    };

String eduRequestStatusLabel(AppLocalizations l, String? s) => switch (s) {
      'pending' => l.pendingStatus,
      'approved' => l.approved,
      'implemented' => l.eaImplemented,
      'rejected' => l.rejected,
      'cancelled' => l.permissionCancelled,
      _ => s ?? '',
    };

String eduComplaintCategoryLabel(AppLocalizations l, String? c) => switch (c) {
      'teacher' => l.eaCatTeacher,
      'marks' => l.eaCatMarks,
      'course_admin' => l.eaCatCourseAdmin,
      'enrollment' => l.eaCatEnrollment,
      'placement' => l.eaCatPlacement,
      'study_mode' => l.eaCatStudyMode,
      _ => l.eaCatOther,
    };

String eduComplaintStatusLabel(AppLocalizations l, String? s) => switch (s) {
      'submitted' => l.eaCsSubmitted,
      'under_review' => l.eaCsUnderReview,
      'awaiting_information' => l.eaCsAwaitingInfo,
      'resolved' => l.eaCsResolved,
      'rejected' => l.rejected,
      'escalated' => l.eaCsEscalated,
      _ => s ?? '',
    };

String eduMarkStatusLabel(AppLocalizations l, String? s) => switch (s) {
      'draft' => l.eaMarkDraft,
      'submitted' => l.eaMarkSubmitted,
      'approved' => l.approved,
      'rejected' => l.eaMarkRejected,
      'published' => l.eaMarkPublished,
      _ => l.eaMarkEmpty,
    };

Color eduStatusColor(String? s) => switch (s) {
      'approved' || 'implemented' || 'published' || 'resolved' => AppColors.success,
      'rejected' || 'cancelled' => AppColors.danger,
      'submitted' || 'pending' || 'under_review' || 'escalated' => AppColors.goldDark,
      'awaiting_information' => AppColors.warning,
      _ => AppColors.faint,
    };

String eduJourneyEventLabel(AppLocalizations l, String? e) => switch (e) {
      'enrolled' => l.eaJEnrolled,
      'withdrawn' => l.eaJWithdrawn,
      'class_changed' => l.eaJClassChanged,
      'stream_changed' => l.eaJStreamChanged,
      'study_mode_changed' => l.eaJStudyModeChanged,
      'subject_added' => l.eaJSubjectAdded,
      'subject_dropped' => l.eaJSubjectDropped,
      'teacher_assigned' => l.eaJTeacherAssigned,
      'teacher_suspended' => l.eaJTeacherSuspended,
      'teacher_reactivated' => l.eaJTeacherReactivated,
      'teacher_removed' => l.eaJTeacherRemoved,
      'mark_submitted' => l.eaJMarkSubmitted,
      'mark_approved' => l.eaJMarkApproved,
      'mark_rejected' => l.eaJMarkRejected,
      'mark_published' => l.eaJMarkPublished,
      'mark_amended' => l.eaJMarkAmended,
      'request_decided' => l.eaJRequestDecided,
      _ => e ?? '',
    };

String _programLabel(AppLocalizations l, String? v) => v == 'distance' ? l.programDistance : (v == 'regular' ? l.programRegular : (v ?? '—'));

// =============================================================================
// Student self-service: requests, complaints, academic journey
// =============================================================================
class EduSelfServiceScreen extends ConsumerStatefulWidget {
  const EduSelfServiceScreen({super.key, this.initialTab});
  final String? initialTab;
  @override
  ConsumerState<EduSelfServiceScreen> createState() => _EduSelfServiceScreenState();
}

class _EduSelfServiceScreenState extends ConsumerState<EduSelfServiceScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this, initialIndex: switch (widget.initialTab) { 'complaints' => 1, 'journey' => 2, _ => 0 });
  late Future<List<Json>> _requests = ref.read(eduRepositoryProvider).myRequests();
  late Future<List<Json>> _complaints = ref.read(eduRepositoryProvider).myComplaints();
  final _journey = PagedListController<Json>();

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _requests = ref.read(eduRepositoryProvider).myRequests();
        _complaints = ref.read(eduRepositoryProvider).myComplaints();
      });

  Future<void> _newRequest() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: const _RequestForm()),
    );
    if (done == true) _reload();
  }

  Future<void> _newComplaint() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: const _ComplaintForm()),
    );
    if (done == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.eaSelfService),
        actions: const [ContextualHelpButton(screenRoute: '/edu/services')],
        bottom: TabBar(controller: _tabs, tabs: [Tab(text: l.eaRequests), Tab(text: l.eaComplaints), Tab(text: l.eaJourney)]),
      ),
      floatingActionButton: switch (_tabs.index) {
        0 => FloatingActionButton.extended(onPressed: _newRequest, icon: const Icon(Icons.add_rounded), label: Text(l.eaNewRequest)),
        1 => FloatingActionButton.extended(onPressed: _newComplaint, icon: const Icon(Icons.report_outlined), label: Text(l.eaNewComplaint)),
        _ => null,
      },
      body: TabBarView(controller: _tabs, children: [
        _ListFuture(
          future: _requests,
          onRetry: _reload,
          empty: l.eaNoRequests,
          itemBuilder: (r) => _RequestCard(request: r, onChanged: _reload),
        ),
        _ListFuture(
          future: _complaints,
          onRetry: _reload,
          empty: l.eaNoComplaints,
          itemBuilder: (c) => _ComplaintTile(complaint: c, onTap: () async {
            await context.push('/edu/complaint/${c['id']}');
            _reload();
          }),
        ),
        PagedListView<Json>(
          controller: _journey,
          fetch: (page) => ref.read(eduRepositoryProvider).journey(page: page),
          emptyMessage: l.eaNoJourney,
          emptyIcon: Icons.timeline_rounded,
          itemBuilder: (context, e, _) => JourneyTile(event: e),
        ),
      ]),
    );
  }
}

class _ListFuture extends StatelessWidget {
  const _ListFuture({required this.future, required this.onRetry, required this.empty, required this.itemBuilder});
  final Future<List<Json>> future;
  final VoidCallback onRetry;
  final String empty;
  final Widget Function(Json) itemBuilder;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: onRetry);
          if (!snap.hasData) return const LoadingView();
          if (snap.data!.isEmpty) return EmptyView(message: empty, icon: Icons.inbox_outlined);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 96), children: [for (final x in snap.data!) Padding(padding: const EdgeInsets.only(bottom: 10), child: itemBuilder(x))]);
        },
      );
}

/// One academic request (student or administrator view).
class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.onChanged, this.admin = false});
  final Json request;
  final VoidCallback onChanged;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final r = request;
    final status = asStr(r['status']);
    final change = [
      if (asStr(r['current_value']) != null) _value(l, r['type'], r['current_value']),
      if (asStr(r['requested_value']) != null || asStr(r['target_class_name']) != null) _value(l, r['type'], r['requested_value'] ?? r['target_class_name']),
    ];
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(eduRequestTypeLabel(l, asStr(r['type'])), style: context.sans(15, weight: FontWeight.w700))),
          Pill(eduRequestStatusLabel(l, status), color: eduStatusColor(status)),
        ]),
        const SizedBox(height: 4),
        Text([asStr(r['ref']), if (admin) '${r['full_name']} · ${r['member_id'] ?? ''}', asStr(r['class_name']) ?? asStr(r['course_name']), f.relative(asDate(r['created_at']) ?? DateTime.now())].whereType<String>().join(' · '),
            style: context.sans(12, color: p.muted)),
        if (change.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(change.join('  →  '), style: context.sans(13, weight: FontWeight.w600))),
        if (asStr(r['reason']) != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${r['reason']}', style: context.sans(13, color: p.text))),
        if (asStr(r['review_note']) != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('${l.eaAdminComment}: ${r['review_note']}', style: context.sans(12, color: p.muted))),
        if (status == 'pending') ...[
          const SizedBox(height: 10),
          if (admin)
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _decide(context, ref, false), child: Text(l.reject))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: () => _decide(context, ref, true), child: Text(l.approve))),
            ])
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  if (!await showConfirm(context, l.eaCancelRequestConfirm) || !context.mounted) return;
                  await runWithProgress(context, () => ref.read(eduRepositoryProvider).cancelRequest(asIntOr(r['id'])), success: l.done);
                  onChanged();
                },
                child: Text(l.cancel),
              ),
            ),
        ],
      ]),
    );
  }

  static String _value(AppLocalizations l, Object? type, Object? v) => type == 'study_mode_change' || type == 'add_class' ? _programLabel(l, asStr(v)) : '${v ?? '—'}';

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    final l = context.l10n;
    final note = await promptText(context, title: approve ? l.approve : l.reject, label: l.eaAdminComment, hint: approve ? l.eaApproveRequestHint : null, maxLines: 2, required: !approve);
    if (note == null || !context.mounted) return;
    await runWithProgress(context, () => ref.read(eduRepositoryProvider).reviewRequest(asIntOr(request['id']), approve: approve, note: note.isEmpty ? null : note),
        success: approve ? l.approved : l.rejected);
    onChanged();
  }
}

/// New academic request: the fields asked depend on the kind of change.
class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm();
  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  String _type = 'study_mode_change';
  int? _classId;
  int? _targetClassId;
  int? _courseId;
  String? _value;
  final _other = TextEditingController();
  final _reason = TextEditingController();
  List<Json> _myClasses = const [];
  List<Json> _openClasses = const [];
  List<Json> _courses = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = ref.read(eduRepositoryProvider);
    try {
      final o = await repo.overview();
      final open = await repo.openClasses();
      if (!mounted) return;
      setState(() {
        _myClasses = asJsonList(o['classes']);
        _openClasses = open;
        _classId = _myClasses.isEmpty ? null : asIntOr(_myClasses.first['id']);
        _loading = false;
      });
      await _loadCourses();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Subjects to drop (the student's class) or to add (another class).
  Future<void> _loadCourses() async {
    final classId = _type == 'add_subject' ? _targetClassId : _classId;
    if (classId == null) return setState(() => _courses = const []);
    final c = await ref.read(eduRepositoryProvider).classDetail(classId);
    if (mounted) setState(() => _courses = asJsonList(c['courses']));
  }

  Json? get _myClass => _myClasses.where((c) => asIntOr(c['id']) == _classId).firstOrNull;

  Future<void> _send() async {
    final l = context.l10n;
    if (_reason.text.trim().length < 3) return showSnack(context, l.vRequired);
    final body = <String, dynamic>{
      'type': _type,
      if (_type != 'add_class' && _type != 'add_subject' && _type != 'drop_subject' && _type != 'other') 'class_id': _classId,
      if (_type == 'class_change' || _type == 'add_class') 'target_class_id': _targetClassId,
      if (_type == 'add_subject' || _type == 'drop_subject') 'course_id': _courseId,
      if (_type == 'other') 'requested_value': _other.text.trim() else if (_value != null) 'requested_value': _value,
      'reason': _reason.text.trim(),
    };
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).createRequest(body), success: l.eaRequestSent);
    if (r != null && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final streams = asValues(_myClass?['streams'], (e) => '$e');
    final needsClass = const ['class_change', 'stream_change', 'study_mode_change', 'drop_class', 'drop_subject'].contains(_type);
    final needsTarget = _type == 'class_change' || _type == 'add_class' || _type == 'add_subject';
    return SafeArea(
      child: _loading
          ? const SizedBox(height: 200, child: LoadingView())
          : ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
              Text(l.eaNewRequest, style: context.serif(19)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(labelText: l.eaRequestType),
                items: [
                  for (final t in const ['study_mode_change', 'stream_change', 'class_change', 'add_class', 'drop_class', 'add_subject', 'drop_subject', 'other'])
                    DropdownMenuItem(value: t, child: Text(eduRequestTypeLabel(l, t))),
                ],
                onChanged: (v) {
                  setState(() {
                    _type = v ?? _type;
                    _value = null;
                    _courseId = null;
                  });
                  _loadCourses();
                },
              ),
              if (needsClass) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _classId,
                  decoration: InputDecoration(labelText: l.eaMyClass),
                  items: [for (final c in _myClasses) DropdownMenuItem(value: asIntOr(c['id']), child: Text('${c['name']}'))],
                  onChanged: (v) {
                    setState(() => _classId = v);
                    _loadCourses();
                  },
                ),
              ],
              if (needsTarget) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _targetClassId,
                  decoration: InputDecoration(labelText: l.eaTargetClass),
                  items: [for (final c in _openClasses) DropdownMenuItem(value: asIntOr(c['id']), child: Text('${c['name']}'))],
                  onChanged: (v) {
                    setState(() => _targetClassId = v);
                    _loadCourses();
                  },
                ),
              ],
              if (_type == 'add_subject' || _type == 'drop_subject') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _courseId,
                  decoration: InputDecoration(labelText: l.eaSubject),
                  items: [for (final c in _courses) DropdownMenuItem(value: asIntOr(c['id']), child: Text('${c['name']}'))],
                  onChanged: (v) => setState(() => _courseId = v),
                ),
              ],
              if (_type == 'study_mode_change' || _type == 'add_class') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _value,
                  decoration: InputDecoration(labelText: l.eaStudyMode),
                  items: [DropdownMenuItem(value: 'regular', child: Text(l.programRegular)), DropdownMenuItem(value: 'distance', child: Text(l.programDistance))],
                  onChanged: (v) => setState(() => _value = v),
                ),
              ],
              if (_type == 'stream_change') ...[
                const SizedBox(height: 10),
                if (streams.isEmpty)
                  Text(l.eaNoStreams, style: context.sans(12, color: AppColors.danger))
                else
                  DropdownButtonFormField<String>(
                    initialValue: _value,
                    decoration: InputDecoration(labelText: l.eaStream),
                    items: [for (final s in streams) DropdownMenuItem(value: s, child: Text(s))],
                    onChanged: (v) => setState(() => _value = v),
                  ),
              ],
              if (_type == 'other') ...[
                const SizedBox(height: 10),
                TextField(controller: _other, decoration: InputDecoration(labelText: l.eaRequestedChange)),
              ],
              const SizedBox(height: 10),
              TextField(controller: _reason, maxLines: 3, decoration: InputDecoration(labelText: l.overrideReason)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _send, child: Text(l.eaSend)),
            ]),
    );
  }
}

class _ComplaintTile extends StatelessWidget {
  const _ComplaintTile({required this.complaint, required this.onTap, this.admin = false});
  final Json complaint;
  final VoidCallback onTap;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final c = complaint;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${c['subject']}', style: context.sans(15, weight: FontWeight.w700))),
          Pill(eduComplaintStatusLabel(l, asStr(c['status'])), color: eduStatusColor(asStr(c['status']))),
        ]),
        const SizedBox(height: 4),
        Text(
          [
            asStr(c['ref']),
            eduComplaintCategoryLabel(l, asStr(c['category'])),
            if (admin) asStr(asJson(c['student'])['full_name']),
            if (admin && c['assigned_to'] != null) '→ ${asJson(c['assigned_to'])['full_name']}',
            f.relative(asDate(c['created_at']) ?? DateTime.now()),
          ].whereType<String>().join(' · '),
          style: context.sans(12, color: context.palette.muted),
        ),
      ]),
    );
  }
}

/// New complaint: category, what it is about (own classes / subjects only), text, optional evidence.
class _ComplaintForm extends ConsumerStatefulWidget {
  const _ComplaintForm();
  @override
  ConsumerState<_ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends ConsumerState<_ComplaintForm> {
  String _category = 'marks';
  int? _classId;
  int? _courseId;
  List<Json> _classes = const [];
  List<Json> _courses = const [];
  final _subject = TextEditingController();
  final _desc = TextEditingController();
  ({String path, String name})? _file;

  @override
  void initState() {
    super.initState();
    ref.read(eduRepositoryProvider).overview().then((o) {
      if (mounted) setState(() => _classes = asJsonList(o['classes']));
    });
  }

  Future<void> _pickClass(int? id) async {
    setState(() {
      _classId = id;
      _courseId = null;
      _courses = const [];
    });
    if (id == null) return;
    final c = await ref.read(eduRepositoryProvider).classDetail(id);
    if (mounted) setState(() => _courses = asJsonList(c['courses']));
  }

  Future<void> _send() async {
    final l = context.l10n;
    if (_subject.text.trim().length < 3 || _desc.text.trim().length < 10) return showSnack(context, l.eaComplaintTooShort);
    final fields = <String, dynamic>{
      'category': _category,
      'class_id': ?_classId,
      'course_id': ?_courseId,
      'subject': _subject.text.trim(),
      'description': _desc.text.trim(),
    };
    final r = await runWithProgress(context, () => ref.read(eduRepositoryProvider).createComplaint(fields, filePath: _file?.path), success: l.eaComplaintSent);
    if (r != null && mounted) {
      await showInfo(context, l.eaComplaintRef(asStr(r['ref']) ?? ''), title: l.eaComplaintSent);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
        Text(l.eaNewComplaint, style: context.serif(19)),
        Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: Text(l.eaComplaintConfidential, style: context.sans(12, color: context.palette.muted))),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: InputDecoration(labelText: l.eaCategory),
          items: [
            for (final c in const ['marks', 'teacher', 'course_admin', 'enrollment', 'placement', 'study_mode', 'other']) DropdownMenuItem(value: c, child: Text(eduComplaintCategoryLabel(l, c))),
          ],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          initialValue: _classId,
          decoration: InputDecoration(labelText: l.eaMyClass),
          items: [DropdownMenuItem<int?>(value: null, child: Text(l.eaNotSpecific)), for (final c in _classes) DropdownMenuItem<int?>(value: asIntOr(c['id']), child: Text('${c['name']}'))],
          onChanged: _pickClass,
        ),
        if (_courses.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            initialValue: _courseId,
            decoration: InputDecoration(labelText: l.eaSubject),
            items: [DropdownMenuItem<int?>(value: null, child: Text(l.eaNotSpecific)), for (final c in _courses) DropdownMenuItem<int?>(value: asIntOr(c['id']), child: Text('${c['name']}'))],
            onChanged: (v) => setState(() => _courseId = v),
          ),
        ],
        const SizedBox(height: 10),
        TextField(controller: _subject, decoration: InputDecoration(labelText: l.eaComplaintSubject)),
        const SizedBox(height: 10),
        TextField(controller: _desc, maxLines: 5, decoration: InputDecoration(labelText: l.eaComplaintDescription)),
        const SizedBox(height: 6),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file_rounded, color: AppColors.gold),
          title: Text(_file?.name ?? l.eaAttachEvidence),
          trailing: _file == null ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _file = null)),
          onTap: () async {
            final f = await pickTypedFile(context);
            if (f != null && mounted) setState(() => _file = f);
          },
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: _send, child: Text(l.eaSend)),
      ]),
    );
  }
}

/// A complaint with its messages. Reviewers also see internal notes and manage the status.
class EduComplaintScreen extends ConsumerStatefulWidget {
  const EduComplaintScreen({super.key, required this.id, this.admin = false});
  final int id;
  final bool admin;
  @override
  ConsumerState<EduComplaintScreen> createState() => _EduComplaintScreenState();
}

class _EduComplaintScreenState extends ConsumerState<EduComplaintScreen> {
  late Future<Json> _future = _load();
  final _msg = TextEditingController();
  bool _internal = false;

  Future<Json> _load() => widget.admin ? ref.read(eduRepositoryProvider).adminComplaint(widget.id) : ref.read(eduRepositoryProvider).myComplaint(widget.id);
  void _reload() => setState(() => _future = _load());

  Future<void> _send({String? status, int? assignTo}) async {
    final l = context.l10n;
    final body = _msg.text.trim();
    final repo = ref.read(eduRepositoryProvider);
    final r = await runWithProgress(
      context,
      () => widget.admin
          ? repo.complaintAction(widget.id, {'body': body.isEmpty ? null : body, 'internal': _internal, 'status': ?status, 'assigned_to': ?assignTo})
          : repo.complaintMessage(widget.id, body),
      success: l.saved,
    );
    if (r != null) {
      _msg.clear();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return PatternScaffold(
      appBar: AppBar(title: Text(l.eaComplaint)),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final c = snap.data!;
          final status = asStr(c['status']);
          final closed = status == 'resolved' || status == 'rejected';
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text('${c['subject']}', style: context.serif(17))),
                      Pill(eduComplaintStatusLabel(l, status), color: eduStatusColor(status)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      [
                        asStr(c['ref']),
                        eduComplaintCategoryLabel(l, asStr(c['category'])),
                        asStr(asJson(c['class'])['name']),
                        asStr(asJson(c['course'])['name']),
                        asStr(asJson(c['assessment'])['title']),
                      ].whereType<String>().join(' · '),
                      style: context.sans(12, color: p.muted),
                    ),
                    if (widget.admin)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          onTap: () => context.push('/edu/journey/${asJson(c['student'])['id']}'),
                          child: Text('${asJson(c['student'])['full_name']} · ${l.eaJourney}', style: context.sans(12, color: AppColors.maroon, weight: FontWeight.w600)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text('${c['description']}', style: context.sans(14)),
                    if (c['has_attachment'] == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('📎 ${c['attachment_name'] ?? ''}', style: context.sans(12, color: p.muted)),
                      ),
                    if (widget.admin && c['resolution_hours'] != null)
                      Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.eaResolvedIn('${c['resolution_hours']}'), style: context.sans(12, color: p.muted))),
                  ]),
                ),
                const SizedBox(height: 8),
                for (final m in asJsonList(c['messages']))
                  Align(
                    alignment: m['from_student'] == true ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(maxWidth: 420),
                      decoration: BoxDecoration(
                        color: m['is_internal'] == true ? AppColors.warning.withValues(alpha: 0.12) : (m['from_student'] == true ? AppColors.gold.withValues(alpha: 0.12) : p.card),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          [asStr(m['author_name']), if (m['is_internal'] == true) l.eaInternalNote, if (asStr(m['status_change']) != null) '→ ${eduComplaintStatusLabel(l, asStr(m['status_change']))}'].whereType<String>().join(' · '),
                          style: context.sans(11, color: p.muted, weight: FontWeight.w600),
                        ),
                        if (m['body'] != '—') Text('${m['body']}', style: context.sans(13)),
                        Text(f.relative(asDate(m['created_at']) ?? DateTime.now()), style: context.sans(10, color: p.subtle)),
                      ]),
                    ),
                  ),
              ]),
            ),
            if (!closed || widget.admin)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.admin)
                      Row(children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(l.eaInternalNote),
                            value: _internal,
                            onChanged: (v) => setState(() => _internal = v ?? false),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: l.status,
                          icon: const Icon(Icons.flag_outlined),
                          onSelected: (s) => s == 'assign_me' ? _send(assignTo: ref.read(currentUserProvider)?.id) : _send(status: s),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'assign_me', child: Text(l.eaAssignToMe)),
                            for (final s in const ['under_review', 'awaiting_information', 'escalated', 'resolved', 'rejected'])
                              PopupMenuItem(value: s, child: Text(eduComplaintStatusLabel(l, s))),
                          ],
                        ),
                      ]),
                    Row(children: [
                      Expanded(child: TextField(controller: _msg, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: widget.admin ? l.eaReplyHint : l.eaAddInfoHint))),
                      IconButton(icon: const Icon(Icons.send_rounded, color: AppColors.maroon), onPressed: () => _msg.text.trim().isEmpty ? null : _send()),
                    ]),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// One event of the academic journey.
class JourneyTile extends StatelessWidget {
  const JourneyTile({super.key, required this.event});
  final Json event;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final e = event;
    final change = [asStr(e['old_value']), asStr(e['new_value'])].whereType<String>();
    return ListTile(
      leading: const Icon(Icons.timeline_rounded, color: AppColors.gold),
      title: Text(eduJourneyEventLabel(l, asStr(e['event']))),
      subtitle: Text(
        [
          asStr(e['class_name']),
          asStr(e['course_name']),
          asStr(e['assessment_title']),
          if (change.isNotEmpty) change.join(' → '),
          asStr(e['reason']),
          if (asStr(e['actor_name']) != null) '${l.eaBy} ${e['actor_name']}',
          f.dateTime(asDate(e['created_at']) ?? DateTime.now()),
        ].whereType<String>().join(' · '),
      ),
    );
  }
}

/// An administrator's view of one student's journey.
class EduStudentJourneyScreen extends ConsumerWidget {
  const EduStudentJourneyScreen({super.key, required this.userId});
  final int userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PatternScaffold(
        appBar: AppBar(title: Text(context.l10n.eaJourney)),
        body: PagedListView<Json>(
          fetch: (page) => ref.read(eduRepositoryProvider).studentJourney(userId, page: page),
          emptyMessage: context.l10n.eaNoJourney,
          emptyIcon: Icons.timeline_rounded,
          itemBuilder: (context, e, _) => JourneyTile(event: e),
        ),
      );
}

// =============================================================================
// Education administrators: marks review, requests, complaints, exports
// =============================================================================
class EduReviewScreen extends ConsumerStatefulWidget {
  const EduReviewScreen({super.key, this.initialTab});
  /// marks (default) · requests · complaints
  final String? initialTab;
  @override
  ConsumerState<EduReviewScreen> createState() => _EduReviewScreenState();
}

class _EduReviewScreenState extends ConsumerState<EduReviewScreen> {
  String _markStatus = 'submitted';
  String _reqStatus = 'pending';
  String? _complaintStatus;
  final _marks = PagedListController<Json>();
  final _requests = PagedListController<Json>();
  final _complaints = PagedListController<Json>();

  Widget _segments<T>(T value, List<(T, String)> items, void Function(T) onChanged) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (v, label) in items)
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(label), selected: v == value, onSelected: (_) => onChanged(v))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(eduRepositoryProvider);
    return DefaultTabController(
      length: 3,
      initialIndex: switch (widget.initialTab) { 'requests' => 1, 'complaints' => 2, _ => 0 },
      child: PatternScaffold(
        appBar: AppBar(
          title: Text(l.eaReviewCenter),
          actions: [
            const ContextualHelpButton(screenRoute: '/edu/review'),
            // Multi-subject marks: wide / long, CSV / Excel / PDF, by class, subjects, period, stream, study mode, status.
            IconButton(tooltip: l.eaMarksExport, icon: const Icon(Icons.file_download_outlined), onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useRootNavigator: true,
                  builder: (ctx) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom), child: const EduMarksExportSheet()),
                )),
          ],
          bottom: TabBar(tabs: [Tab(text: l.eaMarks), Tab(text: l.eaRequests), Tab(text: l.eaComplaints)]),
        ),
        body: TabBarView(children: [
          Column(children: [
            _segments(_markStatus, [('submitted', l.eaMarkSubmitted), ('approved', l.approved), ('rejected', l.eaMarkRejected), ('published', l.eaMarkPublished)], (v) => setState(() => _markStatus = v)),
            Expanded(
              child: PagedListView<Json>(
                key: ValueKey('m$_markStatus'),
                controller: _marks,
                fetch: (page) => repo.marksQueue(status: _markStatus, page: page),
                emptyMessage: l.eaNothingToReview,
                emptyIcon: Icons.grading_rounded,
                itemBuilder: (context, a, _) => TrackTile(
                  title: '${a['course_name']} — ${a['title']}',
                  subtitle: [asStr(a['class_name']), asStr(a['teacher_name']), l.eaMarksCount(asIntOr(a['marks']))].whereType<String>().join(' · '),
                  leading: const ListThumb(icon: Icons.grading_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await context.push('/edu/review/assessment/${a['id']}');
                    await _marks.refresh();
                  },
                ),
              ),
            ),
          ]),
          Column(children: [
            _segments(_reqStatus, [('pending', l.pendingStatus), ('implemented', l.eaImplemented), ('approved', l.approved), ('rejected', l.rejected)], (v) => setState(() => _reqStatus = v)),
            Expanded(
              child: PagedListView<Json>(
                key: ValueKey('r$_reqStatus'),
                controller: _requests,
                fetch: (page) => repo.adminRequests(status: _reqStatus, page: page),
                emptyMessage: l.eaNoRequests,
                separator: const SizedBox(height: 10),
                itemBuilder: (context, r, _) => _RequestCard(request: r, admin: true, onChanged: _requests.refresh),
              ),
            ),
          ]),
          Column(children: [
            _segments<String?>(_complaintStatus, [
              (null, l.all),
              for (final s in const ['submitted', 'under_review', 'awaiting_information', 'escalated', 'resolved', 'rejected']) (s, eduComplaintStatusLabel(l, s)),
            ], (v) => setState(() => _complaintStatus = v)),
            Expanded(
              child: PagedListView<Json>(
                key: ValueKey('c$_complaintStatus'),
                controller: _complaints,
                fetch: (page) => repo.adminComplaints(status: _complaintStatus, page: page),
                emptyMessage: l.eaNoComplaints,
                separator: const SizedBox(height: 10),
                itemBuilder: (context, c, _) => _ComplaintTile(
                  complaint: c,
                  admin: true,
                  onTap: () async {
                    await context.push('/edu/review/complaint/${c['id']}');
                    await _complaints.refresh();
                  },
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// One assessment's marks for review: approve (and publish), reject with a reason, publish, history.
class EduMarksReviewScreen extends ConsumerStatefulWidget {
  const EduMarksReviewScreen({super.key, required this.assessmentId});
  final int assessmentId;
  @override
  ConsumerState<EduMarksReviewScreen> createState() => _EduMarksReviewScreenState();
}

class _EduMarksReviewScreenState extends ConsumerState<EduMarksReviewScreen> {
  late Future<Json> _future = ref.read(eduRepositoryProvider).scoreSheet(widget.assessmentId);
  void _reload() => setState(() => _future = ref.read(eduRepositoryProvider).scoreSheet(widget.assessmentId));

  Future<void> _review(bool approve, {bool publish = false}) async {
    final l = context.l10n;
    String? note;
    if (!approve) {
      note = await promptText(context, title: l.reject, label: l.eaRejectReason, maxLines: 3, required: true);
      if (note == null) return;
    } else if (!await showConfirm(context, publish ? l.eaApprovePublishConfirm : l.eaApproveConfirm)) {
      return;
    }
    if (!mounted) return;
    await runWithProgress(context, () => ref.read(eduRepositoryProvider).reviewMarks(widget.assessmentId, approve: approve, note: note, publish: publish), success: l.saved);
    _reload();
  }

  Future<void> _publish() async {
    final l = context.l10n;
    if (!await showConfirm(context, l.eaPublishConfirm) || !mounted) return;
    await runWithProgress(context, () => ref.read(eduRepositoryProvider).publishMarks(widget.assessmentId), success: l.eaMarkPublished);
    _reload();
  }

  Future<void> _history() async {
    final l = context.l10n;
    final rows = await runWithProgress(context, () => ref.read(eduRepositoryProvider).markHistory(widget.assessmentId));
    if (rows == null || !mounted) return;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(l.eaHistory, style: ctx.serif(18)),
            if (rows.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(l.noResults)),
            for (final h in rows)
              ListTile(
                dense: true,
                title: Text('${h['full_name']} · ${h['action']}'),
                subtitle: Text([
                  '${h['old_score'] ?? '—'} → ${h['new_score'] ?? '—'}',
                  '${eduMarkStatusLabel(l, asStr(h['old_status']))} → ${eduMarkStatusLabel(l, asStr(h['new_status']))}',
                  ?asStr(h['reason']),
                  '${l.eaBy} ${h['actor_name'] ?? '—'}',
                  f.dateTime(asDate(h['created_at']) ?? DateTime.now()),
                ].join(' · ')),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return PatternScaffold(
      appBar: AppBar(title: Text(l.eaMarks), actions: [IconButton(tooltip: l.eaHistory, icon: const Icon(Icons.history_rounded), onPressed: _history)]),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final a = asJson(snap.data!['assessment']);
          final rows = asJsonList(snap.data!['scores']);
          final submitted = rows.where((r) => r['status'] == 'submitted').length;
          final approved = rows.where((r) => r['status'] == 'approved').length;
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
                Text('${a['title']} · ${l.eduMaxScore}: ${a['max_score']}', style: context.sans(13, color: p.muted)),
                for (final r in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r['full_name']}'),
                    subtitle: r['review_note'] == null ? null : Text('${r['review_note']}', style: context.sans(11, color: p.muted)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(r['score'] == null ? '—' : '${r['score']}', style: context.sans(14, weight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Pill(eduMarkStatusLabel(l, asStr(r['status'])), color: eduStatusColor(asStr(r['status']))),
                    ]),
                  ),
              ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
                  if (submitted > 0) ...[
                    OutlinedButton(onPressed: () => _review(false), child: Text(l.reject)),
                    OutlinedButton(onPressed: () => _review(true), child: Text(l.approve)),
                    FilledButton(onPressed: () => _review(true, publish: true), child: Text(l.eaApproveAndPublish)),
                  ],
                  if (approved > 0) FilledButton.tonal(onPressed: _publish, child: Text(l.eaPublishApproved(approved))),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Export students' marks over one or several subjects.
class EduMarksExportSheet extends ConsumerStatefulWidget {
  const EduMarksExportSheet({super.key});
  @override
  ConsumerState<EduMarksExportSheet> createState() => _EduMarksExportSheetState();
}

class _EduMarksExportSheetState extends ConsumerState<EduMarksExportSheet> {
  List<Json> _classes = const [];
  int? _classId;
  List<Json> _courses = const [];
  final _selected = <int>{};
  String _layout = 'wide';
  String? _studyMode;
  String? _markStatus;
  String _enrollment = 'active';
  final _year = TextEditingController();
  final _semester = TextEditingController();
  final _stream = TextEditingController();
  final _student = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(eduRepositoryProvider).adminClasses().then((c) {
      if (mounted) setState(() => _classes = c);
    });
  }

  Future<void> _pickClass(int? id) async {
    setState(() {
      _classId = id;
      _selected.clear();
      _courses = const [];
    });
    if (id == null) return;
    final c = await ref.read(eduRepositoryProvider).classDetail(id);
    if (mounted) setState(() => _courses = asJsonList(c['courses']));
  }

  Json _filters() => {
        'class_id': _classId,
        if (_selected.isNotEmpty) 'course_ids': _selected.join(','),
        'layout': _layout,
        'study_mode': _studyMode,
        'mark_status': _markStatus,
        'enrollment_status': _enrollment,
        'academic_year': _year.text.trim(),
        'semester': _semester.text.trim(),
        'stream': _stream.text.trim(),
        'student': _student.text.trim(),
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
        Row(children: [
          Expanded(child: Text(l.eaMarksExport, style: context.serif(19))),
          ReportExportButton(kind: 'education-marks', filters: _filters),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          initialValue: _classId,
          decoration: InputDecoration(labelText: l.eaClassAll),
          items: [DropdownMenuItem<int?>(value: null, child: Text(l.all)), for (final c in _classes) DropdownMenuItem<int?>(value: asIntOr(c['id']), child: Text('${c['name']}'))],
          onChanged: _pickClass,
        ),
        if (_courses.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l.eaSubjects, style: context.sans(13, weight: FontWeight.w600)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in _courses)
              FilterChip(label: Text('${c['name']}'), selected: _selected.contains(asIntOr(c['id'])), onSelected: (v) => setState(() => v ? _selected.add(asIntOr(c['id'])) : _selected.remove(asIntOr(c['id'])))),
          ]),
        ],
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: 'wide', label: Text(l.eaLayoutWide)), ButtonSegment(value: 'long', label: Text(l.eaLayoutLong))],
          selected: {_layout},
          onSelectionChanged: (s) => setState(() => _layout = s.first),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _year, decoration: InputDecoration(labelText: l.eaAcademicYear))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _semester, decoration: InputDecoration(labelText: l.eaSemester))),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: _stream, decoration: InputDecoration(labelText: l.eaStream))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _student, decoration: InputDecoration(labelText: l.eaStudentIdOrName))),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _studyMode,
          decoration: InputDecoration(labelText: l.eaStudyMode),
          items: [DropdownMenuItem<String?>(value: null, child: Text(l.all)), DropdownMenuItem(value: 'regular', child: Text(l.programRegular)), DropdownMenuItem(value: 'distance', child: Text(l.programDistance))],
          onChanged: (v) => setState(() => _studyMode = v),
        ),
        DropdownButtonFormField<String?>(
          initialValue: _markStatus,
          decoration: InputDecoration(labelText: l.eaMarkStatus),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(l.all)),
            for (final s in const ['published', 'approved', 'submitted', 'draft', 'rejected']) DropdownMenuItem(value: s, child: Text(eduMarkStatusLabel(l, s))),
          ],
          onChanged: (v) => setState(() => _markStatus = v),
        ),
        DropdownButtonFormField<String>(
          initialValue: _enrollment,
          decoration: InputDecoration(labelText: l.eaEnrollmentStatus),
          items: [DropdownMenuItem(value: 'active', child: Text(l.active)), DropdownMenuItem(value: 'withdrawn', child: Text(l.eaJWithdrawn)), DropdownMenuItem(value: 'all', child: Text(l.all))],
          onChanged: (v) => setState(() => _enrollment = v ?? 'active'),
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.eaMissingIsDash, style: context.sans(12, color: context.palette.muted))),
      ]),
    );
  }
}

/// Teachers of one subject: assign, suspend, reactivate, remove (history kept).
class EduCourseTeachersSheet extends ConsumerStatefulWidget {
  const EduCourseTeachersSheet({super.key, required this.courseId, required this.courseName});
  final int courseId;
  final String courseName;
  @override
  ConsumerState<EduCourseTeachersSheet> createState() => _EduCourseTeachersSheetState();
}

class _EduCourseTeachersSheetState extends ConsumerState<EduCourseTeachersSheet> {
  late Future<List<Json>> _future = ref.read(eduRepositoryProvider).courseTeachers(widget.courseId);
  void _set(Future<List<Json>> f) => setState(() => _future = f);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(eduRepositoryProvider);
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(l.eaTeachersOf(widget.courseName), style: context.serif(17)),
            trailing: TextButton.icon(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l.eaAssignTeacher),
              onPressed: () async {
                final sel = await pickUsers(context, multiple: false, title: l.eduTeacher);
                if (sel == null || sel.ids.isEmpty || !context.mounted) return;
                final r = await runWithProgress(context, () => repo.assignTeacher(widget.courseId, sel.ids.first), success: l.saved);
                if (r != null) _set(Future.value(r));
              },
            ),
          ),
          Flexible(
            child: FutureBuilder<List<Json>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) return ErrorView(error: snap.error!);
                if (!snap.hasData) return const LoadingView();
                if (snap.data!.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text(l.eduNoTeacher));
                return ListView(shrinkWrap: true, children: [
                  for (final t in snap.data!)
                    ListTile(
                      leading: const Icon(Icons.co_present_rounded, color: AppColors.gold),
                      title: Text('${t['full_name']}'),
                      subtitle: Text([
                        '${l.eaAssignedBy} ${t['assigned_by_name'] ?? '—'} · ${f.date(asDate(t['assigned_at']))}',
                        if (asStr(t['note']) != null) '${t['note']}',
                      ].join('\n')),
                      isThreeLine: asStr(t['note']) != null,
                      trailing: t['status'] == 'removed'
                          ? Pill(l.eaTeacherRemoved, color: AppColors.faint)
                          : PopupMenuButton<String>(
                              child: Pill(t['status'] == 'active' ? l.active : l.eaTeacherSuspended, color: t['status'] == 'active' ? AppColors.success : AppColors.warning),
                              onSelected: (s) async {
                                final note = await promptText(context, title: l.eaChangeTeacherStatus, label: l.overrideReason, maxLines: 2);
                                if (note == null || !context.mounted) return;
                                final r = await runWithProgress(context, () => repo.setTeacherStatus(asIntOr(t['id']), s, note: note.isEmpty ? null : note), success: l.saved);
                                if (r != null) _set(Future.value(r));
                              },
                              itemBuilder: (_) => [
                                if (t['status'] != 'active') PopupMenuItem(value: 'active', child: Text(l.eaReactivate)),
                                if (t['status'] == 'active') PopupMenuItem(value: 'suspended', child: Text(l.eaSuspend)),
                                PopupMenuItem(value: 'removed', child: Text(l.eaRemove)),
                              ],
                            ),
                    ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}
