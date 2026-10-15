class Playlist {
  final String id;
  String name;
  List<String> mediaIds; // MediaItem ids
  final DateTime createdAt;
  DateTime updatedAt;
  String? thumbnailPath;

  Playlist({
    required this.id,
    required this.name,
    required this.mediaIds,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailPath,
  });

  int get count => mediaIds.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mediaIds': mediaIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'thumbnailPath': thumbnailPath,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        mediaIds: List<String>.from(json['mediaIds'] as List),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        thumbnailPath: json['thumbnailPath'] as String?,
      );

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? mediaIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thumbnailPath,
  }) =>
      Playlist(
        id: id ?? this.id,
        name: name ?? this.name,
        mediaIds: mediaIds ?? List.from(this.mediaIds),
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );
}
