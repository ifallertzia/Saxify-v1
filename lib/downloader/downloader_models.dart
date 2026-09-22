import 'platform_detect.dart';

enum DownloadKind { video, audio }

enum DownloaderMode { bestVideo, audioMp3, ask }

enum JobStatus { idle, fetching, ready, downloading, done, failed, cancelled, skipped }

class MediaFormat {
  const MediaFormat({
    required this.id,
    required this.label,
    this.ext,
    this.height,
    this.filesize,
    this.hasVideo = true,
    this.hasAudio = true,
  });

  final String id;
  final String label;
  final String? ext;
  final int? height;
  final int? filesize;
  final bool hasVideo;
  final bool hasAudio;

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    final Object? height = json['height'] ?? json['resolution'];
    int? parsedHeight;
    if (height is int) {
      parsedHeight = height;
    } else if (height != null) {
      parsedHeight = int.tryParse(height.toString().replaceAll(RegExp(r'[^0-9]'), ''));
    }
    final String id = (json['format_id'] ?? json['id'] ?? json['format'] ?? '').toString();
    final String ext = (json['ext'] ?? json['container'] ?? '').toString();
    final bool video = json['vcodec']?.toString() != 'none' && json['vcodec'] != null
        ? json['vcodec'].toString() != 'none'
        : (json['type']?.toString() != 'audio');
    final String label = (json['format_note'] ??
            json['quality'] ??
            json['resolution'] ??
            (parsedHeight != null ? '${parsedHeight}p' : null) ??
            id)
        .toString();
    return MediaFormat(
      id: id,
      label: label,
      ext: ext.isEmpty ? null : ext,
      height: parsedHeight,
      filesize: json['filesize'] is int
          ? json['filesize'] as int
          : json['size'] is int
              ? json['size'] as int
              : int.tryParse('${json['filesize'] ?? ''}'),
      hasVideo: video,
      hasAudio: json['acodec']?.toString() != 'none',
    );
  }
}

class MediaInfo {
  const MediaInfo({
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.formats,
    required this.sourceHost,
  });

  final String title;
  final String thumbnail;
  final String duration;
  final List<MediaFormat> formats;
  final String sourceHost;

  factory MediaInfo.fromJson(Map<String, dynamic> json, String url) {
    final Object? rawFormats = json['formats'] ?? json['qualities'];
    final List<MediaFormat> formats = <MediaFormat>[];
    if (rawFormats is List) {
      for (final Object? item in rawFormats) {
        if (item is Map) {
          formats.add(MediaFormat.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return MediaInfo(
      title: (json['title'] ?? 'Untitled').toString(),
      thumbnail: (json['thumbnail'] ?? json['thumb'] ?? '').toString(),
      duration: (json['duration'] ?? json['duration_string'] ?? '').toString(),
      formats: formats,
      sourceHost: Uri.tryParse(url)?.host ?? '',
    );
  }
}

class DownloaderHealth {
  const DownloaderHealth({
    required this.ok,
    required this.app,
    required this.version,
    this.ffmpeg,
    this.ytDlp,
    this.raw = '',
    this.error,
  });

  final bool ok;
  final String app;
  final String version;
  final bool? ffmpeg;
  final bool? ytDlp;
  final String raw;
  final String? error;

  bool get branded => app == 'Saxify Downloader';
}

class DownloadRecord {
  DownloadRecord({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    required this.kind,
    required this.quality,
    required this.createdAt,
    this.thumbnail = '',
    this.size = 0,
    this.path,
    this.uri,
    this.status = JobStatus.done,
    this.error,
  });

  final String id;
  final String url;
  String title;
  final MediaPlatform platform;
  final DownloadKind kind;
  String quality;
  final DateTime createdAt;
  String thumbnail;
  int size;
  String? path;
  String? uri;
  JobStatus status;
  String? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'url': url,
        'title': title,
        'platform': platform.name,
        'kind': kind.name,
        'quality': quality,
        'at': createdAt.toIso8601String(),
        'thumb': thumbnail,
        'size': size,
        if (path != null) 'path': path,
        if (uri != null) 'uri': uri,
        'status': status.name,
        if (error != null) 'error': error,
      };

  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    return DownloadRecord(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? 'Download',
      platform: MediaPlatform.values.firstWhere(
        (MediaPlatform p) => p.name == json['platform'],
        orElse: () => MediaPlatform.other,
      ),
      kind: json['kind'] == 'audio' ? DownloadKind.audio : DownloadKind.video,
      quality: json['quality'] as String? ?? '',
      createdAt: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      thumbnail: json['thumb'] as String? ?? '',
      size: json['size'] is int ? json['size'] as int : 0,
      path: json['path'] as String?,
      uri: json['uri'] as String?,
      status: JobStatus.values.firstWhere(
        (JobStatus s) => s.name == json['status'],
        orElse: () => JobStatus.done,
      ),
      error: json['error'] as String?,
    );
  }
}

class BulkRow {
  BulkRow(this.url);

  String url;
  MediaPlatform detected = MediaPlatform.other;
  JobStatus status = JobStatus.idle;
  double fraction = 0;
  String? message;
  String? title;
}

String classifyDownloadError(Object error, {int? status, String body = ''}) {
  final String blob = '${error.toString()} $body'.toLowerCase();
  if (blob.contains('private')) {
    return 'This post is private. Saxify cannot access private content.';
  }
  if (blob.contains('login') || blob.contains('sign in') || blob.contains('cookies')) {
    return 'This content needs a login. Saxify does not bypass logins.';
  }
  if (blob.contains('deleted') || status == 410 || status == 404) {
    return 'This post was deleted or is unavailable.';
  }
  if (blob.contains('unsupported') || status == 415) {
    return 'This link is not supported.';
  }
  if (blob.contains('timeout') || blob.contains('timed out')) {
    return 'The server took too long. It may be waking up — try again.';
  }
  if (status != null && status >= 500) {
    return 'The download server had a problem. Try again in a moment.';
  }
  if (blob.contains('socket') || blob.contains('network') || blob.contains('failed host')) {
    return 'Network error. Check your connection and try again.';
  }
  return 'Could not download this link. Check the URL and try again.';
}
