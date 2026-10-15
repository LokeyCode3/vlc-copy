/// Parses subtitle files into a list of timed [SubtitleEntry] objects.
/// Supported formats: SRT, VTT, ASS, SSA, SUB (MicroDVD), SBV, LRC.
library;

class SubtitleEntry {
  final Duration start;
  final Duration end;
  final String   text;
  const SubtitleEntry({required this.start, required this.end, required this.text});
}

class SubtitleParser {
  /// Parse subtitle content from [content] with file extension [ext].
  static List<SubtitleEntry> parse(String content, String ext) {
    final e = ext.toLowerCase().trim();
    switch (e) {
      case 'vtt':          return _parseVtt(content);
      case 'ass':
      case 'ssa':          return _parseAss(content);
      case 'sub':          return _parseSub(content);
      case 'sbv':          return _parseSbv(content);
      case 'lrc':          return _parseLrc(content);
      default:             return _parseSrt(content); // srt + unknown
    }
  }

  // ── SRT ───────────────────────────────────────────────────────────────────────
  static List<SubtitleEntry> _parseSrt(String raw) {
    final entries = <SubtitleEntry>[];
    final text    = _normalise(raw);
    for (final block in text.trim().split(RegExp(r'\n\n+'))) {
      final lines = block.trim().split('\n');
      if (lines.isEmpty) continue;
      int tl = 0;
      if (!lines[0].contains('-->')) tl = 1;
      if (tl >= lines.length) continue;
      final times = lines[tl].split('-->');
      if (times.length != 2) continue;
      final start = _srtTime(times[0].trim());
      final end   = _srtTime(times[1].trim().split(' ').first);
      if (start == null || end == null) continue;
      final body = lines.sublist(tl + 1).join('\n').trim();
      final clean = _stripTags(body);
      if (clean.isEmpty) continue;
      entries.add(SubtitleEntry(start: start, end: end, text: clean));
    }
    return entries;
  }

  // ── VTT ───────────────────────────────────────────────────────────────────────
  static List<SubtitleEntry> _parseVtt(String raw) {
    final entries = <SubtitleEntry>[];
    final text    = _normalise(raw);
    for (final block in text.trim().split(RegExp(r'\n\n+'))) {
      if (block.startsWith('WEBVTT')) continue;
      final lines = block.trim().split('\n');
      if (lines.isEmpty) continue;
      int tl = 0;
      if (!lines[0].contains('-->')) tl = 1;
      if (tl >= lines.length) continue;
      final times = lines[tl].split('-->');
      if (times.length != 2) continue;
      final start = _vttTime(times[0].trim().split(' ').first);
      final end   = _vttTime(times[1].trim().split(' ').first);
      if (start == null || end == null) continue;
      final body  = lines.sublist(tl + 1).join('\n').trim();
      final clean = _stripTags(body);
      if (clean.isEmpty) continue;
      entries.add(SubtitleEntry(start: start, end: end, text: clean));
    }
    return entries;
  }

  // ── ASS / SSA ─────────────────────────────────────────────────────────────────
  // Parses the [Events] section for Dialogue lines.
  static List<SubtitleEntry> _parseAss(String raw) {
    final entries = <SubtitleEntry>[];
    final text    = _normalise(raw);
    final lines   = text.split('\n');

    List<String> format = [];
    bool inEvents = false;

    for (final line in lines) {
      final l = line.trim();
      if (l.toLowerCase() == '[events]') { inEvents = true; continue; }
      if (l.startsWith('[') && inEvents)  { inEvents = false; continue; }
      if (!inEvents) continue;

      if (l.startsWith('Format:')) {
        format = l.substring(7).split(',').map((s) => s.trim().toLowerCase()).toList();
        continue;
      }
      if (!l.startsWith('Dialogue:')) continue;
      if (format.isEmpty) continue;

      // Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Text here
      final parts = l.substring(9).split(',');
      if (parts.length < format.length) continue;

      final startIdx = format.indexOf('start');
      final endIdx   = format.indexOf('end');
      final textIdx  = format.indexOf('text');
      if (startIdx < 0 || endIdx < 0 || textIdx < 0) continue;

      final start = _assTime(parts[startIdx].trim());
      final end   = _assTime(parts[endIdx].trim());
      if (start == null || end == null) continue;

      // Text field may contain commas; rejoin from textIdx onwards
      final rawText = parts.sublist(textIdx).join(',').trim();
      // Strip ASS override tags: {\an8}, {\i1}, etc.
      final clean = rawText.replaceAll(RegExp(r'\{[^}]*\}'), '').replaceAll(r'\N', '\n').trim();
      if (clean.isEmpty) continue;

      entries.add(SubtitleEntry(start: start, end: end, text: clean));
    }
    return entries;
  }

  // ── SUB (MicroDVD) ────────────────────────────────────────────────────────────
  // Format: {startFrame}{endFrame}text|more text
  // Requires frame rate to convert to time; assumes 23.976 fps if unknown.
  static List<SubtitleEntry> _parseSub(String raw) {
    final entries = <SubtitleEntry>[];
    double fps    = 23.976;
    for (final line in _normalise(raw).split('\n')) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final m = RegExp(r'^\{(\d+)\}\{(\d+)\}(.*)$').firstMatch(l);
      if (m == null) continue;
      final sf    = int.tryParse(m.group(1) ?? '') ?? 0;
      final ef    = int.tryParse(m.group(2) ?? '') ?? 0;
      // First entry with {1}{1} may define fps
      if (sf == 1 && ef == 1) {
        fps = double.tryParse(m.group(3) ?? '') ?? fps;
        continue;
      }
      final start = Duration(milliseconds: (sf / fps * 1000).toInt());
      final end   = Duration(milliseconds: (ef / fps * 1000).toInt());
      final text  = _stripTags(m.group(3)!.replaceAll('|', '\n'));
      if (text.isEmpty) continue;
      entries.add(SubtitleEntry(start: start, end: end, text: text));
    }
    return entries;
  }

  // ── SBV (YouTube) ────────────────────────────────────────────────────────────
  // Format: 0:00:01.000,0:00:03.000\nText
  static List<SubtitleEntry> _parseSbv(String raw) {
    final entries = <SubtitleEntry>[];
    final text    = _normalise(raw);
    for (final block in text.trim().split(RegExp(r'\n\n+'))) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;
      final times = lines[0].split(',');
      if (times.length != 2) continue;
      final start = _vttTime(times[0].trim());
      final end   = _vttTime(times[1].trim());
      if (start == null || end == null) continue;
      final body  = lines.sublist(1).join('\n').trim();
      final clean = _stripTags(body);
      if (clean.isEmpty) continue;
      entries.add(SubtitleEntry(start: start, end: end, text: clean));
    }
    return entries;
  }

  // ── LRC (lyrics) ─────────────────────────────────────────────────────────────
  // Format: [mm:ss.xx]Text
  // Treats each lyric line as 3-second subtitle.
  static List<SubtitleEntry> _parseLrc(String raw) {
    final entries  = <SubtitleEntry>[];
    final timeLine = RegExp(r'^\[(\d+):(\d+\.\d+)\](.*)$');
    final lines    = _normalise(raw).split('\n');
    for (final line in lines) {
      final m = timeLine.firstMatch(line.trim());
      if (m == null) continue;
      final min  = int.tryParse(m.group(1) ?? '') ?? 0;
      final secD = double.tryParse(m.group(2) ?? '') ?? 0;
      final sec  = secD.truncate();
      final ms   = ((secD - sec) * 1000).round();
      final start = Duration(minutes: min, seconds: sec, milliseconds: ms);
      final end   = start + const Duration(seconds: 3);
      final text  = m.group(3)!.trim();
      if (text.isEmpty) continue;
      entries.add(SubtitleEntry(start: start, end: end, text: text));
    }
    return entries;
  }

  // ── Time parsers ──────────────────────────────────────────────────────────────

  /// SRT: 00:01:23,456
  static Duration? _srtTime(String s) {
    try {
      final n = s.replaceAll(',', '.');
      final p = n.split(':');
      final h = int.parse(p[0]);
      final m = int.parse(p[1]);
      final sp = p[2].split('.');
      final sc = int.parse(sp[0]);
      final ms = sp.length > 1 ? int.parse(sp[1].padRight(3, '0').substring(0, 3)) : 0;
      return Duration(hours: h, minutes: m, seconds: sc, milliseconds: ms);
    } catch (_) { return null; }
  }

  /// VTT / SBV: 00:01:23.456  or  01:23.456
  static Duration? _vttTime(String s) {
    try {
      final p = s.split(':');
      if (p.length == 2) {
        final m  = int.parse(p[0]);
        final sp = p[1].split('.');
        final sc = int.parse(sp[0]);
        final ms = sp.length > 1 ? int.parse(sp[1].padRight(3, '0').substring(0, 3)) : 0;
        return Duration(minutes: m, seconds: sc, milliseconds: ms);
      }
      final h  = int.parse(p[0]);
      final m  = int.parse(p[1]);
      final sp = p[2].split('.');
      final sc = int.parse(sp[0]);
      final ms = sp.length > 1 ? int.parse(sp[1].padRight(3, '0').substring(0, 3)) : 0;
      return Duration(hours: h, minutes: m, seconds: sc, milliseconds: ms);
    } catch (_) { return null; }
  }

  /// ASS: 0:00:01.00  (h:mm:ss.cs — centiseconds)
  static Duration? _assTime(String s) {
    try {
      final p  = s.split(':');
      final h  = int.parse(p[0]);
      final m  = int.parse(p[1]);
      final sp = p[2].split('.');
      final sc = int.parse(sp[0]);
      final cs = sp.length > 1 ? int.parse(sp[1].padRight(2, '0').substring(0, 2)) : 0;
      return Duration(hours: h, minutes: m, seconds: sc, milliseconds: cs * 10);
    } catch (_) { return null; }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────────

  static String _normalise(String s) =>
      s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  static String _stripTags(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').trim();

  /// Find the subtitle entry active at [pos].
  static SubtitleEntry? entryAt(List<SubtitleEntry> entries, Duration pos) {
    for (final e in entries) {
      if (pos >= e.start && pos <= e.end) return e;
    }
    return null;
  }
}
