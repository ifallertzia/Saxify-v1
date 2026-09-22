import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/backend_config.dart';
import '../../config/branding.dart';
import '../../core/services/boot_log.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/saxify_theme.dart';
import '../../downloader/universal_downloader.dart';
import '../widgets/search_fab.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.safeMode});

  final bool safeMode;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  String _log = '';
  final TextEditingController _url = TextEditingController();

  @override
  void initState() {
    super.initState();
    _url.text = context.read<SettingsService>().downloaderBaseUrl;
    BootLog.tail().then((String value) {
      if (mounted) setState(() => _log = value);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsService settings = context.watch<SettingsService>();
    final UniversalDownloader downloader = context.watch<UniversalDownloader>();
    final health = downloader.health;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: const <Widget>[SaxifySearchButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: <Widget>[
          Text('${SaxifyBranding.appName} ${SaxifyBranding.versionLabel}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            widget.safeMode ? 'Safe mode is on. Heavy startup was skipped.' : 'Normal startup.',
            style: const TextStyle(color: SaxifyColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text('Downloader backend', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            decoration: const InputDecoration(hintText: 'https://…'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await settings.setDownloaderBaseUrl(_url.text.trim());
                if (!context.mounted) return;
                context.read<UniversalDownloader>().api.baseUrl = settings.downloaderBaseUrl;
                await context.read<UniversalDownloader>().refreshHealth();
              },
              child: const Text('Save & check'),
            ),
          ),
          Text(
            health == null
                ? 'Not checked yet.'
                : 'status: ${health.ok ? 'ok' : 'down'}\n'
                    'app: ${health.app.isEmpty ? '—' : health.app}'
                    '${health.branded ? '' : ' (expected ${BackendConfig.expectedDownloaderApp})'}\n'
                    'version: ${health.version.isEmpty ? '—' : health.version}'
                    ' (expected ${BackendConfig.expectedDownloaderVersion})\n'
                    'ffmpeg: ${health.ffmpeg}\nyt_dlp: ${health.ytDlp}'
                    '${health.error == null ? '' : '\n${health.error}'}',
            style: const TextStyle(fontSize: 12.5, height: 1.45, color: SaxifyColors.textSecondary),
          ),
          const SizedBox(height: 18),
          const Text('Boot log', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            _log.isEmpty ? 'No boot log yet.' : _log,
            style: const TextStyle(fontSize: 11, height: 1.4, color: SaxifyColors.textMuted),
          ),
          const SizedBox(height: 18),
          Text(
            'Logo ${SaxifyBranding.logoWidth.toInt()}×${SaxifyBranding.logoHeight.toInt()} '
            '${SaxifyBranding.logoFormat}\n${SaxifyBranding.logoAsset}',
            style: const TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
          ),
        ],
      ),
    );
  }
}
