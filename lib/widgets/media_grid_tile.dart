import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class MediaGridTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;

  const MediaGridTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: isPlaying
              ? Border.all(color: AppTheme.orange, width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      item.type == MediaType.video
                          ? Icons.videocam_rounded
                          : Icons.music_note_rounded,
                      color: isPlaying ? AppTheme.orange : AppTheme.subtitle,
                      size: 40,
                    ),
                    if (isPlaying)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppTheme.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.equalizer,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    if (item.duration != null)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            formatDuration(item.duration!),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    if (item.isFavourite)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(Icons.favorite,
                            size: 14, color: AppTheme.orange.withValues(alpha: 0.9)),
                      ),
                  ],
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isPlaying
                          ? AppTheme.orange
                          : AppTheme.onBackground,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.artist != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.artist!,
                        style: const TextStyle(
                            color: AppTheme.subtitle, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
