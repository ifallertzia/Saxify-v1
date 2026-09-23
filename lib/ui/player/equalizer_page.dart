import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/native_bridge.dart';
import '../../core/services/playback_service.dart';
import '../../core/theme/saxify_theme.dart';
import '../widgets/neon.dart';
import '../widgets/search_fab.dart';

/// System equalizer bound to the player that is already running.
///
/// Frequencies come from Android `Equalizer.getCenterFreq` (millihertz),
/// which is the API on the device — not the invalid getCenterFrecuencias helper.
class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  EqualizerInfo? _info;
  bool _enabled = true;
  bool _loading = true;
  bool _unsupported = false;
  List<int> _levels = <int>[];
  String? _preset;

  static const List<String> _custom = <String>[
    'Flat',
    'Bass Boost',
    'Vocal',
    'Rock',
    'Pop',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  Future<void> _bind() async {
    if (!Platform.isAndroid) {
      setState(() {
        _loading = false;
        _unsupported = true;
      });
      return;
    }
    final PlaybackService playback = context.read<PlaybackService>();
    int? session = playback.player.androidAudioSessionId;
    if (session == null || session == 0) {
      try {
        session = await playback.player.androidAudioSessionIdStream
            .firstWhere((int? id) => id != null && id != 0)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        session = null;
      }
    }
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _unsupported = true;
      });
      return;
    }
    final EqualizerInfo? info = await NativeBridge.eqInit(session);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _info = info;
      _unsupported = info == null || !info.supported;
      _levels = info == null ? <int>[] : List<int>.from(info.levels);
    });
  }

  Future<void> _applyPreset(String name) async {
    final EqualizerInfo? info = _info;
    if (info == null) return;
    final bool device = await NativeBridge.eqUsePreset(name);
    if (device) {
      setState(() => _preset = name);
      return;
    }
    final List<int> next = _curve(name, info);
    for (int i = 0; i < next.length; i++) {
      await NativeBridge.eqSetBand(i, next[i]);
    }
    if (!mounted) return;
    setState(() {
      _preset = name;
      _levels = next;
      _enabled = true;
    });
  }

  List<int> _curve(String name, EqualizerInfo info) {
    final int n = info.bands;
    final int min = info.minLevel;
    final int max = info.maxLevel;
    int clamp(double unit) {
      final double span = (max - min).toDouble();
      final int value = (min + span * unit).round();
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    return List<int>.generate(n, (int i) {
      final double t = n == 1 ? 0.5 : i / (n - 1);
      switch (name) {
        case 'Bass Boost':
          return clamp(t < 0.35 ? 0.85 : 0.40);
        case 'Vocal':
          return clamp(t > 0.3 && t < 0.7 ? 0.82 : 0.42);
        case 'Rock':
          return clamp(t < 0.25 || t > 0.75 ? 0.8 : 0.45);
        case 'Pop':
          return clamp(0.55 + (t - 0.5).abs() * 0.4);
        case 'Flat':
        default:
          return 0.clamp(min, max);
      }
    });
  }

  @override
  void dispose() {
    // Leave the effect attached so playback keeps the curve after this page closes.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: const <Widget>[SaxifySearchButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _unsupported
              ? const EmptyState(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Equalizer unavailable',
                  message:
                      'This device does not expose an audio session equalizer. Playback is unchanged.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable equalizer'),
                      subtitle: const Text(
                        'Connected to the current player session',
                        style: TextStyle(color: SaxifyColors.textMuted, fontSize: 12),
                      ),
                      value: _enabled,
                      onChanged: (bool v) async {
                        await NativeBridge.eqSetEnabled(v);
                        setState(() => _enabled = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Presets',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String name in <String>[
                          ..._custom,
                          ...?_info?.presets.where((String p) => !_custom.contains(p)),
                        ])
                          ChoiceChip(
                            label: Text(name),
                            selected: _preset == name,
                            onSelected: (_) => _applyPreset(name),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    for (int i = 0; i < (_info?.bands ?? 0); i++)
                      _BandSlider(
                        index: i,
                        centerHz: (_info!.centersMilliHz.length > i
                                ? _info!.centersMilliHz[i]
                                : 0) /
                            1000,
                        min: _info!.minLevel,
                        max: _info!.maxLevel,
                        value: _levels.length > i ? _levels[i] : 0,
                        enabled: _enabled,
                        onChanged: (int level) async {
                          setState(() {
                            _preset = null;
                            if (_levels.length > i) _levels[i] = level;
                          });
                          await NativeBridge.eqSetBand(i, level);
                        },
                      ),
                  ],
                ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.index,
    required this.centerHz,
    required this.min,
    required this.max,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int index;
  final num centerHz;
  final int min;
  final int max;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  String get _label {
    if (centerHz >= 1000) return '${(centerHz / 1000).toStringAsFixed(1)} kHz';
    if (centerHz <= 0) return 'Band ${index + 1}';
    return '${centerHz.round()} Hz';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(_label, style: const TextStyle(fontSize: 12, color: SaxifyColors.textSecondary)),
        Slider(
          min: min.toDouble(),
          max: max.toDouble(),
          value: value.clamp(min, max).toDouble(),
          onChanged: enabled ? (double v) => onChanged(v.round()) : null,
        ),
      ],
    );
  }
}
