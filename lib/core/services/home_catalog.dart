import 'package:flutter/foundation.dart';

import '../models/album_card.dart';
import '../models/artist.dart';
import '../models/song.dart';
import 'library_service.dart';
import 'youtube_service.dart';

/// Everything the Home screen shows.
///
/// The web app's home is a set of rails: Made for you, Mood & genres, Trending
/// now, New releases, Top artists and Recommended for you. The mobile app builds
/// the same rails — "Made for you" and "Recommended" are personalised from what
/// you actually listened to, the rest mirror the site's curated shelves.
class HomeCatalog extends ChangeNotifier {
  HomeCatalog({required YoutubeService youtube, required LibraryService library})
      : _youtube = youtube,
        _library = library;

  final YoutubeService _youtube;
  final LibraryService _library;

  bool loading = true;
  bool refreshing = false;
  String? error;
  bool _loaded = false;
  Future<void>? _loadOperation;

  List<Song> madeForYou = <Song>[];
  List<Song> trending = <Song>[];
  List<Song> recommended = <Song>[];

  /// Release shelves are deliberately India-first; every card opens a song-only search.
  static const List<AlbumCard> newReleases = <AlbumCard>[
    AlbumCard(
      query: 'latest Hindi Bollywood songs 2026 official audio',
      title: 'Bollywood Fresh',
      artist: 'Hindi · 2026',
      coverVideoId: 'NwgOjWWTwyM',
    ),
    AlbumCard(
      query: 'new Hindi indie songs 2026',
      title: 'Hindi Indie',
      artist: 'India · Indie',
      coverVideoId: '8lGpmDxT98o',
    ),
    AlbumCard(
      query: 'latest Punjabi songs 2026 official audio',
      title: 'Punjabi Heat',
      artist: 'Punjabi · 2026',
      coverVideoId: 'p9EAwHf6XjI',
    ),
    AlbumCard(
      query: 'Hindi devotional bhajan 2026',
      title: 'Bhakti & Devotion',
      artist: 'Hindi · Bhajan',
      coverVideoId: '3Xl2N5OQKME',
    ),
    AlbumCard(
      query: 'Hindi lofi chill songs',
      title: 'Hindi Lo-Fi',
      artist: 'Chill · India',
      coverVideoId: '0zdlvwZ8yuw',
    ),
    AlbumCard(
      query: 'Tamil Telugu latest songs 2026',
      title: 'South Indian Hits',
      artist: 'Tamil · Telugu',
      coverVideoId: 'ThdQv0PFUsc',
    ),
  ];

  static const List<ArtistRef> topArtists = <ArtistRef>[
    ArtistRef(channelId: '', name: 'Arijit Singh', imageUrl: ''),
    ArtistRef(channelId: '', name: 'Shreya Ghoshal', imageUrl: ''),
    ArtistRef(channelId: '', name: 'A. R. Rahman', imageUrl: ''),
    ArtistRef(channelId: '', name: 'Sonu Nigam', imageUrl: ''),
    ArtistRef(channelId: '', name: 'Lata Mangeshkar', imageUrl: ''),
    ArtistRef(channelId: '', name: 'Jubin Nautiyal', imageUrl: ''),
    ArtistRef(channelId: '', name: 'Diljit Dosanjh', imageUrl: ''),
    ArtistRef(channelId: '', name: 'Anirudh Ravichander', imageUrl: ''),
    ArtistRef(channelId: '', name: 'Neha Kakkar', imageUrl: ''),
    ArtistRef(channelId: '', name: 'Kishore Kumar', imageUrl: ''),
  ];

  /// India-first mood and genre shelves. Every label is a tappable song station.
  static const List<(String, String)> moodGenres = <(String, String)>[
    ('Bollywood', 'Hindi Bollywood hit songs'),
    ('Hindi Pop', 'Hindi pop songs India'),
    ('Hindi Indie', 'Hindi indie songs India'),
    ('Punjabi', 'Punjabi hit songs India'),
    ('Devotional', 'Hindi bhajan devotional songs'),
    ('Workout', 'Hindi workout gym songs'),
    ('Chill', 'Hindi chill songs relaxing'),
    ('Lo-Fi', 'Hindi lofi songs chill beats'),
    ('Romance', 'Hindi romantic love songs'),
    ('Sufi', 'Hindi Sufi songs India'),
    ('Qawwali', 'Indian qawwali songs'),
    ('Ghazal', 'Hindi ghazal songs'),
    ('Retro', 'Hindi old retro songs'),
    ('Classical', 'Indian classical instrumental music'),
    ('Party', 'Hindi party dance songs'),
    ('Focus', 'Indian instrumental focus music'),
    ('Road Trip', 'Hindi road trip songs'),
    ('Marathi', 'Marathi hit songs'),
    ('Bengali', 'Bengali songs India'),
    ('Tamil', 'Tamil hit songs'),
    ('Telugu', 'Telugu hit songs'),
    ('Osho', 'Osho meditation music discourse'),
  ];

  static const List<String> _trendingQueries = <String>[
    'Hindi trending songs India 2026',
    'latest Bollywood Hindi songs official audio',
    'Punjabi trending songs India 2026',
    'Hindi romantic hit songs',
    'Hindi devotional bhajan trending',
    'Hindi indie pop songs India',
    'Tamil Telugu trending songs India',
    'Hindi retro evergreen songs',
    'Hindi workout songs playlist',
    'Indian lofi chill songs',
  ];

  static const List<String> _madeForYouFallback = <String>[
    'Hindi romantic songs playlist',
    'Hindi lofi chill songs',
    'Bollywood soft songs',
    'Hindi pop hits India',
    'Hindi devotional bhajan songs',
    'Punjabi love songs',
  ];

  static const List<String> _recommendedFallback = <String>[
    'Hindi indie songs India',
    'latest Bollywood songs Hindi',
    'Hindi retro hit songs',
    'Indian classical instrumental',
    'Hindi sufi songs',
    'Hindi workout songs',
    'Osho meditation music',
    'Punjabi party songs',
  ];

  /// Loads each shelf automatically on first use. Concurrent callers (for
  /// example the Home screen and Today's Mix button) share one request.
  Future<void> load({bool force = false}) {
    if (_loaded && !force) return Future<void>.value();
    final Future<void>? inFlight = _loadOperation;
    if (inFlight != null) return inFlight;

    final Future<void> operation = Future<void>.microtask(_performLoad);
    _loadOperation = operation;
    return operation.whenComplete(() {
      if (identical(_loadOperation, operation)) _loadOperation = null;
    });
  }

  Future<void> _performLoad() async {
    if (_loaded) {
      refreshing = true;
    } else {
      loading = true;
    }
    error = null;
    notifyListeners();

    try {
      final List<List<String>> queries = <List<String>>[
        _madeForYouQueries(),
        _trendingQueries,
        _recommendedQueries(),
      ];

      final List<List<Song>> rails = await Future.wait(<Future<List<Song>>>[
        _rail(queries[0], 6),
        _rail(queries[1], 10),
        _rail(queries[2], 8),
      ]);
      if (rails.every((List<Song> shelf) => shelf.isEmpty)) {
        throw StateError('The music service returned no catalog results');
      }

      madeForYou = rails[0];
      trending = rails[1];
      recommended = rails[2];
      _loaded = true;
      error = null;
    } catch (e) {
      error = 'Could not load your home feed. Pull down to try again.';
      debugPrint('HomeCatalog.load failed: $e');
    } finally {
      loading = false;
      refreshing = false;
      notifyListeners();
    }
  }

  /// Fetches a few stations at a time to avoid firing twenty YouTube requests
  /// simultaneously on slower phones or mobile connections.
  Future<List<Song>> _rail(List<String> queries, int limit) async {
    final List<Song> songs = <Song>[];
    final List<String> selected = queries.take(limit).toList();
    for (int start = 0; start < selected.length; start += 4) {
      final List<String> batch = selected.skip(start).take(4).toList();
      final List<Song?> results = await Future.wait(<Future<Song?>>[
        for (final String query in batch) _youtube.topSong(query),
      ]);
      songs.addAll(results.whereType<Song>());
    }
    return songs;
  }

  /// "Made for you": artists you actually played, then curated fallbacks.
  List<String> _madeForYouQueries() {
    final List<String> personal = <String>[];
    for (final String artist in _library.recentArtistNames(limit: 3)) {
      personal.add('best of $artist');
    }
    for (final Song song in _library.likedSongs.take(2)) {
      personal.add('songs like ${song.title}');
    }
    return <String>[...personal, ..._madeForYouFallback];
  }

  /// "Recommended for you": your recent listening first, then discovery picks.
  List<String> _recommendedQueries() {
    final List<String> personal = <String>[];
    for (final String title in _library.recentSongTitles(limit: 3)) {
      personal.add('songs like $title');
    }
    for (final String artist in _library.recentArtistNames(limit: 2)) {
      personal.add('$artist mix');
    }
    return <String>[...personal, ..._recommendedFallback];
  }
}
