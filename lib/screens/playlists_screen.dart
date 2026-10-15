import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../providers/media_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/media_list_tile.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';
import '_media_options_sheet.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProvider>(
      builder: (ctx, media, _) {
        final playlists = media.playlists;
        final favourites = media.favourites;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Playlists'),
              bottom: const TabBar(
                labelColor: AppTheme.orange,
                unselectedLabelColor: AppTheme.subtitle,
                indicatorColor: AppTheme.orange,
                tabs: [
                  Tab(text: 'Playlists'),
                  Tab(text: 'Favourites'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _createPlaylist(ctx, media),
                ),
              ],
            ),
            body: TabBarView(
              children: [
                _PlaylistTab(playlists: playlists, media: media),
                _FavouritesTab(items: favourites, media: media),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createPlaylist(BuildContext ctx, MediaProvider media) async {
    String name = '';
    final result = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, name),
              child: const Text('Create')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await media.createPlaylist(result);
    }
  }
}

class _PlaylistTab extends StatelessWidget {
  final List<Playlist> playlists;
  final MediaProvider media;

  const _PlaylistTab({required this.playlists, required this.media});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.playlist_play_rounded, size: 72, color: AppTheme.subtitle),
          SizedBox(height: 16),
          Text('No playlists yet',
              style: TextStyle(color: AppTheme.onSurface)),
          SizedBox(height: 8),
          Text('Tap + to create a playlist',
              style: TextStyle(color: AppTheme.subtitle)),
        ]),
      );
    }
    return ListView.separated(
      itemCount: playlists.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, color: AppTheme.divider),
      itemBuilder: (ctx, i) {
        final pl = playlists[i];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.playlist_play_rounded,
                color: AppTheme.orange, size: 26),
          ),
          title: Text(pl.name,
              style: const TextStyle(color: AppTheme.onBackground)),
          subtitle: Text('${pl.count} items · ${formatDate(pl.updatedAt)}',
              style: const TextStyle(color: AppTheme.subtitle, fontSize: 12)),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.subtitle),
            onSelected: (val) async {
              if (val == 'rename') {
                final name = await _promptRename(ctx, pl.name);
                if (name != null && name.isNotEmpty) {
                  await media.renamePlaylist(pl.id, name);
                }
              } else if (val == 'delete') {
                await media.deletePlaylist(pl.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: Colors.redAccent))),
            ],
          ),
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) =>
                  PlaylistDetailScreen(playlistId: pl.id),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _promptRename(BuildContext ctx, String current) async {
    String name = current;
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Rename Playlist'),
        content: TextFormField(
          initialValue: current,
          autofocus: true,
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, name),
              child: const Text('Save')),
        ],
      ),
    );
  }
}

class _FavouritesTab extends StatelessWidget {
  final List<MediaItem> items;
  final MediaProvider media;

  const _FavouritesTab({required this.items, required this.media});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.favorite_border_rounded,
              size: 72, color: AppTheme.subtitle),
          SizedBox(height: 16),
          Text('No favourites yet',
              style: TextStyle(color: AppTheme.onSurface)),
          SizedBox(height: 8),
          Text('Tap the heart icon on any media',
              style: TextStyle(color: AppTheme.subtitle)),
        ]),
      );
    }
    final player = context.read<PlayerProvider>();
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, color: AppTheme.divider),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return MediaListTile(
          item: item,
          isPlaying: player.currentItem?.id == item.id,
          onTap: () async {
            await media.recordPlay(item.id);
            await player.playItem(item, queue: items, queueIndex: i);
            if (!ctx.mounted) return;
            Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => item.type == MediaType.video
                    ? const VideoPlayerScreen()
                    : const AudioPlayerScreen(),
              ),
            );
          },
          onLongPress: () =>
              showMediaOptionsSheet(ctx, item, media, player),
          trailing: IconButton(
            icon: const Icon(Icons.favorite_rounded,
                color: AppTheme.orange, size: 20),
            onPressed: () => media.toggleFavourite(item.id),
          ),
        );
      },
    );
  }
}

// ── Playlist Detail ───────────────────────────────────────────────────────────

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<MediaProvider, PlayerProvider>(
      builder: (ctx, media, player, _) {
        final pl = media.playlists.firstWhere(
          (p) => p.id == playlistId,
          orElse: () => Playlist(
            id: '',
            name: 'Not found',
            mediaIds: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        final items = media.getPlaylistItems(playlistId);
        final currentId = player.currentItem?.id;

        return Scaffold(
          appBar: AppBar(
            title: Text(pl.name),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.shuffle_rounded),
                  onPressed: () async {
                    player.toggleShuffle();
                    await media.recordPlay(items.first.id);
                    await player.playItem(items.first,
                        queue: items, queueIndex: 0);
                    if (!ctx.mounted) return;
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => items.first.type == MediaType.video
                            ? const VideoPlayerScreen()
                            : const AudioPlayerScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: items.isEmpty
              ? const Center(
                  child: Text('No items in this playlist',
                      style: TextStyle(color: AppTheme.subtitle)),
                )
              : ReorderableListView.builder(
                  itemCount: items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    media.reorderPlaylist(playlistId, oldIndex, newIndex);
                  },
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_rounded,
                            color: Colors.white),
                      ),
                      onDismissed: (_) =>
                          media.removeFromPlaylist(playlistId, item.id),
                      child: MediaListTile(
                        key: ValueKey(item.id),
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
                              builder: (_) =>
                                  item.type == MediaType.video
                                      ? const VideoPlayerScreen()
                                      : const AudioPlayerScreen(),
                            ),
                          );
                        },
                        onLongPress: () =>
                            showMediaOptionsSheet(context, item, media, player),
                        trailing: const Icon(Icons.drag_handle_rounded,
                            color: AppTheme.subtitle),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
