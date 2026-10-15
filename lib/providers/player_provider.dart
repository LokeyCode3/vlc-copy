import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/media_item.dart';
import '../utils/subtitle_parser.dart';
import '../utils/embedded_subtitle_detector.dart';
import '../utils/mkv_subtitle_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum PlayerRepeatMode { none, one, all }
enum PlayerState { idle, loading, ready, playing, paused, error }

// ─────────────────────────────────────────────────────────────────────────────
// Subtitle track
// ─────────────────────────────────────────────────────────────────────────────

class SubtitleTrackInfo {
  final int     id;       // index; negative for embedded, >= 0 for sidecar/external, 200+ for MKV Web
  final String  label;
  final String  language;
  final String? filePath;
  final String? codec;
  final bool    isSupported;
  final String? unsupportedReason;

  const SubtitleTrackInfo({
    required this.id,
    required this.label,
    required this.language,
    this.filePath,
    this.codec,
    this.isSupported = true,
    this.unsupportedReason,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PlayerProvider
// ─────────────────────────────────────────────────────────────────────────────

class PlayerProvider extends ChangeNotifier {
  VideoPlayerController? _videoController;
  final AudioPlayer      _audioPlayer = AudioPlayer();
  AudioSession?          _audioSession;

  MediaItem?      _currentItem;
  List<MediaItem> _queue      = [];
  int             _queueIndex = -1;

  PlayerRepeatMode _repeatMode    = PlayerRepeatMode.none;
  bool             _shuffle       = false;
  double           _playbackSpeed = 1.0;
  PlayerState      _state         = PlayerState.idle;
  String?          _errorMessage;
  bool             _isVideo       = false;
  double           _volume        = 1.0;

  // Subtitles — loaded from sidecar files next to the video and embedded tracks
  List<SubtitleTrackInfo> _subtitleTracks     = [];
  int                     _activeSubtitleId   = -1;
  bool                    _subtitlesEnabled   = true;
  List<SubtitleEntry>     _activeSubtitles    = [];
  List<EmbeddedSubtitleTrackInfo> _embeddedSubtitleTracks = [];
  Map<int, int> _embeddedSubtitleTrackMapping = {}; // Maps sequential ID to stream index
  List<MkvSubtitleTrack>  _mkvSubtitleTracks  = [];

  Timer? _positionTimer;
  void Function(String id, Duration position)? onPositionUpdate;

  PlayerProvider() { _initAudioSession(); }

  // ── Getters ──────────────────────────────────────────────────────────────────

  MediaItem?               get currentItem          => _currentItem;
  List<MediaItem>          get queue                => List.unmodifiable(_queue);
  int                      get queueIndex           => _queueIndex;
  PlayerRepeatMode         get repeatMode           => _repeatMode;
  bool                     get shuffle              => _shuffle;
  double                   get playbackSpeed        => _playbackSpeed;
  PlayerState              get state                => _state;
  String?                  get errorMessage         => _errorMessage;
  bool                     get isVideo              => _isVideo;
  bool                     get isPlaying            => _state == PlayerState.playing;
  double                   get volume               => _volume;
  VideoPlayerController?   get videoController      => _videoController;
  AudioPlayer              get audioPlayer          => _audioPlayer;
  List<SubtitleTrackInfo>  get subtitleTracks       => List.unmodifiable(_subtitleTracks);
  List<EmbeddedSubtitleTrackInfo>  get embeddedSubtitleTracks => List.unmodifiable(_embeddedSubtitleTracks);
  int                      get activeSubtitleId     => _activeSubtitleId;
  int?                     get activeSubtitleTrackIndex =>
      _activeSubtitleId == -1 ? null : _activeSubtitleId;
  bool                     get subtitlesEnabled     => _subtitlesEnabled;
  List<SubtitleEntry>      get activeSubtitles      => List.unmodifiable(_activeSubtitles);

  Duration get position {
    if (_isVideo && _videoController != null) return _videoController!.value.position;
    return _audioPlayer.position;
  }

  Duration get duration {
    if (_isVideo && _videoController != null) {
      final d = _videoController!.value.duration;
      return d == Duration.zero ? (_currentItem?.duration ?? Duration.zero) : d;
    }
    return _audioPlayer.duration ?? Duration.zero;
  }

  // ── Audio session ─────────────────────────────────────────────────────────────

  Future<void> _initAudioSession() async {
    _audioSession = await AudioSession.instance;
    await _audioSession!.configure(const AudioSessionConfiguration.music());
    _audioPlayer.playbackEventStream.listen(
      (e) { if (e.processingState == ProcessingState.completed) _handleCompletion(); },
      onError: (e) => _setError(e.toString()),
    );
    _audioPlayer.playerStateStream.listen((s) {
      if (_isVideo) return;
      if (s.playing) {
        _setState(PlayerState.playing);
      } else if (s.processingState == ProcessingState.loading ||
          s.processingState == ProcessingState.buffering) {
        _setState(PlayerState.loading);
      } else if (s.processingState == ProcessingState.ready) {
        if (_state != PlayerState.playing) _setState(PlayerState.paused);
      }
    });
  }

  // ── Playback ──────────────────────────────────────────────────────────────────

  Future<void> playItem(MediaItem item, {List<MediaItem>? queue, int? queueIndex}) async {
    if (queue != null) {
      _queue      = List.from(queue);
      _queueIndex = queueIndex ?? queue.indexOf(item);
      if (_queueIndex < 0) _queueIndex = 0;
    } else if (!_queue.any((m) => m.id == item.id)) {
      _queue = [item]; _queueIndex = 0;
    } else {
      _queueIndex = _queue.indexWhere((m) => m.id == item.id);
    }
    await _playInternal(item);
  }

  Future<void> _playInternal(MediaItem item) async {
    _setState(PlayerState.loading);
    final previousPath = _currentItem?.path;
    _currentItem  = item;
    _isVideo      = item.type == MediaType.video;
    _errorMessage = null;
    if (previousPath != null && previousPath != item.path) {
      _resetSubtitleState();
    }
    notifyListeners();

    try {
      if (_isVideo) {
        await _disposeVideo();
        if (kIsWeb || item.path.startsWith('blob:') || item.path.startsWith('http://') || item.path.startsWith('https://')) {
          _videoController = VideoPlayerController.networkUrl(Uri.parse(item.path));
        } else {
          _videoController = VideoPlayerController.file(File(item.path));
        }
        await _videoController!.initialize();
        await _videoController!.setPlaybackSpeed(_playbackSpeed);
        await _videoController!.setVolume(_volume);
        _videoController!.addListener(_videoListener);

        // Restore position
        final dur = _videoController!.value.duration;
        if (item.lastPosition != null &&
            item.lastPosition! > Duration.zero &&
            dur > Duration.zero &&
            item.lastPosition! < dur - const Duration(seconds: 5)) {
          await _videoController!.seekTo(item.lastPosition!);
        }
        await _videoController!.play();
        _setState(PlayerState.playing);
        if (!kIsWeb) {
          try { await WakelockPlus.enable(); } catch (_) {}
        }

        // Load subtitles from sidecar in background (native only)
        if (!kIsWeb && !item.path.startsWith('blob:') && !item.path.startsWith('http')) {
          _loadSubtitlesBackground(item.path);
        }
      } else {
        await _audioPlayer.stop();
        if (!kIsWeb) {
          try { await _audioSession?.setActive(true); } catch (_) {}
        }
        if (kIsWeb || item.path.startsWith('blob:') || item.path.startsWith('http://') || item.path.startsWith('https://')) {
          await _audioPlayer.setUrl(item.path);
        } else {
          await _audioPlayer.setFilePath(item.path);
        }
        await _audioPlayer.setSpeed(_playbackSpeed);
        await _audioPlayer.setVolume(_volume);
        if (item.lastPosition != null && item.lastPosition! > Duration.zero) {
          await _audioPlayer.seek(item.lastPosition!);
        }
        await _audioPlayer.play();
        if (!kIsWeb) {
          try { await WakelockPlus.disable(); } catch (_) {}
        }
      }
      _startPositionTimer(item.id);
    } catch (e) {
      if (kDebugMode) print('Error playing item: $e');
      _setError('Failed to play: $e');
    }
  }

  // ── Subtitles ─────────────────────────────────────────────────────────────────

  /// Scans for sidecar subtitle files next to the video and loads them.
  /// Also detects embedded subtitle tracks in the video file.
  /// Supports: SRT, VTT, ASS, SSA, SUB, SBV, LRC
  Future<void> _loadSubtitlesBackground(String videoPath) async {
    if (kIsWeb || videoPath.startsWith('blob:') || videoPath.startsWith('http')) {
      return;
    }
    if (kDebugMode) {
      print('📽️ Starting subtitle loading for: $videoPath');
    }

    final dir    = p.dirname(videoPath);
    final base   = p.basenameWithoutExtension(videoPath);
    const exts   = ['srt', 'vtt', 'ass', 'ssa', 'sub', 'sbv', 'lrc'];
    final tracks = <SubtitleTrackInfo>[];
    int idx      = 0;

    // First, detect embedded subtitles
    final embeddedTracks = await EmbeddedSubtitleDetector.detectEmbeddedSubtitles(videoPath);
    _embeddedSubtitleTracks = embeddedTracks;

    if (kDebugMode) {
      print('📽️ Found ${embeddedTracks.length} embedded subtitle tracks');
    }

    // Then, scan for sidecar subtitle files
    for (final ext in exts) {
      // Exact match: movie.srt
      final exact = File(p.join(dir, '$base.$ext'));
      if (await exact.exists()) {
        tracks.add(SubtitleTrackInfo(
            id: idx++, label: _labelForExt(ext), language: '', filePath: exact.path));
      }
    }

    // Language-tagged: movie.en.srt, movie.English.srt, etc.
    try {
      final d = Directory(dir);
      await for (final entity in d.list()) {
        if (entity is! File) continue;
        final name    = p.basename(entity.path).toLowerCase();
        final fileExt = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
        if (!exts.contains(fileExt)) continue;
        if (!name.startsWith('${base.toLowerCase()}.')) continue;
        // Skip already-added exact matches
        if (tracks.any((t) =>
            t.label == _labelForExt(fileExt) && t.language.isEmpty)) {
          continue;
        }
        final parts    = p.basenameWithoutExtension(entity.path).split('.');
        final langCode = parts.length > 1 ? parts.sublist(1).join('.') : '';
        tracks.add(SubtitleTrackInfo(
          id: idx++,
          label: '${_expandLang(langCode)} (.$fileExt)',
          language: langCode,
          filePath: entity.path,
        ));
      }
    } catch (_) {}

    if (kDebugMode) {
      print('📽️ Found ${tracks.length} sidecar subtitle files');
    }

    // Combine embedded and sidecar tracks
    // Embedded tracks use negative IDs starting at -100 (-100, -101, ...)
    // so that -1 remains reserved for "no track / disabled"
    final allTracks = <SubtitleTrackInfo>[];
    _embeddedSubtitleTrackMapping = {};
    for (int i = 0; i < embeddedTracks.length; i++) {
      final track = embeddedTracks[i];
      final uiId = -100 - i;
      allTracks.add(SubtitleTrackInfo(
        id: uiId,
        label: track.label,
        language: track.language,
      ));
      _embeddedSubtitleTrackMapping[uiId] = track.id;
    }
    allTracks.addAll(tracks);

    if (kDebugMode) {
      print('📽️ Total subtitle tracks available: ${allTracks.length}');
    }

    if (allTracks.isEmpty) return;

    _subtitleTracks = allTracks;

    // Auto-load the first track (prefer embedded if available)
    if (embeddedTracks.isNotEmpty) {
      if (kDebugMode) {
        print('📽️ Auto-loading first embedded track: ${embeddedTracks.first.label}');
      }
      await _loadEmbeddedTrackEntries(videoPath, embeddedTracks.first);
    } else if (tracks.isNotEmpty) {
      if (kDebugMode) {
        print('📽️ Auto-loading first sidecar track');
      }
      await _loadTrackEntries(videoPath, tracks.first);
    }

    notifyListeners();
  }

  Future<void> _loadTrackEntries(String videoPath, SubtitleTrackInfo track) async {
    // 1. If track has direct filePath, load it
    if (track.filePath != null) {
      try {
        final file = File(track.filePath!);
        if (await file.exists()) {
          final ext = p.extension(track.filePath!).replaceFirst('.', '').toLowerCase();
          final content = await file.readAsString();
          final entries = SubtitleParser.parse(content, ext);
          if (entries.isNotEmpty) {
            _activeSubtitles  = entries;
            _activeSubtitleId = track.id;
            _subtitlesEnabled = true;
            return;
          }
        }
      } catch (_) {}
    }

    final dir  = p.dirname(videoPath);
    final base = p.basenameWithoutExtension(videoPath);
    const exts = ['srt', 'vtt', 'ass', 'ssa', 'sub', 'sbv', 'lrc'];

    // Try exact match
    for (final ext in exts) {
      final file = File(p.join(dir, '$base.$ext'));
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final entries = SubtitleParser.parse(content, ext);
          if (entries.isNotEmpty) {
            _activeSubtitles  = entries;
            _activeSubtitleId = track.id;
            _subtitlesEnabled = true;
            return;
          }
        } catch (_) {}
      }
    }

    // Try language-tagged files
    try {
      final d = Directory(dir);
      await for (final entity in d.list()) {
        if (entity is! File) continue;
        final name    = p.basename(entity.path).toLowerCase();
        final fileExt = p.extension(entity.path).replaceFirst('.', '').toLowerCase();
        if (!exts.contains(fileExt)) continue;
        if (!name.startsWith('${base.toLowerCase()}.')) continue;
        final content = await entity.readAsString();
        final entries = SubtitleParser.parse(content, fileExt);
        if (entries.isNotEmpty) {
          _activeSubtitles  = entries;
          _activeSubtitleId = track.id;
          _subtitlesEnabled = true;
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadEmbeddedTrackEntries(
      String videoPath, EmbeddedSubtitleTrackInfo embeddedTrack) async {
    if (kDebugMode) {
      print('📽️ Loading embedded track: ${embeddedTrack.label} (stream index: ${embeddedTrack.id})');
    }

    try {
      final extractedPath =
          await EmbeddedSubtitleDetector.extractSubtitleToSrt(videoPath, embeddedTrack.id);
      if (extractedPath == null) return;

      final file = File(extractedPath);
      final content = await file.readAsString();
      final entries = SubtitleParser.parse(content, 'srt');

      if (kDebugMode) {
        print('📽️ Parsed ${entries.length} subtitle entries from track: ${embeddedTrack.label}');
      }

      if (entries.isNotEmpty) {
        _activeSubtitles = entries;
        // Find the sequential ID for this stream index
        final sequentialId = _embeddedSubtitleTrackMapping.entries
            .firstWhere((entry) => entry.value == embeddedTrack.id,
                orElse: () => const MapEntry(-1, -1))
            .key;
        _activeSubtitleId = sequentialId;
        _subtitlesEnabled = true;

        if (kDebugMode) {
          print('📽️ Successfully loaded subtitle track: ${embeddedTrack.label} (UI ID: $sequentialId)');
        }
      }

      // Clean up temporary file
      await file.delete();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading embedded subtitle: $e');
      }
    }
  }

  String? _lastParsedMkvKey;

  void loadMkvSubtitlesFromBytes(Uint8List bytes, [String cacheKey = '']) {
    if (cacheKey.isNotEmpty && _lastParsedMkvKey == cacheKey && _mkvSubtitleTracks.isNotEmpty) {
      if (kDebugMode) {
        print('[Subtitle Debug] Using cached MKV subtitle tracks for $cacheKey (${_mkvSubtitleTracks.length} tracks)');
      }
      return;
    }
    _lastParsedMkvKey = cacheKey.isNotEmpty ? cacheKey : null;

    try {
      final tracks = MkvSubtitleParser.parse(bytes, fileSize: bytes.length);
      if (kDebugMode) {
        print('[Subtitle Debug] MKV container parsed: ${tracks.length} track(s) found');
      }
      if (tracks.isNotEmpty) {
        _mkvSubtitleTracks = tracks;
        _subtitleTracks = [];
        for (int i = 0; i < tracks.length; i++) {
          final t = tracks[i];
          _subtitleTracks.add(SubtitleTrackInfo(
            id: 200 + i,
            label: t.label,
            language: t.language,
            codec: t.codec,
            isSupported: t.isSupported,
            unsupportedReason: t.unsupportedReason,
          ));
        }
        if (kDebugMode) {
          print('[Subtitle Debug] Track list registered:');
          for (final st in _subtitleTracks) {
            print('  • ID: ${st.id}, Label: "${st.label}", Lang: "${st.language}", Codec: "${st.codec}", Supported: ${st.isSupported}');
          }
        }
        // Auto-select English or first supported track if available
        int defaultIdx = tracks.indexWhere((t) => t.isSupported && t.language.toLowerCase().startsWith('en'));
        if (defaultIdx < 0) defaultIdx = tracks.indexWhere((t) => t.isSupported);
        if (defaultIdx >= 0) {
          _activeSubtitleId = 200 + defaultIdx;
          _activeSubtitles = tracks[defaultIdx].entries;
          _subtitlesEnabled = true;
          if (kDebugMode) {
            print('[Subtitle Debug] Auto-selected track number: ${tracks[defaultIdx].trackNumber} (ID: $_activeSubtitleId, "${tracks[defaultIdx].label}"), mode: showing, cue count: ${_activeSubtitles.length}');
            for (int i = 0; i < 3 && i < _activeSubtitles.length; i++) {
              final c = _activeSubtitles[i];
              print('  -> Cue $i: [${c.start.inSeconds}s -> ${c.end.inSeconds}s] "${c.text.replaceAll('\n', ' ')}"');
            }
          }
        } else {
          _activeSubtitleId = -1;
          _activeSubtitles = [];
          _subtitlesEnabled = false;
          if (kDebugMode) {
            print('[Subtitle Debug] No supported subtitle tracks available to auto-select. Mode: disabled, cue count: 0');
          }
        }
        notifyListeners();
      } else {
        if (kDebugMode) {
          print('[Subtitle Debug] No subtitle streams found in MKV file.');
        }
      }
    } catch (e) {
      if (kDebugMode) print('[Subtitle Debug] Error parsing MKV subtitles: $e');
    }
  }

  Future<void> selectSubtitleTrack(int trackId, [String videoPath = '']) async {
    // Check if this is an MKV parsed track (id >= 200)
    if (_mkvSubtitleTracks.isNotEmpty && trackId >= 200) {
      final mkvIdx = trackId - 200;
      if (mkvIdx >= 0 && mkvIdx < _mkvSubtitleTracks.length) {
        final track = _mkvSubtitleTracks[mkvIdx];
        if (!track.isSupported) {
          if (kDebugMode) {
            print('[Subtitle Debug] Track ID: $trackId is unsupported (${track.codec}): ${track.unsupportedReason}');
          }
          return;
        }
        _activeSubtitleId = trackId;
        _activeSubtitles = track.entries;
        _subtitlesEnabled = true;
        notifyListeners();
        if (kDebugMode) {
          print('[Subtitle Debug] Selected track number: ${track.trackNumber} (ID: $trackId, "${track.label}"), mode: showing, cue count: ${track.entries.length}');
          for (int i = 0; i < 3 && i < track.entries.length; i++) {
            final c = track.entries[i];
            print('  -> Cue $i: [${c.start.inSeconds}s -> ${c.end.inSeconds}s] "${c.text.replaceAll('\n', ' ')}"');
          }
        }
        return;
      }
    }

    final track = _subtitleTracks.firstWhere(
        (t) => t.id == trackId,
        orElse: () => const SubtitleTrackInfo(id: -999999, label: '', language: ''));
    if (track.id == -999999) return;
    final path = videoPath.isNotEmpty ? videoPath : (_currentItem?.path ?? '');

    // Check if this is an embedded track (negative ID)
    if (trackId < 0) {
      // Get the actual stream index from the mapping
      final streamIndex = _embeddedSubtitleTrackMapping[trackId];
      if (streamIndex != null) {
        final embeddedTrack = _embeddedSubtitleTracks.firstWhere(
            (t) => t.id == streamIndex,
            orElse: () => const EmbeddedSubtitleTrackInfo(id: -1, label: '', language: ''));
        if (embeddedTrack.id != -1) {
          if (kDebugMode) {
            print('[Subtitle Debug] Selecting embedded track: ${embeddedTrack.label} (UI ID: $trackId -> stream index: $streamIndex)');
          }
          await _loadEmbeddedTrackEntries(path, embeddedTrack);
          if (kDebugMode) {
            print('[Subtitle Debug] Selected track ID: $trackId ("${embeddedTrack.label}"), mode: showing, cue count: ${_activeSubtitles.length}');
          }
        }
      }
    } else {
      await _loadTrackEntries(path, track);
      if (kDebugMode) {
        print('[Subtitle Debug] Selected track ID: $trackId ("${track.label}"), mode: showing, cue count: ${_activeSubtitles.length}');
      }
    }
    notifyListeners();
  }

  Future<void> selectEmbeddedSubtitleTrack(int trackId, String videoPath) =>
      selectSubtitleTrack(trackId, videoPath);

  void enableSubtitles()  {
    _subtitlesEnabled = true;
    if (kDebugMode) {
      print('[Subtitle Debug] Subtitles enabled (mode: showing, activeId: $_activeSubtitleId, cue count: ${_activeSubtitles.length})');
    }
    notifyListeners();
  }

  void disableSubtitles() {
    _subtitlesEnabled = false;
    _activeSubtitleId = -1;
    _activeSubtitles = [];
    if (kDebugMode) {
      print('[Subtitle Debug] Selected track ID: off, mode: disabled, cue count: 0');
    }
    notifyListeners();
  }

  void clearSubtitles()   {
    _activeSubtitles = []; _activeSubtitleId = -1;
    _subtitlesEnabled = true; notifyListeners();
  }

  void loadExternalSubtitles(List<SubtitleEntry> entries, String fileName) {
    // External subtitles use a positive ID starting from the highest sidecar ID + 1
    final maxSidecarId = _subtitleTracks.where((t) => t.id >= 0 && t.id < 200).fold<int>(
        0, (max, t) => t.id > max ? t.id : max);
    _subtitleTracks = [
      ..._subtitleTracks.where((t) => t.id >= 0),
      SubtitleTrackInfo(id: maxSidecarId + 1, label: 'External: $fileName', language: ''),
    ];
    _activeSubtitles  = entries;
    _activeSubtitleId = maxSidecarId + 1;
    _subtitlesEnabled = true;
    notifyListeners();
  }

  void _resetSubtitleState() {
    _subtitleTracks   = [];
    _activeSubtitles  = [];
    _activeSubtitleId = -1;
    _subtitlesEnabled = true;
    _embeddedSubtitleTrackMapping = {};
    _mkvSubtitleTracks = [];
  }

  String _labelForExt(String ext) => ext.toUpperCase();

  String _expandLang(String code) {
    const t = {
      'en': 'English', 'eng': 'English', 'fr': 'French', 'fra': 'French',
      'de': 'German',  'deu': 'German',  'es': 'Spanish','spa': 'Spanish',
      'pt': 'Portuguese','por': 'Portuguese','it': 'Italian','ita': 'Italian',
      'ja': 'Japanese','jpn': 'Japanese','zh': 'Chinese', 'zho': 'Chinese',
      'ko': 'Korean',  'kor': 'Korean',  'ar': 'Arabic',  'ara': 'Arabic',
      'ru': 'Russian', 'rus': 'Russian', 'hi': 'Hindi',   'hin': 'Hindi',
      'ta': 'Tamil',   'tam': 'Tamil',   'te': 'Telugu',  'tel': 'Telugu',
      'ml': 'Malayalam','mal': 'Malayalam','tr': 'Turkish','tur': 'Turkish',
    };
    return t[code.toLowerCase()] ?? code.toUpperCase();
  }

  // ── Video listener ────────────────────────────────────────────────────────────

  void _videoListener() {
    if (_videoController == null) return;
    final val = _videoController!.value;
    if (val.hasError) { _setError(val.errorDescription ?? 'Video error'); return; }
    if (val.isPlaying) {
      _setState(PlayerState.playing);
    } else if (val.isInitialized && !val.isPlaying) {
      final dur = val.duration;
      final pos = val.position;
      if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 200)) {
        _handleCompletion();
      } else {
        _setState(PlayerState.paused);
      }
    }
  }

  void _handleCompletion() {
    switch (_repeatMode) {
      case PlayerRepeatMode.one:  seekTo(Duration.zero); resume();
      case PlayerRepeatMode.all:  _advanceQueue(wrap: true);
      case PlayerRepeatMode.none:
        if (_queueIndex < _queue.length - 1) {
          _advanceQueue();
        } else {
          _setState(PlayerState.paused);
          WakelockPlus.disable();
        }
    }
  }

  // ── Transport controls ────────────────────────────────────────────────────────

  Future<void> togglePlayPause() async => isPlaying ? await pause() : await resume();

  Future<void> resume() async {
    if (_isVideo && _videoController != null) {
      await _videoController!.play();
    } else {
      await _audioPlayer.play();
    }
    _setState(PlayerState.playing);
  }

  Future<void> pause() async {
    if (_isVideo && _videoController != null) {
      await _videoController!.pause();
    } else {
      await _audioPlayer.pause();
    }
    _setState(PlayerState.paused);
  }

  Future<void> seekTo(Duration pos) async {
    if (_isVideo && _videoController != null) {
      await _videoController!.seekTo(pos);
    } else {
      await _audioPlayer.seek(pos);
    }
    notifyListeners();
  }

  Future<void> seekRelative(Duration offset) async {
    final raw = position + offset;
    await seekTo(raw < Duration.zero ? Duration.zero : raw > duration ? duration : raw);
  }

  Future<void> skipNext() => _advanceQueue();
  Future<void> skipPrev() async {
    if (position.inSeconds > 3) {
      await seekTo(Duration.zero);
    } else {
      await _goBack();
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    if (_isVideo && _videoController != null) {
      await _videoController!.setPlaybackSpeed(speed);
    } else {
      await _audioPlayer.setSpeed(speed);
    }
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    if (_isVideo && _videoController != null) {
      await _videoController!.setVolume(_volume);
    } else {
      await _audioPlayer.setVolume(_volume);
    }
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = PlayerRepeatMode.values[(_repeatMode.index + 1) % 3];
    notifyListeners();
  }

  void toggleShuffle() { _shuffle = !_shuffle; notifyListeners(); }

  void setQueue(List<MediaItem> items, {int startIndex = 0}) {
    _queue = List.from(items); _queueIndex = startIndex;
  }

  Future<void> jumpToIndex(int i) async {
    if (i < 0 || i >= _queue.length) return;
    _queueIndex = i; await _playInternal(_queue[i]);
  }

  Future<void> _advanceQueue({bool wrap = false}) async {
    if (_queue.isEmpty) return;
    int next = _shuffle
        ? DateTime.now().millisecondsSinceEpoch % _queue.length
        : _queueIndex + 1;
    if (next >= _queue.length) {
      if (wrap) {
        next = 0;
      } else {
        return;
      }
    }
    _queueIndex = next; await _playInternal(_queue[next]);
  }

  Future<void> _goBack() async {
    if (_queue.isEmpty) return;
    int prev = _queueIndex - 1;
    if (prev < 0) prev = _queue.length - 1;
    _queueIndex = prev; await _playInternal(_queue[prev]);
  }

  void _setState(PlayerState s) { if (_state == s) return; _state = s; notifyListeners(); }
  void _setError(String msg) {
    String friendlyMsg = msg;
    if (msg.contains('NO_EXCEEDS_CAPABILITIES') ||
        msg.contains('MediaCodecVideoRenderer error') ||
        msg.contains('IHEVCD_UNSUPPORTED_BIT_DEPTH') ||
        (msg.contains('hvc1.2') && msg.contains('10bit'))) {
      friendlyMsg =
          '10-bit HEVC (H.265) video format exceeds decoder capabilities.\n\n'
          'The Android emulator hardware decoder does not support 10-bit HEVC color profiles. '
          'Please test on a physical Android device with HEVC 10-bit hardware support, or use an 8-bit video file.';
    } else if (msg.contains('Decoder failed') || msg.contains('CodecException')) {
      friendlyMsg =
          'Video decoder failed on this device.\n\n'
          'The video codec format is not supported by the current device decoder.';
    }
    _errorMessage = friendlyMsg;
    _state = PlayerState.error;
    notifyListeners();
  }

  void _startPositionTimer(String id) {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isPlaying) onPositionUpdate?.call(id, position);
    });
  }

  Stream<Duration> get positionStream async* {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 250));
      yield position;
    }
  }

  Future<void> _disposeVideo() async {
    _videoController?.removeListener(_videoListener);
    await _videoController?.dispose();
    _videoController = null;
  }

  @override
  Future<void> dispose() async {
    _positionTimer?.cancel();
    await _disposeVideo();
    await _audioPlayer.dispose();
    await WakelockPlus.disable();
    super.dispose();
  }
}
