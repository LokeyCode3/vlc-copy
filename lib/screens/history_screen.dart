import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/media_list_tile.dart';
import 'video_player_screen.dart';
import 'audio_player_screen.dart';
import '_media_options_sheet.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MediaProvider, PlayerProvider>(
      builder: (ctx, media, player, _) {
        final items = media.history;
        final currentId = player.currentItem?.id;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('${items.length} Recently Played'),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'Clear history',
                  onPressed: () => _confirmClear(ctx, media),
                ),
            ],
          ),
          body: items.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history_rounded,
                        size: 72, color: AppTheme.subtitle),
                    SizedBox(height: 16),
                    Text('No history yet',
                        style: TextStyle(color: AppTheme.onSurface)),
                    SizedBox(height: 8),
                    Text('Play some media to see it here',
                        style: TextStyle(color: AppTheme.subtitle)),
                  ]),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 0, color: AppTheme.divider),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return MediaListTile(
                      item: item,
                      isPlaying: item.id == currentId,
                      onTap: () async {
                        await media.recordPlay(item.id);
                        await player.playItem(item,
                            queue: items, queueIndex: i);
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => item.type == MediaType.video
                                ? const VideoPlayerScreen()
                                : const AudioPlayerScreen(),
                          ),
                        );
                      },
                      onLongPress: () =>
                          showMediaOptionsSheet(context, item, media, player),
                      trailing: item.lastPlayed != null
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                formatDate(item.lastPlayed!),
                                style: const TextStyle(
                                    color: AppTheme.subtitle, fontSize: 11),
                              ),
                            )
                          : null,
                    );
                  },
                ),
        );
      },
    );
  }

  void _confirmClear(BuildContext ctx, MediaProvider media) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Remove all playback history?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              media.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
