import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class MediaListTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool isPlaying;

  const MediaListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.trailing,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
                border: isPlaying
                    ? Border.all(color: AppTheme.orange, width: 2)
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    item.type == MediaType.video
                        ? Icons.videocam_rounded
                        : Icons.music_note_rounded,
                    color: isPlaying ? AppTheme.orange : AppTheme.subtitle,
                    size: 26,
                  ),
                  if (isPlaying)
                    Positioned(
                      bottom: 3,
                      right: 3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppTheme.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow,
                            size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: isPlaying ? AppTheme.orange : AppTheme.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (item.artist != null) ...[
                        Text(item.artist!,
                            style: const TextStyle(
                                color: AppTheme.onSurface, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const Text(' · ',
                            style: TextStyle(
                                color: AppTheme.subtitle, fontSize: 12)),
                      ],
                      if (item.duration != null)
                        Text(
                          formatDuration(item.duration!),
                          style: const TextStyle(
                              color: AppTheme.subtitle, fontSize: 12),
                        ),
                    ],
                  ),
                  if (item.lastPosition != null &&
                      item.duration != null &&
                      item.duration!.inSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(
                        value: (item.lastPosition!.inMilliseconds /
                                item.duration!.inMilliseconds)
                            .clamp(0.0, 1.0),
                        minHeight: 2,
                        backgroundColor: Colors.white10,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppTheme.orange),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
