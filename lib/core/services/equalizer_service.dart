import 'package:equalizer_flutter/equalizer_flutter.dart' as eq;
import 'package:flutter/foundation.dart';

/// Audio equalizer (Part 10).
///
/// **API verification result (as demanded by the brief):** the old
/// `Equalizer.getCenterFrecuencias()` / `getBandFrequencies()` surface does
/// not exist in any current Flutter plugin. The only maintained-looking
/// package is `equalizer_flutter` (0.0.1), whose real API is:
///
///   getBandLevelRange()      -> band level range (dB)
///   getBandLevel(bandId)     -> current level for a band
///   setBandLevel(bandId, db)
///   getCenterBandFreqs()     -> center frequencies (milliHertz)
///   getPresetNames()         -> device presets
///   setPreset(name)
///   open(sessionId)          -> system equalizer screen
///
/// This service wraps that API and, crucially, **feature-detects** it at
/// runtime: if the device has no equalizer, the plugin is unavailable, or
/// the call throws (very possible on OEM builds), `supported` stays false
/// and the Settings section hides itself completely — the brief's
/// "device not supporting -> hide section gracefully" rule.
class EqualizerService extends ChangeNotifier {
  EqualizerService() {
    _probe();
  }

  bool _supported = false;
  bool _probing = false;
  bool _enabled = false;
  List<int> _centerFreqsHz = <int>[];
  List<int> _levelsDb = <int>[];
  int _minDb = -20;
  int _maxDb = 20;
  List<String> _devicePresets = <String>[];
  String? _probeError;

  /// Whether this device actually exposes an equalizer.
  bool get supported => _supported;
  bool get probing => _probing;
  bool get enabled => _enabled;
  List<int> get centerFreqsHz => List<int>.unmodifiable(_centerFreqsHz);
  List<int> get levelsDb => List<int>.unmodifiable(_levelsDb);
  int get minDb => _minDb;
  int get maxDb => _maxDb;
  String? get probeError => _probeError;

  /// The brief's presets, mapped onto whatever the device offers.
  static const List<String> presets = <String>[
    'Bass Boost', 'Vocal', 'Rock', 'Pop', 'Flat',
  ];

  Future<void> _probe() async {
    if (_probing) return;
    _probing = true;
    notifyListeners();
    try {
      // A single call that only exists on real devices with an EQ.
      final List<int> freqs = await eq.EqualizerFlutter.getCenterBandFreqs();
      if (freqs.isEmpty) {
        _probeError = 'no bands';
      } else {
        _centerFreqsHz = freqs.map((int mHz) => mHz ~/ 1000).toList();
        try {
          final List<int> range = await eq.EqualizerFlutter.getBandLevelRange();
          if (range.length >= 2) {
            _minDb = range.first;
            _maxDb = range.last;
          }
        } catch (_) {/* defaults are fine */}
        _levelsDb = List<int>.filled(_centerFreqsHz.length, 0);
        try {
          _devicePresets = await eq.EqualizerFlutter.getPresetNames();
        } catch (_) {/* device may have none */}
        _supported = true;
      }
    } catch (e) {
      debugPrint('[Equalizer] probe failed: $e');
      _probeError = '$e';
      _supported = false;
    } finally {
      _probing = false;
      notifyListeners();
    }
  }

  Future<bool> setEnabled(bool value) async {
    if (!_supported) return false;
    try {
      // No setEnabled in the plugin API — emulate: Flat (all 0) == off,
      // any non-flat state == on.
      _enabled = value;
      if (!value) {
        await applyPreset('Flat');
      }
      return true;
    } catch (e) {
      debugPrint('[Equalizer] setEnabled failed: $e');
      return false;
    }
  }

  Future<bool> setBand(int bandIndex, int levelDb) async {
    if (!_supported) return false;
    if (bandIndex < 0 || bandIndex >= _centerFreqsHz.length) return false;
    try {
      final int clamped = levelDb.clamp(_minDb, _maxDb);
      await eq.EqualizerFlutter.setBandLevel(bandIndex, clamped);
      _levelsDb[bandIndex] = clamped;
      _enabled = _levelsDb.any((int l) => l != 0);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Equalizer] setBand failed: $e');
      return false;
    }
  }

  /// Applies one of the brief's presets. Device presets with the same name
  /// are used when the OEM ships them; otherwise a built-in curve.
  Future<bool> applyPreset(String name) async {
    if (!_supported) return false;
    try {
      if (_devicePresets.contains(name)) {
        await eq.EqualizerFlutter.setPreset(name);
      } else {
        final List<int> curve = _builtInCurve(name);
        for (int i = 0; i < curve.length && i < _levelsDb.length; i++) {
          await eq.EqualizerFlutter.setBandLevel(i, curve[i]);
        }
        _levelsDb = curve;
      }
      _enabled = name != 'Flat';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Equalizer] applyPreset($name) failed: $e');
      return false;
    }
  }

  /// Built-in curves scaled to the device's dB range. Shape is fixed
  /// (bass shelf / vocal peak / rock / pop / flat); amplitude adapts.
  List<int> _builtInCurve(String name) {
    final int n = _levelsDb.length;
    final int span = (_maxDb - _minDb) ~/ 2; // stay in the safe half-range
    int shape(int i) {
      final double t = n <= 1 ? 0 : i / (n - 1); // 0..1 across the bands
      switch (name) {
        case 'Bass Boost':
          return t < 0.3 ? span : (t < 0.5 ? span ~/ 2 : 0);
        case 'Vocal':
          final double d = (t - 0.55).abs();
          return d < 0.22 ? span : (d < 0.35 ? span ~/ 2 : -span ~/ 3);
        case 'Rock':
          return t < 0.25 || t > 0.75 ? span : (t > 0.35 && t < 0.6 ? span ~/ 3 : 0);
        case 'Pop':
          return t < 0.3 ? span ~/ 2 : (t > 0.6 ? span ~/ 2 : 0);
        default: // Flat
          return 0;
      }
    }

    return List<int>.generate(n, (int i) => shape(i), growable: false);
  }

  /// Releases the device equalizer (lifecycle rule: call from dispose).
  Future<void> release() async {
    try {
      await eq.EqualizerFlutter.removeAudioSessionId(0);
    } catch (_) {/* best effort */}
    _supported = false;
    _enabled = false;
    notifyListeners();
  }
}
