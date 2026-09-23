import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../downloader/downloader_models.dart';
import '../../downloader/local_downloader.dart';

import '../../config/branding.dart';
import '../models/song.dart';
import '../utils/filenames.dart';
import 'native_bridge.dart';
import 'playback_service.dart';

enum MusicDownloadPhase { idle, running, done, failed, cancelled }

class MusicDownloadJob {
  MusicDownloadJob({required this.song, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  final Song song;
  final DateTime createdAt;
  MusicDownloadPhase phase = MusicDownloadPhase.idle;
  double fraction = 0;
  int received = 0;
  int size = 0;
  String? error;
  String? savedPath;
  String? savedUri;

  /// Private app copy used for offline playback, independent of Android's
  /// public Downloads/MediaStore permission and URI behavior.
  String? offlinePath;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'song': song.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'phase': phase.name,
        'fraction': fraction,
        'received': received,
        'size': size,
        if (error != null) 'error': error,
        if (savedPath != null) 'savedPath': savedPath,
        if (savedUri != null) 'savedUri': savedUri,
        if (offlinePath != null) 'offlinePath': offlinePath,
      };

  static MusicDownloadJob? fromJson(Map<String, dynamic> json) {
    final Object? rawSong = json['song'];
    if (rawSong is! Map) return null;
    final MusicDownloadJob job = MusicDownloadJob(
      song: Song.fromJson(rawSong.cast<String, dynamic>()),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    )
      ..phase = MusicDownloadPhase.values.firstWhere(
        (MusicDownloadPhase value) => value.name == json['phase'],
        orElse: () => MusicDownloadPhase.done,
      )
      ..fraction = (json['fraction'] as num?)?.toDouble() ?? 1
      ..received = json['received'] is int ? json['received'] as int : 0
      ..size = json['size'] is int ? json['size'] as int : 0
      ..error = json['error'] as String?
      ..savedPath = json['savedPath'] as String?
      ..savedUri = json['savedUri'] as String?
      ..offlinePath = json['offlinePath'] as String?;
    return job;
  }
}

/// Android song downloads use the bundled on-device yt-dlp + FFmpeg pipeline;
/// other platforms fall back to the existing stream resolver. The app keeps
/// an app-private offline copy and tries to publish a public Downloads copy.
/// Downloading never touches play/pause/seek.
class MusicDownloadService extends ChangeNotifier {
  MusicDownloadService({Dio? dio, SharedPreferences? prefs, LocalDownloader? local})
      : _dio = dio ?? Dio(),
        _prefs = prefs,
        _local = local ?? LocalDownloader() {
    jobs.addAll(_readJobs());
  }

  static const String _historyKey = 'saxify.music_downloads.v1';
  final Dio _dio;
  final LocalDownloader _local;
  String? _localJobId;
  bool _cancelRequested = false;
  final SharedPreferences? _prefs;
  final List<MusicDownloadJob> jobs = <MusicDownloadJob>[];
  CancelToken? _token;
  MusicDownloadJob? _activeJob;
  bool _busy = false;

  MusicDownloadJob? get active => _activeJob;

  List<MusicDownloadJob> get downloaded => List<MusicDownloadJob>.unmodifiable(
        jobs.where((MusicDownloadJob job) =>
            job.phase == MusicDownloadPhase.done &&
            job.offlinePath != null &&
            File(job.offlinePath!).existsSync()),
      );

  MusicDownloadJob? jobFor(String songId) {
    for (final MusicDownloadJob job in jobs) {
      if (job.song.id == songId) return job;
    }
    return null;
  }

  bool isDownloaded(String songId) =>
      downloaded.any((MusicDownloadJob job) => job.song.id == songId);

  List<MusicDownloadJob> _readJobs() {
    final String? raw = _prefs?.getString(_historyKey);
    if (raw == null || raw.isEmpty) return <MusicDownloadJob>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <MusicDownloadJob>[];
      return decoded
          .whereType<Map>()
          .map((Map item) => MusicDownloadJob.fromJson(item.cast<String, dynamic>()))
          .whereType<MusicDownloadJob>()
          .where((MusicDownloadJob job) =>
              job.phase == MusicDownloadPhase.done &&
              job.offlinePath != null &&
              File(job.offlinePath!).existsSync())
          .toList();
    } catch (e) {
      debugPrint('[Saxify][MusicDownloads] history read failed: $e');
      return <MusicDownloadJob>[];
    }
  }

  Future<void> _persist() async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final List<MusicDownloadJob> saved = jobs
        .where((MusicDownloadJob job) =>
            job.phase == MusicDownloadPhase.done && job.offlinePath != null)
        .take(120)
        .toList();
    await prefs.setString(
      _historyKey,
      jsonEncode(saved.map((MusicDownloadJob job) => job.toJson()).toList()),
    );
  }

  Future<MusicDownloadJob> enqueue(Song song, PlaybackService? playback) async {
    final MusicDownloadJob? existing = jobFor(song.id);
    if (existing != null &&
        (existing.phase == MusicDownloadPhase.running ||
            existing.phase == MusicDownloadPhase.idle ||
            (existing.phase == MusicDownloadPhase.done &&
                existing.offlinePath != null &&
                File(existing.offlinePath!).existsSync()))) {
      return existing;
    }

    final MusicDownloadJob job = MusicDownloadJob(song: song);
    jobs.insert(0, job);
    if (jobs.length > 120) jobs.removeLast();
    notifyListeners();
    await _pump(playback);
    return job;
  }

  Future<void> _pump(PlaybackService? playback) async {
    if (_busy) return;
    _busy = true;
    try {
      while (true) {
        MusicDownloadJob? next;
        for (final MusicDownloadJob job in jobs.reversed) {
          if (job.phase == MusicDownloadPhase.idle) {
            next = job;
            break;
          }
        }
        if (next == null) break;
        _activeJob = next;
        next.phase = MusicDownloadPhase.running;
        notifyListeners();
        await _run(next, playback);
      }
    } finally {
      _activeJob = null;
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _run(MusicDownloadJob job, PlaybackService? playback) async {
    _cancelRequested = false;
    _token = CancelToken();
    File? temp;
    try {
      File offlineFile;
      String mime;
      if (_local.supported) {
        // Android: use the SAME bundled yt-dlp pipeline as Add link / Bulk.
        // yt-dlp + FFmpeg produce a real MP3, not a renamed WebM/M4A stream.
        final String jobId = LocalDownloader.newJobId();
        _localJobId = jobId;
        final LocalFile result = await _local.download(
          url: 'https://www.youtube.com/watch?v=${job.song.id}',
          jobId: jobId,
          kind: DownloadKind.audio,
          onProgress: (double value) {
            if (_cancelRequested) return;
            job.fraction = value;
            notifyListeners();
          },
        );
        offlineFile = File(result.path);
        mime = result.mime;
      } else {
        // Other platforms: stream-resolver fallback (still no Saxify backend).
        // Preserve the actual container, never label raw audio as MP3.
        if (playback == null) throw StateError('Player is required on this platform');
        final String streamUrl = await playback
            .resolvePlayableStreamUrl(VideoId(job.song.id))
            .timeout(const Duration(seconds: 35));
        final String streamMime = Uri.tryParse(streamUrl)?.queryParameters['mime'] ?? '';
        final String ext = streamMime.contains('webm') ? 'webm' : 'm4a';
        mime = ext == 'webm' ? 'audio/webm' : 'audio/mp4';
        final Directory documents = await getApplicationDocumentsDirectory();
        final Directory folder = Directory('${documents.path}/${SaxifyBranding.downloadFolderName}/Music');
        await folder.create(recursive: true);
        offlineFile = File('${folder.path}/${Filenames.saxify('${job.song.title}_${job.song.id}', ext)}');
        temp = File('${offlineFile.path}.part');
        if (temp.existsSync()) await temp.delete();
        await _dio.download(
          streamUrl,
          temp.path,
          cancelToken: _token,
          options: Options(receiveTimeout: const Duration(minutes: 12)),
          onReceiveProgress: (int got, int all) {
            job.received = got;
            job.fraction = all <= 0 ? 0 : (got / all).clamp(0.0, 0.96);
            notifyListeners();
          },
        );
        await temp.rename(offlineFile.path);
      }
      if (_cancelRequested) {
        await offlineFile.delete();
        throw StateError('Download cancelled');
      }
      final int size = await offlineFile.length();
      final RandomAccessFile raf = await offlineFile.open();
      final List<int> head = await raf.read(32);
      await raf.close();
      if (Filenames.looksCorrupt(head, size)) {
        await offlineFile.delete();
        throw StateError('Downloaded audio is empty or invalid');
      }
      job.offlinePath = offlineFile.path;
      job.size = size;

      SavedFile? publicFile;
      try {
        publicFile = await NativeBridge.saveToDownloads(
          sourcePath: offlineFile.path,
          displayName: Filenames.saxify('${job.song.title}_${job.song.id}', offlineFile.path.split('.').last),
          mime: mime,
        );
      } catch (e) {
        debugPrint('Public song copy unavailable: $e');
      }
      if (_cancelRequested) {
        await NativeBridge.deleteDownload(uri: publicFile?.uri,
          path: publicFile?.uri?.startsWith('file:') == true ? publicFile?.path : null);
        await offlineFile.delete();
        throw StateError('Download cancelled');
      }
      job.savedPath = publicFile?.uri?.startsWith('file:') == true
          ? publicFile?.path : null;
      job.savedUri = publicFile?.uri;
      job.phase = MusicDownloadPhase.done;
      job.fraction = 1;
      job.error = null;
      await _persist();
    } on DioException catch (e) {
      job.phase = CancelToken.isCancel(e) ? MusicDownloadPhase.cancelled : MusicDownloadPhase.failed;
      job.error = job.phase == MusicDownloadPhase.cancelled ? 'Download cancelled' : (e.message ?? 'Network error');
    } catch (e) {
      job.phase = _cancelRequested || localDownloadError(e).toLowerCase().contains('cancel')
          ? MusicDownloadPhase.cancelled : MusicDownloadPhase.failed;
      job.error = localDownloadError(e);
    } finally {
      _deleteTemp(temp);
      _token = null;
      _localJobId = null;
      notifyListeners();
    }
  }

  void _deleteTemp(File? file) {
    try {
      if (file?.existsSync() == true) file!.deleteSync();
    } catch (_) {}
  }

  void cancel([MusicDownloadJob? job]) {
    if (job != null && job != _activeJob) {
      if (job.phase == MusicDownloadPhase.idle) {
        job.phase = MusicDownloadPhase.cancelled;
        notifyListeners();
      }
      return;
    }
    _cancelRequested = true;
    _token?.cancel('user');
    final String? id = _localJobId;
    if (id != null) _local.cancel(id);
  }

  Future<void> delete(MusicDownloadJob job, {PlaybackService? playback}) async {
    if (job == _activeJob) cancel(job);
    if (job.offlinePath != null) {
      try {
        final File offline = File(job.offlinePath!);
        if (offline.existsSync()) await offline.delete();
      } catch (e) {
        debugPrint('[Saxify][MusicDownloads] private delete failed: $e');
      }
    }
    try {
      if (job.savedUri != null || job.savedPath != null) {
        await NativeBridge.deleteDownload(uri: job.savedUri, path: job.savedPath);
      }
    } catch (e) {
      debugPrint('[Saxify][MusicDownloads] public delete failed: $e');
    }
    playback?.forgetOfflineSong(job.song.id);
    jobs.remove(job);
    await _persist();
    notifyListeners();
  }
}
