import 'package:flutter/material.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

Future<void> showPlaybackSpeedSheet(
    BuildContext context, PlayerProvider player) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _PlaybackSpeedSheet(player: player),
  );
}

class _PlaybackSpeedSheet extends StatefulWidget {
  final PlayerProvider player;

  const _PlaybackSpeedSheet({required this.player});

  @override
  State<_PlaybackSpeedSheet> createState() => _PlaybackSpeedSheetState();
}

class _PlaybackSpeedSheetState extends State<_PlaybackSpeedSheet> {
  late double _speed;

  @override
  void initState() {
    super.initState();
    _speed = widget.player.playbackSpeed;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Playback Speed',
                  style: TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  speedLabel(_speed),
                  style: const TextStyle(
                      color: AppTheme.orange,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.divider),
          // Speed buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: playbackSpeeds.map((s) {
                final selected = (_speed - s).abs() < 0.01;
                return GestureDetector(
                  onTap: () {
                    setState(() => _speed = s);
                    widget.player.setPlaybackSpeed(s);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.orange
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      speedLabel(s),
                      style: TextStyle(
                        color: selected ? Colors.white : AppTheme.onSurface,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('0.25×',
                    style: TextStyle(color: AppTheme.subtitle, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _speed.clamp(0.25, 4.0),
                    min: 0.25,
                    max: 4.0,
                    divisions: 15,
                    onChanged: (v) {
                      // Snap to known values
                      final snapped = playbackSpeeds.reduce((a, b) =>
                          (a - v).abs() < (b - v).abs() ? a : b);
                      setState(() => _speed = snapped);
                      widget.player.setPlaybackSpeed(snapped);
                    },
                  ),
                ),
                const Text('4×',
                    style: TextStyle(color: AppTheme.subtitle, fontSize: 11)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton(
              onPressed: () {
                setState(() => _speed = 1.0);
                widget.player.setPlaybackSpeed(1.0);
              },
              child: const Text('Reset to 1×'),
            ),
          ),
        ],
      ),
    );
  }
}
