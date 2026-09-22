import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../config/backend_config.dart';
import '../../config/branding.dart';
import '../models/song.dart';
import '../utils/filenames.dart';
import 'native_bridge.dart';
import 'playback_service.dart';

enum MusicDownloadPhase { idle, running, done, failed, cancelled }

class MusicDownloadJob {
  MusicDownloadJob({required this.song});

  final Song song;
  MusicDownloadPhase phase = MusicDownloadPhase.idle;
  double fraction = 0;
  int received = 0;
  String? error;
  String? savedPath;
  String? savedUri;
}

/// Saves a song the player can already stream. Runs beside playback — it never
/// calls play/pause/seek and never replaces the current URL.
class MusicDownloadService extends ChangeNotifier {
  MusicDownloadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final List<MusicDownloadJob> jobs = <MusicDownloadJob>[];
  CancelToken? _token;
  bool _busy = false;

  MusicDownloadJob? get active {
    for (final MusicDownloadJob job in jobs.reversed) {
      if (job.phase == MusicDownloadPhase.running) return job;
    }
    return null;
  }

  Future<MusicDownloadJob> enqueue(Song song, PlaybackService playback) async {
    final MusicDownloadJob job = MusicDownloadJob(song: song);
    jobs.insert(0, job);
    if (jobs.length > 40) jobs.removeLast();
    notifyListeners();
    await _pump(playback);
    return job;
  }

  Future<void> _pump(PlaybackService playback) async {
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
        next.phase = MusicDownloadPhase.running;
        notifyListeners();
        await _run(next, playback);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _run(MusicDownloadJob job, PlaybackService playback) async {
    _token = CancelToken();
    try {
      final String url = await playback
          .resolvePlayableStreamUrl(VideoId(job.song.id))
          .timeout(const Duration(seconds: 25));
      final Directory cache = await getTemporaryDirectory();
      final String name = Filenames.saxify(job.song.title, 'mp3');
      final File temp = File('${cache.path}/$name');
      if (temp.existsSync()) await temp.delete();

      await _dio.download(
        url,
        temp.path,
        cancelToken: _token,
        options: Options(
          headers: BackendConfig.downloadHeaders(),
          receiveTimeout: const Duration(minutes: 8),
          sendTimeout: const Duration(seconds: 20),
        ),
        onReceiveProgress: (int received, int total) {
          job.received = received;
          job.fraction = total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);
          notifyListeners();
        },
      );

      final int size = await temp.length();
      final List<int> head = await temp.openRead(0, 32).fold<List<int>>(
            <int>[],
            (List<int> acc, List<int> chunk) => acc..addAll(chunk),
          );
      if (Filenames.looksCorrupt(head, size)) {
        throw Exception('Downloaded file looks empty or is not audio');
      }

      final SavedFile? saved = await NativeBridge.saveToDownloads(
        sourcePath: temp.path,
        displayName: name,
        mime: 'audio/mpeg',
      );
      job.savedPath = saved?.path ?? temp.path;
      job.savedUri = saved?.uri;
      if (saved == null && !Platform.isAndroid) {
        final Directory docs = await getApplicationDocumentsDirectory();
        final Directory folder = Directory('${docs.path}/${SaxifyBranding.downloadFolderName}');
        if (!folder.existsSync()) folder.createSync(recursive: true);
        final File dest = File('${folder.path}/$name');
        await temp.copy(dest.path);
        job.savedPath = dest.path;
      }
      job.phase = MusicDownloadPhase.done;
      job.fraction = 1;
      try {
        if (temp.existsSync() && job.savedPath != temp.path) await temp.delete();
      } catch (_) {}
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        job.phase = MusicDownloadPhase.cancelled;
        job.error = 'Download cancelled';
      } else {
        job.phase = MusicDownloadPhase.failed;
        job.error = e.message ?? 'Network error';
      }
    } catch (e) {
      job.phase = MusicDownloadPhase.failed;
      job.error = '$e';
    } finally {
      _token = null;
      notifyListeners();
    }
  }

  void cancel() {
    _token?.cancel('user');
  }

  Future<void> delete(MusicDownloadJob job) async {
    final bool ok = await NativeBridge.deleteDownload(uri: job.savedUri, path: job.savedPath);
    if (ok || job.savedPath == null) {
      jobs.remove(job);
      notifyListeners();
    }
  }
}
