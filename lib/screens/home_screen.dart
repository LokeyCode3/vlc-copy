import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../utils/platform_utils.dart';
import 'desktop/desktop_vlc_screen.dart';
import 'video_library_screen.dart';
import 'audio_library_screen.dart';
import 'playlists_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'browse_screen.dart';
import '../widgets/mini_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _screens = <Widget>[
    BrowseScreen(),
    VideoLibraryScreen(),
    AudioLibraryScreen(),
    PlaylistsScreen(),
    HistoryScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder_rounded),
      label: 'Browse',
    ),
    NavigationDestination(
      icon: Icon(Icons.videocam_outlined),
      selectedIcon: Icon(Icons.videocam_rounded),
      label: 'Video',
    ),
    NavigationDestination(
      icon: Icon(Icons.music_note_outlined),
      selectedIcon: Icon(Icons.music_note_rounded),
      label: 'Audio',
    ),
    NavigationDestination(
      icon: Icon(Icons.playlist_play_outlined),
      selectedIcon: Icon(Icons.playlist_play_rounded),
      label: 'Playlists',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history_rounded),
      label: 'History',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<MediaProvider>().scanDevice();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isDesktop(context)) {
      return const DesktopVlcScreen();
    }

    final nav = context.watch<NavigationProvider>();
    final selectedIndex = nav.selectedIndex;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/images/vlc_logo.png',
              errorBuilder: (_, __, ___) => const Icon(
                    Icons.play_circle_fill,
                    color: AppTheme.orange,
                    size: 28,
                  )),
        ),
        title: const Text('ISPC Player'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _screens[selectedIndex]),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => nav.switchTab(i),
        destinations: _destinations,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: _MediaSearchDelegate(
          context.read<MediaProvider>(), context.read<PlayerProvider>()),
    );
  }
}

// ── Search ─────────────────────────────────────────────────────────────────

class _MediaSearchDelegate extends SearchDelegate<String> {
  final MediaProvider _media;
  final PlayerProvider _player;

  _MediaSearchDelegate(this._media, this._player);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.surface,
        iconTheme: IconThemeData(color: AppTheme.onBackground),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppTheme.subtitle),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = _media.search(query);
    if (query.isEmpty) {
      return const Center(
          child: Text('Type to search…',
              style: TextStyle(color: AppTheme.subtitle)));
    }
    if (results.isEmpty) {
      return const Center(
          child: Text('No results',
              style: TextStyle(color: AppTheme.subtitle)));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final item = results[i];
        return ListTile(
          leading: Icon(
            item.type == MediaType.video
                ? Icons.videocam_rounded
                : Icons.music_note_rounded,
            color: AppTheme.orange,
          ),
          title: Text(item.title,
              style: const TextStyle(color: AppTheme.onBackground)),
          subtitle:
              item.artist != null ? Text(item.artist!) : null,
          onTap: () {
            close(ctx, item.id);
            _player.playItem(item, queue: [item]);
          },
        );
      },
    );
  }
}
