import 'dart:convert';

/// One entry in the Universal Downloads library (local history only until
/// cloud backup is opted into). Persisted as JSON in shared_preferences.
class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.platform,
    required this.title,
    this.thumbnail,
    this.mediaType = 'video',
    this.quality,
    this.sizeBytes,
    this.localPath,
    this.status = 'done',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String url;
  final String platform; // instagram, tiktok, x, pinterest, ... 'other'
  final String title;
  final String? thumbnail;

  /// `video` or `audio`.
  final String mediaType;

  /// e.g. `1080p (mp4)` / `MP3 192 kbps`.
  final String? quality;

  final int? sizeBytes;

  /// Where the file lives on this device (empty when deleted elsewhere).
  final String? localPath;

  /// `done`, `failed`, `cancelled` ...
  String status;

  final DateTime createdAt;

  bool get filePresent => localPath != null && localPath!.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'url': url,
        'platform': platform,
        'title': title,
        if (thumbnail != null && thumbnail!.isNotEmpty) 'thumb': thumbnail,
        'type': mediaType,
        if (quality != null) 'quality': quality,
        if (sizeBytes != null) 'size': sizeBytes,
        if (localPath != null) 'path': localPath,
        'status': status,
        'at': createdAt.toIso8601String(),
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      url: json['url'] as String? ?? '',
      platform: json['platform'] as String? ?? 'other',
      title: json['title'] as String? ?? 'Untitled',
      thumbnail: json['thumb'] as String?,
      mediaType: json['type'] as String? ?? 'video',
      quality: json['quality'] as String?,
      sizeBytes: json['size'] is int ? json['size'] as int : null,
      localPath: json['path'] as String?,
      status: json['status'] as String? ?? 'done',
      createdAt:
          DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // ------------------------------------------------------------ persistence
  /// The whole library as one JSON blob (kept small by [maxItems]).
  static String encodeAll(List<DownloadItem> items) =>
      jsonEncode(items.map((DownloadItem i) => i.toJson()).toList());

  static List<DownloadItem> decodeAll(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <DownloadItem>[];
      final List<DownloadItem> out = <DownloadItem>[];
      for (final Object? item in decoded) {
        if (item is Map) {
          out.add(DownloadItem.fromJson(item.cast<String, dynamic>()));
        }
      }
      return out;
    } catch (_) {
      return <DownloadItem>[];
    }
  }
}
