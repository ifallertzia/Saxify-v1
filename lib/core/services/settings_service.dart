import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../downloader/downloader_models.dart';

/// Everything the Settings screen owns, persisted with shared_preferences.
///
/// Keys are stable strings so the store survives renames of the Dart fields.
class SettingsService extends ChangeNotifier {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  // ---------------------------------------------------------------- keys
  static const String kDisplayName = 'saxify.display_name';
  static const String kEmail = 'saxify.email';
  static const String kAccentId = 'saxify.accent_id';
  static const String kAutoRotateTheme = 'saxify.auto_rotate_theme';
  static const String kRotateSeconds = 'saxify.rotate_seconds';
  static const String kQualityWifi = 'saxify.quality_wifi';
  static const String kQualityMobile = 'saxify.quality_mobile';
  static const String kGapless = 'saxify.gapless';
  static const String kAutoplay = 'saxify.autoplay';
  static const String kRememberPosition = 'saxify.remember_position';
  static const String kPlaybackSpeed = 'saxify.playback_speed';
  static const String kExplicitFilter = 'saxify.explicit_filter';
  static const String kLastPositions = 'saxify.last_positions';
  static const String kDownloaderMode = 'saxify.downloader_mode';
  static const String kLastPlaylistCode = 'saxify.last_playlist_code';
  static const String kAutoPlaylistSync = 'saxify.auto_playlist_sync';
  static const String kMaxDownloadHistory = 'saxify.max_download_history';

  // ---------------------------------------------------------------- account
  String get displayName => _prefs.getString(kDisplayName)?.trim() ?? '';
  Future<void> setDisplayName(String v) =>
      _prefs.setString(kDisplayName, v.trim()).then((_) => notifyListeners());

  String get email => _prefs.getString(kEmail) ?? 'dastaanenajdik@gmail.com';
  Future<void> setEmail(String v) =>
      _prefs.setString(kEmail, v).then((_) => notifyListeners());

  // ---------------------------------------------------------------- theme
  String get accentId => _prefs.getString(kAccentId) ?? 'neon-violet';
  Future<void> setAccentId(String v) =>
      _prefs.setString(kAccentId, v).then((_) => notifyListeners());

  bool get autoRotateTheme => _prefs.getBool(kAutoRotateTheme) ?? true;
  Future<void> setAutoRotateTheme(bool v) =>
      _prefs.setBool(kAutoRotateTheme, v).then((_) => notifyListeners());

  /// Rotation cadence in seconds. 150s == 2.5 minutes, right in the middle of
  /// the "every 2–3 minutes" the app promises.
  int get rotateSeconds => _prefs.getInt(kRotateSeconds) ?? 150;
  Future<void> setRotateSeconds(int v) =>
      _prefs.setInt(kRotateSeconds, v).then((_) => notifyListeners());

  // ---------------------------------------------------------------- audio
  String get qualityWifi => _prefs.getString(kQualityWifi) ?? 'high';
  Future<void> setQualityWifi(String v) =>
      _prefs.setString(kQualityWifi, v).then((_) => notifyListeners());

  String get qualityMobile => _prefs.getString(kQualityMobile) ?? 'medium';
  Future<void> setQualityMobile(String v) =>
      _prefs.setString(kQualityMobile, v).then((_) => notifyListeners());

  String qualityForConnection({required bool wifi}) => wifi ? qualityWifi : qualityMobile;

  bool get gapless => _prefs.getBool(kGapless) ?? true;
  Future<void> setGapless(bool v) =>
      _prefs.setBool(kGapless, v).then((_) => notifyListeners());

  bool get autoplay => _prefs.getBool(kAutoplay) ?? true;
  Future<void> setAutoplay(bool v) =>
      _prefs.setBool(kAutoplay, v).then((_) => notifyListeners());

  bool get rememberPosition => _prefs.getBool(kRememberPosition) ?? true;
  Future<void> setRememberPosition(bool v) =>
      _prefs.setBool(kRememberPosition, v).then((_) => notifyListeners());

  double get playbackSpeed => _prefs.getDouble(kPlaybackSpeed) ?? 1.0;
  Future<void> setPlaybackSpeed(double v) =>
      _prefs.setDouble(kPlaybackSpeed, v).then((_) => notifyListeners());

  bool get explicitFilter => _prefs.getBool(kExplicitFilter) ?? false;
  Future<void> setExplicitFilter(bool v) =>
      _prefs.setBool(kExplicitFilter, v).then((_) => notifyListeners());

  // ------------------------------------------------- resume-where-you-left
  Map<String, dynamic> _positions() {
    final String? raw = _prefs.getString(kLastPositions);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Where the listener stopped, or null when resuming would be pointless.
  Duration? resumePositionFor(String songId) {
    if (!rememberPosition) return null;
    final Object? ms = _positions()[songId];
    final int value = ms is int ? ms : 0;
    if (value < 5000) return null; // don't resume a barely-started track
    return Duration(milliseconds: value);
  }

  Future<void> saveResumePosition(String songId, Duration position) async {
    final Map<String, dynamic> map = _positions();
    map[songId] = position.inMilliseconds;
    final List<String> keys = map.keys.toList();
    // Keep only the 40 most recent entries so the blob stays small.
    if (keys.length > 40) {
      for (final String k in keys.sublist(0, keys.length - 40)) {
        map.remove(k);
      }
    }
    await _prefs.setString(kLastPositions, jsonEncode(map));
  }

  Future<void> forgetPositions() => _prefs.remove(kLastPositions);

  // ------------------------------------------------------- v2 remotes
  DownloaderMode get downloaderMode {
    final String raw = _prefs.getString(kDownloaderMode) ?? DownloaderMode.ask.name;
    return DownloaderMode.values.firstWhere(
      (DownloaderMode mode) => mode.name == raw,
      orElse: () => DownloaderMode.ask,
    );
  }

  Future<void> setDownloaderMode(DownloaderMode mode) =>
      _prefs.setString(kDownloaderMode, mode.name).then((_) => notifyListeners());

  String? get lastPlaylistCode => _prefs.getString(kLastPlaylistCode);

  Future<void> setLastPlaylistCode(String code) =>
      _prefs.setString(kLastPlaylistCode, code).then((_) => notifyListeners());

  bool get autoPlaylistSync => _prefs.getBool(kAutoPlaylistSync) ?? true;

  Future<void> setAutoPlaylistSync(bool value) =>
      _prefs.setBool(kAutoPlaylistSync, value).then((_) => notifyListeners());

  int get maxDownloadHistory => _prefs.getInt(kMaxDownloadHistory) ?? 120;

  Future<void> resetAll() async {
    await _prefs.clear();
    notifyListeners();
  }
}
