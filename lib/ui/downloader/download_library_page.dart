import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import '../../downloader/downloader_models.dart';
import '../../downloader/platform_detect.dart';
import '../../downloader/universal_downloader.dart';
import '../../core/services/native_bridge.dart';
import '../widgets/artwork.dart';
import '../widgets/neon.dart';
import '../widgets/search_fab.dart';

class DownloadLibraryPage extends StatefulWidget {
  const DownloadLibraryPage({super.key});

  @override
  State<DownloadLibraryPage> createState() => _DownloadLibraryPageState();
}

class _DownloadLibraryPageState extends State<DownloadLibraryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final UniversalDownloader downloader = context.watch<UniversalDownloader>();
    final List<DownloadRecord> items = downloader.filtered(_query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download library'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear all',
            onPressed: items.isEmpty
                ? null
                : () async {
                    final bool? ok = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialog) => AlertDialog(
                        title: const Text('Clear all downloads?'),
                        content: const Text('This removes saved files and the local history.'),
                        actions: <Widget>[
                          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (ok == true) await downloader.clearAll();
                  },
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          const SaxifySearchButton(),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search history',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (String v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nothing saved yet',
                    message: 'Downloads stay on this device until you delete them.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 140),
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int i) {
                      final DownloadRecord item = items[i];
                      return ListTile(
                        leading: Artwork(url: item.thumbnail, size: 48, radius: 8),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${PlatformDetect.label(item.platform)} · ${item.kind.name} · ${item.quality}'
                          ' · ${Fmt.date(item.createdAt)}',
                          maxLines: 2,
                          style: const TextStyle(fontSize: 11, color: SaxifyColors.textMuted),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (String action) => _action(context, downloader, item, action),
                          itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                            PopupMenuItem(value: 'open', child: Text('Open')),
                            PopupMenuItem(value: 'share', child: Text('Share')),
                            PopupMenuItem(value: 'again', child: Text('Download again')),
                            PopupMenuItem(value: 'copy', child: Text('Copy URL')),
                            PopupMenuItem(value: 'post', child: Text('Open original post')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    UniversalDownloader downloader,
    DownloadRecord item,
    String action,
  ) async {
    switch (action) {
      case 'open':
        if (item.uri != null && item.uri!.startsWith('content:')) {
          await NativeBridge.openContent(
            item.uri!,
            item.mime,
          );
        } else if (item.path != null) {
          await NativeBridge.openContent(
            item.path!,
            item.mime,
          );
        }
        return;
      case 'share':
        if (item.path != null) {
          await NativeBridge.shareFile(
            path: item.path!,
            mime: item.mime,
            uri: item.uri,
            title: item.title,
          );
        }
        return;
      case 'again':
        downloader.setUrl(item.url);
        await downloader.fetch();
        await downloader.download(kind: item.kind, best: true);
        return;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: item.url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied')));
        }
        return;
      case 'post':
        final Uri? uri = Uri.tryParse(item.url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return;
      case 'delete':
        await downloader.deleteRecord(item);
        return;
    }
  }
}
