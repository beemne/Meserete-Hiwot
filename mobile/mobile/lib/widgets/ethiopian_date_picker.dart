import 'package:flutter/material.dart';

import '../core/l10n/l10n.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

/// Ethiopian-calendar date picker (13 months, Pagume 5/6 days). Used everywhere a date is
/// chosen; returns the Gregorian [DateTime] (date only) the rest of the app stores.
Future<DateTime?> showEthiopianDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) =>
    showDialog<DateTime>(
      context: context,
      builder: (_) => _EthiopianDatePicker(initial: initialDate, first: DateUtils.dateOnly(firstDate), last: DateUtils.dateOnly(lastDate)),
    );

class _EthiopianDatePicker extends StatefulWidget {
  const _EthiopianDatePicker({required this.initial, required this.first, required this.last});
  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_EthiopianDatePicker> createState() => _EthiopianDatePickerState();
}

class _EthiopianDatePickerState extends State<_EthiopianDatePicker> {
  late EthiopianDate _selected = EthiopianDate.fromGregorian(widget.initial);
  late int _year = _selected.year;
  late int _month = _selected.month;
  bool _pickingYear = false;

  bool _enabled(EthiopianDate e) {
    final g = e.toGregorian();
    return !g.isBefore(widget.first) && !g.isAfter(widget.last);
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    if (m < 1) {
      m = 13;
      y--;
    } else if (m > 13) {
      m = 1;
      y++;
    }
    setState(() {
      _month = m;
      _year = y;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, 'am');
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    final today = EthiopianDate.fromGregorian(DateTime.now());
    final g = _selected.toGregorian();
    final gregorianLabel = MaterialLocalizations.of(context).formatMediumDate(g);

    // Monday-first grid; weekday of the 1st of the visible month.
    final firstWeekday = EthiopianDate(_year, _month, 1).toGregorian().weekday; // 1 = Monday
    final days = EthiopianDate.daysInMonth(_year, _month);
    final weekdayNames = [l.weekday1, l.weekday2, l.weekday3, l.weekday4, l.weekday5, l.weekday6, l.weekday7];

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header: the chosen date in the Ethiopian calendar (Gregorian underneath).
          Container(
            color: AppColors.maroon,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${f.monthName(_selected.month)} ${_selected.day}፣ ${_selected.year}', style: context.serif(22, color: Colors.white)),
              const SizedBox(height: 2),
              Text('${l.calendarEthiopian} · $gregorianLabel', style: context.sans(12, color: AppColors.goldLight)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: _pickingYear ? null : () => _shiftMonth(-1)),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _pickingYear = !_pickingYear),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: Text('${f.monthName(_month)} $_year', overflow: TextOverflow.ellipsis, style: context.sans(15, weight: FontWeight.w700, color: p.text))),
                    Icon(_pickingYear ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: p.muted),
                  ]),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: _pickingYear ? null : () => _shiftMonth(1)),
            ]),
          ),
          SizedBox(
            height: 300,
            child: _pickingYear
                ? _YearList(
                    selected: _year,
                    first: EthiopianDate.fromGregorian(widget.first).year,
                    last: EthiopianDate.fromGregorian(widget.last).year,
                    onPick: (y) => setState(() {
                      _year = y;
                      _pickingYear = false;
                    }),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: [
                      Row(children: [
                        for (final w in weekdayNames)
                          Expanded(
                            child: Center(
                              child: Text(w.characters.take(isAm ? 1 : 2).toString(), style: context.sans(12, weight: FontWeight.w600, color: p.muted)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 7,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 1; i < firstWeekday; i++) const SizedBox.shrink(),
                            for (var d = 1; d <= days; d++)
                              Builder(builder: (context) {
                                final e = EthiopianDate(_year, _month, d);
                                final enabled = _enabled(e);
                                final selected = e == _selected;
                                final isToday = e == today;
                                return Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Material(
                                    color: selected ? AppColors.maroon : Colors.transparent,
                                    shape: CircleBorder(side: isToday && !selected ? const BorderSide(color: AppColors.gold, width: 1.5) : BorderSide.none),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: enabled ? () => setState(() => _selected = e) : null,
                                      child: Center(
                                        child: Text(
                                          '$d',
                                          style: context.sans(14, weight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? Colors.white : (enabled ? p.text : p.faint)),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              TextButton(
                onPressed: () {
                  final t = EthiopianDate.fromGregorian(DateTime.now());
                  setState(() {
                    _year = t.year;
                    _month = t.month;
                    _pickingYear = false;
                    if (_enabled(t)) _selected = t;
                  });
                },
                child: Text(l.todayDate),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
              FilledButton(onPressed: _enabled(_selected) ? () => Navigator.pop(context, _selected.toGregorian()) : null, child: Text(l.ok)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _YearList extends StatefulWidget {
  const _YearList({required this.selected, required this.first, required this.last, required this.onPick});
  final int selected;
  final int first;
  final int last;
  final ValueChanged<int> onPick;
  @override
  State<_YearList> createState() => _YearListState();
}

class _YearListState extends State<_YearList> {
  late final _ctrl = ScrollController(initialScrollOffset: ((widget.selected - widget.first) ~/ 3 - 2).clamp(0, 1 << 20) * 52.0);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final years = [for (var y = widget.first; y <= widget.last; y++) y];
    return GridView.count(
      controller: _ctrl,
      crossAxisCount: 3,
      childAspectRatio: 2.6,
      padding: const EdgeInsets.all(8),
      children: [
        for (final y in years)
          Padding(
            padding: const EdgeInsets.all(4),
            child: y == widget.selected
                ? FilledButton(onPressed: () => widget.onPick(y), child: Text('$y'))
                : OutlinedButton(onPressed: () => widget.onPick(y), child: Text('$y')),
          ),
      ],
    );
  }
}
