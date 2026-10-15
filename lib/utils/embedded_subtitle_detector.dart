import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/foundation.dart';

class EmbeddedSubtitleTrackInfo {
  final int id;
  final String label;
  final String language;

  const EmbeddedSubtitleTrackInfo({
    required this.id,
    required this.label,
    required this.language,
  });
}

class EmbeddedSubtitleDetector {
  /// Detects embedded subtitle tracks in a video file using FFmpeg.
  /// Returns a list of subtitle track information.
  static Future<List<EmbeddedSubtitleTrackInfo>> detectEmbeddedSubtitles(
      String videoPath) async {
    if (kIsWeb) return const [];

    if (kDebugMode) {
      print('🔍 Starting embedded subtitle detection for: $videoPath');
    }

    try {
      final escapedVideoPath = videoPath.replaceAll("'", "'\\''");
      final command = '-i \'$escapedVideoPath\' -map 0:s -c copy -f null - 2>&1';
      if (kDebugMode) {
        print('🔍 Running FFmpeg command: $command');
      }

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (kDebugMode) {
        print('🔍 FFmpeg return code: $returnCode');
      }

      // FFmpeg returns 1 when probing with -f null, which is expected
      // We just need to check the output
      final output = await session.getOutput();
      if (kDebugMode) {
        print('🔍 FFmpeg output length: ${output?.length ?? 0}');
        if (output != null && output.isNotEmpty) {
          print('🔍 FFmpeg output preview: ${output.substring(0, output.length > 500 ? 500 : output.length)}');
        }
      }

      if (output == null || output.isEmpty) return const [];

      // Parse the output to find subtitle streams
      final tracks = <EmbeddedSubtitleTrackInfo>[];
      final lines = output.split('\n');

      for (final line in lines) {
        // Look for subtitle stream lines
        if (line.contains('Subtitle:') || line.contains('Stream #0:s')) {
          if (kDebugMode) {
            print('🔍 Found subtitle line: $line');
          }

          // Try to extract stream index
          final indexMatch = RegExp(r'Stream #0:(\d+)').firstMatch(line);
          final index = indexMatch != null ? int.tryParse(indexMatch.group(1) ?? '') : null;

          if (index != null) {
            // Try to extract language code from format (eng), (ara), etc.
            // The format is like: Stream #0:2(eng): Subtitle
            final langMatch = RegExp(r'Stream #0:\d+\(([a-z]{2,3})\)').firstMatch(line);
            String languageCode = '';
            if (langMatch != null) {
              languageCode = langMatch.group(1) ?? '';
            }

            if (kDebugMode) {
              print('🔍 Extracted language code: $languageCode from line: $line');
            }

            // Expand language code to full name
            String languageName = _expandLanguageCode(languageCode);

            // Try to extract codec name
            final codecMatch = RegExp(r'(\w+)\s+Subtitle').firstMatch(line);
            String label = languageName.isNotEmpty ? languageName : 'Track ${index + 1}';
            if (codecMatch != null && languageName.isEmpty) {
              label = '${codecMatch.group(1)?.toUpperCase() ?? 'SUB'} Track ${index + 1}';
            }

            if (kDebugMode) {
              print('🔍 Parsed subtitle track: $label (index: $index, lang: $languageCode -> $languageName)');
            }

            tracks.add(EmbeddedSubtitleTrackInfo(
              id: index,
              label: label,
              language: languageCode,
            ));
          }
        }
      }

      // Sort tracks by index to ensure correct order
      tracks.sort((a, b) => a.id.compareTo(b.id));

      if (kDebugMode) {
        print('🔍 Final sorted subtitle tracks:');
        for (final track in tracks) {
          print('🔍   - Index ${track.id}: ${track.label} (${track.language})');
        }
      }

      if (kDebugMode) {
        print('🔍 Total embedded subtitle tracks detected: ${tracks.length}');
      }

      return tracks;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error detecting embedded subtitles: $e');
        print('❌ Stack trace: $stackTrace');
      }
      return const [];
    }
  }

  /// Extracts embedded subtitle track to a temporary SRT file.
  /// Returns the path to the extracted file or null on failure.
  static Future<String?> extractSubtitleToSrt(
      String videoPath, int streamIndex) async {
    if (kIsWeb) return null;

    if (kDebugMode) {
      print('🔍 Extracting subtitle stream $streamIndex from: $videoPath');
    }

    try {
      final dir = Directory.systemTemp;
      if (!await dir.exists()) {
        dir.createSync();
      }

      final tempFile = File(
          '${dir.path}/subtitle_${DateTime.now().millisecondsSinceEpoch}.srt');

      // Use FFmpeg to extract the subtitle stream to SRT format
      // Map the exact stream by absolute index $streamIndex
      final escapedVideoPath = videoPath.replaceAll("'", "'\\''");
      final escapedTempPath = tempFile.path.replaceAll("'", "'\\''");
      final command =
          '-i \'$escapedVideoPath\' -map 0:$streamIndex -c:s srt -y \'$escapedTempPath\'';

      if (kDebugMode) {
        print('🔍 Running extraction command: $command');
      }

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (kDebugMode) {
        print('🔍 Extraction return code: $returnCode');
        print('🔍 Temp file exists: ${await tempFile.exists()}');
      }

      if (returnCode?.isValueSuccess() == true && await tempFile.exists()) {
        if (kDebugMode) {
          print('🔍 Successfully extracted subtitle to: ${tempFile.path}');
        }
        return tempFile.path;
      }

      // Clean up on failure
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error extracting subtitle: $e');
        print('❌ Stack trace: $stackTrace');
      }
      return null;
    }
  }

  /// Expand language code to full language name
  static String _expandLanguageCode(String code) {
    if (code.isEmpty) return '';
    const t = {
      'en': 'English', 'eng': 'English',
      'ar': 'Arabic', 'ara': 'Arabic',
      'zh': 'Chinese', 'chi': 'Chinese', 'zho': 'Chinese',
      'fr': 'French', 'fra': 'French', 'fre': 'French',
      'de': 'German', 'deu': 'German', 'ger': 'German',
      'id': 'Indonesian', 'ind': 'Indonesian',
      'it': 'Italian', 'ita': 'Italian',
      'pl': 'Polish', 'pol': 'Polish',
      'pt': 'Portuguese', 'por': 'Portuguese',
      'ru': 'Russian', 'rus': 'Russian',
      'es': 'Spanish', 'spa': 'Spanish',
      'th': 'Thai', 'tha': 'Thai',
      'vi': 'Vietnamese', 'vie': 'Vietnamese',
      'ja': 'Japanese', 'jpn': 'Japanese',
      'ko': 'Korean', 'kor': 'Korean',
      'hi': 'Hindi', 'hin': 'Hindi',
      'ta': 'Tamil', 'tam': 'Tamil',
      'te': 'Telugu', 'tel': 'Telugu',
      'ml': 'Malayalam', 'mal': 'Malayalam',
      'tr': 'Turkish', 'tur': 'Turkish',
      'nl': 'Dutch', 'nld': 'Dutch', 'dut': 'Dutch',
      'sv': 'Swedish', 'swe': 'Swedish',
      'no': 'Norwegian', 'nor': 'Norwegian',
      'da': 'Danish', 'dan': 'Danish',
      'fi': 'Finnish', 'fin': 'Finnish',
      'el': 'Greek', 'ell': 'Greek', 'gre': 'Greek',
      'he': 'Hebrew', 'heb': 'Hebrew',
      'cs': 'Czech', 'ces': 'Czech', 'cze': 'Czech',
      'hu': 'Hungarian', 'hun': 'Hungarian',
      'ro': 'Romanian', 'ron': 'Romanian', 'rum': 'Romanian',
      'uk': 'Ukrainian', 'ukr': 'Ukrainian',
      'bg': 'Bulgarian', 'bul': 'Bulgarian',
      'sr': 'Serbian', 'srp': 'Serbian',
      'hr': 'Croatian', 'hrv': 'Croatian',
      'sk': 'Slovak', 'slk': 'Slovak', 'slo': 'Slovak',
      'sl': 'Slovenian', 'slv': 'Slovenian',
      'et': 'Estonian', 'est': 'Estonian',
      'lv': 'Latvian', 'lav': 'Latvian',
      'lt': 'Lithuanian', 'lit': 'Lithuanian',
      'fa': 'Persian', 'fas': 'Persian', 'per': 'Persian',
    };
    return t[code.toLowerCase()] ?? code.toUpperCase();
  }
}
