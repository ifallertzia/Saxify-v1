import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/artist.dart';
import '../models/song.dart';

/// Thin, typed wrapper around `YoutubeExplode`.
///
/// Every screen goes through this class so there is exactly one HTTP client,
/// one search entry point (`_yt.search`, the same call the original app used)
/// and one place to filter out live streams / broken rows.
class YoutubeService {
  YoutubeService() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  /// Exposed for [PlaybackService], which owns the stream-manifest logic.
  YoutubeExplode get client => _yt;

  // ------------------------------------------------------------------ search
  Future<List<Video>> search(String query, {int limit = 20}) async {
    final VideoSearchList results = await _yt.search.search(query);
    return results.take(limit).toList();
  }

  /// Search + map to [Song], dropping live streams (they have no fixed
  /// duration and cannot be seeked).
  Future<List<Song>> searchSongs(
    String query, {
    int limit = 20,
    String? subtitle,
  }) async {
    final List<Video> videos = await search(query, limit: limit + 6);
    final List<Song> songs = <Song>[];
    for (final Video v in videos) {
      if (v.isLive) continue;
      songs.add(Song.fromVideo(v, subtitle: subtitle));
      if (songs.length >= limit) break;
    }
    return songs;
  }

  /// One representative track for a query — used to build the home rails where
  /// each card is "the best match for this mood".
  Future<Song?> topSong(String query) async {
    try {
      final List<Song> songs = await searchSongs(query, limit: 1);
      return songs.isEmpty ? null : songs.first;
    } catch (e) {
      debugPrint('topSong("$query") failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------- related
  /// Similar tracks, used both for "Recommended" and for the never-stop
  /// auto-next behaviour when a queue runs out.
  Future<List<Song>> similarSongs(
    String videoId, {
    int limit = 12,
    Set<String> exclude = const <String>{},
  }) async {
    final Video video = await _yt.videos.get(VideoId(videoId));
    final RelatedVideosList? related = await _yt.videos.getRelatedVideos(video);
    if (related == null) return <Song>[];

    final List<Song> out = <Song>[];
    final Set<String> seen = <String>{videoId, ...exclude};
    for (final Video v in related) {
      if (v.isLive) continue;
      if (seen.contains(v.id.value)) continue;
      seen.add(v.id.value);
      out.add(Song.fromVideo(v));
      if (out.length >= limit) break;
    }
    return out;
  }

  // ---------------------------------------------------------------- channels
  Future<Channel> channel(String channelId) => _yt.channels.get(ChannelId(channelId));

  /// Newest uploads of a channel. `getUploads` is a lazy stream — we only pull
  /// the first page worth of items.
  Future<List<Song>> channelUploads(String channelId, {int limit = 30}) async {
    final List<Video> uploads =
        await _yt.channels.getUploads(ChannelId(channelId)).take(limit).toList();
    final List<Song> songs = <Song>[];
    for (final Video v in uploads) {
      if (v.isLive) continue;
      songs.add(Song.fromVideo(v));
    }
    return songs;
  }

  /// Channel metadata for a video we already have — used by the "open artist"
  /// action on a song row.
  Future<ArtistRef?> artistForVideo(String videoId) async {
    try {
      final Channel channel = await _yt.channels.getByVideo(VideoId(videoId));
      return ArtistRef(
        channelId: channel.id.value,
        name: channel.title,
        imageUrl: channel.logoUrl,
        subscribers: channel.subscribersCount?.toString(),
      );
    } catch (e) {
      debugPrint('artistForVideo($videoId) failed: $e');
      return null;
    }
  }

  void close() => _yt.close();
}
