import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/services/settings_service.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import '../../downloader/downloader_models.dart';
import '../../downloader/platform_detect.dart';
import '../../downloader/universal_downloader.dart';
import '../widgets/artwork.dart';
import '../widgets/neon.dart';
import 'download_library_page.dart';

/// Saxify Downloader. Same workflow as a link saver, Saxify visual language.
class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});

  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage> {
  final TextEditingController _url = TextEditingController();
  final List<TextEditingController> _bulkLinks = <TextEditingController>[
    TextEditingController(),
  ];
  bool _bulkMode = false;
  DownloadKind _kind = DownloadKind.video;
  String? _formatId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final SettingsService settings = context.read<SettingsService>();
      final UniversalDownloader downloader = context.read<UniversalDownloader>();
      downloader.api.baseUrl = settings.downloaderBaseUrl;
      downloader.refreshHealth();
      final DownloaderMode mode = settings.downloaderMode;
      if (mode == DownloaderMode.audioMp3) {
        setState(() => _kind = DownloadKind.audio);
      }
    });
  }

  @override
  void dispose() {
    _url.dispose();
    for (final TextEditingController controller in _bulkLinks) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    final String text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    if (_bulkMode) {
      final List<String> urls = PlatformDetect.splitUrls(text);
      if (urls.isNotEmpty) {
        setState(() {
          for (final TextEditingController controller in _bulkLinks) {
            controller.dispose();
          }
          _bulkLinks
            ..clear()
            ..addAll(urls.map((String url) => TextEditingController(text: url)));
        });
        _syncBulk();
      }
    } else {
      _url.text = PlatformDetect.splitUrls(text).first;
      context.read<UniversalDownloader>().setUrl(_url.text);
      setState(() {});
    }
  }

  void _syncBulk() {
    final String raw = _bulkLinks
        .map((TextEditingController controller) => controller.text.trim())
        .where((String url) => url.isNotEmpty)
        .join('\n');
    context.read<UniversalDownloader>().loadBulk(raw);
  }

  void _addBulkLink() {
    setState(() => _bulkLinks.add(TextEditingController()));
  }

  void _removeBulkLink(int index) {
    if (_bulkLinks.length == 1) {
      _bulkLinks.first.clear();
    } else {
      _bulkLinks.removeAt(index).dispose();
    }
    setState(() {});
    _syncBulk();
  }

  Future<void> _fetch() async {
    final UniversalDownloader downloader = context.read<UniversalDownloader>();
    downloader.setUrl(_url.text);
    await downloader.fetch();
  }

  Future<void> _download(UniversalDownloader downloader) async {
    final DownloadKind kind = _kind;
    MediaFormat? format;
    if (_formatId != null && downloader.info != null) {
      for (final MediaFormat item in downloader.info!.formats) {
        if (item.id == _formatId) format = item;
      }
    }
    final DownloadRecord? record = await downloader.download(
      kind: kind,
      format: format,
      best: format == null,
    );
    if (!mounted) return;
    final String message = record != null
        ? 'Saved to Download/Saxify'
        : (downloader.jobError ?? 'Download failed');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final UniversalDownloader downloader = context.watch<UniversalDownloader>();
    final SettingsService settings = context.watch<SettingsService>();
    final MediaInfo? info = downloader.info;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Saxify Downloader',
                    style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Library',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const DownloadLibraryPage()),
                  ),
                  icon: const Icon(Icons.folder_outlined),
                ),
              ],
            ),
            Text(
              downloader.health == null
                  ? 'Checking server…'
                  : downloader.health!.ok
                      ? '${downloader.health!.app} · ${downloader.health!.version}'
                      : (downloader.health!.error ?? 'Server unreachable'),
              style: const TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final DownloaderMode mode in DownloaderMode.values)
                  ChoiceChip(
                    label: Text(_modeLabel(mode)),
                    selected: settings.downloaderMode == mode,
                    onSelected: (_) {
                      settings.setDownloaderMode(mode);
                      setState(() {
                        _kind = mode == DownloaderMode.audioMp3
                            ? DownloadKind.audio
                            : DownloadKind.video;
                        _formatId = null;
                      });
                    },
                  ),
                ChoiceChip(
                  label: const Text('Bulk'),
                  selected: _bulkMode,
                  onSelected: (bool v) => setState(() => _bulkMode = v),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Downloads use best quality by default. Public YouTube links are sent to the configured backend; private or login-gated content is not supported.',
              style: TextStyle(fontSize: 11, color: SaxifyColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (!_bulkMode) ...<Widget>[
              TextField(
                controller: _url,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Paste a public link',
                  suffixIcon: IconButton(
                    tooltip: 'Paste',
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste_rounded),
                  ),
                ),
                onChanged: downloader.setUrl,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Detected: ${PlatformDetect.label(downloader.detected)}',
                      style: const TextStyle(fontSize: 12, color: SaxifyColors.textSecondary),
                    ),
                  ),
                  TextButton(onPressed: _fetch, child: const Text('Fetch')),
                ],
              ),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    for (final MediaPlatform platform in PlatformDetect.manual)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(PlatformDetect.label(platform), style: const TextStyle(fontSize: 11)),
                          selected: downloader.overridePlatform == platform,
                          onSelected: (_) => downloader.setOverride(platform),
                        ),
                      ),
                  ],
                ),
              ),
              if (downloader.platformMismatch)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Platform mismatch — the link does not match the platform you picked.',
                    style: TextStyle(color: SaxifyColors.danger, fontSize: 12),
                  ),
                ),
              if (downloader.fetching)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (downloader.infoError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(downloader.infoError!, style: const TextStyle(color: SaxifyColors.danger)),
                ),
              if (info != null) ...<Widget>[
                const SizedBox(height: 12),
                NeonCard(
                  child: Row(
                    children: <Widget>[
                      Artwork(url: info.thumbnail, size: 72, radius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(info.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              '${info.sourceHost} · ${info.duration}',
                              style: const TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('Video + audio'),
                      selected: _kind == DownloadKind.video,
                      onSelected: (_) => setState(() {
                        _kind = DownloadKind.video;
                        _formatId = null;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Video only'),
                      selected: _kind == DownloadKind.videoOnly,
                      onSelected: (_) => setState(() {
                        _kind = DownloadKind.videoOnly;
                        _formatId = null;
                      }),
                    ),
                    ChoiceChip(
                      label: const Text('Audio only (MP3)'),
                      selected: _kind == DownloadKind.audio,
                      onSelected: (_) => setState(() {
                        _kind = DownloadKind.audio;
                        _formatId = null;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('Best quality'),
                      selected: _formatId == null,
                      onSelected: (_) => setState(() => _formatId = null),
                    ),
                    for (final MediaFormat format in info.formats.where(
                      (MediaFormat format) => switch (_kind) {
                        DownloadKind.audio => format.hasAudio,
                        DownloadKind.videoOnly => format.hasVideo && !format.hasAudio,
                        DownloadKind.video => format.hasVideo && format.hasAudio,
                      },
                    ))
                      ChoiceChip(
                        label: Text(format.label),
                        selected: _formatId == format.id,
                        onSelected: (_) => setState(() => _formatId = format.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                NeonButton(
                  label: downloader.jobStatus == JobStatus.downloading ? 'Downloading…' : 'Download',
                  icon: Icons.download_rounded,
                  expand: true,
                  onPressed: downloader.jobStatus == JobStatus.downloading
                      ? null
                      : () => _download(downloader),
                ),
              ],
            ] else ...<Widget>[
              const Text(
                'Format · best quality by default',
                style: TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('Video + audio'),
                    selected: _kind == DownloadKind.video,
                    onSelected: downloader.bulkRunning
                        ? null
                        : (_) => setState(() {
                              _kind = DownloadKind.video;
                              _formatId = null;
                            }),
                  ),
                  ChoiceChip(
                    label: const Text('Video only'),
                    selected: _kind == DownloadKind.videoOnly,
                    onSelected: downloader.bulkRunning
                        ? null
                        : (_) => setState(() {
                              _kind = DownloadKind.videoOnly;
                              _formatId = null;
                            }),
                  ),
                  ChoiceChip(
                    label: const Text('Audio only (MP3)'),
                    selected: _kind == DownloadKind.audio,
                    onSelected: downloader.bulkRunning
                        ? null
                        : (_) => setState(() {
                              _kind = DownloadKind.audio;
                              _formatId = null;
                            }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < _bulkLinks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _bulkLinks[i],
                          enabled: !downloader.bulkRunning,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Link ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => _syncBulk(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove link',
                        onPressed: downloader.bulkRunning ? null : () => _removeBulkLink(i),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: downloader.bulkRunning ? null : _addBulkLink,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add link'),
                  ),
                  TextButton.icon(
                    onPressed: downloader.bulkRunning ? null : _paste,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('Paste links'),
                  ),
                ],
              ),
              for (int i = 0; i < downloader.bulk.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(downloader.bulk[i].title ?? downloader.bulk[i].url,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${PlatformDetect.label(downloader.bulk[i].detected)} · ${downloader.bulk[i].status.name}'
                        '${downloader.bulk[i].message == null ? '' : ' · ${downloader.bulk[i].message}'}',
                        maxLines: 2,
                        style: const TextStyle(fontSize: 11, color: SaxifyColors.textMuted),
                      ),
                      if (downloader.bulk[i].status == JobStatus.downloading)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: LinearProgressIndicator(
                            value: downloader.bulk[i].fraction <= 0
                                ? null
                                : downloader.bulk[i].fraction,
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: NeonButton(
                      label: downloader.bulkRunning ? 'Queue running…' : 'Start queue',
                      icon: Icons.playlist_play_rounded,
                      expand: true,
                      onPressed: downloader.bulkRunning || downloader.bulk.isEmpty
                          ? null
                          : () async {
                              final Map<String, int> summary = await downloader.runBulk(
                                mode: settings.downloaderMode,
                                kind: _kind,
                              );
                              if (!context.mounted) return;
                              await showDialog<void>(
                                context: context,
                                builder: (BuildContext dialog) => AlertDialog(
                                  title: const Text('Bulk finished'),
                                  content: Text(
                                    'DONE ${summary['done'] ?? 0}\n'
                                    'FAILED ${summary['failed'] ?? 0}\n'
                                    'SKIPPED ${summary['skipped'] ?? 0}',
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialog),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: downloader.bulkRunning ? downloader.requestStopBulk : null,
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ],
            if (downloader.jobStatus == JobStatus.downloading) ...<Widget>[
              const SizedBox(height: 14),
              LinearProgressIndicator(value: downloader.fraction == 0 ? null : downloader.fraction),
              const SizedBox(height: 6),
              Text(
                '${(downloader.fraction * 100).round()}% · ${downloader.speedLabel}'
                '${downloader.startedAt == null ? '' : ' · ${Fmt.clock(DateTime.now().difference(downloader.startedAt!))}'}',
                style: const TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: downloader.cancel, child: const Text('Cancel')),
              ),
            ],
            if (downloader.jobError != null && downloader.jobStatus == JobStatus.failed)
              Text(downloader.jobError!, style: const TextStyle(color: SaxifyColors.danger)),
          ],
        ),
      ),
    );
  }

  String _modeLabel(DownloaderMode mode) {
    switch (mode) {
      case DownloaderMode.bestVideo:
        return 'Best Video';
      case DownloaderMode.audioMp3:
        return 'Audio MP3';
      case DownloaderMode.ask:
        return 'Ask Me';
    }
  }
}
