import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storage;

  bool _darkMode = true;
  bool _resumePlayback = true;
  bool _hardwareDecoding = true;
  bool _autoRotate = true;
  bool _showSubtitlesByDefault = false;
  double _subtitleSize = 18.0;
  String _subtitleColor = 'white';
  double _subtitleOutline = 3.0;
  String _subtitleBgColor = 'black';
  double _subtitleBgOpacity = 0.75;
  double _defaultPlaybackSpeed = 1.0;
  bool _skipSilence = false;
  int _seekInterval = 10; // seconds
  bool _continuePlaylist = true;
  String _sortBy = 'name'; // name | date | duration | size
  bool _sortAscending = true;
  String _defaultView = 'list'; // list | grid

  SettingsProvider(this._storage) {
    _load();
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  bool get darkMode => _darkMode;
  bool get resumePlayback => _resumePlayback;
  bool get hardwareDecoding => _hardwareDecoding;
  bool get autoRotate => _autoRotate;
  bool get showSubtitlesByDefault => _showSubtitlesByDefault;
  double get subtitleSize => _subtitleSize;
  String get subtitleColor => _subtitleColor;
  double get subtitleOutline => _subtitleOutline;
  String get subtitleBgColor => _subtitleBgColor;
  double get subtitleBgOpacity => _subtitleBgOpacity;
  double get defaultPlaybackSpeed => _defaultPlaybackSpeed;
  bool get skipSilence => _skipSilence;
  int get seekInterval => _seekInterval;
  bool get continuePlaylist => _continuePlaylist;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  String get defaultView => _defaultView;

  void _load() {
    final s = _storage.loadSettings();
    _darkMode = s['darkMode'] as bool? ?? true;
    _resumePlayback = s['resumePlayback'] as bool? ?? true;
    _hardwareDecoding = s['hardwareDecoding'] as bool? ?? true;
    _autoRotate = s['autoRotate'] as bool? ?? true;
    _showSubtitlesByDefault = s['showSubtitlesByDefault'] as bool? ?? false;
    _subtitleSize = (s['subtitleSize'] as num?)?.toDouble() ?? 18.0;
    _subtitleColor = s['subtitleColor'] as String? ?? 'white';
    _subtitleOutline = (s['subtitleOutline'] as num?)?.toDouble() ?? 3.0;
    _subtitleBgColor = s['subtitleBgColor'] as String? ?? 'black';
    _subtitleBgOpacity = (s['subtitleBgOpacity'] as num?)?.toDouble() ?? 0.75;
    _defaultPlaybackSpeed =
        (s['defaultPlaybackSpeed'] as num?)?.toDouble() ?? 1.0;
    _skipSilence = s['skipSilence'] as bool? ?? false;
    _seekInterval = s['seekInterval'] as int? ?? 10;
    _continuePlaylist = s['continuePlaylist'] as bool? ?? true;
    _sortBy = s['sortBy'] as String? ?? 'name';
    _sortAscending = s['sortAscending'] as bool? ?? true;
    _defaultView = s['defaultView'] as String? ?? 'list';
  }

  Map<String, dynamic> _toMap() => {
        'darkMode': _darkMode,
        'resumePlayback': _resumePlayback,
        'hardwareDecoding': _hardwareDecoding,
        'autoRotate': _autoRotate,
        'showSubtitlesByDefault': _showSubtitlesByDefault,
        'subtitleSize': _subtitleSize,
        'subtitleColor': _subtitleColor,
        'subtitleOutline': _subtitleOutline,
        'subtitleBgColor': _subtitleBgColor,
        'subtitleBgOpacity': _subtitleBgOpacity,
        'defaultPlaybackSpeed': _defaultPlaybackSpeed,
        'skipSilence': _skipSilence,
        'seekInterval': _seekInterval,
        'continuePlaylist': _continuePlaylist,
        'sortBy': _sortBy,
        'sortAscending': _sortAscending,
        'defaultView': _defaultView,
      };

  Future<void> _save() => _storage.saveSettings(_toMap());

  Future<void> setDarkMode(bool v) async {
    _darkMode = v;
    notifyListeners();
    await _save();
  }

  Future<void> setResumePlayback(bool v) async {
    _resumePlayback = v;
    notifyListeners();
    await _save();
  }

  Future<void> setHardwareDecoding(bool v) async {
    _hardwareDecoding = v;
    notifyListeners();
    await _save();
  }

  Future<void> setAutoRotate(bool v) async {
    _autoRotate = v;
    notifyListeners();
    await _save();
  }

  Future<void> setShowSubtitlesByDefault(bool v) async {
    _showSubtitlesByDefault = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSubtitleSize(double v) async {
    _subtitleSize = v.clamp(10.0, 40.0);
    notifyListeners();
    await _save();
  }

  Future<void> setSubtitleColor(String v) async {
    _subtitleColor = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSubtitleOutline(double v) async {
    _subtitleOutline = v.clamp(0.0, 10.0);
    notifyListeners();
    await _save();
  }

  Future<void> setSubtitleBgColor(String v) async {
    _subtitleBgColor = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSubtitleBgOpacity(double v) async {
    _subtitleBgOpacity = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultPlaybackSpeed(double v) async {
    _defaultPlaybackSpeed = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSkipSilence(bool v) async {
    _skipSilence = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSeekInterval(int v) async {
    _seekInterval = v.clamp(5, 60);
    notifyListeners();
    await _save();
  }

  Future<void> setContinuePlaylist(bool v) async {
    _continuePlaylist = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSortBy(String v) async {
    _sortBy = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSortAscending(bool v) async {
    _sortAscending = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultView(String v) async {
    _defaultView = v;
    notifyListeners();
    await _save();
  }
}
