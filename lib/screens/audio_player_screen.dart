import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/playback_speed_sheet.dart';
import '../widgets/queue_sheet.dart';

class AudioPlayerScreen extends StatelessWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<PlayerProvider, MediaProvider, SettingsProvider>(
      builder: (ctx, player, media, settings, _) {
        final item = player.currentItem;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.background,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 30, color: AppTheme.onBackground),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: const Text('Now Playing',
                style: TextStyle(color: AppTheme.onSurface, fontSize: 14)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showMoreOptions(ctx, player, media),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Artwork
                _buildArtwork(player, item),
                const SizedBox(height: 32),
                // Track info
                _buildTrackInfo(ctx, item, media),
                const SizedBox(height: 24),
                // Seek bar
                _buildSeekBar(ctx, player),
                const SizedBox(height: 16),
                // Controls
                _buildControls(ctx, player, settings),
                const SizedBox(height: 12),
                // Bottom row
                _buildBottomRow(ctx, player),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtwork(PlayerProvider player, item) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: player.isPlaying ? 240 : 200,
      height: player.isPlaying ? 240 : 200,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.orange.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: AppTheme.orange,
        size: 80,
      ),
    );
  }

  Widget _buildTrackInfo(BuildContext ctx, item, MediaProvider media) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.title ?? 'Unknown',
                  style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item?.artist ?? 'Unknown Artist',
                  style: const TextStyle(
                      color: AppTheme.onSurface, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Favourite button
          if (item != null)
            IconButton(
              icon: Icon(
                item.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: item.isFavourite ? AppTheme.orange : AppTheme.subtitle,
                size: 26,
              ),
              onPressed: () => media.toggleFavourite(item.id),
            ),
        ],
      ),
    );
  }

  Widget _buildSeekBar(BuildContext ctx, PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<Duration>(
        stream: player.positionStream,
        initialData: player.position,
        builder: (ctx, snap) {
          final pos = snap.data ?? Duration.zero;
          final dur = player.duration;
          final pct = dur.inMilliseconds > 0
              ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
              : 0.0;

          return Column(
            children: [
              Slider(
                value: pct,
                onChanged: (v) {
                  player.seekTo(
                      Duration(milliseconds: (v * dur.inMilliseconds).toInt()));
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(pos),
                        style: const TextStyle(
                            color: AppTheme.subtitle, fontSize: 12)),
                    Text(formatDuration(dur),
                        style: const TextStyle(
                            color: AppTheme.subtitle, fontSize: 12)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls(BuildContext ctx, PlayerProvider player, SettingsProvider settings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 40,
          color: AppTheme.onBackground,
          onPressed: player.skipPrev,
        ),
        // -seek
        IconButton(
          icon: const Icon(Icons.replay_10_rounded),
          iconSize: 34,
          color: AppTheme.onSurface,
          onPressed: () =>
              player.seekRelative(Duration(seconds: -settings.seekInterval)),
        ),
        // Play/Pause
        GestureDetector(
          onTap: player.togglePlayPause,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.orange,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.orange.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Icon(
              player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        // +seek
        IconButton(
          icon: const Icon(Icons.forward_10_rounded),
          iconSize: 34,
          color: AppTheme.onSurface,
          onPressed: () =>
              player.seekRelative(Duration(seconds: settings.seekInterval)),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 40,
          color: AppTheme.onBackground,
          onPressed: player.skipNext,
        ),
      ],
    );
  }

  Widget _buildBottomRow(BuildContext ctx, PlayerProvider player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Shuffle
          IconButton(
            icon: Icon(Icons.shuffle_rounded,
                color: player.shuffle ? AppTheme.orange : AppTheme.subtitle,
                size: 22),
            onPressed: player.toggleShuffle,
          ),
          // Volume row
          Row(
            children: [
              const Icon(Icons.volume_down_rounded,
                  color: AppTheme.subtitle, size: 18),
              SizedBox(
                width: 100,
                child: Slider(
                  value: player.volume,
                  onChanged: player.setVolume,
                  min: 0,
                  max: 1,
                ),
              ),
              const Icon(Icons.volume_up_rounded,
                  color: AppTheme.subtitle, size: 18),
            ],
          ),
          // Repeat
          IconButton(
            icon: Icon(
              player.repeatMode == PlayerRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: player.repeatMode != PlayerRepeatMode.none
                  ? AppTheme.orange
                  : AppTheme.subtitle,
              size: 22,
            ),
            onPressed: player.cycleRepeatMode,
          ),
          // Queue
          IconButton(
            icon: const Icon(Icons.queue_music_rounded,
                color: AppTheme.subtitle, size: 22),
            onPressed: () => showQueueSheet(ctx, player),
          ),
          // Speed
          TextButton(
            onPressed: () => showPlaybackSpeedSheet(ctx, player),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
            ),
            child: Text(
              speedLabel(player.playbackSpeed),
              style: const TextStyle(color: AppTheme.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(
      BuildContext ctx, PlayerProvider player, MediaProvider media) {
    final item = player.currentItem;
    if (item == null) return;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded,
                  color: AppTheme.onSurface),
              title: const Text('File info',
                  style: TextStyle(color: AppTheme.onBackground)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    title: const Text('File Info'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Title: ${item.title}',
                            style: const TextStyle(
                                color: AppTheme.onSurface)),
                        if (item.artist != null)
                          Text('Artist: ${item.artist}',
                              style: const TextStyle(
                                  color: AppTheme.onSurface)),
                        if (item.album != null)
                          Text('Album: ${item.album}',
                              style: const TextStyle(
                                  color: AppTheme.onSurface)),
                        if (item.duration != null)
                          Text(
                              'Duration: ${formatDuration(item.duration!)}',
                              style: const TextStyle(
                                  color: AppTheme.onSurface)),
                        Text('Size: ${formatFileSize(item.path)}',
                            style:
                                const TextStyle(color: AppTheme.onSurface)),
                        Text('Path: ${item.path}',
                            style:
                                const TextStyle(color: AppTheme.onSurface)),
                      ],
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close')),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded, color: AppTheme.onSurface),
              title: const Text('Playback speed',
                  style: TextStyle(color: AppTheme.onBackground)),
              onTap: () {
                Navigator.pop(ctx);
                showPlaybackSpeedSheet(ctx, player);
              },
            ),
            ListTile(
              leading: Icon(
                item.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: AppTheme.orange,
              ),
              title: Text(
                item.isFavourite ? 'Remove from favourites' : 'Add to favourites',
                style: const TextStyle(color: AppTheme.onBackground),
              ),
              onTap: () {
                media.toggleFavourite(item.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
