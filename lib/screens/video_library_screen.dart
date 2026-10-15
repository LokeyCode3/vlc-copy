import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/media_list_tile.dart';
import '../widgets/media_grid_tile.dart';
import '../widgets/sort_button.dart';
import 'video_player_screen.dart';
import '_media_options_sheet.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  bool _gridView = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MediaProvider>().scanDevice();
      });
    }
  }

  List<MediaItem> _sorted(List<MediaItem> items, SettingsProvider s) {
    final list = List<MediaItem>.from(items);
    switch (s.sortBy) {
      case 'date':
        list.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      case 'duration':
        list.sort((a, b) => (a.duration ?? Duration.zero)
            .compareTo(b.duration ?? Duration.zero));
        break;
      default:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return s.sortAscending ? list : list.reversed.toList();
  }

  Future<void> _pickVideoFiles() async {
    final media = context.read<MediaProvider>();
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp', 'ts'],
    );
    if (res.isNotEmpty) {
      final paths = res.map((f) => f.path).whereType<String>().toList();
      await media.addFiles(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<MediaProvider, PlayerProvider, SettingsProvider>(
      builder: (ctx, media, player, settings, _) {
        final items = _sorted(media.videos, settings);
        final currentId = player.currentItem?.id;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(items.isEmpty ? 'Videos' : '${items.length} Videos'),
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
                  tooltip: 'Scan for videos',
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
            child: items.isEmpty
                ? _buildEmpty(context, media)
                : (_gridView
                    ? _buildGrid(items, player, media, currentId)
                    : _buildList(items, player, media, currentId)),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.orange,
            tooltip: 'Add or scan videos',
            onPressed: _pickVideoFiles,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext ctx, MediaProvider media) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(ctx).size.height * 0.15),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_rounded, size: 72, color: AppTheme.subtitle),
                const SizedBox(height: 16),
                const Text('No videos in library',
                    style: TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Videos copied to your device (Downloads, Movies) will appear here automatically.',
                    style: TextStyle(color: AppTheme.subtitle, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => media.scanDevice(),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Scan Device for Videos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    ctx.read<NavigationProvider>().switchTab(0);
                  },
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Browse Device Folders'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildList(List<MediaItem> items, PlayerProvider player,
      MediaProvider media, String? currentId) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, color: AppTheme.divider),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return MediaListTile(
          item: item,
          isPlaying: item.id == currentId,
          onTap: () => _play(ctx, item, items, i, player, media),
          onLongPress: () =>
              showMediaOptionsSheet(ctx, item, media, player),
          trailing: IconButton(
            icon: Icon(
              item.isFavourite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: item.isFavourite ? AppTheme.orange : AppTheme.subtitle,
              size: 20,
            ),
            onPressed: () => media.toggleFavourite(item.id),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<MediaItem> items, PlayerProvider player,
      MediaProvider media, String? currentId) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
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

  Future<void> _play(BuildContext ctx, MediaItem item, List<MediaItem> queue,
      int index, PlayerProvider player, MediaProvider media) async {
    await media.recordPlay(item.id);
    await player.playItem(item, queue: queue, queueIndex: index);
    if (!ctx.mounted) return;
    Navigator.push(ctx,
        MaterialPageRoute(builder: (_) => const VideoPlayerScreen()));
  }
}
