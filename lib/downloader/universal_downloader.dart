import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/services/native_bridge.dart';
import '../core/utils/filenames.dart';
import 'download_history_store.dart';
import 'downloader_models.dart';
import 'local_downloader.dart';
import 'platform_detect.dart';

/// Bulk and single-link downloads share one on-device yt-dlp pipeline. No
/// download-server health/fetch/download endpoint is ever used here.
class UniversalDownloader extends ChangeNotifier {
  UniversalDownloader({
    required DownloadHistoryStore history,
    LocalDownloader? local,
  })  : _history = history,
        _local = local ?? LocalDownloader() {
    records = _history.read();
  }

  final DownloadHistoryStore _history;
  final LocalDownloader _local;

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
  String? _jobId;
  bool _cancelRequested = false;
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
    health = await _local.health();
    healthLoading = false;
    notifyListeners();
  }

  Future<MediaInfo?> fetch() async {
    final String url = activeUrl;
    final String? blocked = PlatformDetect.blockedReason(url);
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
      final MediaInfo loaded = await _local.fetchInfo(url);
      if (activeUrl != url) return null; // don't show a previous link's formats
      info = loaded;
      return loaded;
    } catch (error) {
      if (activeUrl == url) {
        info = null;
        infoError = localDownloadError(error);
      }
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
    if (_jobId != null) return null;
    final String url = activeUrl;
    final String? blocked = PlatformDetect.blockedReason(url);
    if (blocked != null) {
      jobError = blocked;
      jobStatus = JobStatus.failed;
      notifyListeners();
      return null;
    }
    final String title = info?.title ?? 'download';
    final String thumbnail = info?.thumbnail ?? '';
    final MediaPlatform platform = effectivePlatform;
    final String jobId = LocalDownloader.newJobId();
    _jobId = jobId;
    _cancelRequested = false;
    jobStatus = JobStatus.downloading;
    fraction = 0;
    received = 0;
    total = null;
    jobError = null;
    speedLabel = 'On device';
    startedAt = DateTime.now();
    notifyListeners();

    LocalFile? file;
    try {
      file = await _local.download(
        url: url,
        jobId: jobId,
        kind: kind,
        formatId: best ? null : format?.id,
        formatHasAudio: format?.hasAudio ?? false,
        onProgress: (double value) {
          if (_jobId != jobId || _cancelRequested) return;
          fraction = value;
          if (_activeBulkRow != null) _activeBulkRow!.fraction = value;
          notifyListeners();
        },
      );
      if (_cancelRequested) throw StateError('Download cancelled');
      if (!await File(file.path).exists()) throw StateError('Downloaded file is missing');
      final String name = Filenames.saxify(title, file.extension.isEmpty ? 'mp4' : file.extension);
      SavedFile? saved;
      try {
        saved = await NativeBridge.saveToDownloads(
          sourcePath: file.path, displayName: name, mime: file.mime,
        );
      } catch (error) {
        debugPrint('Public Downloads copy unavailable: $error');
      }
      if (_cancelRequested) {
        await NativeBridge.deleteDownload(uri: saved?.uri,
          path: saved?.uri?.startsWith('file:') == true ? saved?.path : null);
        throw StateError('Download cancelled');
      }
      final DownloadRecord record = DownloadRecord(
        id: jobId,
        url: url,
        title: title,
        platform: platform,
        kind: kind,
        quality: format?.label ?? 'Best available',
        createdAt: DateTime.now(),
        thumbnail: thumbnail,
        size: file.size,
        // Keep the private file for offline use even if MediaStore fails.
        path: file.path,
        uri: saved?.uri,
      );
      records.insert(0, record);
      await _history.write(records);
      jobStatus = JobStatus.done;
      fraction = 1;
      notifyListeners();
      return record;
    } catch (error) {
      if (file != null) {
        try { await File(file.path).parent.delete(recursive: true); } catch (_) {}
      }
      jobStatus = _cancelRequested || localDownloadError(error).toLowerCase().contains('cancel')
          ? JobStatus.cancelled : JobStatus.failed;
      jobError = jobStatus == JobStatus.cancelled ? 'Download cancelled' : localDownloadError(error);
    } finally {
      _jobId = null;
      notifyListeners();
    }
    return null;
  }

  void cancel() {
    _cancelRequested = true;
    final String? id = _jobId;
    if (id != null) _local.cancel(id);
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
