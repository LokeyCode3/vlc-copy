import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../providers/media_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (ctx, settings, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            children: [
              _section('Appearance'),
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme'),
                value: settings.darkMode,
                onChanged: settings.setDarkMode,
              ),
              _divider(),
              _section('Playback'),
              SwitchListTile(
                title: const Text('Resume Playback'),
                subtitle: const Text('Resume from where you left off'),
                value: settings.resumePlayback,
                onChanged: settings.setResumePlayback,
              ),
              SwitchListTile(
                title: const Text('Continue Playlist'),
                subtitle: const Text('Auto-play next item in queue'),
                value: settings.continuePlaylist,
                onChanged: settings.setContinuePlaylist,
              ),
              ListTile(
                title: const Text('Default Playback Speed'),
                subtitle: Text(speedLabel(settings.defaultPlaybackSpeed)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showSpeedPicker(ctx, settings),
              ),
              ListTile(
                title: const Text('Seek Interval'),
                subtitle: Text('${settings.seekInterval} seconds'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showSeekIntervalPicker(ctx, settings),
              ),
              _divider(),
              _section('Video'),
              SwitchListTile(
                title: const Text('Hardware Decoding'),
                subtitle: const Text('Use hardware acceleration'),
                value: settings.hardwareDecoding,
                onChanged: settings.setHardwareDecoding,
              ),
              SwitchListTile(
                title: const Text('Auto Rotate'),
                subtitle: const Text('Rotate screen with content'),
                value: settings.autoRotate,
                onChanged: settings.setAutoRotate,
              ),
              _divider(),
              _section('Subtitles'),
              SwitchListTile(
                title: const Text('Show Subtitles by Default'),
                value: settings.showSubtitlesByDefault,
                onChanged: settings.setShowSubtitlesByDefault,
              ),
              ListTile(
                title: const Text('Subtitle Size'),
                subtitle: Text('${settings.subtitleSize.toInt()}pt'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showSubtitleSizePicker(ctx, settings),
              ),
              ListTile(
                title: const Text('Subtitle Color'),
                subtitle: Text(settings.subtitleColor),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showColorPicker(ctx, settings),
              ),
              _divider(),
              _section('Library'),
              ListTile(
                title: const Text('Sort By'),
                subtitle: Text(
                    '${settings.sortBy[0].toUpperCase()}${settings.sortBy.substring(1)} · '
                    '${settings.sortAscending ? "Ascending" : "Descending"}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showSortPicker(ctx, settings),
              ),
              ListTile(
                title: const Text('Default View'),
                subtitle: Text(settings.defaultView == 'list' ? 'List' : 'Grid'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showViewPicker(ctx, settings),
              ),
              _divider(),
              _section('Data'),
              ListTile(
                title: const Text('Clear Play History',
                    style: TextStyle(color: Colors.redAccent)),
                leading: const Icon(Icons.delete_sweep_rounded,
                    color: Colors.redAccent),
                onTap: () => _confirmClearHistory(ctx),
              ),
              ListTile(
                title: const Text('Clear Entire Library',
                    style: TextStyle(color: Colors.redAccent)),
                leading: const Icon(Icons.library_add_check_rounded,
                    color: Colors.redAccent),
                onTap: () => _confirmClearLibrary(ctx),
              ),
              _divider(),
              _section('About'),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded,
                    color: AppTheme.orange),
                title: Text('ISPC Player'),
                subtitle: Text('Version 1.0.0 · Powered by ISPC'),
              ),
              _divider(),
              _section('Legal'),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined,
                    color: AppTheme.orange),
                title: const Text('Privacy Policy'),
                subtitle: const Text(AppConfig.privacyPolicyLabel),
                trailing: const Icon(Icons.open_in_new_rounded,
                    size: 16, color: AppTheme.onSurface),
                onTap: () => _launchUrl(AppConfig.privacyPolicyUrl),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_rounded,
                    color: AppTheme.orange),
                title: const Text('Terms & Conditions'),
                subtitle: const Text(AppConfig.termsLabel),
                trailing: const Icon(Icons.open_in_new_rounded,
                    size: 16, color: AppTheme.onSurface),
                onTap: () => _launchUrl(AppConfig.termsAndConditionsUrl),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.orange,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _divider() => const Divider(color: AppTheme.divider, height: 1);

  void _showSpeedPicker(BuildContext ctx, SettingsProvider settings) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Default Playback Speed',
                  style: TextStyle(
                      color: AppTheme.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            ...playbackSpeeds.map((s) => ListTile(
                  title: Text(speedLabel(s),
                      style: const TextStyle(color: AppTheme.onBackground)),
                  trailing: settings.defaultPlaybackSpeed == s
                      ? const Icon(Icons.check_rounded, color: AppTheme.orange)
                      : null,
                  onTap: () {
                    settings.setDefaultPlaybackSpeed(s);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSeekIntervalPicker(BuildContext ctx, SettingsProvider settings) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Seek Interval',
                  style: TextStyle(
                      color: AppTheme.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            for (final sec in [5, 10, 15, 20, 30, 60])
              ListTile(
                title: Text('$sec seconds',
                    style: const TextStyle(color: AppTheme.onBackground)),
                trailing: settings.seekInterval == sec
                    ? const Icon(Icons.check_rounded, color: AppTheme.orange)
                    : null,
                onTap: () {
                  settings.setSeekInterval(sec);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSubtitleSizePicker(BuildContext ctx, SettingsProvider settings) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Subtitle Size',
                    style: TextStyle(
                        color: AppTheme.onBackground,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Sample Subtitle Text',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: settings.subtitleSize,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4)
                      ]),
                ),
              ),
              Slider(
                value: settings.subtitleSize,
                min: 10,
                max: 40,
                divisions: 30,
                label: '${settings.subtitleSize.toInt()}pt',
                onChanged: (v) {
                  setState(() {});
                  settings.setSubtitleSize(v);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext ctx, SettingsProvider settings) {
    const colors = ['white', 'yellow', 'cyan', 'green', 'red'];
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Subtitle Color',
                  style: TextStyle(
                      color: AppTheme.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            ...colors.map((c) => ListTile(
                  leading: CircleAvatar(
                      backgroundColor: _colorFromName(c), radius: 12),
                  title: Text(
                      c[0].toUpperCase() + c.substring(1),
                      style: const TextStyle(color: AppTheme.onBackground)),
                  trailing: settings.subtitleColor == c
                      ? const Icon(Icons.check_rounded, color: AppTheme.orange)
                      : null,
                  onTap: () {
                    settings.setSubtitleColor(c);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _colorFromName(String name) {
    switch (name) {
      case 'yellow': return Colors.yellow;
      case 'cyan': return Colors.cyan;
      case 'green': return Colors.green;
      case 'red': return Colors.red;
      default: return Colors.white;
    }
  }

  void _showSortPicker(BuildContext ctx, SettingsProvider settings) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sort Library By',
                  style: TextStyle(
                      color: AppTheme.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            for (final opt in ['name', 'date', 'duration'])
              ListTile(
                title: Text(opt[0].toUpperCase() + opt.substring(1),
                    style: const TextStyle(color: AppTheme.onBackground)),
                trailing: settings.sortBy == opt
                    ? Icon(
                        settings.sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: AppTheme.orange)
                    : null,
                onTap: () {
                  if (settings.sortBy == opt) {
                    settings.setSortAscending(!settings.sortAscending);
                  } else {
                    settings.setSortBy(opt);
                  }
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showViewPicker(BuildContext ctx, SettingsProvider settings) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Default View',
                  style: TextStyle(
                      color: AppTheme.onBackground,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.list_rounded, color: AppTheme.onSurface),
              title: const Text('List', style: TextStyle(color: AppTheme.onBackground)),
              trailing: settings.defaultView == 'list'
                  ? const Icon(Icons.check_rounded, color: AppTheme.orange)
                  : null,
              onTap: () {
                settings.setDefaultView('list');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: AppTheme.onSurface),
              title: const Text('Grid', style: TextStyle(color: AppTheme.onBackground)),
              trailing: settings.defaultView == 'grid'
                  ? const Icon(Icons.check_rounded, color: AppTheme.orange)
                  : null,
              onTap: () {
                settings.setDefaultView('grid');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('This will remove all playback history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ctx.read<MediaProvider>().clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmClearLibrary(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Clear Library'),
        content: const Text(
            'This will remove all media from the library. Files on disk will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final media = ctx.read<MediaProvider>();
              for (final item in List.from(media.library)) {
                await media.removeFromLibrary(item.id);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
