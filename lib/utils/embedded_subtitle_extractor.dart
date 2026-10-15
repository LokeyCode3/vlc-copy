// This file is retained for sidecar-subtitle discovery only.
// Embedded subtitle track probing and activation is now handled by
// flutter_vlc_player (VlcPlayerController.getSpuTracks / setSpuTrack)
// inside PlayerProvider.
//
// This class is only used if VLC reports zero SPU tracks and a sidecar
// .srt / .vtt / .ass file exists next to the video.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'subtitle_parser.dart';

/// Lightweight model — kept so existing imports in player_provider compile.
class EmbeddedSubtitleTrack {
  final int    streamIndex;
  final String label;
  final String language;
  const EmbeddedSubtitleTrack({
    required this.streamIndex,
    required this.label,
    required this.language,
  });
}

class EmbeddedSubtitleExtractor {
  EmbeddedSubtitleExtractor._();

  static const _exts = ['srt', 'vtt', 'ass', 'ssa'];

  /// Scans for companion sidecar subtitle files next to [videoPath].
  static Future<List<EmbeddedSubtitleTrack>> probeTracks(String videoPath) async {
    if (kIsWeb) return const [];
    final dir    = p.dirname(videoPath);
    final base   = p.basenameWithoutExtension(videoPath);
    final tracks = <EmbeddedSubtitleTrack>[];
    int index    = 0;

    for (final ext in _exts) {
      final f = File(p.join(dir, '$base.$ext'));
      if (await f.exists()) {
        tracks.add(EmbeddedSubtitleTrack(
          streamIndex: index++,
          label: 'Subtitle (.$ext)',
          language: '',
        ));
      }
    }
    return tracks;
  }

  /// Parses the sidecar file at [streamIndex] from the [probeTracks] result.
  static Future<List<SubtitleEntry>> extractTrack(
      String videoPath, int streamIndex) async {
    if (kIsWeb) return const [];
    final dir  = p.dirname(videoPath);
    final base = p.basenameWithoutExtension(videoPath);
    int idx    = 0;
    for (final ext in _exts) {
      final f = File(p.join(dir, '$base.$ext'));
      if (await f.exists()) {
        if (idx == streamIndex) {
          final content = await f.readAsString();
          return SubtitleParser.parse(content, ext);
        }
        idx++;
      }
    }
    return const [];
  }
}
