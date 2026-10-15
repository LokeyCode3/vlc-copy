import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';
import '../services/storage_service.dart';
import '../services/media_scanner.dart';

class MediaProvider extends ChangeNotifier {
  final StorageService _storage;

  List<MediaItem> _library = [];
  List<Playlist> _playlists = [];
  List<String> _historyIds = []; // ordered newest-first
  bool _isScanning = false;

  MediaProvider(this._storage) {
    _load();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  List<MediaItem> get library => List.unmodifiable(_library);
  List<MediaItem> get videos =>
      _library.where((m) => m.type == MediaType.video).toList();
  List<MediaItem> get audio =>
      _library.where((m) => m.type == MediaType.audio).toList();
  List<MediaItem> get favourites =>
      _library.where((m) => m.isFavourite).toList();
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get isScanning => _isScanning;

  List<MediaItem> get history {
    final result = <MediaItem>[];
    for (final id in _historyIds) {
      final item = _findById(id);
      if (item != null) result.add(item);
    }
    return result;
  }

  MediaItem? _findById(String id) {
    try {
      return _library.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  MediaItem? findById(String id) => _findById(id);

  // ── Init ───────────────────────────────────────────────────────────────────

  void _load() {
    _library = _storage.loadMediaLibrary();
    _playlists = _storage.loadPlaylists();
    _historyIds = _storage.loadHistory();
    notifyListeners();
  }

  Future<void> _saveLibrary() => _storage.saveMediaLibrary(_library);
  Future<void> _savePlaylists() => _storage.savePlaylists(_playlists);
  Future<void> _saveHistory() => _storage.saveHistory(_historyIds);

  // ── Scanning ───────────────────────────────────────────────────────────────

  Future<void> scanDevice() async {
    if (kIsWeb) return;
    _isScanning = true;
    notifyListeners();

    try {
      final found = await MediaScanner.scanCommonDirectories();
      final existingPaths = _library.map((m) => m.path).toSet();
      int added = 0;
      for (final item in found) {
        if (!existingPaths.contains(item.path)) {
          _library.add(item);
          added++;
        }
      }
      if (added > 0) {
        await _saveLibrary();
      }
    } catch (_) {}

    _isScanning = false;
    notifyListeners();
  }

  Future<void> scanDirectory(String dirPath) async {
    _isScanning = true;
    notifyListeners();

    final found = await MediaScanner.scanDirectory(dirPath);
    final existingPaths = _library.map((m) => m.path).toSet();
    int added = 0;
    for (final item in found) {
      if (!existingPaths.contains(item.path)) {
        _library.add(item);
        added++;
      }
    }
    if (added > 0) await _saveLibrary();

    _isScanning = false;
    notifyListeners();
  }

  Future<void> addFile(String path) async {
    if (_library.any((m) => m.path == path)) return;
    final item = await MediaScanner.buildFromPath(path);
    if (item != null) {
      _library.add(item);
      await _saveLibrary();
      notifyListeners();
    }
  }

  Future<void> addFiles(List<String> paths) async {
    bool changed = false;
    for (final path in paths) {
      if (_library.any((m) => m.path == path)) continue;
      final item = await MediaScanner.buildFromPath(path);
      if (item != null) {
        _library.add(item);
        changed = true;
      }
    }
    if (changed) {
      await _saveLibrary();
      notifyListeners();
    }
  }

  final Map<String, Uint8List> _webFileBytes = {};
  Uint8List? getWebFileBytes(String path) => _webFileBytes[path];

  /// Web-only: add a file from in-memory bytes using a blob URL.
  Future<void> addWebFile({
    required String blobUrl,
    required String name,
    required String extension,
    required Uint8List bytes,
  }) async {
    _webFileBytes[blobUrl] = bytes;
    if (_library.any((m) => m.path == blobUrl)) return;
    final isVideo = MediaScanner.isVideo('file.$extension');
    final item = MediaItem(
      id: blobUrl.hashCode.abs().toString() +
          DateTime.now().millisecondsSinceEpoch.toString(),
      path: blobUrl,
      title: name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      type: isVideo ? MediaType.video : MediaType.audio,
      addedAt: DateTime.now(),
    );
    _library.add(item);
    await _saveLibrary();
    notifyListeners();
  }

  Future<void> removeFromLibrary(String id) async {
    _library.removeWhere((m) => m.id == id);
    _historyIds.remove(id);
    for (final pl in _playlists) {
      pl.mediaIds.remove(id);
    }
    await Future.wait([_saveLibrary(), _saveHistory(), _savePlaylists()]);
    notifyListeners();
  }

  // ── Favourites ─────────────────────────────────────────────────────────────

  Future<void> toggleFavourite(String id) async {
    final idx = _library.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    _library[idx].isFavourite = !_library[idx].isFavourite;
    await _saveLibrary();
    notifyListeners();
  }

  // ── History ────────────────────────────────────────────────────────────────

  Future<void> recordPlay(String id, {Duration? position}) async {
    final idx = _library.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    _library[idx].lastPlayed = DateTime.now();
    if (position != null) _library[idx].lastPosition = position;

    _historyIds.remove(id);
    _historyIds.insert(0, id);
    if (_historyIds.length > 200) _historyIds = _historyIds.sublist(0, 200);

    await Future.wait([_saveLibrary(), _saveHistory()]);
    notifyListeners();
  }

  Future<void> updateLastPosition(String id, Duration position) async {
    final idx = _library.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    _library[idx].lastPosition = position;
    await _saveLibrary();
  }

  Future<void> clearHistory() async {
    _historyIds.clear();
    for (final item in _library) {
      item.lastPlayed = null;
    }
    await Future.wait([_saveLibrary(), _saveHistory()]);
    notifyListeners();
  }

  // ── Playlists ──────────────────────────────────────────────────────────────

  Future<Playlist> createPlaylist(String name) async {
    final pl = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      mediaIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _playlists.add(pl);
    await _savePlaylists();
    notifyListeners();
    return pl;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final idx = _playlists.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _playlists[idx].name = name;
    _playlists[idx].updatedAt = DateTime.now();
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addToPlaylist(String playlistId, String mediaId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    if (_playlists[idx].mediaIds.contains(mediaId)) return;
    _playlists[idx].mediaIds.add(mediaId);
    _playlists[idx].updatedAt = DateTime.now();
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> removeFromPlaylist(String playlistId, String mediaId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    _playlists[idx].mediaIds.remove(mediaId);
    _playlists[idx].updatedAt = DateTime.now();
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> reorderPlaylist(
      String playlistId, int oldIndex, int newIndex) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return;
    final ids = _playlists[idx].mediaIds;
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    _playlists[idx].updatedAt = DateTime.now();
    await _savePlaylists();
    notifyListeners();
  }

  List<MediaItem> getPlaylistItems(String playlistId) {
    final pl = _playlists.firstWhere((p) => p.id == playlistId,
        orElse: () => Playlist(
              id: '',
              name: '',
              mediaIds: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
    return pl.mediaIds
        .map((id) => _findById(id))
        .whereType<MediaItem>()
        .toList();
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  List<MediaItem> search(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    return _library
        .where((m) =>
            m.title.toLowerCase().contains(q) ||
            (m.artist?.toLowerCase().contains(q) ?? false) ||
            (m.album?.toLowerCase().contains(q) ?? false))
        .toList();
  }
}
