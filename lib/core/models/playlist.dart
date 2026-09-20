import 'song.dart';

/// A user-created playlist, persisted locally.
class Playlist {
  Playlist({
    required this.id,
    required this.name,
    List<Song>? songs,
    DateTime? createdAt,
    this.coverUrl,
  })  : songs = songs ?? <Song>[],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  final List<Song> songs;
  final DateTime createdAt;

  /// Optional pinned cover; falls back to the first song's artwork.
  String? coverUrl;

  String get artwork => coverUrl ?? (songs.isEmpty ? '' : songs.first.thumbnailUrl);

  int get count => songs.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'created': createdAt.toIso8601String(),
        if (coverUrl != null) 'cover': coverUrl,
        'songs': songs.map((Song s) => s.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final Object? rawSongs = json['songs'];
    final List<Song> songs = <Song>[];
    if (rawSongs is List) {
      for (final Object? item in rawSongs) {
        if (item is Map) {
          songs.add(Song.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return Playlist(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Playlist',
      songs: songs,
      createdAt:
          DateTime.tryParse(json['created'] as String? ?? '') ?? DateTime.now(),
      coverUrl: json['cover'] as String?,
    );
  }
}
