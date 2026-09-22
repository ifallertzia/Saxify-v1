import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/download_item.dart';
import '../../core/services/downloader/downloader_service.dart';
import '../../core/services/storage_placer.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import '../widgets/artwork.dart';
import '../widgets/neon.dart';

/// Part 11.5 — Downloads Library: the persisted history with search,
/// filter, open, copy URL, open original post, download again, delete and
/// clear-all.
class DownloaderLibrarySection extends StatefulWidget {
  const DownloaderLibrarySection({super.key});

  @override
  State<DownloaderLibrarySection> createState() =>
      _DownloaderLibrarySectionState();
}

class _DownloaderLibrarySectionState extends State<DownloaderLibrarySection> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<DownloadItem> _items = <DownloadItem>[];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final DownloaderService downloader =
        context.read<DownloaderService>();
    final List<DownloadItem> items = await downloader.history();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  List<DownloadItem> get _visible {
    final String q = _searchCtrl.text.trim().toLowerCase();
    return _items.where((DownloadItem i) {
      if (_filter == 'video' && i.mediaType != 'video') return false;
      if (_filter == 'audio' && i.mediaType != 'audio') return false;
      if (q.isEmpty) return true;
      return i.title.toLowerCase().contains(q) ||
          i.url.toLowerCase().contains(q) ||
          i.platform.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _delete(DownloadItem item) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Delete this download?'),
        content: const Text(
            'The file will be removed from your device and from the '
            'library list. You can always download it again.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFF8A8A))),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final DownloaderService downloader =
        context.read<DownloaderService>();
    if (item.filePresent) {
      await StoragePlacer.deleteFile(item.localPath!);
    }
    await downloader.deleteHistoryItem(item);
    _load();
  }

  Future<void> _clearAll() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Clear the whole library?'),
        content: const Text(
            'This removes every record from the Saxify Downloader library '
            'on this device. The files themselves stay in Download/Saxify.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Clear all',
                style: TextStyle(color: Color(0xFFFF8A8A))),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final DownloaderService downloader =
        context.read<DownloaderService>();
    await downloader.clearHistory();
    _load();
  }

  Future<void> _copyUrl(DownloadItem item) async {
    await Clipboard.setData(ClipboardData(text: item.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text('Link copied to clipboard')));
  }

  Future<void> _openPost(DownloadItem item) async {
    try {
      await launchUrl(Uri.parse(item.url),
          mode: LaunchMode.externalApplication);
    } catch (_) {/* no browser for the scheme — ignore */}
  }

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    final List<DownloadItem> visible = _visible;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search downloads…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
                borderSide: const BorderSide(color: SaxifyColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
                borderSide: BorderSide(color: accent.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: <Widget>[
              for (final MapEntry<String, String> f
                  in <String, String>{
                    'all': 'All',
                    'video': 'Video',
                    'audio': 'Audio'
                  }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.value, style: const TextStyle(fontSize: 11.5)),
                    selected: _filter == f.key,
                    onSelected: (_) =>
                        setState(() => _filter = f.key),
                    selectedColor:
                        accent.primary.withValues(alpha: 0.2),
                    checkmarkColor: accent.primary,
                  ),
                ),
              const Spacer(),
              if (_items.isNotEmpty)
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Clear all',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFFF8A8A))),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.download_for_offline_rounded,
                      title: 'No downloads yet',
                      message:
                          'Everything you download shows up here — '
                          'searchable, openable, shareable.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 40),
                      itemCount: visible.length,
                      itemBuilder: (BuildContext c, int i) =>
                          _LibraryTile(
                            item: visible[i],
                            onOpenPost: () => _openPost(visible[i]),
                            onCopyUrl: () => _copyUrl(visible[i]),
                            onDelete: () => _delete(visible[i]),
                          ),
                    ),
        ),
      ],
    );
  }
}

class _LibraryTile extends StatelessWidget {
  const _LibraryTile({
    required this.item,
    required this.onOpenPost,
    required this.onCopyUrl,
    required this.onDelete,
  });

  final DownloadItem item;
  final VoidCallback onOpenPost;
  final VoidCallback onCopyUrl;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final DownloaderService downloader = context.read<DownloaderService>();
    final SaxifyAccent accent = context.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
          color: SaxifyColors.card,
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(SaxifyTheme.radiusSm),
              child: Artwork(
                url: item.thumbnail ?? '',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                fallbackIcon: item.mediaType == 'audio'
                    ? Icons.music_note_rounded
                    : Icons.video_file_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.platform[0].toUpperCase()}${item.platform.substring(1)}'
                    '${item.quality == null ? '' : ' · ${item.quality}'}'
                    '${item.sizeBytes == null ? '' : ' · ${Fmt.bytes(item.sizeBytes!.toDouble())}'}',
                    style: const TextStyle(
                        fontSize: 10.5, color: SaxifyColors.textFaint),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: item.filePresent ? 'Open file' : 'File missing',
              icon: Icon(
                item.filePresent
                    ? Icons.play_circle_outline_rounded
                    : Icons.error_outline_rounded,
                size: 22,
                color: item.filePresent
                    ? accent.primary
                    : SaxifyColors.textFaint,
              ),
              onPressed: item.filePresent
                  ? () => downloader.openLocalFile(item)
                  : null,
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (String action) {
                switch (action) {
                  case 'again':
                    downloader.downloadAgain(item);
                    break;
                  case 'post':
                    onOpenPost();
                    break;
                  case 'copy':
                    onCopyUrl();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (BuildContext c) =>
                  <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'again',
                  child: Text('Download again',
                      style: TextStyle(fontSize: 12.5)),
                ),
                const PopupMenuItem<String>(
                  value: 'post',
                  child: Text('Open original post',
                      style: TextStyle(fontSize: 12.5)),
                ),
                const PopupMenuItem<String>(
                  value: 'copy',
                  child: Text('Copy link',
                      style: TextStyle(fontSize: 12.5)),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(
                          fontSize: 12.5, color: Color(0xFFFF8A8A))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
