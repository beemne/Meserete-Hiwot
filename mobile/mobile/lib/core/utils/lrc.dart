/// Time-synced lyrics in the .lrc format: "[mm:ss.xx] line". Several time tags may share a line
/// ("[00:12.00][01:30.50] chorus"); "[offset:+250]" shifts every line (milliseconds); other tags
/// ([ti:], [ar:] …) are ignored.
class LrcLine {
  const LrcLine(this.time, this.text);
  final Duration time;
  final String text;
}

final _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _offsetTag = RegExp(r'^\s*\[offset:\s*([+-]?\d+)\s*\]', caseSensitive: false);

/// Parsed, time-ordered lines (empty when the text has no time tags).
List<LrcLine> parseLrc(String? text) {
  if (text == null || text.trim().isEmpty) return const [];
  var offset = 0;
  final out = <LrcLine>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final o = _offsetTag.firstMatch(raw);
    if (o != null) {
      offset = int.tryParse(o.group(1)!) ?? 0;
      continue;
    }
    final tags = _timeTag.allMatches(raw).toList();
    if (tags.isEmpty) continue;
    final lyric = raw.substring(tags.last.end).trim();
    for (final t in tags) {
      final frac = t.group(3);
      final ms = frac == null ? 0 : int.parse(frac.padRight(3, '0').substring(0, 3));
      final at = Duration(minutes: int.parse(t.group(1)!), seconds: int.parse(t.group(2)!), milliseconds: ms) - Duration(milliseconds: offset);
      out.add(LrcLine(at.isNegative ? Duration.zero : at, lyric));
    }
  }
  out.sort((a, b) => a.time.compareTo(b.time));
  return out;
}

/// The index of the line being sung at [position] (-1 before the first line).
int currentLrcLine(List<LrcLine> lines, Duration position) {
  var lo = 0, hi = lines.length - 1, found = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].time <= position) {
      found = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return found;
}

String formatLrcTime(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  final cs = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
  return '$m:$s.$cs';
}

/// .lrc text from timed lines (with an optional title tag).
String writeLrc(List<LrcLine> lines, {String? title}) => [
      if (title != null && title.isNotEmpty) '[ti:$title]',
      for (final l in lines) '[${formatLrcTime(l.time)}]${l.text}',
    ].join('\n');

/// The plain lines of lyrics to time (blank lines dropped).
List<String> lyricLines(String lyrics) => lyrics.split(RegExp(r'\r?\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

/// Most times one line may be sung (the first time + repeats).
const lrcMaxTimesPerLine = 3;

/// Synced lyrics as the singers see them: every line once, in order, with all the moments it is
/// sung. A repeated line ("[00:12.00][01:30.50] chorus") is shown once and the highlight goes back
/// to it — the line is never listed again.
class LrcSheet {
  const LrcSheet(this.lines, this.times);
  final List<String> lines;

  /// times[i] = when line i is sung (ascending; 1..[lrcMaxTimesPerLine] for a timed line).
  final List<List<Duration>> times;

  bool get isEmpty => lines.isEmpty;

  /// (time, line) pairs in time order.
  List<({Duration time, int line})> get cues {
    final out = [for (var i = 0; i < lines.length; i++) for (final t in times[i]) (time: t, line: i)];
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }

  /// The line being sung at [position] (-1 before the first line).
  int lineAt(Duration position) {
    var line = -1;
    for (final c in cues) {
      if (c.time > position) break;
      line = c.line;
    }
    return line;
  }

  /// Where tapping line [i] seeks: its next singing after [position], else its first one.
  Duration? seekFor(int i, Duration position) {
    if (i < 0 || i >= times.length || times[i].isEmpty) return null;
    return times[i].firstWhere((t) => t > position, orElse: () => times[i].first);
  }

  String write({String? title}) => [
        if (title != null && title.isNotEmpty) '[ti:$title]',
        for (var i = 0; i < lines.length; i++)
          if (times[i].isNotEmpty) '${times[i].map((t) => '[${formatLrcTime(t)}]').join()}${lines[i]}',
      ].join('\n');
}

/// Parse .lrc keeping each line once with all its time tags (lines without tags are dropped).
LrcSheet parseLrcSheet(String? text) {
  if (text == null || text.trim().isEmpty) return const LrcSheet([], []);
  var offset = 0;
  final lines = <String>[];
  final times = <List<Duration>>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final o = _offsetTag.firstMatch(raw);
    if (o != null) {
      offset = int.tryParse(o.group(1)!) ?? 0;
      continue;
    }
    final tags = _timeTag.allMatches(raw).toList();
    if (tags.isEmpty) continue;
    final ts = <Duration>[];
    for (final t in tags) {
      final frac = t.group(3);
      final ms = frac == null ? 0 : int.parse(frac.padRight(3, '0').substring(0, 3));
      final at = Duration(minutes: int.parse(t.group(1)!), seconds: int.parse(t.group(2)!), milliseconds: ms) - Duration(milliseconds: offset);
      ts.add(at.isNegative ? Duration.zero : at);
    }
    ts.sort();
    lines.add(raw.substring(tags.last.end).trim());
    times.add(ts);
  }
  return LrcSheet(lines, times);
}
