import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/player_provider.dart';

enum DesktopSidebarSection {
  playlist,
  mediaLibrary,
  myVideos,
  myMusic,
  myPictures,
  bonjour,
  upnp,
  sap,
  podcasts,
  jamendo,
  icecast,
}

class DesktopSidebar extends StatelessWidget {
  final DesktopSidebarSection currentSection;
  final ValueChanged<DesktopSidebarSection> onSectionChanged;

  const DesktopSidebar({
    super.key,
    required this.currentSection,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaProvider>();
    final player = context.watch<PlayerProvider>();

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFFE8E8EC),
        border: Border(
          right: BorderSide(color: Color(0xFFC7C7CC), width: 1.0),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildHeader('LIBRARY'),
          _buildItem(
            section: DesktopSidebarSection.playlist,
            icon: Icons.queue_music_rounded,
            label: 'Playlist',
            badgeCount: player.queue.isNotEmpty
                ? player.queue.length
                : (media.videos.isNotEmpty ? media.videos.length : null),
          ),
          _buildItem(
            section: DesktopSidebarSection.mediaLibrary,
            icon: Icons.video_library_outlined,
            label: 'Media Library',
            badgeCount: media.videos.length + media.audio.length,
          ),
          const SizedBox(height: 12),
          _buildHeader('MY COMPUTER'),
          _buildItem(
            section: DesktopSidebarSection.myVideos,
            icon: Icons.movie_outlined,
            label: 'My Videos',
            badgeCount: media.videos.length,
          ),
          _buildItem(
            section: DesktopSidebarSection.myMusic,
            icon: Icons.music_note_rounded,
            label: 'My Music',
            badgeCount: media.audio.length,
          ),
          _buildItem(
            section: DesktopSidebarSection.myPictures,
            icon: Icons.photo_library_outlined,
            label: 'My Pictures',
          ),
          const SizedBox(height: 12),
          _buildHeader('LOCAL NETWORK'),
          _buildItem(
            section: DesktopSidebarSection.bonjour,
            icon: Icons.language_rounded,
            label: 'Bonjour Network Discovery',
          ),
          _buildItem(
            section: DesktopSidebarSection.upnp,
            icon: Icons.router_outlined,
            label: "Universal Plug'n'Play",
          ),
          _buildItem(
            section: DesktopSidebarSection.sap,
            icon: Icons.cell_tower_rounded,
            label: 'Network streams (SAP)',
          ),
          const SizedBox(height: 12),
          _buildHeader('INTERNET'),
          _buildItem(
            section: DesktopSidebarSection.podcasts,
            icon: Icons.podcasts_rounded,
            label: 'Podcasts',
          ),
          _buildItem(
            section: DesktopSidebarSection.jamendo,
            icon: Icons.graphic_eq_rounded,
            label: 'Jamendo Selections',
          ),
          _buildItem(
            section: DesktopSidebarSection.icecast,
            icon: Icons.radio_rounded,
            label: 'Icecast Radio Directory',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6E6E73),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildItem({
    required DesktopSidebarSection section,
    required IconData icon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = currentSection == section;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: () => onSectionChanged(section),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD2D2D7) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFF3C3C43),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFF1C1C1E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount != null && badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFB0B0B8)
                        : const Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3A3A3C),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
