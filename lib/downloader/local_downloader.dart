import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'downloader_models.dart';

/// Bundled Android yt-dlp bridge. Media is resolved, downloaded and merged on
/// the phone. No Saxify download server is consulted. The EventChannel carries
/// progress separately so a MethodChannel download can finish asynchronously.
class LocalDownloader {
  LocalDownloader();

  static const MethodChannel _method = MethodChannel('com.saxify.app/bridge');
  static const EventChannel _events = EventChannel('com.saxify.app/download_progress');
  static Stream<Object?>? _progress;
  static int _sequence = 0;

  bool get supported => !kIsWeb && Platform.isAndroid;

  static String newJobId() =>
      'dl_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_sequence++}';

  Future<DownloaderHealth> health() async {
    if (!supported) {
      return const DownloaderHealth(
        ok: false, app: 'On-device downloader', version: '',
        error: 'Local yt-dlp downloads are available on Android.',
      );
    }
    try {
      final Object? raw = await _method.invokeMethod<Object>('localDownloaderHealth');
      final Map<String, dynamic> data = (raw as Map).cast<String, dynamic>();
      return DownloaderHealth(
        ok: data['status'] == 'ok',
        app: data['app']?.toString() ?? 'On-device downloader',
        version: data['version']?.toString() ?? '',
        ffmpeg: data['ffmpeg'] == true,
        ytDlp: data['yt_dlp'] == true,
      );
    } catch (error) {
      return DownloaderHealth(
        ok: false, app: 'On-device downloader', version: '',
        error: localDownloadError(error),
      );
    }
  }

  Future<MediaInfo> fetchInfo(String url) async {
    if (!supported) throw UnsupportedError('Local yt-dlp is Android-only');
    final Object? raw = await _method.invokeMethod<Object>(
      'fetchLocalInfo', <String, String>{'url': url},
    );
    if (raw is! Map) throw StateError('No metadata returned for this link');
    return MediaInfo.fromJson(raw.cast<String, dynamic>(), url);
  }

  Future<LocalFile> download({
    required String url,
    required String jobId,
    required DownloadKind kind,
    String? formatId,
    bool formatHasAudio = false,
    required void Function(double fraction) onProgress,
  }) async {
    if (!supported) throw UnsupportedError('Local yt-dlp is Android-only');
    _progress ??= _events.receiveBroadcastStream().asBroadcastStream();
    final StreamSubscription<Object?> subscription = _progress!.listen((Object? raw) {
      if (raw is! Map || raw['jobId'] != jobId) return;
      final Object? value = raw['fraction'];
      if (value is num) onProgress(value.toDouble().clamp(0.0, 1.0));
    });
    try {
      final Object? raw = await _method.invokeMethod<Object>(
        'downloadLocal', <String, Object?>{
          'url': url,
          'jobId': jobId,
          'kind': switch (kind) {
            DownloadKind.audio => 'audio',
            DownloadKind.video => 'video',
            DownloadKind.videoOnly => 'video_only',
          },
          'formatId': formatId,
          'formatHasAudio': formatHasAudio,
        },
      );
      if (raw is! Map) throw StateError('Download finished without a file');
      final String path = raw['path']?.toString() ?? '';
      if (path.isEmpty) throw StateError('Download finished without a file');
      return LocalFile(
        path: path,
        extension: raw['extension']?.toString().toLowerCase() ?? '',
        size: raw['size'] is num ? (raw['size'] as num).toInt() : 0,
        kind: kind,
      );
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> cancel(String jobId) async {
    if (!supported) return;
    await _method.invokeMethod<bool>('cancelLocal', <String, String>{'jobId': jobId});
  }
}

class LocalFile {
  const LocalFile({required this.path, required this.extension, required this.size,
    this.kind = DownloadKind.video});

  final String path;
  final String extension;
  final int size;
  final DownloadKind kind;

  String get mime => switch (extension) {
        'mp3' => 'audio/mpeg',
        'm4a' => 'audio/mp4',
        'webm' => kind == DownloadKind.audio ? 'audio/webm' : 'video/webm',
        'mkv' => 'video/x-matroska',
        'opus' => 'audio/ogg',
        _ => 'video/mp4',
      };
}

String localDownloadError(Object error) {
  if (error is PlatformException) {
    final String message = error.message ?? '';
    if (message.toLowerCase().contains('cancel')) return 'Download cancelled';
    if (message.toLowerCase().contains('private') ||
        message.toLowerCase().contains('sign in') ||
        message.toLowerCase().contains('login')) {
      return 'This link needs a login or is private. Saxify cannot bypass it.';
    }
    return message.isEmpty ? 'Could not download this link on this device.' : message;
  }
  if (error is UnsupportedError) return error.message?.toString() ?? 'Unsupported platform';
  return error.toString();
}
