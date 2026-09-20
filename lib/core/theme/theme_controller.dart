import 'dart:async';

import 'package:flutter/foundation.dart';

import '../theme/sidify_accents.dart';
import 'settings_service.dart';

/// Owns "which neon accent is the app wearing right now".
///
/// Two modes, exactly like the web app's Appearance panel:
///  * **auto** — cycles through the 6 accents every ~2.5 minutes so the app
///    keeps changing its look on its own.
///  * **pinned** — the user tapped a swatch in Settings, so the accent stays
///    put until they turn auto-rotation back on.
class ThemeController extends ChangeNotifier {
  ThemeController(this._settings) {
    _index = SidifyAccents.indexOfId(_settings.accentId);
    if (_settings.autoRotateTheme) _startTimer();
  }

  final SettingsService _settings;

  int _index = 0;
  Timer? _timer;

  SidifyAccent get accent => SidifyAccents.all[_index];
  int get index => _index;
  bool get autoRotate => _settings.autoRotateTheme;
  Duration get rotateInterval => Duration(seconds: _settings.rotateSeconds);

  /// Seconds until the next automatic switch (used by the Settings countdown).
  int secondsUntilNextSwitch() {
    if (!autoRotate) return 0;
    final Duration elapsed = DateTime.now().difference(_lastSwitch);
    final int remaining = rotateInterval.inSeconds - elapsed.inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  DateTime _lastSwitch = DateTime.now();

  /// Pin a specific accent. Turns auto-rotation off — the user asked for this
  /// exact colour.
  Future<void> pin(String accentId) async {
    await _stopTimer();
    _index = SidifyAccents.indexOfId(accentId);
    await _settings.setAccentId(accentId);
    await _settings.setAutoRotateTheme(false);
    notifyListeners();
  }

  Future<void> setAutoRotate(bool value) async {
    await _settings.setAutoRotateTheme(value);
    if (value) {
      await _settings.setAccentId(accent.id);
      _startTimer();
    } else {
      await _stopTimer();
    }
    notifyListeners();
  }

  Future<void> setRotateInterval(Duration interval) async {
    await _settings.setRotateSeconds(interval.inSeconds);
    if (autoRotate) _startTimer();
    notifyListeners();
  }

  /// Jump to the next accent (also what the auto timer calls).
  Future<void> cycle({bool persist = true}) async {
    _index = (_index + 1) % SidifyAccents.all.length;
    _lastSwitch = DateTime.now();
    if (persist) await _settings.setAccentId(accent.id);
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _lastSwitch = DateTime.now();
    _timer = Timer.periodic(rotateInterval, (_) => cycle());
  }

  Future<void> _stopTimer() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
