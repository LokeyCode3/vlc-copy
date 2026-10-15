import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../screens/video_player_screen.dart';
import '../screens/audio_player_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        final item = player.currentItem;
        if (item == null || player.state == PlayerState.idle) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            if (player.isVideo) {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const VideoPlayerScreen()));
            } else {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AudioPlayerScreen()));
            }
          },
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                  top: BorderSide(color: AppTheme.orange.withValues(alpha: 0.3), width: 1)),
            ),
            child: Column(
              children: [
                // Progress bar
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  initialData: player.position,
                  builder: (ctx, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = player.duration;
                    final pct =
                        dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
                    return LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 2,
                      backgroundColor: Colors.white10,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.orange),
                    );
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // Thumbnail / Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            player.isVideo
                                ? Icons.videocam_rounded
                                : Icons.music_note_rounded,
                            color: AppTheme.orange,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Title + time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                    color: AppTheme.onBackground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              StreamBuilder<Duration>(
                                stream: player.positionStream,
                                initialData: player.position,
                                builder: (ctx, snap) {
                                  final pos = snap.data ?? Duration.zero;
                                  final dur = player.duration;
                                  return Text(
                                    '${formatDuration(pos)} / ${formatDuration(dur)}',
                                    style: const TextStyle(
                                        color: AppTheme.subtitle, fontSize: 11),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Controls
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: player.skipPrev,
                          iconSize: 22,
                          color: AppTheme.onSurface,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                          onPressed: player.togglePlayPause,
                          iconSize: 28,
                          color: AppTheme.orange,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: player.skipNext,
                          iconSize: 22,
                          color: AppTheme.onSurface,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
