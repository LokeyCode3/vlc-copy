import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../utils/format_utils.dart';

class DesktopControlBar extends StatelessWidget {
  final VoidCallback onToggleView;
  final bool isVideoView;

  const DesktopControlBar({
    super.key,
    required this.onToggleView,
    required this.isVideoView,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E7),
        border: Border(
          top: BorderSide(color: Color(0xFFC7C7CC), width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // ── Transport Buttons ──────────────────────────────────────────────
          _iconBtn(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Previous',
            onTap: () => player.skipPrev(),
          ),
          _iconBtn(
            icon: player.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            tooltip: player.isPlaying ? 'Pause' : 'Play',
            size: 20,
            onTap: () => player.togglePlayPause(),
          ),
          _iconBtn(
            icon: Icons.skip_next_rounded,
            tooltip: 'Next',
            onTap: () => player.skipNext(),
          ),
          _iconBtn(
            icon: Icons.stop_rounded,
            tooltip: 'Stop',
            onTap: () {
              player.pause();
              player.seekTo(Duration.zero);
            },
          ),
          _iconBtn(
            icon: Icons.menu_rounded,
            tooltip: isVideoView ? 'Show Playlist' : 'Show Video Screen',
            isActive: isVideoView,
            onTap: onToggleView,
          ),

          const SizedBox(width: 8),

          // ── Timeline / Scrubber ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<Duration>(
              stream: player.positionStream,
              initialData: player.position,
              builder: (_, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = player.duration;
                final maxSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
                final curSec = pos.inSeconds.toDouble().clamp(0.0, maxSec);

                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: const Color(0xFF007AFF),
                    inactiveTrackColor: const Color(0xFFC7C7CC),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: curSec,
                    max: maxSec,
                    onChanged: (v) {
                      player.seekTo(Duration(seconds: v.toInt()));
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 8),

          // ── Time Display ───────────────────────────────────────────────────
          StreamBuilder<Duration>(
            stream: player.positionStream,
            initialData: player.position,
            builder: (_, snap) {
              final pos = snap.data ?? Duration.zero;
              return Text(
                formatDuration(pos),
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C3C43),
                ),
              );
            },
          ),

          const SizedBox(width: 14),

          // ── Volume Controls ────────────────────────────────────────────────
          GestureDetector(
            onTap: () {
              player.setVolume(player.volume > 0 ? 0 : 1.0);
            },
            child: Icon(
              player.volume == 0
                  ? Icons.volume_off_rounded
                  : (player.volume < 0.5
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded),
              size: 15,
              color: const Color(0xFF3C3C43),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 70,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                activeTrackColor: const Color(0xFF8E8E93),
                inactiveTrackColor: const Color(0xFFC7C7CC),
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: player.volume.clamp(0.0, 1.0),
                onChanged: (v) => player.setVolume(v),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Fullscreen Button ──────────────────────────────────────────────
          _iconBtn(
            icon: Icons.fullscreen_rounded,
            tooltip: 'Fullscreen',
            onTap: onToggleView,
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double size = 16,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFD1D1D6) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: Icon(
            icon,
            size: size,
            color: isActive ? const Color(0xFF007AFF) : const Color(0xFF3C3C43),
          ),
        ),
      ),
    );
  }
}
