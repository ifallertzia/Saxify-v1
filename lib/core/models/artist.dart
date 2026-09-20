import 'song.dart';

/// A YouTube channel as it appears in the library / artist rails.
class ArtistRef {
  const ArtistRef({
    required this.channelId,
    required this.name,
    required this.imageUrl,
    this.subscribers,
  });

  final String channelId;
  final String name;
  final String imageUrl;
  final String? subscribers;

  ArtistRef copyWith({String? imageUrl, String? subscribers, String? name}) {
    return ArtistRef(
      channelId: channelId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      subscribers: subscribers ?? this.subscribers,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': channelId,
        'name': name,
        'img': imageUrl,
        if (subscribers != null) 'subs': subscribers,
      };

  factory ArtistRef.fromJson(Map<String, dynamic> json) => ArtistRef(
        channelId: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Artist',
        imageUrl: json['img'] as String? ?? '',
        subscribers: json['subs'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is ArtistRef && other.channelId == channelId;

  @override
  int get hashCode => channelId.hashCode;
}

/// A history entry: the song plus when it was played.
class HistoryEntry {
  const HistoryEntry({required this.song, required this.playedAt});

  final Song song;
  final DateTime playedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'at': playedAt.toIso8601String(),
        'song': song.toJson(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final Object? raw = json['song'];
    return HistoryEntry(
      playedAt:
          DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      song:
          Song.fromJson(raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{}),
    );
  }
}
