import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/playlist.dart';

class StorageService {
  static const _mediaKey = 'media_library';
  static const _playlistKey = 'playlists';
  static const _historyKey = 'play_history';
  static const _settingsKey = 'app_settings';

  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // ── Media Library ──────────────────────────────────────────────────────────

  List<MediaItem> loadMediaLibrary() {
    final raw = _prefs.getString(_mediaKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final items = list
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
        .toList();
    // On web, blob URLs expire when the session ends — remove stale entries
    if (kIsWeb) {
      return items.where((m) => !m.path.startsWith('blob:')).toList();
    }
    return items;
  }

  Future<void> saveMediaLibrary(List<MediaItem> items) async {
    await _prefs.setString(
        _mediaKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  // ── Playlists ──────────────────────────────────────────────────────────────

  List<Playlist> loadPlaylists() {
    final raw = _prefs.getString(_playlistKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    await _prefs.setString(
        _playlistKey, jsonEncode(playlists.map((e) => e.toJson()).toList()));
  }

  // ── History ────────────────────────────────────────────────────────────────

  List<String> loadHistory() {
    return _prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> saveHistory(List<String> ids) async {
    await _prefs.setStringList(_historyKey, ids);
  }

  // ── Settings ───────────────────────────────────────────────────────────────

  Map<String, dynamic> loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings));
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    final settings = loadSettings();
    return settings[key] ?? defaultValue;
  }

  Future<void> setSetting(String key, dynamic value) async {
    final settings = loadSettings();
    settings[key] = value;
    await saveSettings(settings);
  }
}
