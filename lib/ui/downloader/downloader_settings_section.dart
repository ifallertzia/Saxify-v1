import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/backend_config.dart';
import '../../core/services/downloader/downloader_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';

/// Part 11.7 — Downloader settings: mode, auto quality, filename suffix,
/// history, sound feedback, and a live backend health check.
class DownloaderSettingsSection extends StatefulWidget {
  const DownloaderSettingsSection({super.key});

  @override
  State<DownloaderSettingsSection> createState() =>
      _DownloaderSettingsSectionState();
}

class _DownloaderSettingsSectionState
    extends State<DownloaderSettingsSection> {
  BackendHealth? _health;
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final DownloaderService downloader =
        context.watch<DownloaderService>();
    final SaxifyAccent accent = context.accent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      children: <Widget>[
        _Card(
          title: 'Download mode',
          subtitle: 'Used when you do not pick a format yourself',
          child: Column(
            children: <Widget>[
              for (final DownloaderMode mode in DownloaderMode.values)
                RadioListTile<DownloaderMode>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: mode,
                  groupValue: downloader.mode,
                  onChanged: (DownloaderMode? v) {
                    if (v != null) downloader.setMode(v);
                  },
                  activeColor: accent.primary,
                  title: Text(mode.label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    mode == DownloaderMode.bestVideo
                        ? 'Always the highest-quality video'
                        : mode == DownloaderMode.audioMp3
                            ? 'Audio only — MP3 192 kbps when available'
                            : 'Ask on every download',
                    style: const TextStyle(
                        fontSize: 11, color: SaxifyColors.textFaint),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Options',
          child: Column(
            children: <Widget>[
              _SwitchRow(
                label: 'Auto quality',
                subtitle: 'Pick the best format automatically',
                value: downloader.autoQuality,
                onChanged: downloader.setAutoQuality,
              ),
              const Divider(height: 16),
              _SwitchRow(
                label: 'Add “_saxify” to filenames',
                subtitle: 'Downloads/Saxify/title_saxify.mp4',
                value: downloader.filenameSuffix,
                onChanged: downloader.setFilenameSuffix,
              ),
              const Divider(height: 16),
              _SwitchRow(
                label: 'Save to library',
                subtitle: 'Keep a history of your downloads',
                value: downloader.historyEnabled,
                onChanged: downloader.setHistoryEnabled,
              ),
              const Divider(height: 16),
              _SwitchRow(
                label: 'Completion feedback',
                subtitle: 'A light haptic tap when a download finishes',
                value: downloader.sound,
                onChanged: downloader.setSound,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Library history',
          subtitle: 'How many entries to keep on this device',
          child: Column(
            children: <Widget>[
              Text(
                'Keep the last ${downloader.historyMax} downloads '
                '(default 120)',
                style: const TextStyle(
                    fontSize: 12, color: SaxifyColors.textSecondary),
              ),
              Slider(
                value: downloader.historyMax.toDouble(),
                min: 10,
                max: 500,
                divisions: 49,
                activeColor: accent.primary,
                onChanged: (double v) =>
                    downloader.setHistoryMax(v.round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          title: 'Backend',
          subtitle: BackendConfig.downloaderConfigured
              ? BackendConfig.downloaderBaseUrl
              : 'Not configured yet',
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _health?.summary ??
                          'Check the Saxify Downloader server status.',
                      style: const TextStyle(
                          fontSize: 12,
                          color: SaxifyColors.textSecondary),
                    ),
                  ),
                  if (_checking)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton.icon(
                      onPressed: _check,
                      icon: const Icon(Icons.health_and_safety_rounded,
                          size: 15),
                      label: const Text('Check',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              if (!BackendConfig.downloaderConfigured)
                const Text(
                  'Point BackendConfig.downloaderBaseUrl at your deployed '
                  'downloader server (README → Downloader backend) to '
                  'enable downloads.',
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: Color(0xFFFFD9A3)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final BackendHealth health =
        await context.read<DownloaderService>().healthCheck();
    if (!mounted) return;
    setState(() {
      _health = health;
      _checking = false;
    });
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SaxifyTheme.radiusLg),
        color: SaxifyColors.card,
        border: Border.all(
            color: accent.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle!,
                style: const TextStyle(
                    fontSize: 11.5, color: SaxifyColors.textFaint),
              ),
            ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: SaxifyColors.textFaint)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: accent.primary,
        ),
      ],
    );
  }
}
