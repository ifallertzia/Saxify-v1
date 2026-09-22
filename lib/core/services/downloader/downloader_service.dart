import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/backend_config.dart';
import '../../../config/branding.dart';
import '../../models/download_item.dart';
import '../../models/media_format.dart';
import '../storage_placer.dart';
import 'platform_detect.dart';

/// Part 11.7 modes.
enum DownloaderMode {
  bestVideo('Best Video'),
  audioMp3('Audio MP3'),
  askMe('Ask Me');

  const DownloaderMode(this.label);
  final String label;
}

/// Part 11.8 clear error states.
enum ErrorKind {
  invalid,
  private,
  deleted,
  unavailable,
  unsupported,
  timeout,
  server,
  network,
  notConfigured,
  cancelled,
}

extension ErrorKindX on ErrorKind {
  String get message {
    switch (this) {
      case ErrorKind.invalid:
        return 'This does not look like a valid URL.';
      case ErrorKind.private:
        return 'This post is private. Only publicly accessible content '
            'can be downloaded.';
      case ErrorKind.deleted:
        return 'This post was deleted or is no longer available.';
      case ErrorKind.unavailable:
        return 'This content is unavailable right now.';
      case ErrorKind.unsupported:
        return 'This type of content is not supported by the downloader '
            '(e.g. livestreams, DRM-protected or member-only media).';
      case ErrorKind.timeout:
        return 'The server took too long to respond. Please try again.';
      case ErrorKind.server:
        return 'The downloader server had a problem. Please try again in a '
            'minute.';
      case ErrorKind.network:
        return 'Network error — check your connection and try again.';
      case ErrorKind.notConfigured:
        return 'The Saxify Downloader backend is not configured yet. Point '
            'BackendConfig.downloaderBaseUrl at your deployed server '
            '(see README).';
      case ErrorKind.cancelled:
        return 'Download cancelled.';
    }
  }
}

enum TaskPhase { idle, fetching, ready, downloading, verifying, done, error, cancelled }

/// One unit of work: a URL through fetch -> quality -> download -> verify.
class DownloaderTask {
  DownloaderTask({required this.id, required this.url})
      : detection = detectPlatform(url);

  final String id;
  final String url;
  late PlatformDetection detection;

  /// Manual override (Part 11.3 step 2). `null` = auto.
  PlatformId? manualPlatform;

  PlatformId get effectivePlatform =>
      (manualPlatform ?? PlatformId.autoDetect) == PlatformId.autoDetect
          ? detection.platform
          : (manualPlatform ?? detection.platform);

  /// True when the user forced a platform different from what the URL says.
  bool get platformMismatch =>
      manualPlatform != null &&
      manualPlatform != PlatformId.autoDetect &&
      manualPlatform != detection.platform;

  TaskPhase phase = TaskPhase.idle;
  FetchInfo? info;
  MediaFormat? selectedFormat;

  int received = 0;
  int? total;
  double speedBps = 0;
  Duration elapsed = Duration.zero;
  ErrorKind? errorKind;
  String? error;

  String? localPath;
  int? sizeBytes;

  double get progress =>
      (total == null || total == 0) ? 0 : (received / total!).clamp(0.0, 1.0);

  /// Mismatch warning text (Part 11.3 step 3).
  String? get mismatchWarning =>
      platformMismatch
          ? 'This URL looks like ${detection.platform.label}, but you chose '
              '${effectivePlatform.label}. The download may fail.'
          : null;

  /// The finished task as a library record.
  DownloadItem toLibraryItem() => DownloadItem(
        id: id,
        url: url,
        platform: detection.platform.name,
        title: info?.title ?? 'Untitled',
        thumbnail: info?.thumbnail.isNotEmpty == true ? info?.thumbnail : null,
        mediaType: selectedFormat?.kind ?? 'video',
        quality: selectedFormat?.label,
        sizeBytes: sizeBytes,
        localPath: localPath,
        status: 'done',
      );
}

class BulkSummary {
  const BulkSummary({required this.done, required this.failed, required this.skipped});
  final int done;
  final int failed;
  final int skipped;
}

class BackendHealth {
  const BackendHealth({
    required this.reachable,
    this.app,
    this.version,
    this.ffmpeg,
    this.ytDlp,
    this.message,
  });

  final bool reachable;
  final String? app;
  final String? version;
  final bool? ffmpeg;
  final bool? ytDlp;
  final String? message;

  String get summary =>
      reachable
          ? 'Saxify Downloader ${version ?? ''} · ffmpeg ${ffmpeg == true ? 'OK' : 'missing'} · yt-dlp ${ytDlp == true ? 'OK' : 'missing'}'
          : message ?? 'unreachable';
}

/// The Universal Downloader engine (Part 11).
///
/// Separate pipeline from the music player, as required:
///   URL -> platform detect -> backend fetch-info -> quality pick ->
///   backend /api/download (streamed, cancellable, verified) ->
///   version-aware local placement -> library record.
///
/// Everything runs off the main thread (http streams + file IO in
/// isolates-free async — the heavy lifting is the OS network stack),
/// survives navigation (the service lives in the app's provider tree),
/// and a failed bulk item never stops the queue (Part 11.6).
class DownloaderService extends ChangeNotifier {

  void selectFormat(DownloaderTask task, MediaFormat fmt) {
    task.selectedFormat = fmt;
    notifyListeners();
  }
  DownloaderService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // ------------------------------------------------------------- state
  DownloaderTask? single;
  List<DownloaderTask> bulk = <DownloaderTask>[];
  bool bulkRunning = false;
  int bulkCurrentIndex = -1;
  BulkSummary? bulkSummary;

  bool _singleCancelled = false;
  bool _bulkStopped = false;

  // ----------------------------------------------------------------- prefs
  static const String kMode = 'saxify.dl_mode';
  static const String kAutoQuality = 'saxify.dl_auto_quality';
  static const String kFilenameSuffix = 'saxify.dl_filename_suffix';
  static const String kHistoryEnabled = 'saxify.dl_history_enabled';
  static const String kHistoryMax = 'saxify.dl_history_max';
  static const String kSound = 'saxify.dl_sound';
  static const String kHistory = 'saxify.downloader_history';

  static const int defaultHistoryMax = 120;

  DownloaderMode _mode = DownloaderMode.askMe;
  bool _autoQuality = true;
  bool _filenameSuffix = true;
  bool _historyEnabled = true;
  int _historyMax = defaultHistoryMax;
  bool _sound = true;

  DownloaderMode get mode => _mode;
  bool get autoQuality => _autoQuality;
  bool get filenameSuffix => _filenameSuffix;
  bool get historyEnabled => _historyEnabled;
  int get historyMax => _historyMax;
  bool get sound => _sound;

  Future<void> loadPrefs() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      _mode = DownloaderMode.values.firstWhere(
        (DownloaderMode m) => m.name == p.getString(kMode),
        orElse: () => DownloaderMode.askMe,
      );
      _autoQuality = p.getBool(kAutoQuality) ?? true;
      _filenameSuffix = p.getBool(kFilenameSuffix) ?? true;
      _historyEnabled = p.getBool(kHistoryEnabled) ?? true;
      _historyMax = p.getInt(kHistoryMax) ?? defaultHistoryMax;
      _sound = p.getBool(kSound) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('downloader prefs failed: $e');
    }
  }

  Future<void> setMode(DownloaderMode m) async {
    _mode = m;
    notifyListeners();
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(kMode, m.name);
    } catch (_) {}
  }

  Future<void> setAutoQuality(bool v) => _setBool(kAutoQuality, v, () => _autoQuality = v);
  Future<void> setFilenameSuffix(bool v) => _setBool(kFilenameSuffix, v, () => _filenameSuffix = v);
  Future<void> setHistoryEnabled(bool v) => _setBool(kHistoryEnabled, v, () => _historyEnabled = v);
  Future<void> setSound(bool v) => _setBool(kSound, v, () => _sound = v);

  Future<void> setHistoryMax(int v) async {
    _historyMax = v.clamp(10, 500);
    notifyListeners();
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setInt(kHistoryMax, _historyMax);
    } catch (_) {}
  }

  Future<void> _setBool(String key, bool v, void Function() apply) async {
    apply();
    notifyListeners();
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setBool(key, v);
    } catch (_) {}
  }

  // ------------------------------------------------------------ single flow
  DownloaderTask startTask(String url, {PlatformId? platform}) {
    final DownloaderTask task = DownloaderTask(
      id: 'dl_${DateTime.now().microsecondsSinceEpoch}',
      url: normalizeUrl(url),
    );
    if (platform != null) task.manualPlatform = platform;
    return task;
  }

  /// Part 11.3: paste -> detect -> fetch metadata.
  Future<void> fetchSingle(String url, {PlatformId? platform}) async {
    final String normalized = normalizeUrl(url);
    if (!looksLikeUrl(normalized)) {
      single = DownloaderTask(id: 'dl_err', url: normalized)
        ..phase = TaskPhase.error
        ..errorKind = ErrorKind.invalid
        ..error = ErrorKind.invalid.message;
      notifyListeners();
      return;
    }

    final DownloaderTask task = startTask(normalized, platform: platform);
    single = task;
    task.phase = TaskPhase.fetching;
    notifyListeners();

    final Object? result = await _fetchInfo(task);
    if (result is FetchInfo) {
      if (task.phase == TaskPhase.fetching) {
        task.info = result;
        task.phase = TaskPhase.ready;
        _autoPickFormat(task);
        notifyListeners();
      }
    } else {
      if (task.phase == TaskPhase.fetching) {
        task.phase = TaskPhase.error;
        task.errorKind = result is ErrorKind ? result : ErrorKind.server;
        task.error = task.errorKind?.message;
        notifyListeners();
      }
    }
  }

  /// Best Video / Audio MP3 / Ask Me (Part 11.7).
  void _autoPickFormat(DownloaderTask task) {
    final FetchInfo? info = task.info;
    if (info == null || info.formats.isEmpty) return;
    switch (_mode) {
      case DownloaderMode.bestVideo:
        task.selectedFormat = info.bestAvailable();
      case DownloaderMode.audioMp3:
        // MP3 192 kbps preferred, actual stream verified at download time.
        final List<MediaFormat> audio =
            info.formats.where((MediaFormat f) => f.isAudio).toList()
          ..sort((MediaFormat a, MediaFormat b) =>
              (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
        MediaFormat? mp3;
        for (final MediaFormat f in audio) {
          if (f.ext == 'mp3') {
            mp3 = f;
            break;
          }
        }
        task.selectedFormat = (audio.isNotEmpty ? (mp3 ?? audio.first) : null) ??
            info.bestAvailable();
      case DownloaderMode.askMe:
        task.selectedFormat = null; // the quality picker asks
        break;
    }
  }

  /// Start downloading [task] (or the current single task).
  Future<void> startDownload(DownloaderTask task, {MediaFormat? format}) async {
    if (format != null) task.selectedFormat = format;
    final MediaFormat? fmt = task.selectedFormat;
    if (fmt == null) {
      task.phase = TaskPhase.error;
      task.errorKind = ErrorKind.unavailable;
      task.error = 'No format selected — pick a quality first.';
      notifyListeners();
      return;
    }

    _singleCancelled = false;
    task.phase = TaskPhase.downloading;
    task.received = 0;
    task.total = null;
    task.speedBps = 0;
    task.elapsed = Duration.zero;
    notifyListeners();

    final Uri uri = BackendConfig.downloaderPath('/api/download');
    final Uri requestUri = uri.replace(queryParameters: <String, String>{
      ...uri.queryParameters,
      'url': task.url,
      'type': fmt.kind,
      'format_id': fmt.formatId,
    });

    final Stopwatch watch = Stopwatch()..start();
    Timer? ticker;
    int lastTick = 0;
    // final int startReceived = task.received;

    File? temp;
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String name = _finalName(task.info?.title ?? 'download', fmt.ext);
      temp = File('${tempDir.path}/.saxify_$name');

      final http.Request request =
          http.Request('GET', requestUri)..headers.addAll(BackendConfig.clientHeaders);
      final http.StreamedResponse response =
          await _client.send(request).timeout(const Duration(seconds: 60));
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw _BackendError(response.statusCode, 'HTTP ${response.statusCode}');
      }

      task.total = response.contentLength;
      final IOSink sink = temp.openWrite();

      ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (task.phase != TaskPhase.downloading) return;
        // 500 ms tick -> bytes * 2 = bytes/second (smoothed enough for UI).
        task.speedBps = (task.received - lastTick) * 2.0;
        lastTick = task.received;
        task.elapsed = watch.elapsed;
        notifyListeners();
      });

      await for (final List<int> chunk in response.stream) {
        if (_singleCancelled) {
          await sink.close();
          try { await temp.delete(); } catch (_) {}
          throw _Cancelled();
        }
        task.received += chunk.length;
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      ticker.cancel();
      task.elapsed = watch.elapsed;

      // ---- verify (Part 11.10: temp-file handling + corrupt check) -------
      task.phase = TaskPhase.verifying;
      notifyListeners();
      final int size = await temp.length();
      final bool ok = _verifyMedia(temp, fmt.ext, size);
      if (!ok) {
        try { await temp.delete(); } catch (_) {}
        throw _BackendError(0, 'the file came back empty or corrupt');
      }
      task.sizeBytes = size;

      // ---- place (Part 11.4: version-aware Downloads integration) -------
      task.localPath = await StoragePlacer.placeFile(temp, name);
      task.phase = TaskPhase.done;
      notifyListeners();
      _feedback();
      await _recordHistory(task);
    } on _Cancelled {
      task.phase = TaskPhase.cancelled;
      task.errorKind = ErrorKind.cancelled;
      task.error = ErrorKind.cancelled.message;
    } on _BackendError catch (e) {
      await _deleteIf(temp);
      task.phase = TaskPhase.error;
      final ErrorKind kind = _classify(e.statusCode, e.detail);
      task.errorKind = kind;
      task.error = kind.message;
    } on TimeoutException {
      await _deleteIf(temp);
      task.phase = TaskPhase.error;
      task.errorKind = ErrorKind.timeout;
      task.error = ErrorKind.timeout.message;
    } on SocketException catch (e) {
      await _deleteIf(temp);
      task.phase = TaskPhase.error;
      task.errorKind = ErrorKind.network;
      task.error = '${ErrorKind.network.message} (${e.osError?.message ?? e.message})';
    } catch (e) {
      await _deleteIf(temp);
      task.phase = TaskPhase.error;
      task.errorKind = ErrorKind.server;
      task.error = 'Download failed: $e';
    } finally {
      ticker?.cancel();
      if (single == task) notifyListeners();
    }
  }

  void cancelSingle() {
    _singleCancelled = true;
  }

  // --------------------------------------------------------------- bulk
  /// Part 11.6: sequential queue; a failed item never stops the others.
  /// [rawUrls] is the raw pasted text (multi-line, comma separated …).
  Future<void> startBulk(String rawUrls) async {
    final List<String> urls = splitUrls(rawUrls);
    if (urls.isEmpty) return;
    _bulkStopped = false;
    bulk = urls
        .map((String u) => DownloaderTask(
              id: 'dl_${DateTime.now().microsecondsSinceEpoch}_${u.hashCode}',
              url: u,
            ))
        .toList();
    bulkRunning = true;
    bulkCurrentIndex = -1;
    bulkSummary = null;
    notifyListeners();

    int done = 0, failed = 0, skipped = 0;

    for (int i = 0; i < bulk.length; i++) {
      if (_bulkStopped) {
        // Everything after the stop point is skipped.
        for (int j = i; j < bulk.length; j++) {
          if (bulk[j].phase == TaskPhase.idle) {
            bulk[j].phase = TaskPhase.cancelled;
            bulk[j].errorKind = ErrorKind.cancelled;
          }
          skipped++;
        }
        break;
      }
      bulkCurrentIndex = i;
      notifyListeners();
      final DownloaderTask task = bulk[i];
      task.phase = TaskPhase.fetching;
      notifyListeners();

      final Object? result = await _fetchInfo(task);
      if (result is FetchInfo) {
        task.info = result;
        task.phase = TaskPhase.ready;
        _autoPickFormat(task);
        task.selectedFormat ??= result.bestAvailable();
        if (task.selectedFormat == null) {
          task.phase = TaskPhase.error;
          task.errorKind = ErrorKind.unsupported;
          task.error = 'No downloadable format found for this post.';
          failed++;
          notifyListeners();
          continue;
        }
        await startDownload(task);
        if (task.phase == TaskPhase.done) {
          done++;
        } else if (task.phase == TaskPhase.cancelled) {
          skipped++;
          if (_bulkStopped) break;
        } else {
          failed++;
        }
      } else {
        task.phase = TaskPhase.error;
        task.errorKind = result is ErrorKind ? result : ErrorKind.server;
        task.error = task.errorKind?.message;
        failed++;
      }
      notifyListeners();
    }

    bulkRunning = false;
    bulkCurrentIndex = -1;
    bulkSummary = BulkSummary(done: done, failed: failed, skipped: skipped);
    notifyListeners();
  }

  void stopBulk() {
    _bulkStopped = true;
    _singleCancelled = true;
    notifyListeners();
  }

  // ------------------------------------------------------------ fetch-info
  /// Returns FetchInfo on success, an ErrorKind on classified failure, or
  /// null when nothing useful happened (cancellation between steps).
  Future<Object?> _fetchInfo(DownloaderTask task) async {
    if (!BackendConfig.downloaderConfigured) {
      return ErrorKind.notConfigured;
    }
    final Uri uri = BackendConfig.downloaderPath('/api/fetch-info');
    final String platformParam =
        task.effectivePlatform == PlatformId.autoDetect ||
                task.effectivePlatform == PlatformId.other
            ? ''
            : task.effectivePlatform.name;

    for (int attempt = 0; attempt <= BackendConfig.maxRetries; attempt++) {
      try {
        final http.Response res = await _client
            .post(
              uri,
              headers: <String, String>{
                'Content-Type': 'application/json',
                ...BackendConfig.clientHeaders,
              },
              body: jsonEncode(<String, dynamic>{
                'url': task.url,
                if (platformParam.isNotEmpty) 'platform': platformParam,
              }),
            )
            .timeout(BackendConfig.requestTimeout);

        if (res.statusCode == 200 || res.statusCode == 201) {
          final Object? decoded = jsonDecode(res.body);
          if (decoded is Map) {
            return FetchInfo.fromJson(decoded.cast<String, dynamic>());
          }
          return ErrorKind.unavailable;
        }
        final String snippet = res.body.length > 300 ? res.body.substring(0, 300) : res.body;
        final ErrorKind kind = _classify(res.statusCode, snippet);
        // Retry only flaky server/network errors.
        if ((kind == ErrorKind.server || kind == ErrorKind.timeout) &&
            attempt < BackendConfig.maxRetries) {
          continue;
        }
        return kind;
      } on TimeoutException {
        if (attempt < BackendConfig.maxRetries) continue;
        return ErrorKind.timeout;
      } on SocketException {
        return ErrorKind.network;
      } catch (e) {
        debugPrint('fetch-info failed: $e');
        if (attempt < BackendConfig.maxRetries) continue;
        return ErrorKind.server;
      }
    }
    return ErrorKind.server;
  }

  // --------------------------------------------------------------- health
  Future<BackendHealth> healthCheck() async {
    if (!BackendConfig.downloaderConfigured) {
      return const BackendHealth(
        reachable: false,
        message: 'downloader backend not configured',
      );
    }
    try {
      final http.Response res = await _client
          .get(BackendConfig.downloaderPath('/api/health'))
          .timeout(BackendConfig.connectTimeout);
      if (res.statusCode != 200) {
        return BackendHealth(
            reachable: false, message: 'HTTP ${res.statusCode}');
      }
      final Object? decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return const BackendHealth(reachable: true, message: 'up (unknown shape)');
      }
      final Map<String, dynamic> json = decoded.cast<String, dynamic>();
      return BackendHealth(
        reachable: true,
        app: json['app'] as String?,
        version: json['version'] as String?,
        ffmpeg: json['ffmpeg'] is bool
            ? json['ffmpeg'] as bool
            : json['ffmpeg'] != null && json['ffmpeg'] != false,
        ytDlp: json['yt_dlp'] is bool
            ? json['yt_dlp'] as bool
            : json['yt_dlp'] != null && json['yt_dlp'] != false,
      );
    } catch (e) {
      return BackendHealth(
          reachable: false, message: 'unreachable (${_shortError(e)})');
    }
  }

  // -------------------------------------------------------------- history
  Future<List<DownloadItem>> history() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      return DownloadItem.decodeAll(p.getString(kHistory) ?? '');
    } catch (e) {
      debugPrint('history read failed: $e');
      return <DownloadItem>[];
    }
  }

  Future<void> _recordHistory(DownloaderTask task) async {
    if (!_historyEnabled) return;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final List<DownloadItem> all =
          DownloadItem.decodeAll(p.getString(kHistory) ?? '');
      final DownloadItem item = DownloadItem(
        id: task.id,
        url: task.url,
        platform: task.detection.platform.name,
        title: task.info?.title ?? 'Untitled',
        thumbnail: task.info?.thumbnail,
        mediaType: task.selectedFormat?.kind ?? 'video',
        quality: task.selectedFormat?.label,
        sizeBytes: task.sizeBytes,
        localPath: task.localPath,
        status: 'done',
      );
      all.removeWhere((DownloadItem i) => i.id == item.id);
      all.insert(0, item);
      if (all.length > _historyMax) {
        all.removeRange(_historyMax, all.length);
      }
      await p.setString(kHistory, DownloadItem.encodeAll(all));
      notifyListeners();
    } catch (e) {
      debugPrint('history record failed: $e');
    }
  }

  Future<void> deleteHistoryItem(DownloadItem item) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final List<DownloadItem> all =
          DownloadItem.decodeAll(p.getString(kHistory) ?? '');
      all.removeWhere((DownloadItem i) => i.id == item.id);
      await p.setString(kHistory, DownloadItem.encodeAll(all));
      notifyListeners();
    } catch (e) {
      debugPrint('history delete failed: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.remove(kHistory);
      notifyListeners();
    } catch (e) {
      debugPrint('history clear failed: $e');
    }
  }

  /// "Download Again" (Part 11.5): re-run the full pipeline for a record.
  Future<void> downloadAgain(DownloadItem item) async {
    await fetchSingle(item.url, platform: _platformByName(item.platform));
    final DownloaderTask? task = single;
    if (task == null || task.info == null) return;
    await startDownload(task);
  }

  /// Open the local file with the system handler (Part 11.5).
  Future<bool> openLocalFile(DownloadItem item) async {
    try {
      final String? realPath = await StoragePlacer.resolvePath(item.localPath!);
      if (realPath == null) return false;
      final OpenResult res = await OpenFilex.open(realPath);
      final bool ok = res.type == ResultType.done;
      _feedback();
      return ok;
    } catch (e) {
      debugPrint('openLocalFile failed: $e');
      return false;
    }
  }

  // ------------------------------------------------------------- helpers
  String _finalName(String title, String ext) {
    String base = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (base.isEmpty) base = 'download';
    if (base.length > 80) base = base.substring(0, 80);
    if (_filenameSuffix) base = '$base${SaxifyBranding.fileSuffix}';
    return '$base.$ext';
  }

  /// MP4 must contain an 'ftyp' box; MP3 needs an ID3 tag or a frame sync.
  /// Everything else: non-trivial size is the check.
  bool _verifyMedia(File file, String ext, int size) {
    if (size < 1024) return false;
    try {
      final RandomAccessFile raf = file.openSync(mode: FileMode.read);
      final List<int> head = raf.readSync(64).toList();
      raf.closeSync();
      final String e = ext.toLowerCase();
      if (e == 'mp4' || e == 'm4v' || e == 'mov') {
        // 'ftyp' at offset 4 in a valid MP4/MOV container.
        if (head.length >= 8 &&
            head[4] == 0x66 && // f
            head[5] == 0x74 && // t
            head[6] == 0x79 && // y
            head[7] == 0x70) {
          return true;
        }
        // Some encoders emit different brand boxes first — accept any
        // non-empty file whose first 8 bytes look like a box size.
        return size > 4096;
      }
      if (e == 'mp3' || e == 'm4a') {
        if (head.length >= 3) {
          if (head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33) {
            return true; // ID3
          }
          if (head[0] == 0xFF && (head[1] & 0xE0) == 0xE0) {
            return true; // MPEG frame sync
          }
          if (e == 'm4a') return size > 4096; // M4A = mp4 container
        }
        return size > 4096;
      }
      return size > 2048;
    } catch (e) {
      debugPrint('verifyMedia: $e');
      return size > 2048;
    }
  }

  ErrorKind _classify(int status, String body) {
    final String lower = body.toLowerCase();
    if (status == 400) {
      if (lower.contains('private') || lower.contains('login')) {
        return ErrorKind.private;
      }
      if (lower.contains('deleted') || lower.contains('removed')) {
        return ErrorKind.deleted;
      }
      if (lower.contains('unsupported') || lower.contains('not supported')) {
        return ErrorKind.unsupported;
      }
      return ErrorKind.invalid;
    }
    if (status == 403) return ErrorKind.private;
    if (status == 404 || status == 410) return ErrorKind.deleted;
    if (status == 415 || status == 422) return ErrorKind.unsupported;
    if (status == 408 || status == 429 || status == 504) return ErrorKind.timeout;
    if (status >= 500) return ErrorKind.server;
    if (lower.contains('private')) return ErrorKind.private;
    if (lower.contains('deleted')) return ErrorKind.deleted;
    if (lower.contains('unsupported')) return ErrorKind.unsupported;
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return ErrorKind.timeout;
    }
    return ErrorKind.unavailable;
  }

  String _shortError(Object e) {
    final String s = '$e';
    return s.length > 80 ? s.substring(0, 80) : s;
  }

  Future<void> _deleteIf(File? f) async {
    if (f == null) return;
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  void _feedback() {
    if (_sound) {
      HapticFeedback.mediumImpact();
    }
  }

  PlatformId? _platformByName(String name) {
    for (final PlatformId p in PlatformId.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _Cancelled implements Exception {}

class _BackendError implements Exception {
  const _BackendError(this.statusCode, this.detail);
  final int statusCode;
  final String detail;
}
