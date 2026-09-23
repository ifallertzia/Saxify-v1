import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ifallmusic/core/services/settings_service.dart';
import 'package:ifallmusic/core/services/spatial_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One mock preferences store shared by every service built in a test, so a
/// "restart" really reads what the previous instance wrote.
Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

Future<SpatialAudioService> _service(SharedPreferences prefs) async =>
    SpatialAudioService(SettingsService(prefs));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('8D spatial templates', () {
    test('every template carries a sane orbit frequency and depth', () {
      expect(SpatialPresets.all, isNotEmpty);
      for (final SpatialPreset preset in SpatialPresets.all) {
        expect(preset.rotationHz, inInclusiveRange(0, 0.6));
        expect(preset.depth, inInclusiveRange(0, 1));
        expect(preset.reverb, inInclusiveRange(0, 1));
        expect(preset.label, isNotEmpty);
      }
    });

    test('byId falls back to Off for unknown ids', () {
      expect(SpatialPresets.byId('8d-orbit'), SpatialPresets.orbit);
      expect(SpatialPresets.byId('nope'), SpatialPresets.off);
      expect(SpatialPresets.off.isOff, isTrue);
      expect(SpatialPresets.orbit.isOff, isFalse);
    });
  });

  group('orbit maths', () {
    test('equal-power panning keeps the power constant and the gains in range', () {
      for (double pan = -1; pan <= 1; pan += 0.25) {
        final double angle = (pan + 1) * (math.pi / 4);
        final double left = math.cos(angle);
        final double right = math.sin(angle);
        expect(left, inInclusiveRange(0, 1));
        expect(right, inInclusiveRange(0, 1));
        expect(left * left + right * right, closeTo(1, 1e-9));
      }
    });

    test('a full orbit takes 1 / rotationHz seconds', () async {
      final SpatialAudioService spatial = await _service(await _prefs());
      await spatial.applyPreset(SpatialPresets.orbit);
      expect(spatial.enabled, isTrue);
      expect(spatial.orbitPeriod.inSeconds, 8); // 0.12 Hz ≈ 8.3 s
      spatial.dispose();
    });
  });

  group('settings round-trip', () {
    test('applying a preset persists every parameter', () async {
      final SharedPreferences prefs = await _prefs();
      final SpatialAudioService spatial = await _service(prefs);
      await spatial.applyPreset(SpatialPresets.dreamy);
      expect(spatial.preset.id, '8d-dreamy');
      expect(spatial.reverb, SpatialPresets.dreamy.reverb);

      // A fresh service over the same store reads the values back.
      final SpatialAudioService restored = await _service(prefs);
      expect(restored.preset.id, '8d-dreamy');
      expect(restored.reverb, closeTo(SpatialPresets.dreamy.reverb, 1e-9));
      restored.dispose();
      spatial.dispose();
    });

    test('turning the engine off keeps the chosen template', () async {
      final SpatialAudioService spatial = await _service(await _prefs());
      await spatial.applyPreset(SpatialPresets.club);
      await spatial.setEnabled(false);
      expect(spatial.enabled, isFalse);
      expect(spatial.preset.id, '8d-club');
      spatial.dispose();
    });
  });
}
