import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/media_item.dart';

class MediaScanner {
  static const _videoExtensions = {
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv',
    '.webm', '.m4v', '.3gp', '.ts', '.m2ts', '.mpeg',
    '.mpg', '.ogv', '.f4v', '.rmvb', '.rm',
  };

  static const _audioExtensions = {
    '.mp3', '.aac', '.flac', '.wav', '.ogg', '.m4a',
    '.wma', '.opus', '.ape', '.aiff', '.alac', '.dsf',
  };

  static bool isVideo(String path) =>
      _videoExtensions.contains(p.extension(path).toLowerCase());

  static bool isAudio(String path) =>
      _audioExtensions.contains(p.extension(path).toLowerCase());

  static bool isMedia(String path) => isVideo(path) || isAudio(path);

  /// Scan a directory recursively for media files, safely skipping restricted folders like Android/data.
  static Future<List<MediaItem>> scanDirectory(String dirPath) async {
    if (kIsWeb) return []; // no filesystem on web
    final rootDir = Directory(dirPath);
    if (!await rootDir.exists()) return [];

    final items = <MediaItem>[];
    final queue = <Directory>[rootDir];
    final visited = <String>{rootDir.path};

    while (queue.isNotEmpty) {
      final currentDir = queue.removeAt(0);
      final dirName = p.basename(currentDir.path);
      // Skip Android system/data/obb directories and hidden folders
      if (dirName.startsWith('.') || dirName == 'Android') {
        continue;
      }

      try {
        await for (final entity in currentDir.list(followLinks: false)) {
          final entityName = p.basename(entity.path);
          if (entityName.startsWith('.')) continue;

          if (entity is File) {
            if (isMedia(entity.path)) {
              final item = await _buildMediaItem(entity.path);
              if (item != null) items.add(item);
            }
          } else if (entity is Directory) {
            if (entityName != 'Android' && !entityName.startsWith('.') && visited.add(entity.path)) {
              queue.add(entity);
            }
          }
        }
      } catch (_) {
        // Individual directory read permission denied (e.g., protected Android folder) — continue to next
        continue;
      }
    }
    return items;
  }

  /// Scan standard media locations on Android or device storage.
  static Future<List<MediaItem>> scanCommonDirectories() async {
    if (kIsWeb) return [];
    final items = <MediaItem>[];
    final existingPaths = <String>{};

    final dirsToScan = <String>[];
    if (Platform.isAndroid) {
      const base = '/storage/emulated/0';
      dirsToScan.addAll([
        '$base/Download',
        '$base/Movies',
        '$base/DCIM',
        '$base/Music',
        '$base/Videos',
        '$base/Documents',
        base,
      ]);
    }

    for (final d in dirsToScan) {
      final dir = Directory(d);
      if (await dir.exists()) {
        final found = await scanDirectory(d);
        for (final item in found) {
          if (existingPaths.add(item.path)) {
            items.add(item);
          }
        }
      }
    }
    return items;
  }

  /// Build a MediaItem from a file path (no metadata extraction without extra native plugins).
  static Future<MediaItem?> buildFromPath(String path) async =>
      _buildMediaItem(path);

  static Future<MediaItem?> _buildMediaItem(String filePath) async {
    if (kIsWeb) return null; // web files use blob URLs, handled separately
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final ext = p.extension(filePath).toLowerCase();
      final type = _videoExtensions.contains(ext) ? MediaType.video : MediaType.audio;
      final name = p.basenameWithoutExtension(filePath);

      return MediaItem(
        id: filePath.hashCode.abs().toString() +
            stat.modified.millisecondsSinceEpoch.toString(),
        path: filePath,
        title: name,
        type: type,
        addedAt: stat.modified,
      );
    } catch (_) {
      return null;
    }
  }
}
