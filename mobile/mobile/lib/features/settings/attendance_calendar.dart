import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/activity.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/states.dart';
import '../guidance/contextual_help_sheet.dart';

/// Colour, icon and text colour of a calendar state. The colour is never the only signal: every
/// state also has an icon and a label (legend + day sheet).
({Color color, Color onColor, IconData icon}) attendanceStyle(String state) => switch (state) {
      'present' => (color: const Color(0xFF2E7D32), onColor: Colors.white, icon: Icons.check_rounded),
      'late' => (color: const Color(0xFFC0CA33), onColor: const Color(0xFF212121), icon: Icons.schedule_rounded),
      'excused' => (color: const Color(0xFFFDD835), onColor: const Color(0xFF212121), icon: Icons.verified_user_outlined),
      'absent' => (color: const Color(0xFFC62828), onColor: Colors.white, icon: Icons.close_rounded),
      'upcoming' || 'today' => (color: AppColors.gold, onColor: const Color(0xFF212121), icon: Icons.event_rounded),
      _ => (color: Colors.white, onColor: const Color(0xFF424242), icon: Icons.remove_rounded),
    };

String attendanceStateLabel(AppLocalizations l, String state) => switch (state) {
      'present' => l.attPresent,
      'late' => l.attLate,
      'excused' => l.attExcused,
      'absent' => l.attAbsent,
      'upcoming' || 'today' => l.calendarUpcoming,
      _ => l.calendarNoProgram,
    };

/// My attendance: calendar by Ethiopian month, per program category, with statistics.
class AttendanceCalendarScreen extends ConsumerWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(programRepositoryProvider);
    return PatternScaffold(
      appBar: AppBar(
        title: Text(context.l10n.myAttendance),
        actions: const [
          ContextualHelpButton(screenRoute: '/attendance'),
        ],
      ),
      body: AttendanceCalendarView(fetch: (from, to, cat) => repo.myCalendar(from: from, to: to, categoryId: cat)),
    );
  }
}

final programCategoriesProvider = FutureProvider.autoDispose<List<ProgramCategory>>((ref) => ref.watch(programRepositoryProvider).categories());

typedef CalendarFetch = Future<AttendanceCalendar> Function(String from, String to, int? categoryId);

class AttendanceCalendarView extends ConsumerStatefulWidget {
  const AttendanceCalendarView({super.key, required this.fetch, this.showCategories = true});
  final CalendarFetch fetch;

  /// Off for calendars that are not about programs (e.g. class sessions).
  final bool showCategories;

  @override
  ConsumerState<AttendanceCalendarView> createState() => _AttendanceCalendarViewState();
}

class _AttendanceCalendarViewState extends ConsumerState<AttendanceCalendarView> {
  late EthiopianDate _month; // day = 1
  int? _category;
  AttendanceCalendar? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final today = EthiopianDate.fromGregorian(DateTime.now());
    _month = EthiopianDate(today.year, today.month, 1);
    _load();
  }

  int get _days => EthiopianDate.daysInMonth(_month.year, _month.month);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = Formatters.isoDate(_month.toGregorian());
      final to = Formatters.isoDate(EthiopianDate(_month.year, _month.month, _days).toGregorian());
      final d = await widget.fetch(from, to, _category);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int months) {
    var y = _month.year;
    var m = _month.month + months;
    if (m < 1) {
      m = 13;
      y--;
    } else if (m > 13) {
      m = 1;
      y++;
    }
    _month = EthiopianDate(y, m, 1);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final lang = Localizations.localeOf(context).languageCode;
    final f = Formatters(l, lang);
    final cats = widget.showCategories ? (ref.watch(programCategoriesProvider).value ?? const []) : const <ProgramCategory>[];
    final first = _month.toGregorian();
    final lead = first.weekday - 1; // Monday-first grid
    final todayIso = Formatters.isoDate(DateTime.now());

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 32), children: [
        // Category selector
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(l.allCategories), selected: _category == null, onSelected: (_) {
                _category = null;
                _load();
              }),
            ),
            for (final c in cats)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(c.label(lang)), selected: _category == c.id, onSelected: (_) {
                  _category = c.id;
                  _load();
                }),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
          child: Column(children: [
            Row(children: [
              IconButton(tooltip: l.previousMonth, onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Text('${f.monthName(_month.month)} ${_month.year}', textAlign: TextAlign.center, style: context.serif(17))),
              IconButton(tooltip: l.nextMonth, onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      f.weekday(DateTime(2024, 1, 1 + i)).characters.take(lang == 'am' ? 2 : 3).toString(),
                      style: context.sans(11, color: p.muted, weight: FontWeight.w600),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            if (_loading && _data == null)
              const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
            else if (_error != null)
              ErrorView(error: _error!, onRetry: _load)
            else
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                  for (var day = 1; day <= _days; day++)
                    Builder(builder: (context) {
                      final g = EthiopianDate(_month.year, _month.month, day).toGregorian();
                      final iso = Formatters.isoDate(g);
                      final entry = _data?.days[iso];
                      final state = entry?.state ?? 'none';
                      final st = attendanceStyle(state);
                      return _DayCell(
                        day: day,
                        style: st,
                        isToday: iso == todayIso,
                        hasProgram: entry != null,
                        label: '${f.date(g)} · ${attendanceStateLabel(l, state)}',
                        onTap: entry == null ? null : () => _showDay(context, g, entry.entries),
                      );
                    }),
                ],
              ),
          ]),
        ),
        const SizedBox(height: 10),
        const _Legend(),
        if (_data != null) ...[
          const SizedBox(height: 12),
          AttendanceStatsCard(stats: _data!.stats),
        ],
      ]),
    );
  }

  void _showDay(BuildContext context, DateTime day, List<CalendarEntry> entries) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final f = Formatters(l, lang);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text(f.date(day, withWeekday: true), style: ctx.serif(17)),
          const SizedBox(height: 8),
          for (final e in entries)
            Builder(builder: (ctx) {
              final st = attendanceStyle(e.status);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: st.color, child: Icon(st.icon, color: st.onColor, size: 20)),
                title: Text(e.title),
                subtitle: Text([
                  if (e.category != null) e.category!.label(lang),
                  '${f.time(e.startsAt)} – ${f.time(e.endsAt)}',
                  if (e.location != null) e.location!,
                ].join(' · ')),
                trailing: Pill(attendanceStateLabel(l, e.status), color: e.status == 'excused' || e.status == 'late' ? const Color(0xFF6D6B00) : st.color),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/programs/${e.programId}');
                },
              );
            }),
        ]),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.style, required this.isToday, required this.hasProgram, required this.label, this.onTap});
  final int day;
  final ({Color color, Color onColor, IconData icon}) style;
  final bool isToday;
  final bool hasProgram;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: label,
      button: onTap != null,
      child: Material(
        color: style.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isToday ? AppColors.maroon : p.border, width: isToday ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Stack(children: [
            Center(child: Text('$day', style: TextStyle(color: style.onColor, fontWeight: FontWeight.w700, fontSize: 13))),
            if (hasProgram) Positioned(right: 2, bottom: 2, child: Icon(style.icon, size: 11, color: style.onColor)),
          ]),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(spacing: 12, runSpacing: 6, children: [
      for (final s in ['none', 'upcoming', 'present', 'excused', 'absent'])
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: attendanceStyle(s).color, borderRadius: BorderRadius.circular(5), border: Border.all(color: context.palette.border)),
            child: Icon(attendanceStyle(s).icon, size: 12, color: attendanceStyle(s).onColor),
          ),
          const SizedBox(width: 5),
          Text(attendanceStateLabel(l, s), style: context.sans(12)),
        ]),
    ]);
  }
}

/// Totals for the selected period / category (numbers come from the server).
class AttendanceStatsCard extends StatelessWidget {
  const AttendanceStatsCard({super.key, required this.stats});
  final AttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pct = stats.percentage;
    Widget cell(String label, int n, String state) => Expanded(
          child: Column(children: [
            Text('$n', style: context.serif(18, color: state == 'none' ? null : attendanceStyle(state).color == Colors.white ? null : attendanceStyle(state).color)),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(11, color: context.palette.muted)),
          ]),
        );
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Text(l.attendanceStats, style: context.sans(14, weight: FontWeight.w700)),
          const Spacer(),
          if (pct != null) Pill(l.attendanceRate(pct % 1 == 0 ? pct.toInt().toString() : pct.toStringAsFixed(1)), icon: Icons.insights_rounded),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          cell(l.totalPrograms, stats.total, 'none'),
          cell(l.attPresent, stats.attended, 'present'),
          cell(l.attExcused, stats.excused, 'excused'),
          cell(l.attAbsent, stats.absent, 'absent'),
        ]),
      ]),
    );
  }
}
