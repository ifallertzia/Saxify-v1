/// One downloadable format returned by the Saxify Downloader backend
/// (`POST /api/fetch-info` -> `formats[]`).
class MediaFormat {
  const MediaFormat({
    required this.formatId,
    required this.ext,
    required this.kind,
    this.resolution,
    this.bitrate,
    this.filesizeBytes,
  });

  /// Backend format identifier passed back to `/api/download`.
  final String formatId;

  /// `mp4`, `m4a`, `mp3`, `webm` ...
  final String ext;

  /// `video` or `audio` — the backend `kind` field.
  final String kind;

  /// `1080p`, `720p`, `audio` ...
  final String? resolution;

  /// Kbps when known.
  final int? bitrate;

  /// Bytes when the backend knows the size up front.
  final int? filesizeBytes;

  bool get isVideo => kind == 'video';
  bool get isAudio => kind == 'audio';

  /// Human label for the quality picker.
  String get label {
    if (isAudio) {
      if (bitrate != null) return 'MP3 $bitrate kbps ($ext)';
      return 'Audio ($ext)';
    }
    if (resolution != null && resolution!.isNotEmpty) return '$resolution ($ext)';
    return 'Video ($ext)';
  }

  /// Sort weight for the quality picker: resolution number, then bitrate.
  int get sortWeight {
    if (isAudio) return bitrate ?? 0;
    final RegExpMatch? m = RegExp(r'(\d+)p?').firstMatch(resolution ?? '');
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'format_id': formatId,
        'ext': ext,
        'kind': kind,
        if (resolution != null) 'resolution': resolution,
        if (bitrate != null) 'bitrate': bitrate,
        if (filesizeBytes != null) 'filesize': filesizeBytes,
      };

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    final String kind = json['kind'] as String? ??
        (json['vcodec'] == null || json['vcodec'] == 'none' ? 'audio' : 'video');
    final String? rawExt = json['ext'] as String? ?? json['extension'] as String?;
    final String ext = rawExt ?? (kind == 'audio' ? 'm4a' : 'mp4');

    return MediaFormat(
      formatId: json['format_id'] as String? ?? json['id'] as String? ?? '',
      ext: ext,
      kind: kind,
      resolution: json['resolution'] as String?,
      bitrate: json['bitrate'] is int
          ? json['bitrate'] as int
          : int.tryParse(json['bitrate']?.toString() ?? ''),
      filesizeBytes: json['filesize'] is int
          ? json['filesize'] as int
          : int.tryParse(json['filesize']?.toString() ?? ''),
    );
  }
}

/// The full `POST /api/fetch-info` result for one URL.
class FetchInfo {
  const FetchInfo({
    required this.title,
    required this.thumbnail,
    required this.durationSeconds,
    required this.formats,
    this.sourceHost,
  });

  final String title;
  final String thumbnail;
  final int durationSeconds;
  final List<MediaFormat> formats;

  /// Host of the source post (e.g. instagram.com) — used for mismatch checks.
  final String? sourceHost;

  MediaFormat? bestVideo() {
    final List<MediaFormat> videos =
        formats.where((MediaFormat f) => f.isVideo).toList()
          ..sort((MediaFormat a, MediaFormat b) =>
              b.sortWeight.compareTo(a.sortWeight));
    return videos.isEmpty ? null : videos.first;
  }

  /// Prefer mp4, then m4a/webm, then anything — "MP4 preferred" rule.
  MediaFormat? bestAvailable() {
    final MediaFormat? video = bestVideo();
    if (video != null) {
      final MediaFormat? mp4 = _firstWhereOrNull(
          formats, (MediaFormat f) => f.isVideo && (f.ext == 'mp4' || f.ext == 'm4v'));
      return mp4 ?? video;
    }
    final List<MediaFormat> audio =
        formats.where((MediaFormat f) => f.isAudio).toList()
          ..sort((MediaFormat a, MediaFormat b) =>
              b.sortWeight.compareTo(a.sortWeight));
    if (audio.isEmpty) return null;
    final MediaFormat? mp3 = _firstWhereOrNull(audio, (MediaFormat f) => f.ext == 'mp3');
    return mp3 ?? audio.first;
  }

  factory FetchInfo.fromJson(Map<String, dynamic> json) {
    final Object? rawFormats = json['formats'];
    final List<MediaFormat> formats = <MediaFormat>[];
    if (rawFormats is List) {
      for (final Object? item in rawFormats) {
        if (item is Map) {
          formats.add(MediaFormat.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    final Object? rawDuration = json['duration'];
    return FetchInfo(
      title: json['title'] as String? ?? 'Untitled',
      thumbnail: json['thumbnail'] as String? ??
          json['thumbnail_url'] as String? ??
          '',
      durationSeconds: rawDuration is int
          ? rawDuration
          : int.tryParse('$rawDuration') ??
              0,
      formats: formats,
      sourceHost: json['source_host'] as String? ?? json['host'] as String?,
    );
  }

}

/// Tiny local helper so we do not import collection in model files.
T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final T item in items) {
    if (test(item)) return item;
  }
  return null;
}
