import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/media_list_tile.dart';
import '../widgets/media_grid_tile.dart';
import '../widgets/sort_button.dart';
import 'audio_player_screen.dart';
import '_media_options_sheet.dart';

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen>
    with SingleTickerProviderStateMixin {
  bool _gridView = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<MediaItem> _sorted(List<MediaItem> items, SettingsProvider s) {
    final list = List<MediaItem>.from(items);
    switch (s.sortBy) {
      case 'date':
        list.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      default:
        list.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return s.sortAscending ? list : list.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<MediaProvider, PlayerProvider, SettingsProvider>(
      builder: (ctx, media, player, settings, _) {
        final allAudio = _sorted(media.audio, settings);
        final artists = <String, List<MediaItem>>{};
        final albums = <String, List<MediaItem>>{};
        for (final a in allAudio) {
          if (a.artist != null && a.artist!.isNotEmpty) {
            artists.putIfAbsent(a.artist!, () => []).add(a);
          }
          if (a.album != null && a.album!.isNotEmpty) {
            albums.putIfAbsent(a.album!, () => []).add(a);
          }
        }

        final currentId = player.currentItem?.id;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text('${allAudio.length} Tracks'),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.orange,
              unselectedLabelColor: AppTheme.subtitle,
              indicatorColor: AppTheme.orange,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Artists'),
                Tab(text: 'Albums'),
              ],
            ),
            actions: [
              if (media.isScanning)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.orange),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Scan for audio',
                  onPressed: () => media.scanDevice(),
                ),
              SortButton(settings: settings),
              IconButton(
                icon: Icon(_gridView
                    ? Icons.list_rounded
                    : Icons.grid_view_rounded),
                onPressed: () => setState(() => _gridView = !_gridView),
              ),
            ],
          ),
          body: RefreshIndicator(
            color: AppTheme.orange,
            onRefresh: () => media.scanDevice(),
            child: TabBarView(
              controller: _tabController,
              children: [
                allAudio.isEmpty
                    ? _buildEmpty()
                    : _gridView
                        ? _buildGrid(allAudio, player, media, currentId, ctx)
                        : _buildTrackList(allAudio, player, media, currentId, ctx),
                _buildGroupList(artists, media, player, ctx),
                _buildGroupList(albums, media, player, ctx),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.music_off_rounded, size: 72, color: AppTheme.subtitle),
          SizedBox(height: 16),
          Text('No audio yet', style: TextStyle(color: AppTheme.onSurface)),
          SizedBox(height: 8),
          Text('Browse files to add audio',
              style: TextStyle(color: AppTheme.subtitle)),
        ]),
      );

  Widget _buildTrackList(List<MediaItem> items, PlayerProvider player,
      MediaProvider media, String? currentId, BuildContext ctx) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, color: AppTheme.divider),
      itemBuilder: (context, i) {
        final item = items[i];
        return MediaListTile(
          item: item,
          isPlaying: item.id == currentId,
          onTap: () => _play(ctx, item, items, i, player, media),
          onLongPress: () =>
              showMediaOptionsSheet(ctx, item, media, player),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.subtitle, size: 18),
            onSelected: (val) async {
              if (val == 'fav') await media.toggleFavourite(item.id);
              if (val == 'remove') await media.removeFromLibrary(item.id);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'fav',
                child: Text(item.isFavourite
                    ? 'Remove favourite'
                    : 'Add to favourites'),
              ),
              const PopupMenuItem(
                  value: 'remove', child: Text('Remove from library')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<MediaItem> items, PlayerProvider player,
      MediaProvider media, String? currentId, BuildContext ctx) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return MediaGridTile(
          item: item,
          isPlaying: item.id == currentId,
          onTap: () => _play(ctx, item, items, i, player, media),
          onLongPress: () =>
              showMediaOptionsSheet(ctx, item, media, player),
        );
      },
    );
  }

  Widget _buildGroupList(Map<String, List<MediaItem>> groups,
      MediaProvider media, PlayerProvider player, BuildContext ctx) {
    if (groups.isEmpty) return _buildEmpty();
    final keys = groups.keys.toList()..sort();
    return ListView.separated(
      itemCount: keys.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, color: AppTheme.divider),
      itemBuilder: (context, i) {
        final key = keys[i];
        final items = groups[key]!;
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.music_note_rounded,
                color: AppTheme.orange, size: 22),
          ),
          title:
              Text(key, style: const TextStyle(color: AppTheme.onBackground)),
          subtitle: Text('${items.length} tracks',
              style: const TextStyle(color: AppTheme.subtitle, fontSize: 12)),
          onTap: () {
            _play(ctx, items.first, items, 0, player, media);
          },
        );
      },
    );
  }

  Future<void> _play(BuildContext ctx, MediaItem item, List<MediaItem> queue,
      int index, PlayerProvider player, MediaProvider media) async {
    await media.recordPlay(item.id);
    await player.playItem(item, queue: queue, queueIndex: index);
    if (!ctx.mounted) return;
    Navigator.push(
        ctx, MaterialPageRoute(builder: (_) => const AudioPlayerScreen()));
  }
}
