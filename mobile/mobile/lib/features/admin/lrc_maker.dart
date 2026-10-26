import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/lrc.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/dialogs.dart';
import 'admin_widgets.dart' show AdminScaffold;

/// The timing being made: per lyric line the moments it is sung, plus where "Next line" goes.
/// When the singers repeat a line (up to [lrcMaxTimesPerLine] times), it gets another time and
/// "Next line" continues after it — the line is never written twice.
class LrcTiming {
  LrcTiming(this.lines) : times = List.generate(lines.length, (_) => <Duration>[]);
  final List<String> lines;
  final List<List<Duration>> times;

  /// The line "Next line" stamps.
  int cursor = 0;
  final _history = <({int line, int cursor})>[];

  Duration? get _last {
    Duration? max;
    for (final l in times) {
      for (final t in l) {
        if (max == null || t > max) max = t;
      }
    }
    return max;
  }

  bool get isEmpty => _history.isEmpty && times.every((t) => t.isEmpty);
  bool get finished => cursor >= lines.length;
  int get timedLines => times.where((t) => t.isNotEmpty).length;
  bool canRepeat(int i) => i >= 0 && i < lines.length && times[i].isNotEmpty && times[i].length < lrcMaxTimesPerLine;

  /// "Next line": the line at the cursor starts now.
  bool next(Duration at) => finished ? false : _stamp(cursor, at);

  /// The singers went back to line [i] (already sung): it starts again now.
  bool repeat(int i, Duration at) => canRepeat(i) && _stamp(i, at);

  bool _stamp(int i, Duration at) {
    if (times[i].length >= lrcMaxTimesPerLine) return false;
    final last = _last;
    // A line never starts before the previous stamp.
    final t = last != null && at < last ? last : at;
    _history.add((line: i, cursor: cursor));
    times[i].add(t);
    cursor = i + 1;
    return true;
  }

  /// Undo the last stamp; returns its time (to seek back a little).
  Duration? undo() {
    if (_history.isEmpty) return null;
    final h = _history.removeLast();
    final t = times[h.line].removeLast();
    cursor = h.cursor;
    return t;
  }

  void clear() {
    for (final t in times) {
      t.clear();
    }
    _history.clear();
    cursor = 0;
  }

  /// Continue an existing .lrc whose lines match the lyrics.
  void load(LrcSheet sheet) {
    if (sheet.isEmpty || sheet.lines.length > lines.length) return;
    for (var i = 0; i < sheet.lines.length; i++) {
      if (sheet.lines[i] != lines[i]) return;
    }
    for (var i = 0; i < sheet.lines.length; i++) {
      times[i].addAll(sheet.times[i].take(lrcMaxTimesPerLine));
    }
    final cues = sheet.cues;
    cursor = cues.isEmpty ? 0 : cues.last.line + 1;
  }

  LrcSheet get sheet => LrcSheet(lines, [for (final t in times) [...t]..sort()]);
}

/// Make time-synced lyrics (.lrc) inside the app: the recording plays and the administrator taps
/// "Next line" the moment each line starts. When a line is sung again, tap it in the list (or
/// "Repeat"): it is timed again instead of being written twice. Undo steps back. Returns the .lrc
/// text (null when left without finishing).
class LrcMakerScreen extends ConsumerStatefulWidget {
  const LrcMakerScreen({super.key, required this.track, required this.lyrics, this.existing});
  final PlayerTrack track;
  final String lyrics;

  /// Current .lrc, to continue from its times.
  final String? existing;

  @override
  ConsumerState<LrcMakerScreen> createState() => _LrcMakerScreenState();
}

class _LrcMakerScreenState extends ConsumerState<LrcMakerScreen> {
  late final _timing = LrcTiming(lyricLines(widget.lyrics))..load(parseLrcSheet(widget.existing));
  final _scroll = ScrollController();

  AudioController get _audio => ref.read(audioProvider.notifier);
  Duration get _pos => ref.read(positionProvider).value ?? Duration.zero;
  List<String> get _lines => _timing.lines;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _audio.playSingle(widget.track));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _stamp() {
    setState(() => _timing.next(_pos));
    _follow();
  }

  void _repeatLine(int i) {
    if (!_timing.canRepeat(i)) {
      if (_timing.times[i].length >= lrcMaxTimesPerLine) showSnack(context, context.l10n.lrcRepeatLimit);
      return;
    }
    setState(() => _timing.repeat(i, _pos));
    _follow();
  }

  /// "Repeat": choose the line the singers went back to.
  Future<void> _pickRepeat() async {
    final l = context.l10n;
    final i = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(l.lrcRepeatPick, style: ctx.sans(14, weight: FontWeight.w700))),
          for (var i = 0; i < _lines.length; i++)
            if (_timing.times[i].isNotEmpty)
              ListTile(
                dense: true,
                enabled: _timing.canRepeat(i),
                title: Text(_lines[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text('×${_timing.times[i].length}'),
                onTap: () => Navigator.pop(ctx, i),
              ),
        ]),
      ),
    );
    if (i != null && mounted) _repeatLine(i);
  }

  void _undo() {
    final last = _timing.undo();
    if (last == null) return;
    final back = last - const Duration(seconds: 2);
    _audio.seek(back.isNegative ? Duration.zero : back);
    setState(() {});
    _follow();
  }

  Future<void> _restart() async {
    if (!_timing.isEmpty && !await showConfirm(context, context.l10n.lrcRestartConfirm, destructive: true)) return;
    setState(_timing.clear);
    await _audio.seek(Duration.zero);
    if (!ref.read(audioProvider).playing) await _audio.toggle();
  }

  void _follow() {
    final i = _timing.cursor;
    if (!_scroll.hasClients) return;
    final target = (i * 44.0 - 120).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _done() => Navigator.of(context).pop(_timing.sheet.write());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final s = ref.watch(audioProvider);
    final pos = ref.watch(positionProvider).value ?? Duration.zero;
    final isMine = s.current?.id == widget.track.id;
    final singing = _timing.sheet.lineAt(pos);
    final finished = _timing.finished;

    return AdminScaffold(
      title: l.lrcMaker,
      actions: [
        TextButton(key: const ValueKey('lrc-done'), onPressed: _timing.isEmpty ? null : _done, child: Text(l.done)),
      ],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('${l.lrcMakerHint}\n${l.lrcRepeatHint}', style: context.sans(12, color: p.muted)),
        ),
        Expanded(
          child: _lines.isEmpty
              ? Center(child: Text(l.lrcNoLyrics, style: context.sans(13, color: p.muted)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _lines.length,
                  itemBuilder: (context, i) {
                    final times = _timing.times[i];
                    final done = times.isNotEmpty;
                    final next = i == _timing.cursor;
                    return InkWell(
                      key: ValueKey('lrc-line-$i'),
                      borderRadius: BorderRadius.circular(8),
                      // Tap a line already sung when the singers go back to it.
                      onTap: done && isMine ? () => _repeatLine(i) : null,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: next ? AppColors.gold.withValues(alpha: 0.18) : (i == singing ? AppColors.maroon.withValues(alpha: 0.10) : null),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          SizedBox(
                            width: 64,
                            child: Text(done ? formatLrcTime(times.last) : '--:--.--', style: context.sans(12, color: done ? AppColors.goldDark : p.subtle)),
                          ),
                          Expanded(
                            child: Text(
                              _lines[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.serif(15, weight: next || i == singing ? FontWeight.w700 : FontWeight.w500, color: done ? p.text : p.muted),
                            ),
                          ),
                          if (times.length > 1) Padding(padding: const EdgeInsets.only(left: 6), child: Text('×${times.length}', style: context.sans(12, weight: FontWeight.w700, color: AppColors.maroon))),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(Formatters.duration(isMine ? pos : Duration.zero), style: context.sans(13, weight: FontWeight.w600)),
                const Spacer(),
                Text(l.lrcProgress('${_timing.timedLines}', '${_lines.length}'), style: context.sans(12, color: p.muted)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                IconButton(tooltip: l.lrcRestart, icon: const Icon(Icons.restart_alt_rounded), onPressed: _restart),
                IconButton(
                  tooltip: l.lrcBack5,
                  icon: const Icon(Icons.replay_5_rounded),
                  onPressed: () {
                    final b = pos - const Duration(seconds: 5);
                    _audio.seek(b.isNegative ? Duration.zero : b);
                  },
                ),
                IconButton(
                  tooltip: s.playing ? l.pause : l.play,
                  icon: Icon(isMine && s.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 36, color: AppColors.maroon),
                  onPressed: () => isMine ? _audio.toggle() : _audio.playSingle(widget.track),
                ),
                IconButton(tooltip: l.lrcUndo, icon: const Icon(Icons.undo_rounded), onPressed: _timing.isEmpty ? null : _undo),
                IconButton(key: const ValueKey('lrc-repeat'), tooltip: l.lrcRepeat, icon: const Icon(Icons.repeat_one_rounded), onPressed: _timing.isEmpty || !isMine ? null : _pickRepeat),
                const SizedBox(width: 4),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('lrc-stamp'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: finished || !isMine ? null : _stamp,
                    child: Text(finished ? l.lrcAllTimed : l.lrcNextLine, textAlign: TextAlign.center),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
