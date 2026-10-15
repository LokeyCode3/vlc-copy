import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../providers/player_provider.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/subtitle_parser.dart';
import '../widgets/playback_speed_sheet.dart';
import '../widgets/queue_sheet.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool   _controlsVisible       = true;
  Timer? _hideTimer;
  bool   _isFullscreen          = false;
  double _volumeLevel           = 1.0;
  double _brightness            = 0.5;
  bool   _showVolumeOverlay     = false;
  bool   _showBrightnessOverlay = false;
  double? _dragStartX;
  double? _dragStartPos;

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WakelockPlus.disable();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4),
        () { if (mounted) setState(() => _controlsVisible = false); });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _resetHideTimer();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    SystemChrome.setPreferredOrientations(_isFullscreen
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PlayerProvider, MediaProvider, SettingsProvider>(
      builder: (ctx, player, _, settings, __) {
        final ctrl = player.videoController;
        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _showControls,
            onHorizontalDragStart: (d) {
              _dragStartX   = d.localPosition.dx;
              _dragStartPos = player.position.inSeconds.toDouble();
            },
            onHorizontalDragUpdate: (d) {
              if (_dragStartX == null || _dragStartPos == null) return;
              final sec = (_dragStartPos! + (d.localPosition.dx - _dragStartX!) / 5)
                  .clamp(0.0, player.duration.inSeconds.toDouble());
              player.seekTo(Duration(seconds: sec.toInt()));
              _showControls();
            },
            onHorizontalDragEnd: (_) { _dragStartX = null; _dragStartPos = null; },
            onVerticalDragUpdate: (d) {
              final left  = d.localPosition.dx < MediaQuery.of(context).size.width / 2;
              final delta = -d.delta.dy / 200;
              if (left) {
                setState(() { _brightness = (_brightness + delta).clamp(0, 1);
                  _showBrightnessOverlay = true; });
              } else {
                setState(() { _volumeLevel = (_volumeLevel + delta).clamp(0, 1);
                  _showVolumeOverlay = true; });
                player.setVolume(_volumeLevel);
              }
            },
            onVerticalDragEnd: (_) => Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                setState(() {
                  _showBrightnessOverlay = false;
                  _showVolumeOverlay     = false;
                });
              }
            }),
            child: Stack(fit: StackFit.expand, children: [
              // ── Video ──────────────────────────────────────────────────────
              if (ctrl != null && ctrl.value.isInitialized)
                Center(child: AspectRatio(
                    aspectRatio: ctrl.value.aspectRatio,
                    child: VideoPlayer(ctrl)))
              else if (player.state != PlayerState.error)
                const Center(child: CircularProgressIndicator(color: AppTheme.orange)),

              // ── Subtitle overlay ───────────────────────────────────────────
              if (player.subtitlesEnabled && player.activeSubtitles.isNotEmpty)
                Positioned(
                  bottom: 72, left: 16, right: 16,
                  child: StreamBuilder<Duration>(
                    stream: player.positionStream,
                    initialData: player.position,
                    builder: (_, snap) {
                      final entry = SubtitleParser.entryAt(
                          player.activeSubtitles, snap.data ?? Duration.zero);
                      if (entry == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(entry.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w500, height: 1.4,
                            shadows: [Shadow(blurRadius: 4,
                                color: Colors.black, offset: Offset(1, 1))],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ── Controls ───────────────────────────────────────────────────
              if (_controlsVisible || !player.isPlaying)
                _buildControls(ctx, player, settings),

              // ── Side overlays ──────────────────────────────────────────────
              if (_showBrightnessOverlay)
                _sideOverlay(Icons.brightness_6_rounded, _brightness,
                    '${(_brightness * 100).toInt()}%', Alignment.centerLeft),
              if (_showVolumeOverlay)
                _sideOverlay(Icons.volume_up_rounded, _volumeLevel,
                    '${(_volumeLevel * 100).toInt()}%', Alignment.centerRight),

              // ── Error ──────────────────────────────────────────────────────
              if (player.state == PlayerState.error)
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E22).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.orange, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'Playback Error',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          player.errorMessage ?? 'An error occurred during playback.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(ctx).pop(),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text('Back'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (player.currentItem != null) {
                                  player.playItem(player.currentItem!);
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orange,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Loading ────────────────────────────────────────────────────
              if (player.state == PlayerState.loading)
                const Center(child: CircularProgressIndicator(color: AppTheme.orange)),
            ]),
          ),
        );
      },
    );
  }

  // ── Controls layout ───────────────────────────────────────────────────────────

  Widget _buildControls(BuildContext ctx, PlayerProvider player, SettingsProvider s) {
    final item = player.currentItem;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
          stops: [0, .45, 1],
        ),
      ),
      child: SafeArea(child: Column(children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
            Expanded(child: Text(item?.title ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            TextButton(
              onPressed: () => showPlaybackSpeedSheet(ctx, player),
              child: Text(speedLabel(player.playbackSpeed),
                  style: const TextStyle(color: AppTheme.orange, fontSize: 13)),
            ),
            IconButton(
              icon: Icon(Icons.subtitles_rounded,
                  color: player.subtitlesEnabled && player.subtitleTracks.isNotEmpty
                      ? AppTheme.orange : Colors.white70),
              onPressed: () => _showSubtitleSheet(ctx, player),
            ),
            IconButton(
              icon: const Icon(Icons.queue_music_rounded, color: Colors.white70),
              onPressed: () => showQueueSheet(ctx, player),
            ),
            IconButton(
              icon: Icon(_isFullscreen
                  ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                  color: Colors.white),
              onPressed: _toggleFullscreen,
            ),
          ]),
        ),
        const Spacer(),
        // Center controls
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Btn(icon: Icons.replay_10_rounded, onTap: () {
            player.seekRelative(Duration(seconds: -s.seekInterval)); _showControls();
          }),
          const SizedBox(width: 24),
          _Btn(icon: Icons.skip_previous_rounded, size: 36, onTap: () {
            player.skipPrev(); _showControls();
          }),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () { player.togglePlayPause(); _showControls(); },
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 1.5),
              ),
              child: Icon(
                player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(width: 16),
          _Btn(icon: Icons.skip_next_rounded, size: 36, onTap: () {
            player.skipNext(); _showControls();
          }),
          const SizedBox(width: 24),
          _Btn(icon: Icons.forward_10_rounded, onTap: () {
            player.seekRelative(Duration(seconds: s.seekInterval)); _showControls();
          }),
        ]),
        const Spacer(),
        // Bottom bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(children: [
            StreamBuilder<Duration>(
              stream: player.positionStream,
              initialData: player.position,
              builder: (_, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = player.duration;
                final pct = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
                return Column(children: [
                  SliderTheme(
                    data: SliderTheme.of(ctx).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: pct,
                      onChanged: (v) {
                        player.seekTo(Duration(
                            milliseconds: (v * dur.inMilliseconds).toInt()));
                        _showControls();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDuration(pos),
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(formatDuration(dur),
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                  ),
                ]);
              },
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                icon: Icon(
                  player.repeatMode == PlayerRepeatMode.one
                      ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  color: player.repeatMode != PlayerRepeatMode.none
                      ? AppTheme.orange : Colors.white70, size: 22),
                onPressed: () { player.cycleRepeatMode(); _showControls(); },
              ),
              IconButton(
                icon: Icon(Icons.shuffle_rounded,
                    color: player.shuffle ? AppTheme.orange : Colors.white70, size: 22),
                onPressed: () { player.toggleShuffle(); _showControls(); },
              ),
              IconButton(
                icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white70, size: 22),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 22),
                onPressed: () => _moreOptions(ctx, player),
              ),
            ]),
          ]),
        ),
      ])),
    );
  }

  Widget _sideOverlay(IconData icon, double val, String label, Alignment align) =>
      Align(
        alignment: align,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.black54,
              borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            SizedBox(height: 80,
                child: RotatedBox(quarterTurns: -1,
                    child: LinearProgressIndicator(value: val,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white)))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ]),
        ),
      );

  // ── Subtitle sheet ────────────────────────────────────────────────────────────

  void _showSubtitleSheet(BuildContext ctx, PlayerProvider player) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, ss) {
          final tracks  = player.subtitleTracks;
          final active  = player.activeSubtitleId;
          final enabled = player.subtitlesEnabled;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(2))),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.subtitles_rounded, color: AppTheme.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Subtitle Tracks',
                        style: TextStyle(color: AppTheme.onBackground,
                            fontSize: 16, fontWeight: FontWeight.w700))),
                    if (tracks.isNotEmpty)
                      Row(children: [
                        Text(enabled ? 'On' : 'Off',
                            style: TextStyle(
                                color: enabled ? AppTheme.orange : AppTheme.subtitle,
                                fontSize: 13)),
                        Switch(value: enabled, activeThumbColor: AppTheme.orange,
                            onChanged: (v) {
                              v ? player.enableSubtitles() : player.disableSubtitles();
                              ss(() {});
                            }),
                      ]),
                  ]),
                ),
                const Divider(color: AppTheme.divider, height: 1),
                // Track list or empty state
                if (tracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(children: [
                      Icon(Icons.subtitles_off_rounded, color: AppTheme.subtitle, size: 40),
                      SizedBox(height: 12),
                      Text(
                        'No subtitle file found next to this video.\n\n'
                        'Place a subtitle file with the same name as the video\n'
                        'in the same folder, e.g.:\n'
                        '  movie.srt  /  movie.en.srt\n'
                        '  movie.vtt  /  movie.ass\n\n'
                        'Or tap "Load file" to pick one manually.\n\n'
                        'Supported formats:\n'
                        'SRT · VTT · ASS · SSA · SUB · SBV · LRC',
                        style: TextStyle(color: AppTheme.subtitle, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tracks.length,
                      itemBuilder: (_, i) {
                        final t   = tracks[i];
                        final sel = t.id == active && enabled;
                        final isSupp = t.isSupported;
                        return ListTile(
                          enabled: isSupp,
                          leading: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sel ? AppTheme.orange.withValues(alpha: 0.15) : Colors.transparent,
                              border: Border.all(
                                  color: sel ? AppTheme.orange : AppTheme.divider, width: 1.5),
                            ),
                            child: Icon(
                              sel ? Icons.check_rounded : (isSupp ? Icons.subtitles_outlined : Icons.block_rounded),
                              color: sel ? AppTheme.orange : (isSupp ? AppTheme.onSurface : AppTheme.subtitle), size: 18),
                          ),
                          title: Text(
                            isSupp ? t.label : '${t.label} [${(t.codec ?? 'PGS').toUpperCase()} - Unsupported]',
                            style: TextStyle(
                                color: isSupp
                                    ? (sel ? AppTheme.orange : AppTheme.onBackground)
                                    : AppTheme.subtitle,
                                fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                          subtitle: Text(
                              !isSupp
                                  ? (t.unsupportedReason ?? 'Image-based subtitle requires OCR')
                                  : (t.language.isNotEmpty ? t.language : 'Embedded'),
                              style: const TextStyle(color: AppTheme.subtitle, fontSize: 12)),
                          onTap: () async {
                            if (!isSupp) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(t.unsupportedReason ?? 'Bitmap subtitle cannot be rendered without OCR'),
                                  backgroundColor: Colors.orange.shade900,
                                ),
                              );
                              return;
                            }
                            Navigator.pop(sheetCtx);
                            await player.selectSubtitleTrack(
                                t.id, player.currentItem?.path ?? '');
                          },
                        );
                      },
                    ),
                  ),
                const Divider(color: AppTheme.divider, height: 1),
                ListTile(
                  leading: const Icon(Icons.subtitles_off_rounded, color: AppTheme.onSurface),
                  title: const Text('Disable subtitles',
                      style: TextStyle(color: AppTheme.onBackground)),
                  onTap: () { player.disableSubtitles(); Navigator.pop(sheetCtx); },
                ),
                ListTile(
                  leading: const Icon(Icons.file_open_rounded, color: AppTheme.onSurface),
                  title: const Text('Load subtitle file',
                      style: TextStyle(color: AppTheme.onBackground)),
                  subtitle: const Text('SRT · VTT · ASS · SSA · SUB · SBV · LRC',
                      style: TextStyle(color: AppTheme.subtitle, fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _pickSubtitle(ctx, player);
                  },
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickSubtitle(BuildContext ctx, PlayerProvider player) async {
    final msg = ScaffoldMessenger.of(ctx);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub', 'sbv', 'lrc'],
      );
      if (result.isEmpty) return;
      final f = result.first;
      String content = '';
      if (kIsWeb) {
        final bytes = await f.readAsBytes();
        content = utf8.decode(bytes, allowMalformed: true);
      } else if (f.path != null) {
        final bytes = await File(f.path!).readAsBytes();
        content = utf8.decode(bytes, allowMalformed: true);
      }
      final ext = (f.extension ?? 'srt').toLowerCase();
      final entries = SubtitleParser.parse(content, ext);
      if (!mounted) return;
      if (entries.isEmpty) {
        msg.showSnackBar(const SnackBar(
            content: Text('No entries found — check the file format')));
        return;
      }
      player.loadExternalSubtitles(entries, f.name);
      msg.showSnackBar(SnackBar(
          content: Text('${entries.length} subtitles loaded from "${f.name}"')));
    } catch (e) {
      if (!mounted) return;
      msg.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _moreOptions(BuildContext ctx, PlayerProvider player) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16),
              child: Text('More Options',
                  style: TextStyle(color: AppTheme.onBackground,
                      fontSize: 16, fontWeight: FontWeight.w600))),
          const Divider(color: AppTheme.divider),
          ListTile(
            leading: const Icon(Icons.speed_rounded, color: AppTheme.onSurface),
            title: Text('Speed: ${speedLabel(player.playbackSpeed)}',
                style: const TextStyle(color: AppTheme.onBackground)),
            onTap: () { Navigator.pop(ctx); showPlaybackSpeedSheet(ctx, player); },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded, color: AppTheme.onSurface),
            title: const Text('Queue', style: TextStyle(color: AppTheme.onBackground)),
            onTap: () { Navigator.pop(ctx); showQueueSheet(ctx, player); },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: AppTheme.onSurface),
            title: const Text('File info', style: TextStyle(color: AppTheme.onBackground)),
            onTap: () {
              Navigator.pop(ctx);
              final item = player.currentItem;
              if (item == null) return;
              showDialog(context: ctx, builder: (_) => AlertDialog(
                title: const Text('File Info'),
                content: Text(
                  'Title: ${item.title}\nPath: ${item.path}\n'
                  'Duration: ${formatDuration(item.duration ?? Duration.zero)}',
                  style: const TextStyle(color: AppTheme.onSurface)),
                actions: [TextButton(
                    onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
              ));
            },
          ),
        ]),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final double size;
  const _Btn({required this.icon, required this.onTap, this.size = 32});
  @override
  Widget build(BuildContext context) =>
      GestureDetector(onTap: onTap, child: Icon(icon, color: Colors.white, size: size));
}
