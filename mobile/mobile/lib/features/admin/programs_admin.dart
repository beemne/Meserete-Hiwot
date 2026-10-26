import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/error_text.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/activity.dart';
import '../../models/admin.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../services/program_alarms.dart';
import '../../services/offline_pack.dart';
import '../../services/sync_service.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/qr.dart' show scanMemberQr;
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../members/member_form.dart' show memberGroupLabel;
import '../programs/program_text.dart';
import '../settings/account_screens.dart' show attendanceColor, attendanceLabel;
import 'attendance_take.dart';
import 'admin_widgets.dart';
import 'org_admin.dart' show departmentName;
import 'content_admin.dart' show statusLabel;
import 'drafts.dart';
import 'stage_admin.dart' show ProgramOccurrencesScreen, requestAttendanceCorrection;
import 'report_export.dart';
import '../guidance/contextual_help_sheet.dart';
import '../../core/member_groups.dart';

/// Pick a program (admin list, all statuses).
Future<Program?> pickProgram(BuildContext context) => Navigator.of(context).push<Program>(MaterialPageRoute(builder: (_) => const _ProgramPicker()));

/// "Add new" from another editor (banner, page …): create a program and get it back.
Future<Program?> createProgram(BuildContext context) => Navigator.of(context).push<Program>(MaterialPageRoute(builder: (_) => const ProgramEditorScreen(returnOnSave: true)));

class _ProgramPicker extends ConsumerStatefulWidget {
  const _ProgramPicker();
  @override
  ConsumerState<_ProgramPicker> createState() => _ProgramPickerState();
}

class _ProgramPickerState extends ConsumerState<_ProgramPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.programs,
      fab: FloatingActionButton.extended(
        onPressed: () async {
          final p = await createProgram(context);
          if (p != null && context.mounted) Navigator.pop(context, p);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l.newProgram),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          Expanded(
            child: PagedListView<Program>(
              key: ValueKey(_q),
              fetch: (page) => ref.read(adminRepositoryProvider).programs(q: _q.isEmpty ? null : _q, page: page),
              emptyMessage: l.noPrograms,
              itemBuilder: (context, p, _) => TrackTile(
                title: p.title,
                subtitle: '${f.date(p.startsAt)} · ${statusLabel(l, p.status)}',
                leading: ListThumb(icon: Icons.event_rounded, imageUrl: p.imageUrl),
                onTap: () => Navigator.pop(context, p),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
class ProgramsAdminScreen extends ConsumerStatefulWidget {
  const ProgramsAdminScreen({super.key});
  @override
  ConsumerState<ProgramsAdminScreen> createState() => _ProgramsAdminScreenState();
}

class _ProgramsAdminScreenState extends ConsumerState<ProgramsAdminScreen> {
  final _ctrl = PagedListController<Program>();
  String _q = '';
  String? _status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider)!;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return AdminScaffold(
      title: l.programs,
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month_rounded),
          tooltip: 'የቀን መቁጠሪያ (Calendar)',
          onPressed: () => context.push('/programs/calendar'),
        ),
        const ContextualHelpButton(screenRoute: '/admin/programs'),
        ReportExportButton(kind: 'programs', filters: () => {'status': _status, 'q': _q.isEmpty ? null : _q}),
      ],
      fab: me.can(Perm.programsManage)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/admin/programs/edit/new').then((_) => _ctrl.refresh()),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.newProgram),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final s in [null, 'published', 'draft', 'completed', 'cancelled'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text(s == null ? l.all : statusLabel(l, s)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<Program>(
              key: ValueKey('$_q|$_status'),
              controller: _ctrl,
              // Attendance takers without programs.manage see the programs they may take attendance for.
              fetch: (page) => me.can(Perm.programsManage)
                  ? ref.read(adminRepositoryProvider).programs(q: _q.isEmpty ? null : _q, status: _status, page: page)
                  : ref.read(adminRepositoryProvider).takeablePrograms(q: _q.isEmpty ? null : _q, page: page),
              emptyMessage: l.noPrograms,
              itemBuilder: (context, p, _) => TrackTile(
                title: p.title,
                subtitle: [
                  f.dateTime(p.displayStart),
                  if (p.isRecurring) programRecurrenceText(context, p),
                  statusLabel(l, p.status),
                  l.participantsCount(p.participantCount),
                ].join(' · '),
                leading: ListThumb(icon: Icons.event_rounded, imageUrl: p.imageUrl),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    final route = switch (v) {
                      'edit' => '/admin/programs/edit/${p.id}',
                      'participants' => '/admin/programs/${p.id}/participants',
                      _ => '/admin/programs/${p.id}/attendance',
                    };
                    context.push(route).then((_) => _ctrl.refresh());
                  },
                  itemBuilder: (_) => [
                    if (me.can(Perm.programsManage)) PopupMenuItem(value: 'edit', child: Text(l.edit)),
                    if (me.can(Perm.programsManage)) PopupMenuItem(value: 'participants', child: Text(l.participants)),
                    if (me.can(Perm.attendanceManage)) PopupMenuItem(value: 'attendance', child: Text(l.attendanceRoster)),
                  ],
                ),
                onTap: () => context.push(me.can(Perm.programsManage) ? '/admin/programs/edit/${p.id}' : '/admin/programs/${p.id}/attendance').then((_) => _ctrl.refresh()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgramEditorScreen extends ConsumerStatefulWidget {
  const ProgramEditorScreen({super.key, this.programId, this.returnOnSave = false});
  final int? programId;

  /// Opened from another editor's "add new": close after the first save and hand the program back.
  final bool returnOnSave;
  @override
  ConsumerState<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _capacity = TextEditingController();
  bool _hasEnd = true;
  Set<int> _offsets = Program.defaultReminderOffsets.toSet();
  final _remTitle = TextEditingController();
  final _remBody = TextEditingController();
  DateTime _starts = DateTime.now().add(const Duration(days: 7));
  DateTime _ends = DateTime.now().add(const Duration(days: 7, hours: 2));
  bool _requiresReg = false;
  bool _requiresAtt = true;
  bool _reminder = true;
  bool _isMandatoryReminder = false;
  /// Remind the audience every 15 days (null = off) from [_intervalStart] (null = server default).
  int? _intervalDays;
  DateTime? _intervalStart;
  String _audience = 'all'; // all = general program, participants = special event
  String? _eventType;
  int? _categoryId;
  String _recurrence = 'once'; // once | weekly | twice_monthly | monthly | ethiopian_days
  Set<int> _ethDays = {1, 10, 19}; // ሰርክ by default
  bool _additional = false;
  bool _countsForSelection = true;
  bool _isEducation = false;
  Set<int> _classIds = {};
  int? _scheduleId;
  int? _academicYearId;
  String _sessionType = 'individual'; // individual | shared
  bool _overlapConfirmed = false;
  String _monthlyRule = 'day_of_month'; // day_of_month | nth_weekday
  DateTime? _until;
  Set<String> _groups = {}; // empty = everyone
  bool _saving = false;
  String _status = 'draft';
  Program? _program;
  bool _loading = false;
  Object? _error;
  late final DraftKeeper _draft = DraftKeeper(ref.read(localPrefsProvider), 'program:${widget.programId ?? 'new'}');
  late final _repo = ref.read(adminRepositoryProvider);
  bool _restored = false;
  bool _submitted = false;

  Json _snapshot() => {
    'title': _title.text,
    'description': _desc.text,
    'location': _location.text,
    'capacity': _capacity.text,
    'has_end': _hasEnd,
    'offsets': _offsets.toList(),
    'rem_title': _remTitle.text,
    'rem_body': _remBody.text,
    'starts': _starts.toIso8601String(),
    'ends': _ends.toIso8601String(),
    'requires_reg': _requiresReg,
    'requires_att': _requiresAtt,
    'reminder': _reminder,
    'is_mandatory_reminder': _isMandatoryReminder,
    'interval_days': _intervalDays,
    'interval_start': _intervalStart?.toIso8601String(),
    'audience': _audience,
    'event_type': _eventType,
    'status': _status,
    'category_id': _categoryId,
    'recurrence': _recurrence,
    'monthly_rule': _monthlyRule,
    'until': _until?.toIso8601String(),
    'groups': _groups.toList(),
    'eth_days': _ethDays.toList(),
    'additional': _additional,
    'counts': _countsForSelection,
    'is_education': _isEducation,
    'class_ids': _classIds.toList(),
    'schedule_id': _scheduleId,
    'academic_year_id': _academicYearId,
    'session_type': _sessionType,
  };

  void _restore(Json d) {
    _title.text = asStr(d['title']) ?? '';
    _desc.text = asStr(d['description']) ?? '';
    _location.text = asStr(d['location']) ?? '';
    _capacity.text = asStr(d['capacity']) ?? '';
    _hasEnd = d['has_end'] == null || asBool(d['has_end']);
    if (d['offsets'] != null) _offsets = asValues(d['offsets'], (e) => asIntOr(e)).toSet();
    _remTitle.text = asStr(d['rem_title']) ?? '';
    _remBody.text = asStr(d['rem_body']) ?? '';
    _starts = asDate(d['starts']) ?? _starts;
    _ends = asDate(d['ends']) ?? _ends;
    _requiresReg = asBool(d['requires_reg']);
    _requiresAtt = d['requires_att'] == null || asBool(d['requires_att']);
    _reminder = d['reminder'] == null || asBool(d['reminder']);
    _isMandatoryReminder = asBool(d['is_mandatory_reminder']);
    _intervalDays = asInt(d['interval_days']);
    _intervalStart = asDate(d['interval_start']);
    _audience = asStr(d['audience']) ?? 'all';
    _eventType = asStr(d['event_type']);
    _status = asStr(d['status']) ?? 'draft';
    _categoryId = asInt(d['category_id']);
    _recurrence = asStr(d['recurrence']) ?? 'once';
    _monthlyRule = asStr(d['monthly_rule']) ?? 'day_of_month';
    _until = asDate(d['until']);
    _groups = asValues(d['groups'], (e) => '$e').toSet();
    if (d['eth_days'] != null) _ethDays = asValues(d['eth_days'], (e) => asIntOr(e)).toSet();
    _additional = asBool(d['additional']);
    _countsForSelection = d['counts'] == null || asBool(d['counts']);
    _isEducation = asBool(d['is_education']);
    if (d['class_ids'] != null) _classIds = asValues(d['class_ids'], (e) => asIntOr(e)).toSet();
    _scheduleId = asInt(d['schedule_id']);
    _academicYearId = asInt(d['academic_year_id']);
    _sessionType = asStr(d['session_type']) ?? 'individual';
  }

  void _checkDraft() {
    _draft.setBaseline(_snapshot());
    final d = _draft.pending();
    if (d != null) {
      _restore(d);
      _restored = true;
    }
  }

  void _discardDraft() {
    if (_program != null) {
      _apply(_program!);
    } else {
      _restore({'starts': DateTime.now().add(const Duration(days: 7)).toIso8601String(), 'ends': DateTime.now().add(const Duration(days: 7, hours: 2)).toIso8601String()});
    }
    unawaited(_draft.clear(baseline: _snapshot()));
    setState(() => _restored = false);
  }

  /// Leaving without Save: a new program with a title is stored on the server as a draft.
  void _leave() {
    _draft.flush();
    if (_submitted || _program != null || _title.text.trim().isEmpty || (_hasEnd && !_ends.isAfter(_starts))) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    unawaited(
      _repo
          .createProgram({..._body(), 'status': 'draft'})
          .then((_) async {
            await ref.read(localPrefsProvider).removeDraft('program:new');
            messenger?.showSnackBar(SnackBar(content: Text(l.savedAsDraft)));
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.programId != null) {
      _load(widget.programId!);
    } else {
      _checkDraft();
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load(int id) async {
    setState(() => _loading = true);
    try {
      _apply(await ref.read(adminRepositoryProvider).program(id));
      if (!_restored) _checkDraft();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(Program p) {
    _program = p;
    _title.text = p.title;
    _desc.text = p.description ?? '';
    _location.text = p.location ?? '';
    _capacity.text = p.capacity?.toString() ?? '';
    _hasEnd = p.hasEndTime;
    _offsets = p.reminderOffsets.toSet();
    _remTitle.text = p.reminderTitle ?? '';
    _remBody.text = p.reminderBody ?? '';
    _starts = p.startsAt;
    _ends = p.endsAt;
    _requiresReg = p.requiresRegistration;
    _requiresAtt = p.requiresAttendance;
    _reminder = p.reminderEnabled;
    _audience = p.audience;
    _eventType = p.eventType;
    _status = p.status;
    _categoryId = p.category?.id;
    _recurrence = p.recurrence;
    _monthlyRule = p.monthlyRule ?? 'day_of_month';
    _until = p.recurrenceUntil;
    _groups = p.memberGroups.toSet();
    if (p.ethiopianDays.isNotEmpty) _ethDays = p.ethiopianDays.toSet();
    _additional = p.isAdditional;
    _countsForSelection = p.countsForSelection;
    _isMandatoryReminder = p.isMandatoryReminder;
    _intervalDays = p.reminderIntervalDays;
    _intervalStart = p.reminderIntervalStart;
    _isEducation = p.isEducation || p.classIds.isNotEmpty || p.scheduleId != null;
    _classIds = p.classIds.toSet();
    _scheduleId = p.scheduleId;
    _sessionType = p.classIds.length > 1 ? 'shared' : 'individual';
  }

  Future<void> _save() async {
    final untilBad = _recurrence != 'once' && _until != null && _until!.isBefore(DateTime(_starts.year, _starts.month, _starts.day));
    if (!_form.currentState!.validate() || (_hasEnd && !_ends.isAfter(_starts)) || untilBad) {
      setState(() {});
      showSnack(context, context.l10n.checkFields);
      return;
    }

    // Check for overlapping programs (warning only, never blocks authorized administrators).
    if (!_overlapConfirmed) {
      setState(() => _saving = true);
      try {
        final repo = ref.read(adminRepositoryProvider);
        final conflicts = await repo.checkProgramOverlap({
          'starts_at': _starts.toUtc().toIso8601String(),
          'ends_at': _hasEnd ? _ends.toUtc().toIso8601String() : null,
          'recurrence': _recurrence,
          'monthly_rule': _recurrence == 'monthly' || _recurrence == 'twice_monthly' ? _monthlyRule : null,
          'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
          'exclude_program_id': _program?.id,
        });

        if (conflicts.isNotEmpty && mounted) {
          setState(() => _saving = false);
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded, size: 36, color: AppColors.gold),
              title: const Text('የመርሐግብር መደራረብ ማስጠንቀቂያ', style: TextStyle(fontFamily: 'NotoSansEthiopic', fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ከተመረጠው ሰዓት ወይም ቦታ ጋር የሚደራረቡ ሌሎች ፕሮግራሞች አሉ:', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 10),
                    for (final c in conflicts)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(asStr(c['title']) ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: asBool(c['is_same_venue']) ? AppColors.danger.withValues(alpha: 0.15) : AppColors.gold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    asBool(c['is_same_venue']) ? 'ተመሳሳይ ቦታ' : 'ተመሳሳይ ሰዓት',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: asBool(c['is_same_venue']) ? AppColors.danger : AppColors.maroon,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${asStr(c['ethiopian_date'])}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                            if (c['location'] != null && asStr(c['location'])!.isNotEmpty)
                              Text('ቦታ: ${asStr(c['location'])}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    const Text('ይህ ማስጠንቀቂያ ብቻ ነው። የተፈቀደልዎ አስተዳዳሪ ስለሆኑ መደራረቡን አውቀው ፕሮግራሙን ማስቀመጥ መቀጠል ይችላሉ።', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('ይቅር (Cancel)'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('ይቀጥሉ (Proceed)'),
                ),
              ],
            ),
          );

          if (proceed != true) return;
          _overlapConfirmed = true;
        }
      } catch (_) {}
    }

    setState(() => _saving = true);
    final repo = ref.read(adminRepositoryProvider);
    final body = _body();
    try {
      final p = _program == null ? await repo.createProgram(body) : await repo.updateProgram(_program!.id, body);
      if (!mounted) return;
      setState(() {
        _apply(p);
        _error = null;
        _restored = false;
      });
      _submitted = true;
      await _draft.rekey('program:${p.id}');
      await _draft.clear(baseline: _snapshot());
      if (!mounted) return;
      showSnack(context, context.l10n.saved);
      if (widget.returnOnSave) Navigator.of(context).pop(p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Json _body() {
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    return {
      'title': _title.text.trim(),
      'description': opt(_desc),
      'location': opt(_location),
      'starts_at': _starts.toUtc().toIso8601String(),
      // No end time: the program lasts until the end of its day.
      'ends_at': _hasEnd ? _ends.toUtc().toIso8601String() : null,
      'reminder_offsets': _offsets.toList()..sort((a, b) => b.compareTo(a)),
      'requires_registration': _requiresReg,
      'requires_attendance': _requiresAtt,
      'capacity': int.tryParse(_capacity.text.trim()),
      'audience': _audience,
      'event_type': _audience == 'participants' ? (_eventType ?? 'other') : null,
      'status': _status,
      'reminder_enabled': _reminder,
      'is_mandatory_reminder': _isMandatoryReminder,
      'reminders_enforce': _isMandatoryReminder,
      'reminder_title': opt(_remTitle),
      'reminder_body': opt(_remBody),
      // Unset on a new program: the program type's default applies.
      if (_program != null || _intervalDays != null) 'reminder_interval_days': _intervalDays,
      if (_intervalDays != null && _intervalStart != null) 'reminder_interval_start': Formatters.isoDate(_intervalStart!),
      'category_id': ?_categoryId,
      'recurrence': _recurrence,
      'monthly_rule': _recurrence == 'monthly' || _recurrence == 'twice_monthly' ? _monthlyRule : null,
      'recurrence_until': _recurrence == 'once' || _until == null ? null : Formatters.isoDate(_until!),
      'member_groups': _groups.toList(),
      'ethiopian_days': _recurrence == 'ethiopian_days' ? (_ethDays.toList()..sort()) : null,
      'is_additional': _additional,
      'counts_for_selection': _countsForSelection,
      'class_ids': _isEducation ? _classIds.toList() : [],
      'schedule_id': _scheduleId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final repo = ref.read(adminRepositoryProvider);
    if (!_loading) WidgetsBinding.instance.addPostFrameCallback((_) => _draft.changed(_snapshot()));
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: AdminScaffold(
        title: _program == null ? l.newProgram : l.editProgram,
        actions: [
          if (_program != null) ...[
            IconButton(tooltip: l.participants, icon: const Icon(Icons.groups_outlined), onPressed: () => context.push('/admin/programs/${_program!.id}/participants')),
            IconButton(tooltip: l.attendanceRoster, icon: const Icon(Icons.how_to_reg_outlined), onPressed: () => context.push('/admin/programs/${_program!.id}/attendance')),
          ],
        ],
        body: _loading
            ? const LoadingView()
            : Form(
                key: _form,
                onChanged: () => _draft.changed(_snapshot()),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (_restored) DraftRestoredBanner(onDiscard: _discardDraft),
                    TextFormField(
                      controller: _title,
                      validator: (s) => v.text(s, max: 255),
                      decoration: InputDecoration(labelText: l.title),
                    ),
                    const SizedBox(height: 12),
                    ref.watch(adminProgramCategoriesProvider).when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text(errorText(l, e), style: const TextStyle(color: AppColors.danger)),
                          data: (cats) {
                            final lang = Localizations.localeOf(context).languageCode;
                            final options = cats.where((c) => c.isActive || c.id == _categoryId).toList();
                            return DropdownButtonFormField<int>(
                              initialValue: options.any((c) => c.id == _categoryId) ? _categoryId : null,
                              decoration: InputDecoration(labelText: l.programCategory, hintText: l.programCategoryDefault),
                              items: [
                                for (final c in options)
                                  DropdownMenuItem(
                                    value: c.id,
                                    child: Row(children: [
                                      CircleAvatar(radius: 6, backgroundColor: hexColor(c.color)),
                                      const SizedBox(width: 8),
                                      Text(c.label(lang)),
                                    ]),
                                  ),
                              ],
                              onChanged: (x) => setState(() => _categoryId = x),
                            );
                          },
                        ),
                    const SizedBox(height: 14),
                    // Which member groups this program is for (attendance counts only them).
                    Text(l.programForGroups, style: context.sans(13, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      ChoiceChip(label: Text(l.allGroups), selected: _groups.isEmpty, onSelected: (_) => setState(() => _groups = {})),
                      for (final g in {...MemberGroups.keys(), ..._groups})
                        FilterChip(
                          label: Text(memberGroupLabel(l, g)),
                          selected: _groups.contains(g),
                          onSelected: (v) => setState(() => v ? _groups.add(g) : _groups.remove(g)),
                        ),
                    ]),
                    if (_program != null) ...[
                      const SizedBox(height: 14),
                      ProgramTakersSection(programId: _program!.id),
                    ],
                    const SizedBox(height: 14),
                    Text(l.programKind, style: context.sans(13, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 'all',
                          icon: const Icon(Icons.groups_rounded),
                          label: Text(l.programGeneral, maxLines: 2, textAlign: TextAlign.center),
                        ),
                        ButtonSegment(
                          value: 'participants',
                          icon: const Icon(Icons.celebration_rounded),
                          label: Text(l.programSpecial, maxLines: 2, textAlign: TextAlign.center),
                        ),
                      ],
                      selected: {_audience},
                      onSelectionChanged: (x) => setState(() => _audience = x.first),
                    ),
                    if (_audience == 'participants') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _eventType ?? 'other',
                        decoration: InputDecoration(labelText: l.eventType),
                        items: [
                          for (final t in ['wedding', 'holiday', 'memorial', 'celebration', 'other']) DropdownMenuItem(value: t, child: Text(eventTypeLabel(l, t))),
                        ],
                        onChanged: (x) => setState(() => _eventType = x),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(l.specialInviteHint, style: context.sans(12, color: context.palette.muted)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _desc,
                      minLines: 3,
                      maxLines: 10,
                      validator: (s) => v.text(s, max: 20000, optional: true),
                      decoration: InputDecoration(labelText: l.description, alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _location,
                      validator: (s) => v.text(s, max: 255, optional: true),
                      decoration: InputDecoration(labelText: l.location),
                    ),
                    const SizedBox(height: 12),
                    DateTimeField(label: l.startsAt, value: _starts, onChanged: (d) => setState(() => _starts = d ?? _starts)),
                    const SizedBox(height: 12),
                    // The end time is optional: some programs have no fixed end.
                    SwitchListTile(
                      key: const ValueKey('program-has-end'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(_hasEnd ? l.hasEndTime : l.noEndTime),
                      subtitle: _hasEnd ? null : Text(l.noEndTimeHint),
                      value: _hasEnd,
                      onChanged: (x) => setState(() {
                        _hasEnd = x;
                        if (x && !_ends.isAfter(_starts)) _ends = _starts.add(const Duration(hours: 2));
                      }),
                    ),
                    if (_hasEnd)
                      DateTimeField(
                        label: l.endsAt,
                        value: _ends,
                        errorText: _ends.isAfter(_starts) ? null : l.vEndBeforeStart,
                        onChanged: (d) => setState(() => _ends = d ?? _ends),
                      ),
                    const SizedBox(height: 14),
                    Text(l.recurrence, style: context.sans(13, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final (value, icon, label) in [
                        ('once', Icons.event_rounded, l.recurrenceOnce),
                        ('weekly', Icons.view_week_rounded, l.recurrenceWeekly),
                        // 2 days a month, about two weeks apart.
                        ('twice_monthly', Icons.event_repeat_rounded, l.recurrenceTwiceMonthly),
                        ('monthly', Icons.calendar_month_rounded, l.recurrenceMonthly),
                        ('ethiopian_days', Icons.date_range_rounded, l.recurrenceEthiopianDays),
                      ])
                        ChoiceChip(avatar: Icon(icon, size: 18), label: Text(label), selected: _recurrence == value, onSelected: (_) => setState(() => _recurrence = value)),
                    ]),
                    if (_recurrence == 'ethiopian_days') ...[
                      const SizedBox(height: 8),
                      Text(l.ethiopianDaysHint, style: context.sans(12, color: context.palette.muted)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 4, runSpacing: 4, children: [
                        for (var d = 1; d <= 30; d++)
                          FilterChip(
                            visualDensity: VisualDensity.compact,
                            showCheckmark: false,
                            label: Text('$d'),
                            selected: _ethDays.contains(d),
                            onSelected: (v) => setState(() => v ? _ethDays.add(d) : (_ethDays.length > 1 ? _ethDays.remove(d) : null)),
                          ),
                      ]),
                    ],
                    if (_recurrence != 'once') ...[
                      const SizedBox(height: 8),
                      Text(
                        recurrenceSummary(context, _recurrence, _monthlyRule, _starts, ethiopianDays: _ethDays.toList()..sort()),
                        style: context.sans(12, color: context.palette.muted),
                      ),
                      if (_recurrence == 'monthly' || _recurrence == 'twice_monthly') ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _monthlyRule,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: l.monthlyRule),
                          items: [
                            DropdownMenuItem(value: 'day_of_month', child: Text(_recurrence == 'twice_monthly' ? l.twiceMonthlyRuleDay : l.monthlyRuleDay)),
                            DropdownMenuItem(value: 'nth_weekday', child: Text(_recurrence == 'twice_monthly' ? l.twiceMonthlyRuleWeekday : l.monthlyRuleWeekday)),
                          ],
                          onChanged: (x) => setState(() => _monthlyRule = x ?? 'day_of_month'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DateTimeField(
                        label: l.recurrenceUntil,
                        value: _until,
                        withTime: false,
                        clearable: true,
                        errorText: _until != null && _until!.isBefore(DateTime(_starts.year, _starts.month, _starts.day)) ? l.vEndBeforeStart : null,
                        onChanged: (d) => setState(() => _until = d),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      validator: (s) => v.intRange(s, min: 1, max: 1000000, optional: true),
                      decoration: InputDecoration(labelText: l.capacityLabel),
                    ),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.requiresRegistration), value: _requiresReg, onChanged: (x) => setState(() => _requiresReg = x)),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.requiresAttendance), value: _requiresAtt, onChanged: (x) => setState(() => _requiresAtt = x)),
                    if (_requiresAtt)
                      // One HR-assigned taker per occurrence; opens 15 minutes before the start, the
                      // taker presses Start (there is no on-time / late window any more).
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(l.attSessionRuleHint, style: context.sans(12, color: context.palette.muted)),
                      ),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.additionalSession), subtitle: Text(l.additionalSessionHint), value: _additional, onChanged: (x) => setState(() => _additional = x)),
                    if (_additional)
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.countsForSelection), subtitle: Text(l.countsForSelectionHint), value: _countsForSelection, onChanged: (x) => setState(() => _countsForSelection = x)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.school_rounded, color: AppColors.maroon),
                      title: const Text('የትምህርት ክፍል ፕሮግራም (Education Program)'),
                      subtitle: const Text('የክፍል አባላት ብቻ መገኘት እንዲመዘገብላቸው ከክፍለ-ጊዜ መርሐግብር ጋር ያገናኙ'),
                      value: _isEducation,
                      onChanged: (x) => setState(() => _isEducation = x),
                    ),
                    if (_isEducation) ...[
                      const SizedBox(height: 6),
                      // 1. Select Academic Year
                      FutureBuilder<List<Json>>(
                        future: ref.read(eduRepositoryProvider).academicYears(),
                        builder: (context, snap) {
                          final years = snap.data ?? [];
                          if (years.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DropdownButtonFormField<int>(
                              initialValue: _academicYearId ?? (years.any((y) => asBool(y['is_current'])) ? asInt(years.firstWhere((y) => asBool(y['is_current']))['id']) : asInt(years.first['id'])),
                              decoration: const InputDecoration(
                                labelText: 'የትምህርት ዘመን (Academic Year)',
                                prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                              ),
                              items: [
                                for (final y in years)
                                  DropdownMenuItem<int>(
                                    value: asInt(y['id']),
                                    child: Text('${asStr(y['name']) ?? 'Year'} (${asStr(y['eth_year'])} ዓ.ም)'),
                                  ),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _academicYearId = v;
                                  _classIds.clear();
                                  _scheduleId = null;
                                });
                              },
                            ),
                          );
                        },
                      ),

                      // 2. Choose Session Type: Individual-Class vs Shared Session
                      Text('የክፍለ-ጊዜ ዓይነት (Session Type)', style: context.sans(13, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 'individual',
                            icon: Icon(Icons.person_rounded),
                            label: Text('ነጠላ ክፍል (Individual)'),
                          ),
                          ButtonSegment(
                            value: 'shared',
                            icon: Icon(Icons.groups_rounded),
                            label: Text('የተጋራ ክፍለ-ጊዜ (Shared)'),
                          ),
                        ],
                        selected: {_sessionType},
                        onSelectionChanged: (s) => setState(() => _sessionType = s.first),
                      ),
                      const SizedBox(height: 10),

                      // 3. Select Class(es)
                      Text(
                        _sessionType == 'individual' ? 'የሚሳተፍ ክፍል (Select Class)' : 'የሚሳተፉ ክፍሎች (Select Shared Classes)',
                        style: context.sans(13, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<List<Json>>(
                        future: ref.read(eduRepositoryProvider).adminClasses(status: 'active', academicYearId: _academicYearId),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                          final classes = snap.data ?? [];
                          if (classes.isEmpty) return Text('በዚህ የትምህርት ዘመን ንቁ ክፍሎች የሉም', style: context.sans(12, color: context.palette.muted));

                          if (_sessionType == 'individual') {
                            return DropdownButtonFormField<int>(
                              initialValue: _classIds.isNotEmpty ? _classIds.first : null,
                              decoration: const InputDecoration(labelText: 'ክፍል ይምረጡ'),
                              items: [
                                for (final c in classes)
                                  DropdownMenuItem<int>(
                                    value: asIntOr(c['id']),
                                    child: Text(asStr(c['name']) ?? 'Class ${c['id']}'),
                                  ),
                              ],
                              onChanged: (cid) {
                                setState(() {
                                  _classIds = cid != null ? {cid} : {};
                                  _scheduleId = null;
                                });
                              },
                            );
                          }

                          return Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final c in classes)
                                FilterChip(
                                  label: Text(asStr(c['name']) ?? 'Class ${c['id']}'),
                                  selected: _classIds.contains(asIntOr(c['id'])),
                                  onSelected: (selected) {
                                    final cid = asIntOr(c['id']);
                                    setState(() {
                                      if (selected) {
                                        _classIds.add(cid);
                                      } else {
                                        _classIds.remove(cid);
                                      }
                                      _scheduleId = null;
                                    });
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // 4. Timetable Entries Picker & Auto-populate
                      if (_classIds.isNotEmpty) ...[
                        Text('የትምህርት ክፍለ-ጊዜ መርሐግብር (Class Timetable)', style: context.sans(13, weight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        FutureBuilder<List<Json>>(
                          future: ref.read(eduRepositoryProvider).allSchedules(
                                academicYearId: _academicYearId,
                                classId: _sessionType == 'individual' ? _classIds.first : null,
                              ),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                            final schedules = snap.data ?? [];
                            if (schedules.isEmpty) {
                              return Text('ለተመረጠው ክፍል የተመዘገበ የክፍለ-ጊዜ መርሐግብር የለም', style: context.sans(12, color: context.palette.muted));
                            }

                            final weekdayNames = ['', 'ሰኞ', 'ማክሰኞ', 'ረቡዕ', 'ሐሙስ', 'ዓርብ', 'ቅዳሜ', 'እሑድ'];

                            return Column(
                              children: [
                                for (final s in schedules)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: _scheduleId == asIntOr(s['id']) ? AppColors.gold.withValues(alpha: 0.15) : Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _scheduleId == asIntOr(s['id']) ? AppColors.gold : Theme.of(context).dividerColor.withValues(alpha: 0.4),
                                        width: _scheduleId == asIntOr(s['id']) ? 1.5 : 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(
                                        _scheduleId == asIntOr(s['id']) ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                        color: _scheduleId == asIntOr(s['id']) ? AppColors.maroon : AppColors.muted,
                                      ),
                                      title: Text(
                                        '${asStr(s['course_name']) ?? 'ትምህርት'} · ${asStr(s['class_name']) ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        '${weekdayNames[asIntOr(s['weekday'], 1)]} ${asStr(s['starts']) ?? ''} - ${asStr(s['ends']) ?? ''} · ${asStr(s['location']) ?? 'ቦታ አልተገለጸም'}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: TextButton(
                                        child: Text(_scheduleId == asIntOr(s['id']) ? 'ተመርጧል' : 'ከዚህ ሙላ'),
                                        onPressed: () {
                                          setState(() {
                                            _scheduleId = asIntOr(s['id']);
                                            if (_title.text.trim().isEmpty && s['course_name'] != null) {
                                              _title.text = asStr(s['course_name'])!;
                                            }
                                            if (s['location'] != null && asStr(s['location'])!.isNotEmpty) {
                                              _location.text = asStr(s['location'])!;
                                            }
                                            _recurrence = 'weekly';

                                            // Align starts and ends time
                                            final weekday = asIntOr(s['weekday'], 1);
                                            var targetDay = DateTime.now();
                                            while (targetDay.weekday != weekday) {
                                              targetDay = targetDay.add(const Duration(days: 1));
                                            }
                                            final startParts = (asStr(s['starts']) ?? '09:00').split(':').map((p) => int.tryParse(p) ?? 0).toList();
                                            final endParts = (asStr(s['ends']) ?? '11:00').split(':').map((p) => int.tryParse(p) ?? 0).toList();
                                            _starts = DateTime(targetDay.year, targetDay.month, targetDay.day, startParts[0], startParts.length > 1 ? startParts[1] : 0);
                                            _ends = DateTime(targetDay.year, targetDay.month, targetDay.day, endParts[0], endParts.length > 1 ? endParts[1] : 0);
                                            _hasEnd = true;
                                          });
                                          showSnack(context, 'ቀንና ሰዓቱ ከመርሐግብር ተሞልቷል');
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        if (_scheduleId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 16, color: AppColors.maroon),
                                const SizedBox(width: 4),
                                Text('ከተያያዘ የክፍለ-ጊዜ መርሐግብር ጋር ተገናኝቷል (#$_scheduleId)', style: context.sans(11, color: AppColors.maroon, weight: FontWeight.w600)),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => setState(() => _scheduleId = null),
                                  child: const Text('አላቅቅ', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (widget.programId != null && _recurrence != 'once')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.event_busy_rounded),
                          label: Text(l.manageOccurrences),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProgramOccurrencesScreen(programId: widget.programId!))),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: InputDecoration(labelText: l.status),
                      items: [
                        for (final s in ['draft', 'published', 'completed', 'cancelled']) DropdownMenuItem(value: s, child: Text(statusLabel(l, s))),
                      ],
                      onChanged: (x) => setState(() => _status = x!),
                    ),
                    SectionHeader(title: l.reminderSettings),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm_on_rounded, size: 18, color: AppColors.gold),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(l.programReminderTimesHint, style: context.sans(12, color: context.palette.muted)),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(l.reminderEnabled), value: _reminder, onChanged: (x) => setState(() => _reminder = x)),
                    // Every 15 calendar days while the program runs (stops when it is cancelled,
                    // completed or over); the start date defaults to the program start or today.
                    SwitchListTile(
                      key: const ValueKey('program-interval-15'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.event_repeat_rounded, color: AppColors.gold),
                      title: Text(l.remindEvery15Days),
                      subtitle: Text(l.remindEvery15DaysHint),
                      value: _intervalDays != null,
                      onChanged: (x) => setState(() => _intervalDays = x ? 15 : null),
                    ),
                    if (_intervalDays != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DateTimeField(
                          label: l.remindEvery15DaysFrom,
                          value: _intervalStart,
                          withTime: false,
                          clearable: true,
                          onChanged: (d) => setState(() => _intervalStart = d),
                        ),
                      ),
                    if (_reminder) ...[
                      if (ref.watch(currentUserProvider)?.can('programs.reminders_enforce') ?? (ref.watch(currentUserProvider)?.isAdmin ?? false))
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.lock_clock_rounded, color: AppColors.maroon),
                          title: const Text('አስገዳጅ ማንቂያ (Mandatory Reminder)'),
                          subtitle: const Text('ይህ ሲበራ አባላት ማንቂያውን ማጥፋት አይችሉም፤ ማንቂያው በግዴታ ይሰራል'),
                          value: _isMandatoryReminder,
                          onChanged: (x) => setState(() => _isMandatoryReminder = x),
                        ),
                      // Reminder times of the program: 2 days / 1 day / 6 hours / 1 hour before.
                      Text(l.programReminderTimes, style: context.sans(13, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        for (final o in Program.reminderChoices)
                          FilterChip(
                            key: ValueKey('program-offset-$o'),
                            label: Text(remindBeforeText(l, o)),
                            selected: _offsets.contains(o),
                            onSelected: (x) => setState(() => x ? _offsets.add(o) : _offsets.remove(o)),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remTitle,
                        validator: (s) => v.text(s, max: 255, optional: true),
                        decoration: InputDecoration(labelText: l.reminderTitleLabel),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remBody,
                        maxLines: 3,
                        validator: (s) => v.text(s, max: 1000, optional: true),
                        decoration: InputDecoration(labelText: l.reminderBodyLabel),
                      ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText(l, _error!), style: const TextStyle(color: AppColors.danger)),
                      ),
                    const SizedBox(height: 14),
                    Row(children: [
                      if (widget.programId != null) ...[
                        OutlinedButton.icon(
                          key: const ValueKey('delete-program-btn'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text(l.delete),
                          onPressed: _saving ? null : () async {
                            if (!await showConfirm(context, l.deleteConfirm, destructive: true) || !context.mounted) return;
                            final ok = await runWithProgress(context, () async {
                              await _repo.deleteProgram(widget.programId!);
                              return true;
                            }, success: l.deleted);
                            if (ok == true && context.mounted) {
                              _draft.clear();
                              Navigator.pop(context, true);
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(l.save),
                        ),
                      ),
                    ]),
                    const DraftHint(),
                    const SizedBox(height: 16),
                    ImageUploadTile(
                      label: l.coverImage,
                      url: _program?.imageUrl,
                      enabled: _program != null,
                      onUpload: (p) async {
                        final pr = await repo.uploadProgramImage(_program!.id, p);
                        setState(() => _apply(pr));
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// =============================================================================
class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({super.key, required this.programId});
  final int programId;
  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  final _ctrl = PagedListController<Json>();
  String _q = '';

  Future<void> _invite() async {
    final l = context.l10n;
    final sel = await pickUsers(context, title: l.inviteUsers);
    if (sel == null || sel.isEmpty || !mounted) return;
    var notify = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.bulkConfirm(sel.count)),
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: notify, title: Text(l.notifyInvited), onChanged: (v) => setS(() => notify = v ?? true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runWithProgress(context, () => ref.read(adminRepositoryProvider).addParticipants(widget.programId, sel.toTarget(), notify: notify));
    if (r != null && mounted) {
      showSnack(context, l.invitedResult(asIntOr(r['added'])));
      await _ctrl.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(adminRepositoryProvider);
    return AdminScaffold(
      title: l.participants,
      fab: FloatingActionButton.extended(onPressed: _invite, icon: const Icon(Icons.group_add_rounded), label: Text(l.inviteUsers)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          Expanded(
            child: PagedListView<Json>(
              key: ValueKey(_q),
              controller: _ctrl,
              fetch: (page) => repo.participants(widget.programId, q: _q.isEmpty ? null : _q, page: page),
              emptyMessage: l.noResults,
              itemBuilder: (context, p, _) => TrackTile(
                title: '${p['full_name']}',
                subtitle: [
                  if (p['member_id'] != null) '${p['member_id']}',
                  '${p['phone']}',
                  p['status'] == 'registered' ? l.registered : l.invited,
                  if (p['attendance_status'] != null) attendanceLabel(context, '${p['attendance_status']}'),
                ].join(' · '),
                leading: const ListThumb(icon: Icons.person_outline_rounded),
                trailing: IconButton(
                  tooltip: l.removeParticipant,
                  icon: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
                  onPressed: () async {
                    if (!await showConfirm(context, l.removeParticipant, destructive: true) || !context.mounted) return;
                    await runWithProgress(context, () => repo.removeParticipant(widget.programId, asIntOr(p['user_id'])));
                    await _ctrl.refresh();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
/// Attendance of one program occurrence. The occurrence's session has ONE taker, assigned by HR.
/// It becomes available 15 minutes before the scheduled start; the taker presses Start (the
/// official start) and records each member — QR or manual, always with the member's signature
/// unless HR exempted their group — and it ends when the taker presses End or at the scheduled end.
/// Afterwards only corrections change it. Works offline: Start, the records (signatures kept
/// encrypted) and End wait on the phone and sync with their capture times; what the server cannot
/// apply as captured goes to HR for review, never lost.
class AttendanceRosterScreen extends ConsumerStatefulWidget {
  const AttendanceRosterScreen({super.key, required this.programId, this.initialSource});
  final int programId;

  /// 'all' to list every user (walk-ins / programs without registration).
  final String? initialSource;
  @override
  ConsumerState<AttendanceRosterScreen> createState() => _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState extends ConsumerState<AttendanceRosterScreen> {
  final _ctrl = PagedListController<Json>();
  String _q = '';
  late String _source = widget.initialSource == 'all' ? 'all' : 'participants';
  String? _status;
  final _selected = <int>{};
  Json _summary = const {};
  Json _occurrence = const {};

  /// The occurrence's session as known now (server, or the phone's offline Start / End on top).
  Json? _session;
  List<String> _exempt = const [];

  /// Server clock − phone clock, from the last server answer (availability / elapsed use it).
  Duration _skew = Duration.zero;
  Timer? _tick;

  /// Occurrence being marked (YYYY-MM-DD); null = today's / the latest one (server default).
  String? _date;

  // Takers record Attended (signed) or a permission (Excused, reason required). Unmarked members
  // count as Absent once the session has ended. There is no "late".
  static const _filters = ['unmarked', 'present', 'excused', 'absent'];

  @override
  void initState() {
    super.initState();
    // Elapsed time / "opens in" update every second while the screen is open.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _session != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  DateTime get _now => DateTime.now().add(_skew);
  String? get _occDate => _date ?? asStr(_occurrence['date']);
  int? get _myId => ref.read(currentUserProvider)?.id;

  int? get _takerId {
    final s = _session;
    if (s == null) return null;
    if (s['taker'] is Map) return asIntOr((s['taker'] as Map)['id']);
    return s['taker_id'] == null ? null : asIntOr(s['taker_id']);
  }

  String? get _takerName => _session?['taker'] is Map ? asStr((_session!['taker'] as Map)['full_name']) : null;
  bool get _isTaker => _takerId != null && _takerId == _myId;
  String get _sStatus => asStr(_session?['status']) ?? 'scheduled';
  DateTime? _time(String sessionKey, String occurrenceKey) => DateTime.tryParse(asStr(_session?[sessionKey]) ?? asStr(_occurrence[occurrenceKey]) ?? '')?.toLocal();
  DateTime? get _scheduledStart => _time('scheduled_start', 'starts_at');
  DateTime? get _scheduledEnd => _time('scheduled_end', 'ends_at');
  DateTime? get _availableFrom => DateTime.tryParse(asStr(_session?['available_from']) ?? '')?.toLocal() ?? _scheduledStart?.subtract(const Duration(minutes: 15));
  DateTime? get _startedAt => DateTime.tryParse(asStr(_session?['started_at']) ?? '')?.toLocal();
  DateTime? get _endedAt => DateTime.tryParse(asStr(_session?['ended_at']) ?? '')?.toLocal();
  bool get _pastEnd => _scheduledEnd != null && !_now.isBefore(_scheduledEnd!);
  bool get _running => _sStatus == 'active' && !_pastEnd;
  bool get _ended => _sStatus == 'ended' || _sStatus == 'cancelled' || (_sStatus == 'active' && _pastEnd);
  bool get _canMark => _isTaker && _running;
  bool get _canStart => _isTaker && _sStatus == 'scheduled' && _availableFrom != null && !_now.isBefore(_availableFrom!) && !_pastEnd;
  bool get _canEnd => _running && (_isTaker || (ref.read(currentUserProvider)?.can(Perm.attendanceClose) ?? false));
  bool get _canAssign => (ref.read(currentUserProvider)?.can(Perm.attendanceAssign) ?? false) && !_ended;

  /// The roster page with the session worked out (server copy, the phone's offline Start / End,
  /// clock skew) and marks still waiting in the offline queue shown on top.
  Future<Paged<Json>> _fetch(int page) async {
    final res = await ref.read(adminRepositoryProvider).roster(widget.programId, source: _source, status: _status, q: _q.isEmpty ? null : _q, date: _date, page: page);
    final meta = res.meta;
    final pack = ref.read(offlinePackProvider);
    final occ = asJson(meta['occurrence']);
    final date = asStr(occ['date']);
    var session = meta['session'] is Map ? asJson(meta['session']) : null;
    final local = date == null ? null : await pack.localSession(widget.programId, date);
    if (meta['offline'] == true) {
      // Offline: the pack's copy of the session may be newer than the cached roster.
      session = mergeSession(session ?? (date == null ? null : await pack.session(widget.programId, date)), local);
      _exempt = await pack.signatureExemptGroups();
    } else {
      final serverTime = DateTime.tryParse(asStr(session?['server_time']) ?? '');
      if (serverTime != null) _skew = serverTime.difference(DateTime.now());
      _exempt = asValues(asJson(meta['signature_policy'])['exempt_groups'], (e) => '$e');
      if (local != null && date != null) {
        // The server has caught up with this phone's offline Start / End once its state is as far.
        const rank = {'scheduled': 0, 'active': 1, 'ended': 2, 'cancelled': 3};
        if ((rank[session?['status']] ?? 0) >= (rank[local['status']] ?? 0)) {
          await pack.clearLocalSession(widget.programId, date);
        } else {
          session = mergeSession(session, local);
        }
      }
    }
    _session = session;
    return _withPending(res);
  }

  /// Show marks still waiting in the offline queue on top of the (possibly cached) roster.
  Future<Paged<Json>> _withPending(Paged<Json> page) async {
    final sync = ref.read(syncServiceProvider);
    final date = _date ?? asStr(page.meta['occurrence'] is Map ? (page.meta['occurrence'] as Map)['date'] : null);
    final pending = <int, Json>{};
    for (final type in [SyncOp.attendanceSet, SyncOp.attendanceRecord, SyncOp.attendanceClear]) {
      for (final p in await sync.pending(type)) {
        if (asIntOr(p['program_id']) == widget.programId && asStr(p['date']) == date) pending[asIntOr(p['user_id'])] = {...p, '_clear': type == SyncOp.attendanceClear};
      }
    }
    for (final p in await sync.pending(SyncOp.attendanceBulk)) {
      if (asIntOr(p['program_id']) != widget.programId || asStr(p['date']) != date) continue;
      for (final uid in asValues(p['user_ids'], (e) => asIntOr(e))) {
        pending[uid] = {'status': p['status']};
      }
    }
    if (pending.isEmpty) return page;
    final items = [
      for (final r in page.items)
        if (pending[asIntOr(r['user_id'])] case final p?)
          {
            ...r,
            'status': p['_clear'] == true ? 'unmarked' : (p['status'] == 'late' ? 'present' : p['status']),
            'marked': p['_clear'] != true,
            'signed': p['signature'] != null,
            'pending': true,
          }
        else
          r,
    ];
    return Paged(items: items, page: page.page, pages: page.pages, total: page.total, meta: page.meta);
  }

  void _outcomeSnack(SyncOutcome out, {required String done}) {
    final l = context.l10n;
    if (out.rejected) {
      showSnack(context, errorText(l, ApiException(code: out.code ?? ApiException.unknown)));
    } else if (out.conflict) {
      showSnack(context, l.attSentToHr);
    } else if (out.queued) {
      showSnack(context, l.savedOffline);
    } else {
      final srv = out.server is Map ? asJson(out.server) : const <String, dynamic>{};
      showSnack(context, srv['duplicate'] == true ? l.attAlreadyRecorded : done);
    }
  }

  // ---------------------------------------------------------------- session: Start / End / taker

  Future<void> _start() async {
    final l = context.l10n;
    final date = _occDate;
    if (date == null) return;
    final uuid = const Uuid().v4();
    final out = await runWithProgress(
      context,
      () => ref.read(syncServiceProvider).submit(SyncOp.attendanceSessionStart, {'program_id': widget.programId, 'date': date, 'session_uuid': uuid}),
    );
    if (out == null || !mounted) return;
    if (out.queued) {
      // Offline: the phone's clock is the official start until the server confirms it.
      await ref.read(offlinePackProvider).saveLocalSession(widget.programId, date, {
        'status': 'active',
        'started_at': _now.toUtc().toIso8601String(),
        'start_source': 'offline',
        'client_uuid': uuid,
      });
    }
    if (!mounted) return;
    _outcomeSnack(out, done: l.attSessionStartedSnack);
    await _ctrl.refresh();
  }

  Future<void> _end() async {
    final l = context.l10n;
    final date = _occDate;
    if (date == null) return;
    if (!await showConfirm(context, l.attEndConfirm, destructive: true) || !mounted) return;
    final out = await runWithProgress(
      context,
      () => ref.read(syncServiceProvider).submit(SyncOp.attendanceSessionEnd, {'program_id': widget.programId, 'date': date}),
    );
    if (out == null || !mounted) return;
    if (out.queued) {
      final pack = ref.read(offlinePackProvider);
      await pack.saveLocalSession(widget.programId, date, {
        ...?await pack.localSession(widget.programId, date),
        'status': 'ended',
        'ended_at': _now.toUtc().toIso8601String(),
      });
    }
    if (!mounted) return;
    _outcomeSnack(out, done: l.attSessionEndedSnack);
    await _ctrl.refresh();
  }

  /// HR: who takes this occurrence (a substitute while it runs needs a reason, kept in the log).
  Future<void> _assign() async {
    final l = context.l10n;
    final sel = await pickUsers(context, title: l.attChangeTaker, multiple: false);
    if (sel == null || sel.ids.isEmpty || !mounted) return;
    String? reason;
    if (_running) {
      reason = await promptText(context, title: l.attSubstituteReason, label: l.reason, maxLines: 2, required: true);
      if (reason == null || reason.trim().isEmpty || !mounted) return;
    }
    final r = await runWithProgress(
      context,
      () => ref.read(stageRepositoryProvider).assignSessionTaker(widget.programId, _occDate, sel.ids.first, reason: reason?.trim()),
      success: l.saved,
    );
    if (r != null) await _ctrl.refresh();
  }

  // ---------------------------------------------------------------- recording

  /// Attended: the member signs first (unless their group is exempt) — nothing is recorded without
  /// it. Goes through the offline queue (never lost, never doubled).
  Future<void> _recordPresent({required int uid, required String name, String? group, required String via, String? date}) async {
    final l = context.l10n;
    date ??= _occDate;
    if (date == null) return;
    String? signature;
    if (!_exempt.contains(group)) {
      signature = await captureSignature(context, name: name);
      if (signature == null || !mounted) {
        if (mounted) showSnack(context, l.errSignatureRequired);
        return;
      }
    }
    final out = await ref.read(syncServiceProvider).submit(SyncOp.attendanceRecord, {
      'program_id': widget.programId,
      'user_id': uid,
      'date': date,
      'status': 'present',
      'via': via,
      'signature': ?signature,
      'session_uuid': ?asStr(_session?['client_uuid']),
    });
    if (!mounted) return;
    _outcomeSnack(out, done: l.attendanceSaved);
    await _ctrl.refresh();
  }

  Future<void> _mark(Json row, String status) async {
    final l = context.l10n;
    final uid = asIntOr(row['user_id']);
    final date = _occDate;
    if (date == null) return;
    // Tapping the chosen mark again removes it (while the session runs; reason kept).
    if (row['marked'] == true && row['status'] == status) {
      final reason = await promptText(context, title: l.attRemoveReason, label: l.reason, maxLines: 2, required: true);
      if (reason == null || reason.trim().isEmpty || !mounted) return;
      final out = await ref.read(syncServiceProvider).submit(SyncOp.attendanceClear, {'program_id': widget.programId, 'user_id': uid, 'date': date, 'reason': reason.trim()});
      if (!mounted) return;
      _outcomeSnack(out, done: l.attendanceCleared);
      await _ctrl.refresh();
      return;
    }
    if (status == 'present') {
      return _recordPresent(uid: uid, name: '${row['full_name']}', group: asStr(row['member_group']), via: 'manual', date: date);
    }
    final reason = await promptText(context, title: l.attPermissionReason, label: l.reason, maxLines: 2, required: true);
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    final out = await ref.read(syncServiceProvider).submit(SyncOp.attendanceRecord, {
      'program_id': widget.programId,
      'user_id': uid,
      'date': date,
      'status': 'excused',
      'notes': reason.trim(),
      'via': 'manual',
    });
    if (!mounted) return;
    _outcomeSnack(out, done: l.attendanceSaved);
    await _ctrl.refresh();
  }

  /// Choose which occurrence (date) to mark — recurring programs have many.
  Future<void> _pickDate() async {
    final l = context.l10n;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final now = DateTime.now();
    final list = await runWithProgress(
      context,
      () => ref.read(adminRepositoryProvider).occurrences(
            widget.programId,
            from: Formatters.isoDate(now.subtract(const Duration(days: 120))),
            to: Formatters.isoDate(now.add(const Duration(days: 60))),
          ),
    );
    if (list == null || !mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final o in list.reversed)
            ListTile(
              leading: Icon(o['today'] == true ? Icons.today_rounded : (o['active'] == true ? Icons.event_available_rounded : Icons.event_rounded)),
              title: Text(f.date(Formatters.parseDateOnly(asStr(o['date'])), withWeekday: true)),
              subtitle: o['today'] == true ? Text(l.today) : (o['active'] == true ? null : Text(l.calendarUpcoming)),
              selected: (_date ?? asStr(_occurrence['date'])) == asStr(o['date']),
              onTap: () => Navigator.pop(ctx, asStr(o['date'])),
            ),
        ]),
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Excuse several members at once (reason required). Attended is signed one by one.
  Future<void> _bulkExcuse() async {
    final l = context.l10n;
    final reason = await promptText(context, title: l.attPermissionReason, label: l.reason, maxLines: 2, required: true);
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    final date = _occDate;
    if (date == null) return;
    final out = await runWithProgress(
      context,
      () => ref.read(syncServiceProvider).submit(SyncOp.attendanceBulk, {'program_id': widget.programId, 'user_ids': _selected.toList(), 'status': 'excused', 'date': date, 'notes': reason.trim()}),
    );
    if (out == null || !mounted) return;
    _outcomeSnack(out, done: l.attendanceSaved);
    setState(_selected.clear);
    await _ctrl.refresh();
  }

  /// Scan QR codes one after another: each member is identified (photo, name, member ID, type) and
  /// checked, the taker verifies the person, the member signs, then it is recorded at that moment.
  /// Works offline from the member list kept on the phone; records then sync when back online.
  Future<void> _scan() async {
    for (;;) {
      if (!mounted) return;
      final uuid = await scanMemberQr(context);
      if (uuid == null || !mounted) return;
      if (!await _verifyAndRecord(uuid: uuid, via: 'qr', scanning: true)) return;
    }
  }

  /// Members without a smartphone: search by name / member ID, verify, sign, record (manual).
  Future<void> _findMember() async {
    final uid = await findMemberForAttendance(context, programId: widget.programId);
    if (uid == null || !mounted) return;
    await _verifyAndRecord(userId: uid, via: 'manual');
  }

  /// Returns true to go on scanning.
  Future<bool> _verifyAndRecord({String? uuid, int? userId, required String via, bool scanning = false}) async {
    final info = await runWithProgress(context, () => identifyForAttendance(ref, programId: widget.programId, date: _occDate, uuid: uuid, userId: userId));
    if (info == null || !mounted) return false;
    final action = await showAttendanceVerify(context, info, scanning: scanning);
    if (!mounted) return false;
    if (action == VerifyAction.record) {
      final member = asJson(info['member']);
      await _recordPresent(
        uid: asIntOr(member['id']),
        name: asStr(member['full_name']) ?? '',
        group: info['signature_required'] == false ? null : asStr(member['member_group']),
        via: via,
        date: _occDate ?? asStr(asJson(info['occurrence'])['date']),
      );
      return scanning;
    }
    return action == VerifyAction.next;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final online = ref.watch(isOnlineProvider);
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final me = ref.watch(currentUserProvider);
    final canMark = _canMark;
    final canComment = me?.can(Perm.attendanceCorrectionRequest) ?? false;
    final occDate = Formatters.parseDateOnly(_date ?? asStr(_occurrence['date']));
    return AdminScaffold(
      title: _selected.isEmpty ? l.attendanceRoster : l.selectedCount(_selected.length),
      actions: [
        if (_selected.isNotEmpty) IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_selected.clear)),
        // QR and manual entry work offline too (member list kept on the phone; records sync later).
        if (_selected.isEmpty && canMark) IconButton(key: const ValueKey('att-find'), tooltip: l.attFindMember, icon: const Icon(Icons.person_search_rounded), onPressed: _findMember),
        if (_selected.isEmpty && canMark) IconButton(key: const ValueKey('att-scan'), tooltip: l.attScan, icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: _scan),
      ],
      body: Column(
        children: [
          // Occurrence (date) being marked
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AppCard(
              onTap: _pickDate,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.event_rounded, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(child: Text(occDate == null ? l.occurrenceDate : f.date(occDate, withWeekday: true), style: context.sans(14, weight: FontWeight.w600))),
                Text(l.change, style: context.sans(12, color: p.primary)),
              ]),
            ),
          ),
          if (_session != null || _occurrence.isNotEmpty) _sessionCard(context, f),
          if (!online) _Notice(icon: Icons.cloud_off_rounded, text: l.attendanceOfflineNote),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(label: Text(l.showAllUsers), selected: _source == 'all', onSelected: (v) => setState(() => _source = v ? 'all' : 'participants')),
                const SizedBox(width: 6),
                for (final s in [null, ..._filters])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(label: Text(s == null ? l.all : attendanceLabel(context, s)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
                  ),
              ],
            ),
          ),
          if (_summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill('${l.expectedMembers}: ${asIntOr(_summary['expected'])}'),
                  for (final s in ['present', 'excused', 'absent', 'unmarked'])
                    if (asIntOr(_summary[s]) > 0) Pill('${attendanceLabel(context, s)}: ${asIntOr(_summary[s])}', color: attendanceColor(s)),
                ],
              ),
            ),
          Expanded(
            child: PagedListView<Json>(
              key: ValueKey('$_q|$_source|$_status|$_date'),
              controller: _ctrl,
              fetch: _fetch,
              onPageLoaded: (pg) => setState(() {
                _summary = asJson(pg.meta['summary']);
                _occurrence = asJson(pg.meta['occurrence']);
              }),
              emptyMessage: l.noResults,
              itemBuilder: (context, r, _) {
                final uid = asIntOr(r['user_id']);
                final status = asStr(r['status']);
                final sel = _selected.contains(uid);
                final capturedAt = DateTime.tryParse(asStr(r['attended_at']) ?? '')?.toLocal();
                final elapsed = r['elapsed_seconds'] == null ? null : asIntOr(r['elapsed_seconds']);
                return AppCard(
                  padding: const EdgeInsets.fromLTRB(4, 6, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Checkbox(value: sel, onChanged: canMark ? (v) => setState(() => v == true ? _selected.add(uid) : _selected.remove(uid)) : null),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${r['full_name']}', style: context.serif(15, weight: FontWeight.w600, color: p.text)),
                                Text(
                                  [
                                    if (r['member_id'] != null) '${r['member_id']}',
                                    if (status == 'present' && capturedAt != null) f.time(capturedAt),
                                    if (status == 'present' && elapsed != null) l.attMinutesAfterStart(elapsed ~/ 60),
                                    if (r['notes'] != null) '${r['notes']}',
                                  ].join(' · '),
                                  style: context.sans(12, color: p.muted),
                                ),
                              ],
                            ),
                          ),
                          if (r['pending'] == true) Tooltip(message: l.pendingSync, child: const Icon(Icons.cloud_upload_outlined, size: 18, color: AppColors.goldDark)),
                          if (r['via'] == 'qr') Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.qr_code_rounded, size: 16, color: p.subtle)),
                          if (status == 'present' && r['signed'] == true)
                            Tooltip(message: l.attSigned, child: Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.draw_rounded, size: 16, color: p.subtle))),
                          if (status == 'present' && r['legacy'] == true)
                            Tooltip(message: l.attLegacyMark, child: Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.history_rounded, size: 16, color: p.subtle))),
                          if (status != null && status != 'unmarked') Pill(attendanceLabel(context, status), color: attendanceColor(status)),
                          if (canComment && _ended)
                            PopupMenuButton<String>(
                              onSelected: (_) async {
                                final sent = await requestAttendanceCorrection(context, ref, programId: widget.programId, userId: uid, name: '${r['full_name']}', date: _occDate);
                                if (sent) await _ctrl.refresh();
                              },
                              itemBuilder: (_) => [PopupMenuItem(value: 'correction', child: Text(l.attCorrectionRequest))],
                            ),
                        ],
                      ),
                      if (canMark)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              for (final s in const ['present', 'excused'])
                                ChoiceChip(
                                  key: ValueKey('mark-$s-$uid'),
                                  visualDensity: VisualDensity.compact,
                                  label: Text(s == 'present' ? l.attAttended : attendanceLabel(context, s)),
                                  selected: r['marked'] == true && status == s,
                                  onSelected: (_) => _mark(r, s),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
              separator: const SizedBox(height: 8),
            ),
          ),
          if (_selected.isNotEmpty && canMark)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l.markSelectedAs, style: context.sans(13, weight: FontWeight.w600)),
                    OutlinedButton(onPressed: _bulkExcuse, child: Text(attendanceLabel(context, 'excused'))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Scheduled time, the one taker, and Start / End with the official start and elapsed time.
  Widget _sessionCard(BuildContext context, Formatters f) {
    final l = context.l10n;
    final p = context.palette;
    final start = _scheduledStart;
    final end = _scheduledEnd;
    final started = _startedAt;
    final offlineStart = asStr(_session?['start_source']) == 'offline';
    String line;
    IconData icon;
    if (_sStatus == 'cancelled') {
      icon = Icons.event_busy_rounded;
      line = l.attendanceNotOpen;
    } else if (_ended) {
      icon = Icons.lock_rounded;
      final at = _endedAt ?? end;
      line = asStr(_session?['end_reason']) == 'scheduled_end' || _endedAt == null ? l.attSessionEndedAuto(at == null ? '—' : f.time(at)) : l.attSessionEndedAt(f.time(at!));
    } else if (_running && started != null) {
      icon = Icons.timer_rounded;
      final e = _now.difference(started);
      final mm = e.inMinutes.toString().padLeft(2, '0');
      final ss = (e.inSeconds % 60).toString().padLeft(2, '0');
      line = l.attSessionRunning(f.time(started), e.isNegative ? '00:00' : '$mm:$ss');
    } else if (_availableFrom != null && _now.isBefore(_availableFrom!)) {
      icon = Icons.lock_clock_rounded;
      line = l.attSessionOpensAt(f.time(_availableFrom!));
    } else {
      icon = Icons.play_circle_outline_rounded;
      line = _isTaker ? l.attSessionReady : l.attSessionWaiting;
    }
    final taker = _takerName ?? (_takerId == null ? null : (_isTaker ? l.attYou : '#$_takerId'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AppCard(
        key: const ValueKey('att-session'),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: _running ? AppColors.success : AppColors.goldDark),
            const SizedBox(width: 10),
            Expanded(child: Text(line, key: const ValueKey('att-session-line'), style: context.sans(14, weight: FontWeight.w600))),
          ]),
          const SizedBox(height: 6),
          if (start != null && end != null) Text(l.attSessionScheduled(f.time(start), f.time(end)), style: context.sans(12, color: p.muted)),
          Text(taker == null ? l.attNoTakerAssigned : l.attSessionTaker(taker), style: context.sans(12, color: taker == null ? AppColors.danger : p.muted)),
          if (offlineStart && _running) Text(l.attStartedOffline, style: context.sans(11, color: p.subtle)),
          if (!_isTaker && !_ended && _takerId != null) Text(l.attOnlyTakerRecords, style: context.sans(11, color: p.subtle)),
          if (_canStart || _canEnd || _canAssign) const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (_canStart)
              FilledButton.icon(key: const ValueKey('att-start'), onPressed: _start, icon: const Icon(Icons.play_arrow_rounded), label: Text(l.attStart)),
            if (_canEnd)
              OutlinedButton.icon(key: const ValueKey('att-end'), onPressed: _end, icon: const Icon(Icons.stop_rounded), label: Text(l.attEnd)),
            if (_canAssign && online(ref))
              TextButton.icon(key: const ValueKey('att-assign'), onPressed: _assign, icon: const Icon(Icons.manage_accounts_rounded, size: 18), label: Text(l.attChangeTaker)),
          ]),
        ]),
      ),
    );
  }

  static bool online(WidgetRef ref) => ref.read(isOnlineProvider);
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.goldDark),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.sans(12))),
        ]),
      );
}

/// Program categories (from the admin API, including inactive ones).
final adminProgramCategoriesProvider = FutureProvider.autoDispose<List<ProgramCategory>>((ref) => ref.watch(adminRepositoryProvider).programCategories());

// =============================================================================
/// Compose and send a notification to one/selected/filtered/all users, plus send history.
class SendNotificationScreen extends ConsumerStatefulWidget {
  const SendNotificationScreen({super.key, this.initialTarget, this.resend});
  final BulkTarget? initialTarget;

  /// Resend → edit → change receivers → send: the original notification (from its detail screen).
  final Json? resend;
  @override
  ConsumerState<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

final _notifyDepartmentsProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(orgRepositoryProvider).departments());

class _SendNotificationScreenState extends ConsumerState<SendNotificationScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'announcement';
  String _mode = 'selected'; // selected | department | all
  UserSelection? _selection;
  int? _department;
  Program? _linkProgram;
  bool _email = false;
  final _history = PagedListController<Json>();

  @override
  void initState() {
    super.initState();
    final r = widget.resend;
    if (r != null) {
      _title.text = '${r['title'] ?? ''}';
      _body.text = '${r['body'] ?? ''}';
      _kind = const ['announcement', 'reminder', 'program_info', 'admin_message'].contains(r['kind']) ? '${r['kind']}' : 'announcement';
      _email = (r['channels'] is List) && (r['channels'] as List).contains('email');
    }
    final t = widget.initialTarget;
    if (t != null) {
      _selection = t.all
          ? const UserSelection(allMatching: true)
          : t.filter != null
          ? UserSelection(allMatching: true, filter: t.filter!)
          : UserSelection(ids: t.userIds.toSet());
    }
  }

  Future<void> _send() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    final target = _mode == 'all'
        ? const BulkTarget.everyone()
        : _mode == 'department'
            ? (_department == null ? null : BulkTarget.filter({'department_id': _department}))
            : _selection?.toTarget();
    if (target == null || (_mode == 'selected' && (_selection?.isEmpty ?? true))) {
      showSnack(context, l.errNoRecipients);
      return;
    }
    final repo = ref.read(adminRepositoryProvider);
    final count = await runWithProgress(context, () => repo.previewTarget(target));
    if (count == null || !mounted || !await showConfirm(context, l.sendConfirm(count)) || !mounted) return;
    final r = await runWithProgress(
      context,
      () => repo.sendNotification(
        kind: _kind,
        title: _title.text.trim(),
        body: _body.text.trim(),
        target: target,
        entityType: _linkProgram == null ? (widget.resend?['entity_type'] as String?) : 'program',
        entityId: _linkProgram?.id ?? (widget.resend == null ? null : asInt(widget.resend!['entity_id'])),
        email: _email,
        resendOf: widget.resend == null ? null : asInt(widget.resend!['id']),
      ),
    );
    if (r != null && mounted) {
      showSnack(context, l.sentTo(asIntOr(r['recipients'])));
      if (widget.resend != null) {
        context.pop(true);
        return;
      }
      _title.clear();
      _body.clear();
      await _history.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    final me = ref.watch(currentUserProvider)!;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    return DefaultTabController(
      length: 2,
      child: AdminScaffold(
        title: widget.resend == null ? l.sendNotification : l.resendNotification,
        actions: const [ContextualHelpButton(screenRoute: '/admin/notify')],
        bottom: TabBar(
          tabs: [
            Tab(text: l.send),
            Tab(text: l.history),
          ],
        ),
        body: TabBarView(
          children: [
            Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _kind,
                    decoration: InputDecoration(labelText: l.notificationKind),
                    items: [
                      DropdownMenuItem(value: 'announcement', child: Text(l.kindAnnouncement)),
                      DropdownMenuItem(value: 'reminder', child: Text(l.kindReminder)),
                      DropdownMenuItem(value: 'program_info', child: Text(l.kindProgramInfo)),
                      DropdownMenuItem(value: 'admin_message', child: Text(l.kindAdminMessage)),
                    ],
                    onChanged: (x) => setState(() => _kind = x!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    validator: (s) => v.text(s, max: 255),
                    decoration: InputDecoration(labelText: l.title),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    minLines: 3,
                    maxLines: 8,
                    validator: (s) => v.text(s, max: 2000),
                    decoration: InputDecoration(labelText: l.message, alignLabelWithHint: true),
                  ),
                  SectionHeader(title: l.recipients),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'selected', label: Text(l.targetSelected)),
                      ButtonSegment(value: 'department', label: Text(l.department)),
                      if (me.can(Perm.notificationsSendAll)) ButtonSegment(value: 'all', label: Text(l.targetAll)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  if (_mode == 'department') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _department,
                      decoration: InputDecoration(labelText: l.department),
                      items: [
                        for (final d in ref.watch(_notifyDepartmentsProvider).value ?? const <Json>[])
                          DropdownMenuItem(value: asIntOr(d['id']), child: Text(departmentName(context, d), overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (x) => setState(() => _department = x),
                    ),
                  ],
                  if (_mode == 'selected') ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final sel = await pickUsers(context);
                        if (sel != null) setState(() => _selection = sel);
                      },
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(
                        _selection == null
                            ? l.pickUsers
                            : _selection!.allMatching
                            ? l.allMatchingSelected(_selection!.count)
                            : l.selectedCount(_selection!.count),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.linkTo),
                    subtitle: Text(_linkProgram?.title ?? l.none),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_linkProgram != null) IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _linkProgram = null)),
                        TextButton(
                          onPressed: () async {
                            final p = await pickProgram(context);
                            if (p != null) setState(() => _linkProgram = p);
                          },
                          child: Text(l.programs),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _email,
                    onChanged: (x) => setState(() => _email = x),
                    title: Text(l.alsoByEmail),
                    subtitle: Text(l.alsoByEmailHint),
                    secondary: const Icon(Icons.alternate_email_rounded),
                  ),
                  if (widget.resend != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l.resendNote, style: context.sans(12, color: context.palette.muted)),
                    ),
                  const SizedBox(height: 14),
                  FilledButton.icon(onPressed: _send, icon: const Icon(Icons.send_rounded), label: Text(widget.resend == null ? l.send : l.resendNotification)),
                ],
              ),
            ),
            PagedListView<Json>(
              controller: _history,
              fetch: (page) => ref.read(adminRepositoryProvider).broadcasts(page: page),
              emptyMessage: l.noNotifications,
              itemBuilder: (context, b, _) => TrackTile(
                title: '${b['title']}',
                subtitle: '${b['sender_name'] ?? ''} · ${f.dateTime(asDate(b['created_at']))} · ${l.readOf(asIntOr(b['read_count']), asIntOr(b['recipient_count']))}',
                leading: ListThumb(icon: b['resent_from_id'] != null ? Icons.replay_rounded : Icons.campaign_outlined),
                onTap: () async {
                  final changed = await context.push<bool>('/admin/notify/${b['id']}');
                  if (changed == true) await _history.refresh();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String eventTypeLabel(AppLocalizations l, String? t) => switch (t) {
  'wedding' => l.eventWedding,
  'holiday' => l.eventHoliday,
  'memorial' => l.eventMemorial,
  'celebration' => l.eventCelebration,
  _ => l.eventOther,
};
