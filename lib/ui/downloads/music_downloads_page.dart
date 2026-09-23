import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/music_download_service.dart';
import '../../core/services/native_bridge.dart';
import '../../core/services/playback_service.dart';
import '../../core/theme/saxify_theme.dart';
import '../widgets/artwork.dart';
import '../widgets/neon.dart';

/// Settings shortcut to the same private offline library as Library → Downloads.
/// MediaStore is shown only for older/untracked public copies.
class MusicDownloadsPage extends StatefulWidget {
  const MusicDownloadsPage({super.key});

  @override
  State<MusicDownloadsPage> createState() => _MusicDownloadsPageState();
}

class _MusicDownloadsPageState extends State<MusicDownloadsPage> {
  List<SavedFile> _files = <SavedFile>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final List<SavedFile> files = await NativeBridge.listDownloads();
    if (mounted) setState(() => _files = files);
  }

  Future<void> _delete(MusicDownloadJob job) async {
    final bool? ok = await showDialog<bool>(context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Remove download?'),
        content: Text('Remove ${job.song.title} from this device?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Remove')),
        ],
      ));
    if (ok != true || !mounted) return;
    await context.read<MusicDownloadService>().delete(
      job, playback: context.read<PlaybackService>());
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final MusicDownloadService downloads = context.watch<MusicDownloadService>();
    final PlaybackService playback = context.read<PlaybackService>();
    final List<MusicDownloadJob> saved = downloads.downloaded;
    final Set<String> publicUris = saved
        .map((MusicDownloadJob job) => job.savedUri ?? '').toSet();
    final List<SavedFile> legacy = _files.where((SavedFile file) =>
        !publicUris.contains(file.uri) &&
        (file.displayName.endsWith('.mp3') || file.displayName.endsWith('.m4a') ||
         file.displayName.endsWith('.webm'))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Your Downloads'), actions: <Widget>[
        IconButton(tooltip: 'Refresh', onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 140), children: <Widget>[
        if (downloads.active != null) ...<Widget>[
          NeonCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(downloads.active!.song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: downloads.active!.fraction <= 0
                ? null : downloads.active!.fraction),
            const SizedBox(height: 6),
            Text('${(downloads.active!.fraction * 100).round()}% · Saving on this phone',
              style: const TextStyle(fontSize: 12, color: SaxifyColors.textMuted)),
          ])),
          const SizedBox(height: 12),
        ],
        if (saved.isEmpty && legacy.isEmpty && downloads.active == null)
          const EmptyState(icon: Icons.download_outlined, title: 'No downloads yet',
            message: 'Tap Download next to a song. Once saved, it will play offline.'),
        for (final MusicDownloadJob job in saved)
          ListTile(
            leading: Artwork(url: job.song.thumbnailUrl, size: 48, radius: 10),
            title: Text(job.song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${job.song.artist} · ${(job.size / (1024 * 1024)).toStringAsFixed(1)} MB · Offline',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: SaxifyColors.textMuted)),
            onTap: () => playback.playOfflineSong(job.song, job.offlinePath!),
            trailing: IconButton(tooltip: 'Remove from device',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(job)),
          ),
        if (legacy.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text('Other saved files', style: Theme.of(context).textTheme.titleMedium),
          for (final SavedFile file in legacy)
            ListTile(
              title: Text(file.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => NativeBridge.openContent(file.uri ?? file.path ?? '',
                file.displayName.endsWith('.mp3') ? 'audio/mpeg' :
                file.displayName.endsWith('.webm') ? 'audio/webm' : 'audio/mp4'),
            ),
        ],
      ]),
    );
  }
}
