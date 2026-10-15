import 'package:flutter/material.dart';
import '../providers/player_provider.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

Future<void> showQueueSheet(BuildContext context, PlayerProvider player) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _QueueSheet(player: player),
  );
}

class _QueueSheet extends StatelessWidget {
  final PlayerProvider player;

  const _QueueSheet({required this.player});

  @override
  Widget build(BuildContext context) {
    final queue = player.queue;
    final currentIndex = player.queueIndex;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.subtitle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded, color: AppTheme.orange),
                const SizedBox(width: 8),
                Text(
                  '${queue.length} items in queue',
                  style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          // List
          Expanded(
            child: queue.isEmpty
                ? const Center(
                    child: Text('Queue is empty',
                        style: TextStyle(color: AppTheme.subtitle)),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: queue.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0, color: AppTheme.divider),
                    itemBuilder: (ctx, i) {
                      final item = queue[i];
                      final isCurrent = i == currentIndex;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                            border: isCurrent
                                ? Border.all(
                                    color: AppTheme.orange, width: 1.5)
                                : null,
                          ),
                          child: isCurrent
                              ? const Icon(Icons.equalizer,
                                  color: AppTheme.orange, size: 18)
                              : Icon(
                                  item.type == MediaType.video
                                      ? Icons.videocam_rounded
                                      : Icons.music_note_rounded,
                                  color: AppTheme.subtitle,
                                  size: 18,
                                ),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: isCurrent
                                ? AppTheme.orange
                                : AppTheme.onBackground,
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: item.duration != null
                            ? Text(
                                formatDuration(item.duration!),
                                style: const TextStyle(
                                    color: AppTheme.subtitle, fontSize: 11),
                              )
                            : null,
                        trailing: isCurrent
                            ? const SizedBox(
                                width: 8,
                                height: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppTheme.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          player.jumpToIndex(i);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
