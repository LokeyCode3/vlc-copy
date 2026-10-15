import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/player_provider.dart';
import '../services/media_scanner.dart';
import '../models/media_item.dart';
import '../theme/app_theme.dart';
import '../utils/blob_utils.dart';
import '../utils/format_utils.dart';
import 'video_player_screen.dart';
import 'audio_player_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  String? _currentPath;
  List<FileSystemEntity> _entries = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoot();
  }

  Future<void> _loadRoot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final statuses = await [
          Permission.videos,
          Permission.audio,
          Permission.storage,
        ].request();

        final hasMedia = statuses[Permission.videos]?.isGranted == true ||
            statuses[Permission.storage]?.isGranted == true ||
            await Permission.videos.isGranted ||
            await Permission.storage.isGranted ||
            await Permission.manageExternalStorage.isGranted;

        if (!hasMedia) {
          final manage = await Permission.manageExternalStorage.request();
          if (!manage.isGranted &&
              !(await Permission.videos.isGranted) &&
              !(await Permission.storage.isGranted)) {
            setState(() {
              _error = 'Storage / Media permission is required to access videos.';
              _loading = false;
            });
            return;
          }
        }
        final dir = Directory('/storage/emulated/0');
        if (await dir.exists()) {
          await _loadDir(dir.path);
          return;
        }
      }
      // On web, filesystem browsing is not supported — fall through to file picker
      if (kIsWeb) {
        setState(() {
          _error = 'File system browsing is not available on web. Use the + button to pick files.';
          _loading = false;
        });
        return;
      }
      final ext = await getExternalStorageDirectory();
      final docs = await getApplicationDocumentsDirectory();
      final root = ext ?? docs;
      await _loadDir(root.path);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadDir(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = Directory(path);
      final list = await dir.list().toList();
      list.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      setState(() {
        _currentPath = path;
        _entries = list;
        _loading = false;
      });

      // Automatically register any media files in this folder into the library
      final mediaPaths = list
          .where((e) => e is File && MediaScanner.isMedia(e.path))
          .map((e) => e.path)
          .toList();
      if (mediaPaths.isNotEmpty && mounted) {
        context.read<MediaProvider>().addFiles(mediaPaths);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    if (kIsWeb) {
      // On web: use bytes from FilePicker and create blob URLs
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp',
          'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus',
        ],
      );
      if (files.isEmpty) return;
      if (!mounted) return;

      final media = context.read<MediaProvider>();
      int added = 0;
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final mimeType = _mimeForExtension(file.extension ?? '');
        final blobUrl = createBlobUrl(bytes, mimeType);
        await media.addWebFile(
          blobUrl: blobUrl,
          name: file.name,
          extension: file.extension ?? '',
          bytes: bytes,
        );
        added++;
      }
      if (!mounted) return;

      // Determine type from the picked file extensions directly
      final hasVideo = files.any((f) =>
          MediaScanner.isVideo('file.${f.extension ?? ''}'));
      // Tab indices: 0=Browse, 1=Video, 2=Audio
      final targetTab = hasVideo ? 1 : 2;
      final typeLabel = hasVideo ? 'Video' : 'Audio';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $added file(s) to $typeLabel library'),
          action: SnackBarAction(
            label: 'VIEW',
            onPressed: () {
              if (mounted) context.read<NavigationProvider>().switchTab(targetTab);
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      // Auto-switch tab
      context.read<NavigationProvider>().switchTab(targetTab);
      return;
    }

    // Native (Android/iOS/desktop) — pickFiles returns List<PlatformFile>
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp',
        'mp3', 'aac', 'flac', 'wav', 'ogg', 'm4a', 'opus',
      ],
    );
    if (files.isEmpty) return;
    final paths = files.map((f) => f.path).whereType<String>().toList();
    if (!mounted) return;
    await context.read<MediaProvider>().addFiles(paths);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${paths.length} file(s) to library')),
    );
  }

  String _mimeForExtension(String ext) {
    const videoMimes = {
      'mp4': 'video/mp4', 'mkv': 'video/x-matroska', 'webm': 'video/webm',
      'avi': 'video/x-msvideo', 'mov': 'video/quicktime',
    };
    const audioMimes = {
      'mp3': 'audio/mpeg', 'aac': 'audio/aac', 'ogg': 'audio/ogg',
      'wav': 'audio/wav', 'flac': 'audio/flac', 'm4a': 'audio/mp4',
      'opus': 'audio/opus',
    };
    return videoMimes[ext] ?? audioMimes[ext] ?? 'application/octet-stream';
  }

  Future<void> _openFile(String path) async {
    final media = context.read<MediaProvider>();
    final player = context.read<PlayerProvider>();

    await media.addFile(path);
    final item = media.library.firstWhere((m) => m.path == path,
        orElse: () => throw Exception('not found'));

    await media.recordPlay(item.id);
    await player.playItem(item, queue: [item]);

    if (!mounted) return;
    if (item.type == MediaType.video) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const VideoPlayerScreen()));
    } else {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AudioPlayerScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Path breadcrumb
          if (_currentPath != null)
            Container(
              color: AppTheme.surfaceVariant,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_currentPath != '/')
                    GestureDetector(
                      onTap: () {
                        final parent =
                            Directory(_currentPath!).parent.path;
                        _loadDir(parent);
                      },
                      child: const Icon(Icons.arrow_upward_rounded,
                          size: 18, color: AppTheme.orange),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPath!,
                      style: const TextStyle(
                          color: AppTheme.onSurface, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        size: 18, color: AppTheme.onSurface),
                    onPressed: () => _loadDir(_currentPath!),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.orange))
                : _error != null
                    ? _buildError()
                    : _entries.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFiles,
        backgroundColor: AppTheme.orange,
        tooltip: 'Pick files',
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.orange, size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppTheme.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRoot,
                child: const Text('Retry'),
              ),
              if (!kIsWeb && Platform.isAndroid) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('Open App Settings'),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, color: AppTheme.subtitle, size: 64),
            const SizedBox(height: 12),
            const Text('Empty folder',
                style: TextStyle(color: AppTheme.subtitle)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.add),
              label: const Text('Pick files'),
            ),
          ],
        ),
      );

  Widget _buildList() {
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 0, color: AppTheme.divider),
      itemBuilder: (ctx, i) {
        final entity = _entries[i];
        final name = entity.path.split('/').last;
        final isDir = entity is Directory;
        final isMedia = !isDir && MediaScanner.isMedia(entity.path);

        return ListTile(
          leading: Icon(
            isDir
                ? Icons.folder_rounded
                : isMedia
                    ? (MediaScanner.isVideo(entity.path)
                        ? Icons.videocam_rounded
                        : Icons.music_note_rounded)
                    : Icons.insert_drive_file_rounded,
            color: isDir
                ? const Color(0xFFFFC107)
                : isMedia
                    ? AppTheme.orange
                    : AppTheme.subtitle,
          ),
          title: Text(name,
              style: const TextStyle(
                  color: AppTheme.onBackground, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: isMedia
              ? Text(formatFileSize(entity.path),
                  style: const TextStyle(
                      color: AppTheme.subtitle, fontSize: 11))
              : null,
          trailing: isMedia
              ? IconButton(
                  icon: const Icon(Icons.play_circle_outline,
                      color: AppTheme.orange),
                  onPressed: () => _openFile(entity.path),
                )
              : null,
          onTap: isDir
              ? () => _loadDir(entity.path)
              : isMedia
                  ? () => _openFile(entity.path)
                  : null,
        );
      },
    );
  }
}
