import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../providers/media_provider.dart';
import '../../providers/player_provider.dart';

class DesktopPlaylistTable extends StatefulWidget {
  final ValueChanged<MediaItem> onPlayItem;
  final String title;

  const DesktopPlaylistTable({
    super.key,
    required this.onPlayItem,
    this.title = 'Playlist',
  });

  @override
  State<DesktopPlaylistTable> createState() => _DesktopPlaylistTableState();
}

class _DesktopPlaylistTableState extends State<DesktopPlaylistTable> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _selectedRowIndex = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaProvider>();
    final player = context.watch<PlayerProvider>();

    // Use player queue if available, otherwise videos from media provider
    final items = player.queue.isNotEmpty ? player.queue : media.videos;
    final query = _searchCtrl.text.toLowerCase().trim();
    final filtered = query.isEmpty
        ? items
        : items.where((i) => i.title.toLowerCase().contains(query)).toList();

    // Calculate total duration
    final totalDuration = filtered.fold<Duration>(
      Duration.zero,
      (prev, item) => prev + (item.duration ?? Duration.zero),
    );

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Subheader: Playlist title & duration on left, search on right
          Container(
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFEBEBEF),
              border: Border(
                bottom: BorderSide(color: Color(0xFFC7C7CC), width: 0.8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Text(
                  '${widget.title} — ${_formatDuration(totalDuration)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A3A3C),
                  ),
                ),
                const Spacer(),
                // Search box
                Container(
                  width: 170,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFC7C7CC), width: 0.8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 13, color: Color(0xFF8E8E93)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                          decoration: const InputDecoration(
                            hintText: 'Search',
                            hintStyle: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                          child: const Icon(Icons.close_rounded,
                              size: 12, color: Color(0xFF8E8E93)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table column header
          Container(
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              border: Border(
                bottom: BorderSide(color: Color(0xFFD1D1D6), width: 0.8),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'Title',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF636366),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Author',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF636366),
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Duration',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF636366),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table list with zebra striping
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No media in playlist. Drag files here or choose File > Open File.',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final isCurrentPlaying = player.currentItem?.id == item.id;
                      final isSelected = _selectedRowIndex == i;
                      // Alternate background zebra stripe
                      final isEven = i % 2 == 0;
                      final rowBg = isSelected
                          ? const Color(0xFF0A60FF) // Classic macOS selection blue
                          : (isEven ? Colors.white : const Color(0xFFF7F7FA));

                      final textColor = isSelected
                          ? Colors.white
                          : (isCurrentPlaying ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E));

                      return InkWell(
                        onTap: () {
                          setState(() => _selectedRowIndex = i);
                        },
                        onDoubleTap: () {
                          widget.onPlayItem(item);
                        },
                        child: Container(
                          height: 22,
                          color: rowBg,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isCurrentPlaying
                                        ? FontWeight.w700
                                        : (isSelected ? FontWeight.w500 : FontWeight.w400),
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item.artist?.isNotEmpty == true ? item.artist! : '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white70
                                        : const Color(0xFF8E8E93),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  _formatDuration(item.duration),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight:
                                        isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
