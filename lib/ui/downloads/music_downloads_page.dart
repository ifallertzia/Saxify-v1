import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/music_download_service.dart';
import '../../core/services/native_bridge.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import '../widgets/neon.dart';
import '../widgets/search_fab.dart';

class MusicDownloadsPage extends StatefulWidget {
  const MusicDownloadsPage({super.key});

  @override
  State<MusicDownloadsPage> createState() => _MusicDownloadsPageState();
}

class _MusicDownloadsPageState extends State<MusicDownloadsPage> {
  List<SavedFile> _files = <SavedFile>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final List<SavedFile> files = await NativeBridge.listDownloads();
    if (!mounted) return;
    setState(() {
      _files = files.where((SavedFile f) => f.displayName.endsWith('.mp3')).toList();
      _loading = false;
    });
  }

  Future<void> _delete(SavedFile file) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: const Text('Delete from device?'),
        content: Text('Remove ${file.displayName} from Downloads?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await NativeBridge.deleteDownload(uri: file.uri, path: file.path);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final MusicDownloadService downloads = context.watch<MusicDownloadService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: <Widget>[
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
          const SaxifySearchButton(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
              children: <Widget>[
                if (downloads.active != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NeonCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            downloads.active!.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: downloads.active!.fraction == 0 ? null : downloads.active!.fraction),
                          const SizedBox(height: 6),
                          Text(
                            '${(downloads.active!.fraction * 100).round()}%',
                            style: const TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_files.isEmpty && downloads.jobs.isEmpty)
                  const EmptyState(
                    icon: Icons.download_outlined,
                    title: 'No saved songs yet',
                    message: 'Download from a song menu. Files go to Download/Saxify.',
                  ),
                for (final SavedFile file in _files)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(file.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      file.size > 0 ? Fmt.count(file.size) : 'On device',
                      style: const TextStyle(color: SaxifyColors.textMuted, fontSize: 12),
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete from device',
                      icon: const Icon(Icons.delete_outline_rounded, color: SaxifyColors.danger),
                      onPressed: () => _delete(file),
                    ),
                  ),
              ],
            ),
    );
  }
}
