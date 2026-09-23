import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/backend_config.dart';
import '../core/services/native_bridge.dart';
import '../core/utils/filenames.dart';
import 'download_history_store.dart';
import 'downloader_api.dart';
import 'downloader_models.dart';
import 'platform_detect.dart';

/// Universal downloader. Separate from music playback and from the music
/// stream resolver. Uses the downloader backend (yt-dlp / ffmpeg server-side).
class UniversalDownloader extends ChangeNotifier {
  UniversalDownloader({
    required DownloadHistoryStore history,
    DownloaderApi? api,
    Dio? dio,
  })  : _history = history,
        api = api ?? DownloaderApi(),
        _dio = dio ?? Dio() {
    records = _history.read();
  }

  final DownloadHistoryStore _history;
  final DownloaderApi api;
  final Dio _dio;

  List<DownloadRecord> records = <DownloadRecord>[];
  DownloaderHealth? health;
  bool healthLoading = false;

  MediaInfo? info;
  String? infoError;
  bool fetching = false;
  String activeUrl = '';
  MediaPlatform detected = MediaPlatform.other;
  MediaPlatform overridePlatform = MediaPlatform.auto;

  JobStatus jobStatus = JobStatus.idle;
  double fraction = 0;
  int received = 0;
  int? total;
  DateTime? startedAt;
  String? jobError;
  String speedLabel = '';
  CancelToken? _token;
  bool stopBulk = false;
  bool bulkRunning = false;
  BulkRow? _activeBulkRow;

  final List<BulkRow> bulk = <BulkRow>[];

  MediaPlatform get effectivePlatform =>
      overridePlatform == MediaPlatform.auto ? detected : overridePlatform;

  bool get platformMismatch =>
      overridePlatform != MediaPlatform.auto &&
      detected != MediaPlatform.other &&
      overridePlatform != detected;

  void setUrl(String url) {
    activeUrl = url.trim();
    detected = PlatformDetect.detect(activeUrl);
    info = null;
    infoError = null;
    notifyListeners();
  }

  void setOverride(MediaPlatform platform) {
    overridePlatform = platform;
    notifyListeners();
  }

  Future<void> refreshHealth() async {
    healthLoading = true;
    notifyListeners();
    health = await api.health();
    healthLoading = false;
    notifyListeners();
  }

  Future<MediaInfo?> fetch() async {
    final String? blocked = PlatformDetect.blockedReason(activeUrl);
    if (blocked != null) {
      infoError = blocked;
      info = null;
      notifyListeners();
      return null;
    }
    fetching = true;
    infoError = null;
    notifyListeners();
    try {
      final MediaInfo loaded = await api.fetchInfo(activeUrl);
      info = loaded;
      return loaded;
    } catch (e) {
      info = null;
      infoError = classifyDownloadError(e);
      return null;
    } finally {
      fetching = false;
      notifyListeners();
    }
  }

  Future<DownloadRecord?> download({
    required DownloadKind kind,
    MediaFormat? format,
    bool best = false,
  }) async {
    final String? blocked = PlatformDetect.blockedReason(activeUrl);
    if (blocked != null) {
      jobError = blocked;
      jobStatus = JobStatus.failed;
      notifyListeners();
      return null;
    }
    final String type = switch (kind) {
      DownloadKind.audio => 'audio',
      DownloadKind.videoOnly => 'video_only',
      DownloadKind.video => 'video',
    };
    final String ext = kind == DownloadKind.audio ? 'mp3' : 'mp4';
    final String title = info?.title ?? 'download';
    final String name = Filenames.saxify(title, ext);
    jobStatus = JobStatus.downloading;
    fraction = 0;
    received = 0;
    total = null;
    jobError = null;
    startedAt = DateTime.now();
    speedLabel = '';
    notifyListeners();

    File? temp;
    _token = CancelToken();
    int lastBytes = 0;
    DateTime lastTick = DateTime.now();

    try {
      final Directory cache = await getTemporaryDirectory();
      final File tempFile = File('${cache.path}/$name.part');
      temp = tempFile;
      if (tempFile.existsSync()) await tempFile.delete();
      final Uri uri = api.downloadUri(
        url: activeUrl,
        type: type,
        formatId: best ? null : format?.id,
      );
      await _dio.download(
        uri.toString(),
        tempFile.path,
        cancelToken: _token,
        options: Options(
          headers: BackendConfig.downloadHeaders(),
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 20),
        ),
        onReceiveProgress: (int got, int all) {
          received = got;
          total = all > 0 ? all : null;
          fraction = all <= 0 ? 0 : (got / all).clamp(0.0, 1.0);
          if (_activeBulkRow != null) _activeBulkRow!.fraction = fraction;
          final DateTime now = DateTime.now();
          final int ms = now.difference(lastTick).inMilliseconds;
          if (ms > 400) {
            final double kbps = (got - lastBytes) / ms;
            speedLabel = '${kbps.toStringAsFixed(0)} KB/s';
            lastBytes = got;
            lastTick = now;
          }
          notifyListeners();
        },
      );

      final int size = await tempFile.length();
      final RandomAccessFile raf = await tempFile.open();
      final List<int> head = await raf.read(48);
      await raf.close();
      if (Filenames.looksCorrupt(head, size)) {
        throw Exception('File was empty or corrupt');
      }
      final File finalFile = File('${cache.path}/$name');
      if (finalFile.existsSync()) await finalFile.delete();
      await tempFile.rename(finalFile.path);

      SavedFile? saved;
      try {
        saved = await NativeBridge.saveToDownloads(
          sourcePath: finalFile.path,
          displayName: name,
          mime: kind == DownloadKind.audio ? 'audio/mpeg' : 'video/mp4',
        );
      } catch (e) {
        debugPrint('[Saxify][UniversalDownloader] public save failed: $e');
      }
      final DownloadRecord record = DownloadRecord(
        id: 'dl_${DateTime.now().microsecondsSinceEpoch}',
        url: activeUrl,
        title: title,
        platform: effectivePlatform,
        kind: kind,
        quality: format?.label ?? (best ? 'Best available' : type),
        createdAt: DateTime.now(),
        thumbnail: info?.thumbnail ?? '',
        size: size,
        path: saved?.path ?? finalFile.path,
        uri: saved?.uri,
        status: JobStatus.done,
      );
      records.insert(0, record);
      await _history.write(records);
      jobStatus = JobStatus.done;
      fraction = 1;
      notifyListeners();
      return record;
    } on DioException catch (e) {
      _deleteTemp(temp);
      jobStatus = CancelToken.isCancel(e) ? JobStatus.cancelled : JobStatus.failed;
      jobError = CancelToken.isCancel(e)
          ? 'Cancelled'
          : classifyDownloadError(e, status: e.response?.statusCode, body: '${e.response?.data}');
    } catch (e) {
      _deleteTemp(temp);
      jobStatus = JobStatus.failed;
      jobError = classifyDownloadError(e);
    } finally {
      _token = null;
      notifyListeners();
    }
    return null;
  }

  void cancel() => _token?.cancel('user');

  void _deleteTemp(File? file) {
    try {
      if (file?.existsSync() == true) file!.deleteSync();
    } catch (e) {
      debugPrint('[Saxify][UniversalDownloader] temp cleanup failed: $e');
    }
  }

  void loadBulk(String raw) {
    bulk
      ..clear()
      ..addAll(PlatformDetect.splitUrls(raw).map((String url) {
        final BulkRow row = BulkRow(url);
        row.detected = PlatformDetect.detect(url);
        return row;
      }));
    notifyListeners();
  }

  void removeBulk(int index) {
    if (index < 0 || index >= bulk.length) return;
    bulk.removeAt(index);
    notifyListeners();
  }

  void clearBulk() {
    bulk.clear();
    notifyListeners();
  }

  Future<Map<String, int>> runBulk({
    required DownloaderMode mode,
    DownloadKind? kind,
  }) async {
    if (bulkRunning) return <String, int>{'done': 0, 'failed': 0, 'skipped': 0};
    stopBulk = false;
    bulkRunning = true;
    int done = 0;
    int failed = 0;
    int skipped = 0;
    notifyListeners();
    try {
      for (final BulkRow row in List<BulkRow>.of(bulk)) {
        if (stopBulk) {
          row.status = JobStatus.cancelled;
          skipped++;
          notifyListeners();
          continue;
        }
        final String? blocked = PlatformDetect.blockedReason(row.url);
        if (blocked != null) {
          row.status = JobStatus.skipped;
          row.message = blocked;
          skipped++;
          notifyListeners();
          continue;
        }
        row.status = JobStatus.fetching;
        row.fraction = 0;
        notifyListeners();
        setUrl(row.url);
        final MediaInfo? meta = await fetch();
        if (stopBulk) {
          row.status = JobStatus.cancelled;
          skipped++;
          notifyListeners();
          continue;
        }
        if (meta == null) {
          row.status = JobStatus.failed;
          row.message = infoError;
          failed++;
          notifyListeners();
          continue;
        }
        row.title = meta.title;
        final DownloadKind downloadKind = kind ??
            (mode == DownloaderMode.audioMp3 ? DownloadKind.audio : DownloadKind.video);
        row.status = JobStatus.downloading;
        row.fraction = 0;
        _activeBulkRow = row;
        notifyListeners();
        final DownloadRecord? record = await download(kind: downloadKind, best: true);
        _activeBulkRow = null;
        if (record != null) {
          row.status = JobStatus.done;
          row.fraction = 1;
          done++;
        } else if (jobStatus == JobStatus.cancelled) {
          row.status = JobStatus.cancelled;
          skipped++;
        } else {
          row.status = JobStatus.failed;
          row.message = jobError;
          failed++;
        }
        notifyListeners();
      }
    } finally {
      _activeBulkRow = null;
      bulkRunning = false;
      notifyListeners();
    }
    return <String, int>{'done': done, 'failed': failed, 'skipped': skipped};
  }

  void requestStopBulk() {
    stopBulk = true;
    cancel();
    notifyListeners();
  }

  Future<void> deleteRecord(DownloadRecord record) async {
    await NativeBridge.deleteDownload(uri: record.uri, path: record.path);
    records.removeWhere((DownloadRecord r) => r.id == record.id);
    await _history.write(records);
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final DownloadRecord record in List<DownloadRecord>.of(records)) {
      await NativeBridge.deleteDownload(uri: record.uri, path: record.path);
    }
    records = <DownloadRecord>[];
    await _history.write(records);
    notifyListeners();
  }

  List<DownloadRecord> filtered(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return records;
    return records
        .where((DownloadRecord r) =>
            r.title.toLowerCase().contains(q) ||
            r.url.toLowerCase().contains(q) ||
            r.platform.name.contains(q))
        .toList();
  }
}
