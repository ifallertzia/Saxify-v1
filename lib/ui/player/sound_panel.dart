import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/playback_service.dart';
import '../../core/services/spatial_audio_service.dart';
import '../../core/theme/glass.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import 'equalizer_page.dart';

/// The glass "sound" sheet of the player: volume, quick EQ access and the 8D
/// spatial templates with their live sliders. Shared by the player and the
/// equalizer page so both stay identical.
class SoundPanel extends StatelessWidget {
  const SoundPanel({super.key, this.showVolume = true});

  final bool showVolume;

  @override
  Widget build(BuildContext context) {
    final PlaybackService playback = context.watch<PlaybackService>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showVolume) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Row(
              children: <Widget>[
                const Icon(Icons.volume_down_rounded, size: 20),
                Expanded(
                  child: Slider(
                    value: playback.volume.clamp(0.0, 1.0),
                    onChanged: playback.setVolume,
                  ),
                ),
                Icon(
                  Icons.volume_up_rounded,
                  size: 20,
                  color: context.accent.primary,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Text(
                  '${(playback.volume * 100).round()}% volume',
                  style: const TextStyle(fontSize: 11.5, color: SaxifyColors.textMuted),
                ),
                const Spacer(),
                GlassButton(
                  label: 'Full equalizer',
                  icon: Icons.graphic_eq_rounded,
                  compact: true,
                  filled: false,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const EqualizerPage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
        const SpatialControls(),
      ],
    );
  }
}

/// 8D spatial audio templates + live controls.
class SpatialControls extends StatelessWidget {
  const SpatialControls({super.key});

  @override
  Widget build(BuildContext context) {
    final SpatialAudioService spatial = context.watch<SpatialAudioService>();
    final SaxifyAccent accent = context.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: accent.gradient,
                ),
                child: Icon(Icons.surround_sound_rounded, size: 18, color: accent.onAccent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '8D spatial audio',
                      style: SaxifyTheme.appleFont(size: 14.5, weight: FontWeight.w700),
                    ),
                    Text(
                      spatial.enabled
                          ? '${spatial.preset.label} · orbiting at ${spatial.rotationHz.toStringAsFixed(2)} Hz'
                          : 'Real-time orbit panning + reverb — pick a template',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: SaxifyColors.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(value: spatial.enabled, onChanged: spatial.setEnabled),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SpatialPreset preset in SpatialPresets.all)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: spatial.preset.id == preset.id,
                  onSelected: (_) => spatial.applyPreset(preset),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: spatial.preset.id == preset.id
                        ? accent.primary
                        : SaxifyColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (spatial.enabled) ...<Widget>[
          const SizedBox(height: 10),
          _SpatialSlider(
            label: 'Orbit speed',
            value: spatial.rotationHz,
            min: 0.02,
            max: 0.6,
            display: '${spatial.rotationHz.toStringAsFixed(2)} Hz · one circle every ${(1 / (spatial.rotationHz <= 0 ? 1 : spatial.rotationHz)).round()}s',
            onChanged: spatial.setRotationHz,
          ),
          _SpatialSlider(
            label: 'Depth / distance',
            value: spatial.depth,
            min: 0,
            max: 1,
            display: '${(spatial.depth * 100).round()}%',
            onChanged: spatial.setDepth,
          ),
          _SpatialSlider(
            label: 'Reverb (room)',
            value: spatial.reverb,
            min: 0,
            max: 1,
            display: '${(spatial.reverb * 100).round()}%',
            onChanged: spatial.setReverb,
          ),
          const _OrbitMeter(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Text(
              spatial.preset.description,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: SaxifyColors.textFaint,
              ),
            ),
          ),
        ] else
          const SizedBox(height: 18),
      ],
    );
  }
}

class _SpatialSlider extends StatelessWidget {
  const _SpatialSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: SaxifyColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.accent.primary,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Live visualisation of the current 8D orbit — a dot walking around the head.
class _OrbitMeter extends StatelessWidget {
  const _OrbitMeter();

  @override
  Widget build(BuildContext context) {
    final SpatialAudioService spatial = context.watch<SpatialAudioService>();
    final SaxifyAccent accent = context.accent;
    final (double left, double right) = spatial.gains;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: GlassPanel(
        radius: SaxifyTheme.radiusMd,
        blur: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'LIVE ORBIT',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: SaxifyColors.textFaint,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double x = (spatial.pan + 1) / 2 * (constraints.maxWidth - 20);
                  return Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                accent.primary.withValues(alpha: 0.15),
                                accent.primary.withValues(alpha: 0.7),
                                accent.primary.withValues(alpha: 0.15),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: x.clamp(0.0, constraints.maxWidth - 20),
                        top: 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: accent.gradient,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: accent.primary.withValues(alpha: 0.6),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 6,
                        child: Text(
                          'L ${(left * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: SaxifyColors.textFaint,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 6,
                        child: Text(
                          'R ${(right * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: SaxifyColors.textFaint,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
