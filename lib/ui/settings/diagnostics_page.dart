import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../downloader/universal_downloader.dart';
import '../../core/theme/saxify_theme.dart';

/// A user-facing status screen, not a boot log or server configuration editor.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UniversalDownloader>().refreshHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final UniversalDownloader downloader = context.watch<UniversalDownloader>();
    final health = downloader.health;
    return Scaffold(
      appBar: AppBar(title: const Text('Download status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                health?.ok == true ? Icons.offline_pin_rounded : Icons.download_rounded,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                downloader.healthLoading ? 'Preparing downloads…'
                    : health?.ok == true ? 'Ready to save on this device'
                    : 'Downloads unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                health?.ok == true
                    ? 'Public media downloads run locally. Saved songs play offline.'
                    : (health?.error ?? 'Check again when your device is ready.'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: SaxifyColors.textSecondary),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: downloader.healthLoading ? null : downloader.refreshHealth,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Check again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
