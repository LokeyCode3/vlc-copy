import 'dart:io';
import 'package:flutter/foundation.dart';

enum MediaType { video, audio }

class MediaItem {
  final String id;
  final String path;
  final String title;
  final String? artist;
  final String? album;
  final String? thumbnailPath;
  final Duration? duration;
  final MediaType type;
  final DateTime addedAt;
  bool isFavourite;
  Duration? lastPosition;
  DateTime? lastPlayed;

  MediaItem({
    required this.id,
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.thumbnailPath,
    this.duration,
    required this.type,
    required this.addedAt,
    this.isFavourite = false,
    this.lastPosition,
    this.lastPlayed,
  });

  String get fileName => path.split('/').last;

  bool get isVideo => type == MediaType.video;

  bool get exists => kIsWeb ? true : File(path).existsSync();

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'thumbnailPath': thumbnailPath,
        'duration': duration?.inMilliseconds,
        'type': type.index,
        'addedAt': addedAt.toIso8601String(),
        'isFavourite': isFavourite,
        'lastPosition': lastPosition?.inMilliseconds,
        'lastPlayed': lastPlayed?.toIso8601String(),
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String,
        path: json['path'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
        thumbnailPath: json['thumbnailPath'] as String?,
        duration: json['duration'] != null
            ? Duration(milliseconds: json['duration'] as int)
            : null,
        type: MediaType.values[json['type'] as int],
        addedAt: DateTime.parse(json['addedAt'] as String),
        isFavourite: json['isFavourite'] as bool? ?? false,
        lastPosition: json['lastPosition'] != null
            ? Duration(milliseconds: json['lastPosition'] as int)
            : null,
        lastPlayed: json['lastPlayed'] != null
            ? DateTime.parse(json['lastPlayed'] as String)
            : null,
      );

  MediaItem copyWith({
    String? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    String? thumbnailPath,
    Duration? duration,
    MediaType? type,
    DateTime? addedAt,
    bool? isFavourite,
    Duration? lastPosition,
    DateTime? lastPlayed,
  }) =>
      MediaItem(
        id: id ?? this.id,
        path: path ?? this.path,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        duration: duration ?? this.duration,
        type: type ?? this.type,
        addedAt: addedAt ?? this.addedAt,
        isFavourite: isFavourite ?? this.isFavourite,
        lastPosition: lastPosition ?? this.lastPosition,
        lastPlayed: lastPlayed ?? this.lastPlayed,
      );
}
