import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'subtitle_parser.dart';

class MkvSubtitleTrack {
  final int trackNumber;
  final int trackUid;
  final String label;
  final String language;
  final String codec;
  final String name;
  final bool isDefault;
  final bool isForced;
  final bool isSupported;
  final String? unsupportedReason;
  final List<SubtitleEntry> entries;

  const MkvSubtitleTrack({
    required this.trackNumber,
    required this.trackUid,
    required this.label,
    required this.language,
    required this.codec,
    this.name = '',
    this.isDefault = false,
    this.isForced = false,
    this.isSupported = true,
    this.unsupportedReason,
    required this.entries,
  });
}

class _Vint {
  final int value;
  final int length;
  final bool isUnknown;

  const _Vint(this.value, this.length, {this.isUnknown = false});
}

class MkvSubtitleParser {
  /// Reads an EBML Variable-length integer (VINT).
  /// If [mask] is true, strips the leading length marker bit (used for Element Data Sizes).
  /// If [mask] is false, preserves the marker bit (used for Element IDs).
  static _Vint? _readVint(Uint8List data, int offset, {bool mask = true}) {
    if (offset >= data.length) return null;
    final first = data[offset];
    int len = 0;
    int maskVal = 0;
    for (int i = 0; i < 8; i++) {
      if ((first & (0x80 >> i)) != 0) {
        len = i + 1;
        maskVal = 0xFF >> (i + 1);
        break;
      }
    }
    if (len == 0 || offset + len > data.length) return null;

    if (mask) {
      // Check for unknown size (all 1 bits)
      bool allOnes = (first & maskVal) == maskVal;
      int val = first & maskVal;
      for (int i = 1; i < len; i++) {
        if (data[offset + i] != 0xFF) allOnes = false;
        val = (val * 256) + data[offset + i];
      }
      if (allOnes) {
        return _Vint(-1, len, isUnknown: true);
      }
      return _Vint(val, len);
    } else {
      int val = first;
      for (int i = 1; i < len; i++) {
        val = (val * 256) + data[offset + i];
      }
      return _Vint(val, len);
    }
  }

  /// Parses all embedded subtitle tracks and their dialogue entries from MKV file bytes.
  static List<MkvSubtitleTrack> parse(Uint8List data, {int fileSize = 0}) {
    if (data.length < 50) return const [];

    int pos = 0;
    int? segmentStart;
    int? tracksOffset;
    int timecodeScale = 1000000; // default: 1ms = 1,000,000 ns

    // 1. Traverse EBML Root elements to locate Segment (0x18538067)
    while (pos < data.length - 4) {
      final id = _readVint(data, pos, mask: false);
      if (id == null) break;
      pos += id.length;
      final len = _readVint(data, pos, mask: true);
      if (len == null) break;
      pos += len.length;

      if (id.value == 0x1A45DFA3) {
        // EBML Header
        if (len.value > 0) pos += len.value;
      } else if (id.value == 0x18538067) {
        // Segment element found!
        segmentStart = pos;
        if (kDebugMode) {
          print('[Subtitle Debug] Segment found at byte offset: ${pos - id.length - len.length}, payload starts at: $segmentStart (bytes read: ${data.length}, file size: ${fileSize > 0 ? fileSize : data.length})');
        }
        break;
      } else {
        if (len.value > 0 && !len.isUnknown) pos += len.value;
      }
    }

    if (segmentStart == null) {
      if (kDebugMode) print('[Subtitle Debug] Segment element (0x18538067) not found.');
      return const [];
    }

    // 2. Traverse top-level elements inside Segment
    pos = segmentStart;
    final rawTrackHeaders = <int, _TrackHeader>{}; // trackNumber -> header
    int? tracksElementOffset;
    int? tracksElementLen;

    while (pos < data.length - 4) {
      final elemId = _readVint(data, pos, mask: false);
      if (elemId == null) break;
      final idOffset = pos;
      pos += elemId.length;
      final elemLen = _readVint(data, pos, mask: true);
      if (elemLen == null) break;
      pos += elemLen.length;

      final elemEnd = elemLen.isUnknown ? data.length : pos + elemLen.value;

      if (elemId.value == 0x114D9B74) {
        // SeekHead (0x114D9B74)
        int sPos = pos;
        while (sPos < elemEnd && sPos < data.length) {
          final sId = _readVint(data, sPos, mask: false);
          if (sId == null) break;
          sPos += sId.length;
          final sLen = _readVint(data, sPos, mask: true);
          if (sLen == null) break;
          sPos += sLen.length;
          final sEnd = sLen.isUnknown ? elemEnd : sPos + sLen.value;

          if (sId.value == 0x4DBB) {
            // SeekEntry
            int seekIdVal = 0;
            int seekPosVal = 0;
            int inSeekPos = sPos;
            while (inSeekPos < sEnd && inSeekPos < data.length) {
              final fId = _readVint(data, inSeekPos, mask: false);
              if (fId == null) break;
              inSeekPos += fId.length;
              final fLen = _readVint(data, inSeekPos, mask: true);
              if (fLen == null) break;
              inSeekPos += fLen.length;

              if (fId.value == 0x53AB) {
                // SeekID
                int v = 0;
                for (int k = 0; k < fLen.value && (inSeekPos + k) < data.length; k++) {
                  v = (v << 8) | data[inSeekPos + k];
                }
                seekIdVal = v;
              } else if (fId.value == 0x53AC) {
                // SeekPosition
                int v = 0;
                for (int k = 0; k < fLen.value && (inSeekPos + k) < data.length; k++) {
                  v = (v << 8) | data[inSeekPos + k];
                }
                seekPosVal = v;
              }
              inSeekPos += fLen.value;
            }

            if (seekIdVal == 0x1654AE6B) {
              tracksOffset = segmentStart + seekPosVal;
            }
          }
          sPos = sEnd;
        }
        pos = elemEnd;
      } else if (elemId.value == 0x1549A966) {
        // Info (0x1549A966)
        int iPos = pos;
        while (iPos < elemEnd && iPos < data.length) {
          final infoId = _readVint(data, iPos, mask: false);
          if (infoId == null) break;
          iPos += infoId.length;
          final infoLen = _readVint(data, iPos, mask: true);
          if (infoLen == null) break;
          iPos += infoLen.length;
          if (infoId.value == 0x2AD7B1) {
            // TimecodeScale (nanoseconds)
            int v = 0;
            for (int k = 0; k < infoLen.value && (iPos + k) < data.length; k++) {
              v = (v << 8) | data[iPos + k];
            }
            if (v > 0) timecodeScale = v;
          }
          iPos += infoLen.value;
        }
        pos = elemEnd;
      } else if (elemId.value == 0x1654AE6B) {
        // Tracks (0x1654AE6B) directly encountered
        tracksElementOffset = idOffset;
        tracksElementLen = elemLen.value;
        _parseTrackEntries(data, pos, elemEnd, rawTrackHeaders);
        break; // Found Tracks!
      } else if (elemId.value == 0x1F43B675) {
        // Reached Cluster before encountering Tracks directly
        if (tracksOffset != null && tracksOffset < data.length) {
          final tId = _readVint(data, tracksOffset, mask: false);
          if (tId != null && tId.value == 0x1654AE6B) {
            int tPos = tracksOffset + tId.length;
            final tLen = _readVint(data, tPos, mask: true);
            if (tLen != null) {
              tPos += tLen.length;
              final tEnd = tLen.isUnknown ? data.length : tPos + tLen.value;
              tracksElementOffset = tracksOffset;
              tracksElementLen = tLen.value;
              _parseTrackEntries(data, tPos, tEnd, rawTrackHeaders);
              break;
            }
          }
        }
        pos = elemEnd;
      } else {
        // Skip Void (0xEC), CRC-32 (0xBF), etc.
        pos = elemEnd;
      }
    }

    if (rawTrackHeaders.isEmpty && tracksOffset != null && tracksOffset < data.length) {
      final tId = _readVint(data, tracksOffset, mask: false);
      if (tId != null && tId.value == 0x1654AE6B) {
        int tPos = tracksOffset + tId.length;
        final tLen = _readVint(data, tPos, mask: true);
        if (tLen != null) {
          tPos += tLen.length;
          final tEnd = tLen.isUnknown ? data.length : tPos + tLen.value;
          tracksElementOffset = tracksOffset;
          tracksElementLen = tLen.value;
          _parseTrackEntries(data, tPos, tEnd, rawTrackHeaders);
        }
      }
    }

    if (kDebugMode) {
      print('[Subtitle Debug] Tracks element found at byte offset: $tracksElementOffset (length: $tracksElementLen)');
      print('[Subtitle Debug] Parsed ${rawTrackHeaders.length} subtitle TrackEntry elements:');
      for (final h in rawTrackHeaders.values) {
        print('  • TrackEntry: number=${h.trackNumber}, uid=${h.trackUid}, type=17, codec=${h.codec}, language=${h.language}, name="${h.name}", default=${h.isDefault}, forced=${h.isForced}');
      }
    }

    if (rawTrackHeaders.isEmpty) return const [];

    // Map to hold entries per track
    final trackEntries = <int, List<SubtitleEntry>>{};
    for (final k in rawTrackHeaders.keys) {
      trackEntries[k] = [];
    }

    // 3. Scan Clusters (0x1F43B675) for SimpleBlock (0xA3) & BlockGroup (0xA0)
    int cPos = segmentStart;
    while (cPos < data.length - 4) {
      final id = _readVint(data, cPos, mask: false);
      if (id == null) {
        cPos++;
        continue;
      }

      if (id.value == 0x1F43B675) {
        // Cluster
        cPos += id.length;
        final cLen = _readVint(data, cPos, mask: true);
        if (cLen == null) break;
        cPos += cLen.length;
        final clusterEnd = cLen.isUnknown ? data.length : cPos + cLen.value;

        int clusterTimecode = 0;

        int inCPos = cPos;
        while (inCPos < clusterEnd && inCPos < data.length) {
          final subId = _readVint(data, inCPos, mask: false);
          if (subId == null) break;
          inCPos += subId.length;
          final subLen = _readVint(data, inCPos, mask: true);
          if (subLen == null) break;
          inCPos += subLen.length;
          final elemEnd = subLen.isUnknown ? clusterEnd : inCPos + subLen.value;

          if (subId.value == 0xE7) {
            // Cluster Timecode
            int val = 0;
            for (int k = 0; k < subLen.value && (inCPos + k) < data.length; k++) {
              val = (val << 8) | data[inCPos + k];
            }
            clusterTimecode = (val * (timecodeScale / 1000000)).round();
          } else if (subId.value == 0xA3) {
            // SimpleBlock (0xA3)
            final tVint = _readVint(data, inCPos, mask: true);
            if (tVint != null && rawTrackHeaders.containsKey(tVint.value)) {
              int bPos = inCPos + tVint.length;
              if (bPos + 3 <= inCPos + subLen.value) {
                int tCode = (data[bPos] << 8) | data[bPos + 1];
                if (tCode >= 0x8000) tCode -= 0x10000;
                bPos += 3;
                final text = utf8.decode(data.sublist(bPos, inCPos + subLen.value), allowMalformed: true);
                _addSubtitleCue(trackEntries[tVint.value]!, clusterTimecode, tCode, 3000, text);
              }
            }
          } else if (subId.value == 0xA0) {
            // BlockGroup (0xA0)
            int bgPos = inCPos;
            int trackNum = 0;
            int relTime = 0;
            int duration = 3000;
            String text = '';

            while (bgPos < elemEnd && bgPos < data.length) {
              final bgId = _readVint(data, bgPos, mask: false);
              if (bgId == null) break;
              bgPos += bgId.length;
              final bgLen = _readVint(data, bgPos, mask: true);
              if (bgLen == null) break;
              bgPos += bgLen.length;

              if (bgId.value == 0xA1) {
                // Block (0xA1)
                final tVint = _readVint(data, bgPos, mask: true);
                if (tVint != null) {
                  trackNum = tVint.value;
                  int bPos = bgPos + tVint.length;
                  if (bPos + 3 <= bgPos + bgLen.value) {
                    int tCode = (data[bPos] << 8) | data[bPos + 1];
                    if (tCode >= 0x8000) tCode -= 0x10000;
                    relTime = tCode;
                    bPos += 3;
                    text = utf8.decode(data.sublist(bPos, bgPos + bgLen.value), allowMalformed: true);
                  }
                }
              } else if (bgId.value == 0x9B) {
                // BlockDuration (0x9B)
                int val = 0;
                for (int k = 0; k < bgLen.value && (bgPos + k) < data.length; k++) {
                  val = (val << 8) | data[bgPos + k];
                }
                duration = (val * (timecodeScale / 1000000)).round();
              }
              bgPos += bgLen.value;
            }

            if (rawTrackHeaders.containsKey(trackNum) && text.isNotEmpty) {
              _addSubtitleCue(trackEntries[trackNum]!, clusterTimecode, relTime, duration, text);
            }
          }
          inCPos = elemEnd;
        }
        cPos = clusterEnd;
      } else {
        if (id.value == 0x1654AE6B || id.value == 0x114D9B74 || id.value == 0x1549A966) {
          final len = _readVint(data, cPos + id.length, mask: true);
          if (len != null && !len.isUnknown) {
            cPos += id.length + len.length + len.value;
            continue;
          }
        }
        cPos++;
      }
    }

    // 4. Construct MkvSubtitleTrack list handling duplicate languages (e.g. Spanish & Spanish (2))
    final langCounts = <String, int>{};
    for (final h in rawTrackHeaders.values) {
      final code = h.language.toLowerCase();
      langCounts[code] = (langCounts[code] ?? 0) + 1;
    }

    final langCurrentIndex = <String, int>{};
    final result = <MkvSubtitleTrack>[];

    for (final entry in rawTrackHeaders.entries) {
      final h = entry.value;
      final entries = trackEntries[entry.key] ?? [];
      entries.sort((a, b) => a.start.compareTo(b.start));

      final code = h.language.toLowerCase();
      final langName = _expandLang(h.language);
      final count = langCounts[code] ?? 1;
      final curr = (langCurrentIndex[code] ?? 0) + 1;
      langCurrentIndex[code] = curr;

      String label = langName;
      if (h.name.isNotEmpty && !h.name.contains('@')) {
        label = '${h.name} ($langName)';
      } else if (count > 1) {
        label = '$langName ($curr)';
      }

      result.add(MkvSubtitleTrack(
        trackNumber: h.trackNumber,
        trackUid: h.trackUid,
        label: label,
        language: h.language,
        codec: h.codec,
        name: h.name,
        isDefault: h.isDefault,
        isForced: h.isForced,
        isSupported: h.isSupported,
        unsupportedReason: h.unsupportedReason,
        entries: entries,
      ));
    }

    return result;
  }

  static void _parseTrackEntries(Uint8List data, int start, int end, Map<int, _TrackHeader> out) {
    int pos = start;
    while (pos < end && pos < data.length) {
      final id = _readVint(data, pos, mask: false);
      if (id == null) break;
      pos += id.length;
      final len = _readVint(data, pos, mask: true);
      if (len == null) break;
      pos += len.length;
      final entryEnd = pos + len.value;

      if (id.value == 0xAE) {
        // TrackEntry
        int tNum = 0;
        int tUid = 0;
        int tType = 0;
        String codec = '';
        String lang = 'eng';
        String name = '';
        bool flagDefault = true;
        bool flagForced = false;

        int tPos = pos;
        while (tPos < entryEnd && tPos < data.length) {
          final fId = _readVint(data, tPos, mask: false);
          if (fId == null) break;
          tPos += fId.length;
          final fLen = _readVint(data, tPos, mask: true);
          if (fLen == null) break;
          tPos += fLen.length;

          if (fId.value == 0xD7) {
            // TrackNumber
            int v = 0;
            for (int k = 0; k < fLen.value && (tPos + k) < data.length; k++) {
              v = (v << 8) | data[tPos + k];
            }
            tNum = v;
          } else if (fId.value == 0x73C5) {
            // TrackUID
            int v = 0;
            for (int k = 0; k < fLen.value && (tPos + k) < data.length; k++) {
              v = (v << 8) | data[tPos + k];
            }
            tUid = v;
          } else if (fId.value == 0x83) {
            // TrackType (17 = Subtitle)
            int v = 0;
            for (int k = 0; k < fLen.value && (tPos + k) < data.length; k++) {
              v = (v << 8) | data[tPos + k];
            }
            tType = v;
          } else if (fId.value == 0x86) {
            // CodecID
            codec = utf8.decode(data.sublist(tPos, tPos + fLen.value), allowMalformed: true);
          } else if (fId.value == 0x22B59C) {
            // Language
            lang = utf8.decode(data.sublist(tPos, tPos + fLen.value), allowMalformed: true);
          } else if (fId.value == 0x22B59D) {
            // LanguageBCP47
            lang = utf8.decode(data.sublist(tPos, tPos + fLen.value), allowMalformed: true);
          } else if (fId.value == 0x536E) {
            // Name
            name = utf8.decode(data.sublist(tPos, tPos + fLen.value), allowMalformed: true);
          } else if (fId.value == 0x88) {
            // FlagDefault
            flagDefault = data[tPos] != 0;
          } else if (fId.value == 0x55AA) {
            // FlagForced
            flagForced = data[tPos] != 0;
          }
          tPos += fLen.value;
        }

        if (tType == 17 && tNum > 0) {
          final isBitmap = codec.toUpperCase().contains('PGS') ||
              codec.toUpperCase().contains('VOBSUB') ||
              codec.toUpperCase().contains('HDMV');
          out[tNum] = _TrackHeader(
            trackNumber: tNum,
            trackUid: tUid == 0 ? tNum : tUid,
            language: lang.isEmpty ? 'eng' : lang,
            name: name,
            codec: codec.isEmpty ? 'S_TEXT/UTF8' : codec,
            isDefault: flagDefault,
            isForced: flagForced,
            isSupported: !isBitmap,
            unsupportedReason: isBitmap
                ? 'Bitmap subtitle ($codec) requires OCR or video burning'
                : null,
          );
        }
      }
      pos = entryEnd;
    }
  }

  static void _addSubtitleCue(List<SubtitleEntry> out, int clusterTimecode, int relTime, int duration, String text) {
    if (text.isEmpty) return;

    // ASS dialogue format: readOrder,layer,style,name,marginL,marginR,marginV,effect,text
    final parts = text.split(',');
    final cleanText = parts.length >= 9 ? parts.sublist(8).join(',') : text;
    final stripped = cleanText
        .replaceAll(RegExp(r'\{[^}]*\}'), '')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\n', '\n')
        .trim();

    if (stripped.isNotEmpty) {
      final startMs = (clusterTimecode + relTime).clamp(0, 86400000);
      final endMs = startMs + (duration > 0 ? duration : 3000);
      out.add(SubtitleEntry(
        start: Duration(milliseconds: startMs),
        end: Duration(milliseconds: endMs),
        text: stripped,
      ));
    }
  }

  static String _expandLang(String code) {
    const t = {
      'en': 'English', 'eng': 'English',
      'ar': 'Arabic', 'ara': 'Arabic',
      'zh': 'Chinese', 'chi': 'Chinese', 'zho': 'Chinese',
      'fr': 'French', 'fre': 'French', 'fra': 'French',
      'de': 'German', 'ger': 'German', 'deu': 'German',
      'id': 'Indonesian', 'ind': 'Indonesian',
      'it': 'Italian', 'ita': 'Italian',
      'nl': 'Dutch', 'dut': 'Dutch', 'nld': 'Dutch',
      'pl': 'Polish', 'pol': 'Polish',
      'pt': 'Portuguese', 'por': 'Portuguese',
      'ru': 'Russian', 'rus': 'Russian',
      'es': 'Spanish', 'spa': 'Spanish',
      'sv': 'Swedish', 'swe': 'Swedish',
      'th': 'Thai', 'tha': 'Thai',
      'tr': 'Turkish', 'tur': 'Turkish',
      'uk': 'Ukrainian', 'ukr': 'Ukrainian',
      'vi': 'Vietnamese', 'vie': 'Vietnamese',
      'ja': 'Japanese', 'jpn': 'Japanese',
      'ko': 'Korean', 'kor': 'Korean',
      'hi': 'Hindi', 'hin': 'Hindi',
      'ta': 'Tamil', 'tam': 'Tamil',
      'te': 'Telugu', 'tel': 'Telugu',
      'ml': 'Malayalam', 'mal': 'Malayalam',
      'el': 'Greek', 'ell': 'Greek', 'gre': 'Greek',
      'he': 'Hebrew', 'heb': 'Hebrew',
      'cs': 'Czech', 'ces': 'Czech', 'cze': 'Czech',
      'da': 'Danish', 'dan': 'Danish',
      'fi': 'Finnish', 'fin': 'Finnish',
      'hu': 'Hungarian', 'hun': 'Hungarian',
      'no': 'Norwegian', 'nor': 'Norwegian',
      'fa': 'Persian', 'fas': 'Persian', 'per': 'Persian',
    };
    return t[code.toLowerCase()] ?? (code.isEmpty ? 'Unknown' : code.toUpperCase());
  }
}

class _TrackHeader {
  final int trackNumber;
  final int trackUid;
  final String language;
  final String name;
  final String codec;
  final bool isDefault;
  final bool isForced;
  final bool isSupported;
  final String? unsupportedReason;

  const _TrackHeader({
    required this.trackNumber,
    required this.trackUid,
    required this.language,
    required this.name,
    required this.codec,
    required this.isDefault,
    required this.isForced,
    required this.isSupported,
    this.unsupportedReason,
  });
}
