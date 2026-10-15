class SubtitleTrack {
  final int index;
  final String name;
  final String? language;

  const SubtitleTrack({
    required this.index,
    required this.name,
    this.language,
  });

  static const SubtitleTrack none = SubtitleTrack(index: -1, name: 'Disable');

  @override
  bool operator ==(Object other) =>
      other is SubtitleTrack && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

class AudioTrack {
  final int index;
  final String name;
  final String? language;

  const AudioTrack({
    required this.index,
    required this.name,
    this.language,
  });

  @override
  bool operator ==(Object other) =>
      other is AudioTrack && other.index == index;

  @override
  int get hashCode => index.hashCode;
}
