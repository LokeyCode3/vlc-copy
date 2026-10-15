import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'video_player_screen.dart';
import 'audio_player_screen.dart';

Future<void> showMediaOptionsSheet(
  BuildContext context,
  MediaItem item,
  MediaProvider media,
  PlayerProvider player,
) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MediaOptionsSheet(
      item: item,
      media: media,
      player: player,
    ),
  );
}

class _MediaOptionsSheet extends StatelessWidget {
  final MediaItem item;
  final MediaProvider media;
  final PlayerProvider player;

  const _MediaOptionsSheet({
    required this.item,
    required this.media,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    item.type == MediaType.video
                        ? Icons.videocam_rounded
                        : Icons.music_note_rounded,
                    color: AppTheme.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                              color: AppTheme.onBackground,
                              fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (item.duration != null)
                        Text(formatDuration(item.duration!),
                            style: const TextStyle(
                                color: AppTheme.subtitle, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider),
          // Play
          ListTile(
            leading: const Icon(Icons.play_arrow_rounded, color: AppTheme.orange),
            title: const Text('Play', style: TextStyle(color: AppTheme.onBackground)),
            onTap: () async {
              Navigator.pop(context);
              await media.recordPlay(item.id);
              await player.playItem(item, queue: [item]);
              if (!context.mounted) return;
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => item.type == MediaType.video
                          ? const VideoPlayerScreen()
                          : const AudioPlayerScreen()));
            },
          ),
          // Queue next
          ListTile(
            leading: const Icon(Icons.queue_play_next_rounded,
                color: AppTheme.onSurface),
            title: const Text('Play next',
                style: TextStyle(color: AppTheme.onBackground)),
            onTap: () {
              Navigator.pop(context);
              final q = List<MediaItem>.from(player.queue);
              final idx = player.queueIndex;
              if (q.isEmpty) {
                player.playItem(item, queue: [item]);
              } else {
                q.insert(idx + 1, item);
                player.setQueue(q, startIndex: player.queueIndex);
              }
            },
          ),
          // Favourite
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
              Navigator.pop(context);
            },
          ),
          // Add to playlist
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded,
                color: AppTheme.onSurface),
            title: const Text('Add to playlist',
                style: TextStyle(color: AppTheme.onBackground)),
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylist(context, item, media);
            },
          ),
          // File info
          ListTile(
            leading:
                const Icon(Icons.info_outline_rounded, color: AppTheme.onSurface),
            title: const Text('Info',
                style: TextStyle(color: AppTheme.onBackground)),
            onTap: () {
              Navigator.pop(context);
              _showInfo(context, item);
            },
          ),
          // Remove
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            title: const Text('Remove from library',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              media.removeFromLibrary(item.id);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAddToPlaylist(
      BuildContext context, MediaItem item, MediaProvider media) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddToPlaylistSheet(item: item, media: media),
    );
  }

  void _showInfo(BuildContext context, MediaItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('File Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Title', item.title),
            if (item.artist != null) _infoRow('Artist', item.artist!),
            if (item.album != null) _infoRow('Album', item.album!),
            if (item.duration != null)
              _infoRow('Duration', formatDuration(item.duration!)),
            _infoRow('Size', formatFileSize(item.path)),
            _infoRow('Path', item.path),
            _infoRow('Added', formatDate(item.addedAt)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    color: AppTheme.subtitle, fontWeight: FontWeight.w600)),
            TextSpan(
                text: value,
                style: const TextStyle(color: AppTheme.onBackground)),
          ]),
        ),
      );
}

class _AddToPlaylistSheet extends StatelessWidget {
  final MediaItem item;
  final MediaProvider media;

  const _AddToPlaylistSheet({required this.item, required this.media});

  @override
  Widget build(BuildContext context) {
    final playlists = media.playlists;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Add to playlist',
                style: TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          const Divider(color: AppTheme.divider),
          ListTile(
            leading: const Icon(Icons.add_rounded, color: AppTheme.orange),
            title: const Text('New playlist',
                style: TextStyle(color: AppTheme.orange)),
            onTap: () async {
              Navigator.pop(context);
              final name = await _promptName(context);
              if (name == null || name.isEmpty) return;
              final pl = await media.createPlaylist(name);
              await media.addToPlaylist(pl.id, item.id);
            },
          ),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No playlists yet',
                  style: TextStyle(color: AppTheme.subtitle)),
            )
          else
            ...playlists.map(
              (pl) => ListTile(
                leading:
                    const Icon(Icons.playlist_play_rounded, color: AppTheme.onSurface),
                title: Text(pl.name,
                    style: const TextStyle(color: AppTheme.onBackground)),
                subtitle: Text('${pl.count} items',
                    style: const TextStyle(
                        color: AppTheme.subtitle, fontSize: 12)),
                trailing: pl.mediaIds.contains(item.id)
                    ? const Icon(Icons.check_rounded, color: AppTheme.orange)
                    : null,
                onTap: () {
                  if (!pl.mediaIds.contains(item.id)) {
                    media.addToPlaylist(pl.id, item.id);
                  }
                  Navigator.pop(context);
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<String?> _promptName(BuildContext context) async {
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, name),
              child: const Text('Create')),
        ],
      ),
    );
  }
}
