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

  /// Search for music, not arbitrary YouTube uploads. Indian/Hindi results are
  /// tried first; broad fallback is still filtered through the same music-only
  /// classifier so ordinary vlogs, tutorials, interviews and trailers stay out.
  Future<List<Song>> searchSongs(
    String query, {
    int limit = 20,
    String? subtitle,
  }) async {
    final String raw = query.trim();
    if (raw.isEmpty || limit <= 0) return <Song>[];

    final String primary = indianFirstQuery(raw);
    final List<Song> songs = <Song>[];
    final Set<String> seen = <String>{};

    Future<void> collect(String term) async {
      final List<Video> videos =
          await search(term, limit: (limit * 3).clamp(12, 60).toInt());
      for (final Video video in videos) {
        if (video.isLive ||
            !looksLikeSong(title: video.title, author: video.author, duration: video.duration) ||
            !seen.add(video.id.value)) {
          continue;
        }
        songs.add(Song.fromVideo(video, subtitle: subtitle));
        if (songs.length >= limit) break;
      }
    }

    await collect(primary);
    // A second pass helps precise song-title / artist searches without letting
    // video-only results leak into the list. Keep the Hindi-first matches first.
    if (songs.length < limit && primary.toLowerCase() != raw.toLowerCase()) {
      await collect('$raw official song audio');
    }
    return songs.take(limit).toList();
  }

  /// A compact search modifier used throughout the app, including mood cards.
  /// Explicit regional language/genre requests are preserved; other searches
  /// start with Hindi/Indian music for the requested India-first experience.
  static String indianFirstQuery(String raw) {
    final String query = raw.trim();
    if (query.isEmpty) return 'Hindi songs India';
    final bool alreadyRegional = RegExp(
      r'\b(hindi|bollywood|indian|india|punjabi|tamil|telugu|marathi|bengali|kannada|malayalam|gujarati|bhajan|sufi|qawwali|ghazal)\b',
      caseSensitive: false,
    ).hasMatch(query);
    final bool hasMusicWord = RegExp(
      r'\b(song|songs|music|audio|bhajan|track|tracks|hits?)\b',
      caseSensitive: false,
    ).hasMatch(query);
    if (alreadyRegional) return hasMusicWord ? query : '$query songs';
    return 'Hindi song $query official audio';
  }

  /// Metadata-only song detector, exposed so the filter can be covered without
  /// network access. Label/VEVO/Bhakti channels and explicit song titles pass;
  /// obvious talk, gaming, news and tutorial uploads do not.
  static bool looksLikeSong({
    required String title,
    required String author,
    Duration? duration,
  }) {
    if (duration == null || duration.inSeconds < 25) {
      return false;
    }
    final String titleText = title.toLowerCase();
    final String authorText = author.toLowerCase();
    final RegExp notMusic = RegExp(
      r'\b(vlog|podcast|interview|reaction|review|tutorial|how to|news|gameplay|gaming|trailer|teaser|episode|full movie|short film|behind the scenes|making of|live stream|highlights)\b',
      caseSensitive: false,
    );
    if (notMusic.hasMatch(titleText)) return false;

    final RegExp musicTitle = RegExp(
      r'\b(song|songs|music|official audio|official video|music video|lyrics?|lyrical|soundtrack|ost|theme song|bhajan|aarti|kirtan|qawwali|ghazal|sufi|mantra|meditation music|lofi|lo-fi|remix|album|track|jukebox|non-?stop|all songs|full album)\b|गाना|गीत|भजन|आरती|कीर्तन|कव्वाली|ग़ज़ल|संगीत|सॉन्ग',
      caseSensitive: false,
    );
    final RegExp musicChannel = RegExp(
      r'\b(music|records?|recordings?|vevo|entertainment|films?|label|bhakti|sagar|saregama|t-series|zee music|sony music|tips music|ultra music|warner|universal|aditya music|lahari music|sun tv|official artist)\b',
      caseSensitive: false,
    );
    final bool plausibleSongLength = duration.inMinutes <= 15;
    final bool oshoMeditation =
        RegExp(r'\bosho\b', caseSensitive: false).hasMatch('$titleText $authorText') &&
            RegExp(r'\b(meditation|dynamic|kundalini|discourse|mantra|music)\b', caseSensitive: false)
                .hasMatch(titleText);

    // Long-form uploads used to be dropped outright, which hid exactly the
    // things Indian listeners search for: Osho meditations and discourses, hour
    // long bhajan jukeboxes, lofi/chill mixes and study-playlists. They stay
    // rejected unless the title or the channel says "music".
    final bool longForm = duration.inHours >= 1;
    final bool longFormMusic = RegExp(
      r'\b(osho|meditation|mantra|bhajan|kirtan|aarti|satsang|discourse|pravachan|kundalini|dynamic|lofi|lo-?fi|chill|relax|sleep|study|instrumental|classical|raga|sufi|ghazal|piano|jazz|ambient|healing|devotional|jukebox|non-?stop|compilation|full album|all songs|mix|hours?|hours long)\b',
      caseSensitive: false,
    ).hasMatch('$titleText $authorText');
    if (longForm && !longFormMusic && !musicTitle.hasMatch(titleText)) return false;

    return musicTitle.hasMatch(titleText) ||
        (plausibleSongLength && musicChannel.hasMatch(authorText)) ||
        oshoMeditation ||
        (longForm && longFormMusic);
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
      if (v.isLive ||
          !looksLikeSong(title: v.title, author: v.author, duration: v.duration)) {
        continue;
      }
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
      if (v.isLive ||
          !looksLikeSong(title: v.title, author: v.author, duration: v.duration)) {
        continue;
      }
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
