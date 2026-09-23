import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/native_bridge.dart';
import '../../core/services/playback_service.dart';
import '../../core/theme/saxify_theme.dart';

/// The same EQ is available from Settings and from the player sound sheet.
/// It attaches to the existing AudioPlayer session; it never replaces it.
class EqualizerPage extends StatelessWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sound & equalizer')),
        body: const SoundControlsPanel(),
      );
}

class SoundControlsPanel extends StatefulWidget {
  const SoundControlsPanel({super.key, this.controller});

  final ScrollController? controller;

  @override
  State<SoundControlsPanel> createState() => _SoundControlsPanelState();
}

class _SoundControlsPanelState extends State<SoundControlsPanel> {
  EqualizerInfo? _info;
  bool _enabled = true;
  bool _loading = true;
  List<int> _levels = <int>[];
  String? _preset;

  static const List<String> _custom = <String>[
    'Flat', 'Bass Boost', 'Vocal', 'Rock', 'Pop',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  Future<void> _bind() async {
    if (kIsWeb || !Platform.isAndroid) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final PlaybackService playback = context.read<PlaybackService>();
    int? session = playback.player.androidAudioSessionId;
    if (session == null || session == 0) {
      try {
        session = await playback.player.androidAudioSessionIdStream
            .firstWhere((int? id) => id != null && id != 0)
            .timeout(const Duration(seconds: 3));
      } catch (_) { session = null; }
    }
    final EqualizerInfo? info = session == null ? null : await NativeBridge.eqInit(session);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _info = info;
      _enabled = info?.enabled ?? false;
      _levels = info == null ? <int>[] : List<int>.from(info.levels);
    });
  }

  Future<void> _applyPreset(String name) async {
    final EqualizerInfo? info = _info;
    if (info == null) return;
    if (!_enabled) {
      await NativeBridge.eqSetEnabled(true);
      if (mounted) setState(() => _enabled = true);
    }
    final bool device = await NativeBridge.eqUsePreset(name);
    if (device) {
      // Native presets change ALL bands; refresh slider positions too.
      final int? session = context.read<PlaybackService>().player.androidAudioSessionId;
      final EqualizerInfo? current = session == null ? null : await NativeBridge.eqInit(session);
      if (!mounted) return;
      setState(() {
        _preset = name;
        if (current != null) _levels = List<int>.from(current.levels);
      });
      return;
    }
    final List<int> next = _curve(name, info);
    for (int i = 0; i < next.length; i++) {
      await NativeBridge.eqSetBand(i, next[i]);
    }
    if (mounted) setState(() { _preset = name; _levels = next; });
  }

  List<int> _curve(String name, EqualizerInfo info) {
    final int min = info.minLevel;
    final int max = info.maxLevel;
    int clamp(double unit) => (min + (max - min) * unit).round().clamp(min, max).toInt();
    return List<int>.generate(info.bands, (int i) {
      final double t = info.bands == 1 ? 0.5 : i / (info.bands - 1);
      return switch (name) {
        'Bass Boost' => clamp(t < 0.35 ? 0.85 : 0.40),
        'Vocal' => clamp(t > 0.3 && t < 0.7 ? 0.82 : 0.42),
        'Rock' => clamp(t < 0.25 || t > 0.75 ? 0.8 : 0.45),
        'Pop' => clamp(0.55 + (t - 0.5).abs() * 0.4),
        _ => 0.clamp(min, max).toInt(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackService playback = context.watch<PlaybackService>();
    final Color accent = Theme.of(context).colorScheme.primary;
    final EqualizerInfo? info = _info;
    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 48),
      children: <Widget>[
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 18),
        Text('Sound', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Fine-tune your listening',
          style: TextStyle(fontSize: 12, color: SaxifyColors.textSecondary)),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('VOLUME', style: TextStyle(fontSize: 11, letterSpacing: 1.5,
              fontWeight: FontWeight.w700, color: SaxifyColors.textSecondary)),
            Row(children: <Widget>[
              IconButton(
                tooltip: playback.volume == 0 ? 'Unmute' : 'Mute',
                icon: Icon(playback.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: accent),
                onPressed: () {
                  playback.setVolume(playback.volume == 0 ? 0.7 : 0);
                  setState(() {});
                },
              ),
              Expanded(child: Slider(value: playback.volume.clamp(0.0, 1.0),
                onChanged: (double value) {
                  playback.setVolume(value);
                  setState(() {});
                })),
              SizedBox(width: 38, child: Text('${(playback.volume * 100).round()}%',
                textAlign: TextAlign.end, style: const TextStyle(fontSize: 12))),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        Row(children: <Widget>[
          Expanded(child: Text('Equalizer', style: Theme.of(context).textTheme.titleLarge)),
          if (info?.supported == true)
            Switch.adaptive(value: _enabled, onChanged: (bool value) async {
              await NativeBridge.eqSetEnabled(value);
              if (mounted) setState(() => _enabled = value);
            }),
        ]),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (info?.supported != true)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('Equalizer is available while a song is playing on a supported Android device. Volume still works.',
              style: TextStyle(color: SaxifyColors.textSecondary, height: 1.5)),
          )
        else ...<Widget>[
          const Text('Presets', style: TextStyle(fontSize: 12, color: SaxifyColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
            for (final String name in <String>[
              ..._custom,
              ...info!.presets.where((String p) => !_custom.contains(p)),
            ])
              ChoiceChip(label: Text(name), selected: _preset == name,
                onSelected: (_) => _applyPreset(name)),
          ]),
          const SizedBox(height: 18),
          for (int i = 0; i < info!.bands; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: <Widget>[
                SizedBox(width: 62, child: Text(
                  _freq(info!.centersMilliHz.length > i ? info.centersMilliHz[i] : 0, i),
                  style: const TextStyle(fontSize: 11, color: SaxifyColors.textSecondary))),
                Expanded(child: Slider(
                  min: info!.minLevel.toDouble(), max: info.maxLevel.toDouble(),
                  value: (_levels.length > i ? _levels[i] : 0)
                      .clamp(info!.minLevel, info.maxLevel).toDouble(),
                  onChanged: _enabled ? (double value) {
                    final int level = value.round();
                    setState(() {
                      _preset = null;
                      _levels[i] = level;
                    });
                    NativeBridge.eqSetBand(i, level);
                  } : null,
                )),
              ]),
            ),
        ],
      ],
    );
  }

  String _freq(int milliHz, int index) {
    final double hz = milliHz / 1000;
    if (hz <= 0) return 'Band ${index + 1}';
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}k';
    return '${hz.round()}Hz';
  }
}
