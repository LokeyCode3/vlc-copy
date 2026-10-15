import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../providers/media_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/subtitle_parser.dart';
import '../../utils/blob_utils.dart';

class DesktopMenuBar extends StatelessWidget {
  final VoidCallback onToggleSidebar;
  final bool sidebarVisible;
  final VoidCallback onToggleView; // Toggle playlist vs video
  final bool isVideoView;

  const DesktopMenuBar({
    super.key,
    required this.onToggleSidebar,
    required this.sidebarVisible,
    required this.onToggleView,
    required this.isVideoView,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final media = context.watch<MediaProvider>();
    final settings = context.watch<SettingsProvider>();

    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E7),
        border: Border(
          bottom: BorderSide(color: Color(0xFFC7C7CC), width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Apple / App Icon
          const Icon(Icons.play_circle_fill_rounded,
              color: Color(0xFFFF8800), size: 16),
          const SizedBox(width: 8),

          // VLC Menu
          _buildMenuButton(
            context,
            label: 'ispc player',
            isBold: true,
            items: [
              _menuItem('About ispc player', () => _showAbout(context)),
              const PopupMenuDivider(),
              _menuItem('Preferences...', () => _showPreferences(context),
                  shortcut: '⌘,'),
              const PopupMenuDivider(),
              _menuItem('Hide ispc player', () {}, shortcut: '⌘H'),
              _menuItem('Hide Others', () {}, shortcut: '⌥⌘H'),
              _menuItem('Show All', () {}),
              const PopupMenuDivider(),
              _menuItem('Quit ispc player', () {
                if (!kIsWeb) exit(0);
              }, shortcut: '⌘Q'),
            ],
          ),

          // File Menu
          _buildMenuButton(
            context,
            label: 'File',
            items: [
              _menuItem('Open File...', () => _pickAndOpenFile(context, player),
                  shortcut: '⌘O'),
              _menuItem('Advanced Open File...', () => _pickAndOpenFile(context, player),
                  shortcut: '⇧⌘O'),
              _menuItem('Open Network...', () => _openNetworkStream(context, player),
                  shortcut: '⌘N'),
              _menuItem('Open Capture Device...', () {}, shortcut: '⌘R'),
              const PopupMenuDivider(),
              _menuSubmenu('Open Recent', [
                if (media.history.isEmpty)
                  _subItem('No Recent Files', null, enabled: false)
                else
                  ...media.history.take(6).map(
                        (item) => _subItem(item.title, () {
                          player.playItem(item);
                        }),
                      ),
              ]),
              const PopupMenuDivider(),
              _menuItem('Close Window', () {}, shortcut: '⌘W'),
              _menuItem('Reveal in Finder', () {}, shortcut: '⇧⌘R'),
              const PopupMenuDivider(),
              _menuItem('Convert / Stream...', () {}, shortcut: '⇧⌘S'),
              const PopupMenuDivider(),
              _menuItem('Save Playlist...', () {}, shortcut: '⌘S'),
            ],
          ),

          // Edit Menu
          _buildMenuButton(
            context,
            label: 'Edit',
            items: [
              _menuItem('Cut', () {}, shortcut: '⌘X'),
              _menuItem('Copy', () {}, shortcut: '⌘C'),
              _menuItem('Paste', () {}, shortcut: '⌘V'),
              _menuItem('Select All', () {}, shortcut: '⌘A'),
            ],
          ),

          // View Menu
          _buildMenuButton(
            context,
            label: 'View',
            items: [
              _menuItem('Show Tab Bar', () {}),
              _menuItem('Show All Tabs', () {}, shortcut: '⇧⌘\\'),
              const PopupMenuDivider(),
              _menuItem('Show Previous & Next Buttons', () {}),
              _menuItem('Show Shuffle & Repeat Buttons', () {}),
              _menuItem('Show Audio Effects Button', () {}),
              _menuCheckedItem(
                'Show Sidebar',
                sidebarVisible,
                onToggleSidebar,
              ),
              const PopupMenuDivider(),
              _menuItem(
                isVideoView ? 'Show Playlist' : 'Show Video Screen',
                onToggleView,
                shortcut: '⌘L',
              ),
            ],
          ),

          // Playback Menu
          _buildMenuButton(
            context,
            label: 'Playback',
            items: [
              _menuItem(
                player.isPlaying ? 'Pause' : 'Play',
                () => player.togglePlayPause(),
                shortcut: '⌘P',
              ),
              _menuItem('Stop', () {
                player.pause();
                player.seekTo(Duration.zero);
              }, shortcut: '⌘.'),
              _menuItem('Record', () {}, shortcut: '⌥⌘R'),
              const PopupMenuDivider(),
              _speedSliderItem(context, player),
              const PopupMenuDivider(),
              _menuItem('Step Forward', () => player.seekRelative(const Duration(seconds: 10)),
                  shortcut: '⌥⌘▶'),
              _menuItem('Step Backward', () => player.seekRelative(const Duration(seconds: -10)),
                  shortcut: '⌥⌘◀'),
              _menuItem('Jump to Time...', () => _jumpToTime(context, player),
                  shortcut: '⌘J'),
              const PopupMenuDivider(),
              _menuItem('Previous', () => player.skipPrev(), shortcut: '⌘◀'),
              _menuItem('Next', () => player.skipNext(), shortcut: '⌘▶'),
              _menuCheckedItem('Random', player.shuffle, () => player.toggleShuffle(),
                  shortcut: '⌘Z'),
              _menuItem('Repeat Mode: ${player.repeatMode.name.toUpperCase()}',
                  () => player.cycleRepeatMode()),
            ],
          ),

          // Audio Menu
          _buildMenuButton(
            context,
            label: 'Audio',
            items: [
              _menuItem('Increase Volume', () {
                player.setVolume((player.volume + 0.1).clamp(0.0, 1.0));
              }, shortcut: '⌘▲'),
              _menuItem('Decrease Volume', () {
                player.setVolume((player.volume - 0.1).clamp(0.0, 1.0));
              }, shortcut: '⌘▼'),
              _menuItem('Mute', () {
                player.setVolume(player.volume > 0 ? 0 : 1);
              }, shortcut: '⌥⌘▼'),
              const PopupMenuDivider(),
              _menuSubmenu('Stereo Audio Mode', [
                _subItem('Stereo', () {}),
                _subItem('Left', () {}),
                _subItem('Right', () {}),
                _subItem('Reverse Stereo', () {}),
              ]),
              const PopupMenuDivider(),
              _menuSubmenu('Visualizations', [
                _subItem('Disable', () {}),
                _subItem('Spectrometer', () {}),
                _subItem('Scope', () {}),
                _subItem('Spectrum', () {}),
              ]),
            ],
          ),

          // Video Menu
          _buildMenuButton(
            context,
            label: 'Video',
            items: [
              _menuItem('Fullscreen', () => onToggleView(), shortcut: '⌘F'),
              const PopupMenuDivider(),
              _menuSubmenu('Aspect Ratio', [
                _subItem('Default', () {}),
                _subItem('16:9', () {}),
                _subItem('4:3', () {}),
                _subItem('1:1', () {}),
                _subItem('21:9', () {}),
              ]),
              _menuSubmenu('Crop', [
                _subItem('Default', () {}),
                _subItem('16:9', () {}),
                _subItem('4:3', () {}),
                _subItem('2.39:1', () {}),
              ]),
              _menuItem('Take Snapshot', () {}, shortcut: '⌥⌘S'),
            ],
          ),

          // Subtitles Menu
          _buildMenuButton(
            context,
            label: 'Subtitles',
            items: [
              _menuItem('Add Subtitle File...', () => _addSubtitleFile(context, player)),
              _menuSubmenu(
                'Subtitle Track',
                player.subtitleTracks.isEmpty
                    ? [_subItem('No subtitles in file', null, enabled: false)]
                    : [
                        _subItem(
                          'Off',
                          () => player.disableSubtitles(),
                          isChecked: !player.subtitlesEnabled,
                        ),
                        _subDivider(),
                        ...player.subtitleTracks.map((t) {
                          if (!t.isSupported) {
                            return _subItem(
                              '${t.label} [${(t.codec ?? 'PGS').toUpperCase()} - Unsupported]',
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      t.unsupportedReason ??
                                          'Bitmap subtitle (${t.codec}) requires OCR or video burning.',
                                    ),
                                    backgroundColor: Colors.orange.shade900,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              },
                            );
                          }
                          final isSel = t.id == player.activeSubtitleId && player.subtitlesEnabled;
                          return _subItem(
                            t.label,
                            () => player.selectSubtitleTrack(
                                t.id, player.currentItem?.path ?? ''),
                            isChecked: isSel,
                          );
                        }),
                      ],
              ),
              const PopupMenuDivider(),
              _menuSubmenu('Text Size', [
                _subItem('Normal', () => settings.setSubtitleSize(16), isChecked: settings.subtitleSize == 16),
                _subItem('Large', () => settings.setSubtitleSize(20), isChecked: settings.subtitleSize == 20),
                _subItem('Extra Large', () => settings.setSubtitleSize(24), isChecked: settings.subtitleSize == 24),
              ]),
              _menuSubmenu('Text Color', [
                _subItem('White', () => settings.setSubtitleColor('white'), isChecked: settings.subtitleColor == 'white'),
                _subItem('Yellow', () => settings.setSubtitleColor('yellow'), isChecked: settings.subtitleColor == 'yellow'),
                _subItem('Cyan', () => settings.setSubtitleColor('cyan'), isChecked: settings.subtitleColor == 'cyan'),
                _subItem('Green', () => settings.setSubtitleColor('green'), isChecked: settings.subtitleColor == 'green'),
              ]),
              _menuSubmenu('Outline Thickness', [
                _subItem('None', () => settings.setSubtitleOutline(0.0), isChecked: settings.subtitleOutline == 0.0),
                _subItem('Thin', () => settings.setSubtitleOutline(1.0), isChecked: settings.subtitleOutline == 1.0),
                _subItem('Normal', () => settings.setSubtitleOutline(2.0), isChecked: settings.subtitleOutline == 2.0),
                _subItem('Thick', () => settings.setSubtitleOutline(4.0), isChecked: settings.subtitleOutline == 4.0),
              ]),
              const PopupMenuDivider(),
              _opacitySliderItem(context, settings),
              _menuSubmenu('Background Color', [
                _subItem('None (Transparent)', () => settings.setSubtitleBgColor('transparent'), isChecked: settings.subtitleBgColor == 'transparent'),
                _subItem('Black', () => settings.setSubtitleBgColor('black'), isChecked: settings.subtitleBgColor == 'black'),
                _subItem('Dark Grey', () => settings.setSubtitleBgColor('dark_grey'), isChecked: settings.subtitleBgColor == 'dark_grey'),
              ]),
              const PopupMenuDivider(),
              _menuSubmenu('Teletext', [
                _subItem('Teletext On', () {}),
                _subItem('Page 100', () {}),
              ]),
            ],
          ),

          // Window Menu
          _buildMenuButton(
            context,
            label: 'Window',
            items: [
              _menuItem('Minimize', () {}, shortcut: '⌘M'),
              _menuItem('Minimise All', () {}),
              _menuItem('Zoom', () {}, shortcut: '⌃⌘Z'),
              _menuItem('Fill', () {}, shortcut: '⌃⌘F'),
              _menuItem('Centre', () {}, shortcut: '⌃⌘C'),
              const PopupMenuDivider(),
              _menuSubmenu('Move & Resize', [
                _subItem('Left Half', () {}),
                _subItem('Right Half', () {}),
                _subItem('Top Half', () {}),
                _subItem('Bottom Half', () {}),
              ]),
              _menuIconItem('Full-Screen Tile', Icons.crop_landscape_rounded),
              const PopupMenuDivider(),
              _menuIconItem("Move to Mano's iPad", Icons.tablet_mac_rounded, isInteractive: true),
              const PopupMenuDivider(),
              _menuItem('Main Window...', () {
                if (!isVideoView) onToggleView();
              }, shortcut: '⌥⌘C'),
              _menuItem('Playlist...', () {
                if (isVideoView) onToggleView();
              }, shortcut: '⌥⌘P'),
              _menuItem('Media Information...', () => _showMediaInfo(context, player),
                  shortcut: '⌘I'),
              const PopupMenuDivider(),
              _menuItem('Show Previous Tab', () {}, shortcut: '⌃⇧⇥', enabled: false),
              _menuItem('Show Next Tab', () {}, shortcut: '⌃⇥', enabled: false),
              _menuItem('Move Tab to New Window', () {}, enabled: false),
              _menuItem('Merge All Windows', () {}, enabled: false),
              const PopupMenuDivider(),
              _menuItem('Video Effects...', () => _showVideoEffects(context), shortcut: '⌘E'),
              _menuItem('Audio Effects...', () => _showAudioEffects(context), shortcut: '⇧⌘E'),
              _menuItem('Track Synchronization', () => _showTrackSync(context, player)),
              _menuItem('Bookmarks...', () => _showBookmarks(context, player), shortcut: '⌘B'),
              const PopupMenuDivider(),
              _menuItem('Errors and Warnings...', () => _showMessages(context), shortcut: '⌥⌘M'),
              _menuItem('Messages...', () => _showMessages(context), shortcut: '⇧⌥⌘M'),
              const PopupMenuDivider(),
              _menuItem('Bring All to Front', () {}),
              _menuItem('Remove Window from Set', () {}, enabled: false),
            ],
          ),

          // Help Menu
          _buildMenuButton(
            context,
            label: 'Help',
            items: [
              _searchMenuItem(),
              _menuHelpItem('ispc player Help...', () => _showAbout(context)),
              _menuItem('License', () => _showLicense(context)),
              const PopupMenuDivider(),
              _menuItem('Online Documentation...', () {}),
              _menuItem('Online Forum...', () {}),
              _menuItem('Make a donation...', () {}),
              const PopupMenuDivider(),
              _menuItem('VideoLAN Website...', () {}),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helper builders ────────────────────────────────────────────────────────

  Widget _buildMenuButton(
    BuildContext context, {
    required String label,
    required List<PopupMenuEntry<dynamic>> items,
    bool isBold = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFFF6F6F6),
          elevation: 8,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: PopupMenuButton<dynamic>(
        tooltip: '',
        offset: const Offset(0, 24),
        constraints: const BoxConstraints(minWidth: 190, maxWidth: 220),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFD1D1D6), width: 0.5),
        ),
        itemBuilder: (_) => items,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF1C1C1E),
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<dynamic> _menuItem(
    String label,
    VoidCallback? onTap, {
    String? shortcut,
    bool enabled = true,
  }) {
    return PopupMenuItem<dynamic>(
      enabled: enabled,
      height: 24,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: enabled ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
            ),
          ),
          if (shortcut != null) ...[
            const SizedBox(width: 24),
            Text(
              shortcut,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<dynamic> _menuCheckedItem(
    String label,
    bool isChecked,
    VoidCallback onTap, {
    String? shortcut,
  }) {
    return PopupMenuItem<dynamic>(
      height: 24,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: isChecked
                ? const Icon(Icons.check_rounded, size: 14, color: Color(0xFF007AFF))
                : null,
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1C1C1E)),
            ),
          ),
          if (shortcut != null)
            Text(
              shortcut,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93)),
            ),
        ],
      ),
    );
  }

  PopupMenuEntry<dynamic> _menuSubmenu(String label, List<Widget> subItems) {
    return PopupMenuItem<dynamic>(
      height: 26,
      padding: EdgeInsets.zero,
      child: SubmenuButton(
        alignmentOffset: const Offset(186, -4),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(const Color(0xFFF6F6F6)),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(12),
          shadowColor: WidgetStateProperty.all(Colors.black.withValues(alpha: 0.25)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: Color(0xFFD1D1D6), width: 0.8),
            ),
          ),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 4)),
        ),
        menuChildren: subItems,
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(double.infinity, 26)),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 2)),
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFF007AFF);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return Colors.white;
            }
            return const Color(0xFF1C1C1E);
          }),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subItem(
    String label,
    VoidCallback? onTap, {
    bool isChecked = false,
    bool enabled = true,
  }) {
    return MenuItemButton(
      onPressed: enabled ? onTap : null,
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(160, 24)),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 10, vertical: 3)),
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF007AFF);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (!enabled) return const Color(0xFF8E8E93);
          if (states.contains(WidgetState.hovered)) {
            return Colors.white;
          }
          return const Color(0xFF1C1C1E);
        }),
      ),
      leadingIcon: SizedBox(
        width: 16,
        child: isChecked
            ? const Icon(Icons.check_rounded, size: 14)
            : null,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400),
      ),
    );
  }

  Widget _subDivider() {
    return const Divider(height: 5, thickness: 0.8, color: Color(0xFFE5E5EA));
  }

  PopupMenuItem<dynamic> _opacitySliderItem(BuildContext context, SettingsProvider settings) {
    return PopupMenuItem<dynamic>(
      enabled: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: StatefulBuilder(
        builder: (_, setSs) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Background Opacity',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF1C1C1E)),
                  ),
                  Text(
                    '${(settings.subtitleBgOpacity * 100).round()}%',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 18,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 2,
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: const Color(0xFF007AFF),
                    inactiveTrackColor: const Color(0xFFD1D1D6),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: settings.subtitleBgOpacity,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      settings.setSubtitleBgOpacity(v);
                      setSs(() {});
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PopupMenuItem<dynamic> _speedSliderItem(BuildContext context, PlayerProvider player) {
    return PopupMenuItem<dynamic>(
      enabled: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: StatefulBuilder(
        builder: (_, setSs) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Playback Speed',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF1C1C1E)),
                  ),
                  Text(
                    '${player.playbackSpeed.toStringAsFixed(2)}x',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 18,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 2,
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: const Color(0xFF007AFF),
                    inactiveTrackColor: const Color(0xFFD1D1D6),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: player.playbackSpeed.clamp(0.25, 2.0),
                    min: 0.25,
                    max: 2.0,
                    divisions: 7,
                    onChanged: (v) {
                      player.setPlaybackSpeed(v);
                      setSs(() {});
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PopupMenuItem<dynamic> _menuIconItem(
    String label,
    IconData icon, {
    bool isInteractive = false,
  }) {
    return PopupMenuItem<dynamic>(
      enabled: isInteractive,
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isInteractive ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: isInteractive ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<dynamic> _searchMenuItem() {
    return PopupMenuItem<dynamic>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Container(
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFE3E3E8),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: const Row(
          children: [
            Icon(Icons.search, size: 13, color: Color(0xFF8E8E93)),
            SizedBox(width: 6),
            Text(
              'Search',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<dynamic> _menuHelpItem(String label, VoidCallback onTap) {
    return PopupMenuItem<dynamic>(
      height: 24,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              color: Color(0xFF0A60FF),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.question_mark_rounded, size: 10, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1C1C1E)),
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickAndOpenFile(BuildContext context, PlayerProvider player) async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'mp3', 'wav', 'flac', 'webm', 'm4v'],
      );
      if (res.isNotEmpty) {
        final f = res.first;
        final isAudio = ['mp3', 'wav', 'flac', 'm4a'].contains(f.extension?.toLowerCase());
        final isVid = !isAudio;
        String mediaPath;
        Uint8List? mkvBytes;
        if (kIsWeb) {
          final bytes = await f.readAsBytes();
          final mimeType = isVid ? 'video/${f.extension ?? 'mp4'}' : 'audio/${f.extension ?? 'mp3'}';
          mediaPath = createBlobUrl(bytes, mimeType);
          if (context.mounted) {
            await context.read<MediaProvider>().addWebFile(
              blobUrl: mediaPath,
              name: f.name,
              extension: f.extension ?? '',
              bytes: bytes,
            );
          }
          if (isVid && (f.extension?.toLowerCase() == 'mkv' || f.name.toLowerCase().endsWith('.mkv'))) {
            mkvBytes = bytes;
          }
        } else {
          mediaPath = f.path ?? '';
          if (mediaPath.isEmpty) return;
          if (context.mounted) {
            await context.read<MediaProvider>().addFile(mediaPath);
          }
          if (isVid && mediaPath.toLowerCase().endsWith('.mkv')) {
            try {
              final file = File(mediaPath);
              if (await file.exists()) {
                final raf = await file.open();
                mkvBytes = await raf.read(50 * 1024 * 1024);
                await raf.close();
              }
            } catch (_) {}
          }
        }

        final item = MediaItem(
          id: mediaPath,
          title: f.name,
          path: mediaPath,
          duration: Duration.zero,
          type: isVid ? MediaType.video : MediaType.audio,
          addedAt: DateTime.now(),
        );
        await player.playItem(item);
        if (mkvBytes != null) {
          player.loadMkvSubtitlesFromBytes(mkvBytes, mediaPath);
        }
        if (isVid && !isVideoView) {
          onToggleView();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error opening file: $e');
    }
  }

  Future<void> _addSubtitleFile(BuildContext context, PlayerProvider player) async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub', 'sbv', 'lrc'],
      );
      if (res.isNotEmpty) {
        final f = res.first;
        String content = '';
        if (kIsWeb) {
          final bytes = await f.readAsBytes();
          content = utf8.decode(bytes, allowMalformed: true);
        } else if (f.path != null) {
          final bytes = await File(f.path!).readAsBytes();
          content = utf8.decode(bytes, allowMalformed: true);
        }
        if (content.isNotEmpty) {
          final ext = (f.extension ?? 'srt').toLowerCase();
          final entries = SubtitleParser.parse(content, ext);
          if (entries.isNotEmpty) {
            player.loadExternalSubtitles(entries, f.name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Loaded ${entries.length} subtitles from "${f.name}"')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading subtitle file: $e');
    }
  }

  void _openNetworkStream(BuildContext context, PlayerProvider player) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Open Network Stream', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://example.com/stream.m3u8',
            labelText: 'URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(dCtx);
              if (ctrl.text.trim().isNotEmpty) {
                final url = ctrl.text.trim();
                final item = MediaItem(
                  id: url,
                  title: url.split('/').last,
                  path: url,
                  duration: Duration.zero,
                  type: MediaType.video,
                  addedAt: DateTime.now(),
                );
                player.playItem(item);
              }
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  void _jumpToTime(BuildContext context, PlayerProvider player) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Jump to Time', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g. 15:30 or 01:25:00',
            labelText: 'Time (mm:ss)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(dCtx);
              final p = ctrl.text.trim().split(':');
              if (p.length == 2) {
                final m = int.tryParse(p[0]) ?? 0;
                final s = int.tryParse(p[1]) ?? 0;
                player.seekTo(Duration(minutes: m, seconds: s));
              } else if (p.length == 3) {
                final h = int.tryParse(p[0]) ?? 0;
                final m = int.tryParse(p[1]) ?? 0;
                final s = int.tryParse(p[2]) ?? 0;
                player.seekTo(Duration(hours: h, minutes: m, seconds: s));
              }
            },
            child: const Text('Jump'),
          ),
        ],
      ),
    );
  }

  void _showMediaInfo(BuildContext context, PlayerProvider player) {
    final item = player.currentItem;
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Media Information', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${item?.title ?? 'None'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Path: ${item?.path ?? 'None'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text('Duration: ${item?.duration?.inMinutes ?? 0} mins'),
            Text('Subtitle Tracks: ${player.subtitleTracks.length} available'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'ispc player',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF8800), size: 40),
      children: const [
        Text('ispc player is a powerful cross-platform multimedia player.'),
      ],
    );
  }

  void _showPreferences(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Interface: macOS Classic Light/Dark'),
              SizedBox(height: 8),
              Text('Audio: Output Device CoreAudio (Default)'),
              SizedBox(height: 8),
              Text('Video: Hardware-accelerated decoding enabled'),
              SizedBox(height: 8),
              Text('Subtitles: Auto-detect sidecar and embedded tracks'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Save')),
          FilledButton(onPressed: () => Navigator.pop(dCtx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showLicense(BuildContext context) {
    showLicensePage(context: context, applicationName: 'ispc player');
  }

  void _showVideoEffects(BuildContext context) {
    double brightness = 1.0;
    double contrast = 1.0;
    double saturation = 1.0;
    double gamma = 1.0;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: Color(0xFF007AFF)),
              SizedBox(width: 8),
              Text('Video Effects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sliderRow('Brightness', brightness, 0.5, 2.0, (v) => setDs(() => brightness = v)),
                _sliderRow('Contrast', contrast, 0.5, 2.0, (v) => setDs(() => contrast = v)),
                _sliderRow('Saturation', saturation, 0.0, 2.0, (v) => setDs(() => saturation = v)),
                _sliderRow('Gamma', gamma, 0.5, 2.0, (v) => setDs(() => gamma = v)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDs(() {
                brightness = 1.0;
                contrast = 1.0;
                saturation = 1.0;
                gamma = 1.0;
              }),
              child: const Text('Reset'),
            ),
            FilledButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _showAudioEffects(BuildContext context) {
    bool eqEnabled = true;
    final bands = [0.0, 1.2, 0.5, -0.5, 0.0, 2.0, 1.5, 0.0, -1.0, 0.5];
    final labels = ['60Hz', '170Hz', '310Hz', '600Hz', '1kHz', '3kHz', '6kHz', '12kHz', '14kHz', '16kHz'];

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.equalizer_rounded, size: 20, color: Color(0xFF007AFF)),
              SizedBox(width: 8),
              Text('Audio Effects & Equalizer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Checkbox(value: eqEnabled, onChanged: (v) => setDs(() => eqEnabled = v ?? true)),
                    const Text('Enable Equalizer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Text('Preset: ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D1D6)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Flat / Default', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(10, (i) {
                      return Column(
                        children: [
                          Text('${bands[i] > 0 ? '+' : ''}${bands[i].toStringAsFixed(1)}dB',
                              style: const TextStyle(fontSize: 9, color: Colors.black54)),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                  trackHeight: 2,
                                  overlayShape: SliderComponentShape.noOverlay,
                                ),
                                child: Slider(
                                  value: bands[i],
                                  min: -10.0,
                                  max: 10.0,
                                  activeColor: const Color(0xFF007AFF),
                                  onChanged: eqEnabled ? (v) => setDs(() => bands[i] = v) : null,
                                ),
                              ),
                            ),
                          ),
                          Text(labels[i], style: const TextStyle(fontSize: 9, color: Colors.black87)),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setDs(() {
                for (var i = 0; i < bands.length; i++) {
                  bands[i] = 0.0;
                }
              }),
              child: const Text('Reset'),
            ),
            FilledButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _showTrackSync(BuildContext context, PlayerProvider player) {
    double audioDelay = 0.0;
    double subDelay = 0.0;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('Track Synchronization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Audio / Video', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Audio track synchronization:', style: TextStyle(fontSize: 12.5)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: () => setDs(() => audioDelay -= 0.1),
                        ),
                        Text('${audioDelay.toStringAsFixed(1)} s', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () => setDs(() => audioDelay += 0.1),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                const Text('Subtitles / Video', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF007AFF))),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtitle track synchronization:', style: TextStyle(fontSize: 12.5)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: () => setDs(() => subDelay -= 0.1),
                        ),
                        Text('${subDelay.toStringAsFixed(1)} s', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () => setDs(() => subDelay += 0.1),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _showBookmarks(BuildContext context, PlayerProvider player) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Bookmarks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD1D1D6)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('No bookmarks saved for this media.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      final pos = player.position;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added bookmark at ${pos.inMinutes}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}')),
                      );
                      Navigator.pop(dCtx);
                    },
                    child: const Text('Add Bookmark'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showMessages(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Messages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          height: 220,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const SingleChildScrollView(
              child: Text(
                '[main] info: ispc player 1.0.0\n'
                '[core] info: using interface module "macosx"\n'
                '[audio] info: coreaudio output initialized\n'
                '[video] info: Hardware decoding acceleration enabled\n'
                '[subtitles] info: 14 embedded subtitle tracks ready',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF4AF626)),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Clear')),
          FilledButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Close')),
        ],
      ),
    );
  }

  static Widget _sliderRow(String label, double val, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12.5))),
          Expanded(
            child: Slider(
              value: val,
              min: min,
              max: max,
              activeColor: const Color(0xFF007AFF),
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 40, child: Text(val.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5))),
        ],
      ),
    );
  }
}

