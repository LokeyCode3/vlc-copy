import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../providers/media_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/subtitle_parser.dart';
import 'desktop_control_bar.dart';
import 'desktop_menu_bar.dart';
import 'desktop_playlist_table.dart';
import 'desktop_sidebar.dart';

class DesktopVlcScreen extends StatefulWidget {
  const DesktopVlcScreen({super.key});

  @override
  State<DesktopVlcScreen> createState() => _DesktopVlcScreenState();
}

class _DesktopVlcScreenState extends State<DesktopVlcScreen> {
  bool _sidebarVisible = true;
  bool _isVideoView = false;
  DesktopSidebarSection _currentSection = DesktopSidebarSection.playlist;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final player = context.read<PlayerProvider>();

    if (event.logicalKey == LogicalKeyboardKey.space) {
      player.togglePlayPause();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      player.seekRelative(const Duration(seconds: -10));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      player.seekRelative(const Duration(seconds: 10));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      player.setVolume((player.volume + 0.1).clamp(0.0, 1.0));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      player.setVolume((player.volume - 0.1).clamp(0.0, 1.0));
    } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
      player.setVolume(player.volume > 0 ? 0.0 : 1.0);
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      setState(() => _isVideoView = !_isVideoView);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final settings = context.watch<SettingsProvider>();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        body: SafeArea(
          child: Column(
            children: [
              // ── macOS Window Title Bar with Traffic Lights ─────────────────
              _buildMacTitleBar(),

              // ── VLC Desktop Menu Bar ────────────────────────────────────────
              DesktopMenuBar(
                sidebarVisible: _sidebarVisible,
                onToggleSidebar: () {
                  setState(() => _sidebarVisible = !_sidebarVisible);
                },
                isVideoView: _isVideoView,
                onToggleView: () {
                  setState(() => _isVideoView = !_isVideoView);
                },
              ),

              // ── Main Body: Video or Playlist Table ───────────────────────────
              Expanded(
                child: _isVideoView && player.isVideo
                    ? _buildDesktopVideoPlayer(player, settings)
                    : Row(
                        children: [
                          if (_sidebarVisible)
                            DesktopSidebar(
                              currentSection: _currentSection,
                              onSectionChanged: (s) {
                                setState(() => _currentSection = s);
                              },
                            ),
                          Expanded(
                            child: DesktopPlaylistTable(
                              title: _sectionTitle(_currentSection),
                              onPlayItem: (item) async {
                                final mediaProvider = context.read<MediaProvider>();
                                await player.playItem(item);
                                if (kIsWeb) {
                                  final bytes = mediaProvider.getWebFileBytes(item.path);
                                  if (bytes != null && (item.title.toLowerCase().endsWith('.mkv') || item.fileName.toLowerCase().endsWith('.mkv'))) {
                                    player.loadMkvSubtitlesFromBytes(bytes, item.path);
                                  }
                                } else if (item.path.toLowerCase().endsWith('.mkv')) {
                                  try {
                                    final file = File(item.path);
                                    if (await file.exists()) {
                                      final raf = await file.open();
                                      final bytes = await raf.read(50 * 1024 * 1024);
                                      await raf.close();
                                      player.loadMkvSubtitlesFromBytes(bytes, item.path);
                                    }
                                  } catch (_) {}
                                }
                                if (item.isVideo && mounted) {
                                  setState(() => _isVideoView = true);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
              ),

              // ── Desktop Bottom Control Bar ─────────────────────────────────
              DesktopControlBar(
                isVideoView: _isVideoView,
                onToggleView: () {
                  setState(() => _isVideoView = !_isVideoView);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacTitleBar() {
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E7),
        border: Border(
          bottom: BorderSide(color: Color(0xFFC7C7CC), width: 0.8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Mac Traffic Lights
          Row(
            children: [
              _trafficLight(const Color(0xFFFF5F56), const Color(0xFFE0443E)),
              const SizedBox(width: 7),
              _trafficLight(const Color(0xFFFFBD2E), const Color(0xFFDEA123)),
              const SizedBox(width: 7),
              _trafficLight(const Color(0xFF27C93F), const Color(0xFF1AAB29)),
            ],
          ),
          // Window Title
          const Text(
            'ispc player',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF48484A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trafficLight(Color color, Color border) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 0.5),
      ),
    );
  }

  Widget _buildDesktopVideoPlayer(PlayerProvider player, SettingsProvider settings) {
    final ctrl = player.videoController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (player.errorMessage != null) ...[
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    player.errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                const CircularProgressIndicator(color: Color(0xFFFF8800)),
                const SizedBox(height: 12),
                Text(
                  'Opening ${player.currentItem?.title ?? 'media'}...',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: () => setState(() => _isVideoView = !_isVideoView),
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: ctrl.value.aspectRatio,
                child: VideoPlayer(ctrl),
              ),
            ),
            // Subtitles overlay
            if (player.subtitlesEnabled && player.activeSubtitles.isNotEmpty)
              Positioned(
                bottom: 24,
                left: 32,
                right: 32,
                child: StreamBuilder<Duration>(
                  stream: player.positionStream,
                  initialData: player.position,
                  builder: (_, snap) {
                    final entry = SubtitleParser.entryAt(
                      player.activeSubtitles,
                      snap.data ?? Duration.zero,
                    );
                    if (entry == null) return const SizedBox.shrink();
                    final textColor = _parseTextColor(settings.subtitleColor);
                    final bgColor = _parseBgColor(settings.subtitleBgColor, settings.subtitleBgOpacity);
                    final outline = settings.subtitleOutline;
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: settings.subtitleSize,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            shadows: outline > 0
                                ? [
                                    Shadow(blurRadius: outline, color: Colors.black, offset: const Offset(1, 1)),
                                    Shadow(blurRadius: outline, color: Colors.black, offset: const Offset(-1, -1)),
                                    Shadow(blurRadius: outline, color: Colors.black, offset: const Offset(1, -1)),
                                    Shadow(blurRadius: outline, color: Colors.black, offset: const Offset(-1, 1)),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _parseTextColor(String color) {
    switch (color.toLowerCase()) {
      case 'yellow': return const Color(0xFFFFEB3B);
      case 'cyan': return const Color(0xFF00E5FF);
      case 'green': return const Color(0xFF76FF03);
      case 'amber': return const Color(0xFFFFC107);
      default: return Colors.white;
    }
  }

  Color _parseBgColor(String color, double opacity) {
    switch (color.toLowerCase()) {
      case 'transparent': return Colors.transparent;
      case 'dark grey':
      case 'darkgray': return const Color(0xFF2C2C2E).withValues(alpha: opacity);
      case 'solid black': return Colors.black;
      default: return Colors.black.withValues(alpha: opacity);
    }
  }

  String _sectionTitle(DesktopSidebarSection section) {
    switch (section) {
      case DesktopSidebarSection.playlist:
        return 'Playlist';
      case DesktopSidebarSection.mediaLibrary:
        return 'Media Library';
      case DesktopSidebarSection.myVideos:
        return 'My Videos';
      case DesktopSidebarSection.myMusic:
        return 'My Music';
      case DesktopSidebarSection.myPictures:
        return 'My Pictures';
      case DesktopSidebarSection.bonjour:
        return 'Bonjour Network Discovery';
      case DesktopSidebarSection.upnp:
        return "Universal Plug'n'Play";
      case DesktopSidebarSection.sap:
        return 'Network streams (SAP)';
      case DesktopSidebarSection.podcasts:
        return 'Podcasts';
      case DesktopSidebarSection.jamendo:
        return 'Jamendo Selections';
      case DesktopSidebarSection.icecast:
        return 'Icecast Radio Directory';
    }
  }
}
