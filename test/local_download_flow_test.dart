import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saxify/core/models/song.dart';
import 'package:saxify/core/services/music_download_service.dart';
import 'package:saxify/core/services/stream_quality.dart';
import 'package:saxify/core/theme/category_palette.dart';
import 'package:saxify/core/theme/saxify_accents.dart';
import 'package:saxify/core/utils/support_email.dart';
import 'package:saxify/data/labels.dart';
import 'package:saxify/downloader/download_history_store.dart';
import 'package:saxify/downloader/downloader_models.dart';
import 'package:saxify/downloader/local_downloader.dart';
import 'package:saxify/downloader/universal_downloader.dart';
import 'package:saxify/core/services/youtube_service.dart';

class FakeOnDeviceYtDlp extends LocalDownloader {
  FakeOnDeviceYtDlp(this.root);
  final Directory root;
  final List<DownloadKind> requests = <DownloadKind>[];
  final List<String> urls = <String>[];

  @override
  bool get supported => true;

  @override
  Future<DownloaderHealth> health() async => const DownloaderHealth(
    ok: true, app: 'On-device downloader', version: 'bundled', ytDlp: true, ffmpeg: true,
  );

  @override
  Future<MediaInfo> fetchInfo(String url) async {
    urls.add(url);
    return MediaInfo.fromJson(<String, dynamic>{
      'title': 'Test song', 'thumbnail': '', 'duration': '3:45',
      'formats': <Map<String, dynamic>>[
        <String, dynamic>{'format_id': '137', 'ext': 'mp4', 'height': 1080,
          'vcodec': 'h264', 'acodec': 'none'},
        <String, dynamic>{'format_id': '140', 'ext': 'm4a',
          'vcodec': 'none', 'acodec': 'aac'},
      ],
    }, url);
  }

  @override
  Future<LocalFile> download({
    required String url, required String jobId, required DownloadKind kind,
    String? formatId, bool formatHasAudio = false,
    required void Function(double fraction) onProgress,
  }) async {
    urls.add(url);
    requests.add(kind);
    onProgress(0.21);
    onProgress(0.79);
    final File file = File('${root.path}/$jobId.${kind == DownloadKind.audio ? 'mp3' : 'mp4'}');
    await file.writeAsBytes(<int>[0x49, 0x44, 0x33, ...List<int>.filled(2048, 1)]);
    return LocalFile(path: file.path, extension: file.path.split('.').last,
      size: await file.length());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('link/bulk uses local pipeline, keeps offline file and progress', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final dir = await Directory.systemTemp.createTemp('saxify-test-');
    try {
      final fake = FakeOnDeviceYtDlp(dir);
      final downloader = UniversalDownloader(
        history: DownloadHistoryStore(prefs), local: fake);
      await downloader.refreshHealth();
      expect(downloader.health?.ok, isTrue);
      downloader.setUrl('https://youtu.be/abc123');
      final MediaInfo? info = await downloader.fetch();
      expect(info?.formats, hasLength(2));
      final List<double> progress = <double>[];
      downloader.addListener(() => progress.add(downloader.fraction));
      final DownloadRecord? saved = await downloader.download(kind: DownloadKind.video, best: true);
      expect(fake.requests.single, DownloadKind.video);
      expect(saved?.path, isNotNull);
      expect(File(saved!.path!).existsSync(), isTrue);
      expect(progress, contains(0.21));
      expect(progress, contains(0.79));
      expect(downloader.fraction, 1);
      expect(DownloadHistoryStore(prefs).read(), hasLength(1));
      downloader.setUrl('https://youtu.be/only');
      await downloader.fetch();
      await downloader.download(kind: DownloadKind.videoOnly, best: true);
      downloader.loadBulk('https://youtu.be/one\nhttps://youtu.be/two');
      expect(await downloader.runBulk(mode: DownloaderMode.audioMp3),
        <String, int>{'done': 2, 'failed': 0, 'skipped': 0});
      expect(fake.requests, <DownloadKind>[DownloadKind.video,
        DownloadKind.videoOnly, DownloadKind.audio, DownloadKind.audio]);
      await downloader.deleteRecord(saved);
      expect(File(saved.path!).existsSync(), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('song saves a genuine audio file path in Your Downloads history', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final dir = await Directory.systemTemp.createTemp('saxify-song-');
    try {
      final fake = FakeOnDeviceYtDlp(dir);
      final downloads = MusicDownloadService(prefs: prefs, local: fake);
      const song = Song(id: 'abc123', title: 'Hindi song', artist: 'Singer', thumbnailUrl: '');
      final MusicDownloadJob job = await downloads.enqueue(song, null);
      expect(job.phase, MusicDownloadPhase.done);
      expect(job.fraction, 1);
      expect(fake.requests.single, DownloadKind.audio);
      expect(fake.urls.single, contains('youtube.com/watch?v=abc123'));
      expect(job.offlinePath, endsWith('.mp3'));
      expect(File(job.offlinePath!).existsSync(), isTrue);
      expect(MusicDownloadService(prefs: prefs, local: fake).downloaded.single.song.id, song.id);
      await downloads.delete(job);
      expect(File(job.offlinePath!).existsSync(), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('quality, categories, metadata, Osho and Sony channel', () {
    expect(preferStreamQuality(<int>[320, 192, 128, 64], 'high').first, 320);
    expect(preferStreamQuality(<int>[320, 192, 128, 64], 'medium').first, 128);
    expect(preferStreamQuality(<int>[320, 192, 128, 64], 'low').first, 64);
    expect(CategoryPalette.colors.toSet().length, greaterThanOrEqualTo(22));
    expect(CategoryPalette.at(0), isNot(CategoryPalette.at(1)));
    expect(SaxifyAccents.byId('silver').label, 'Silver');
    expect(MusicBrands.all.firstWhere((brand) => brand.name == 'Sony Music India').channelId,
      'UC56gTxNs4f9xZ7Pa2i5xNzg');
    expect(YoutubeService.looksLikeSong(title: 'Osho Dynamic Meditation Music',
      author: 'Osho', duration: const Duration(hours: 1, minutes: 40)), isTrue);
    expect(YoutubeService.looksLikeSong(title: 'Nonstop Hindi Lo-Fi Music Mix',
      author: 'Music India', duration: const Duration(hours: 2)), isTrue);
    expect(YoutubeService.looksLikeSong(title: 'Full Movie Trailer',
      author: 'Video channel', duration: const Duration(hours: 2)), isFalse);
  });

  test('Gmail drafts use %20 rather than literal + between words', () {
    const SupportEmail draft = SupportEmail(
      to: 'hello@example.com', category: 'Playback / background',
      details: 'Song stopped after three minutes.',
    );
    expect(draft.mailto.toString(), contains('Song%20stopped'));
    expect(draft.mailto.toString(), isNot(contains('Song+stopped')));
    expect(draft.mailto.queryParameters['body'], contains('Error examples:'));
    expect(draft.mailto.queryParameters['body'], contains('Suggestions:'));
    expect(draft.gmailWeb.toString(), isNot(contains('Song+stopped')));
  });
}
