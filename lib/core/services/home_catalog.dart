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

  List<Song> madeForYou = <Song>[];
  List<Song> trending = <Song>[];
  List<Song> recommended = <Song>[];

  /// Shelf data straight off sidify.vercel.app.
  static const List<AlbumCard> newReleases = <AlbumCard>[
    AlbumCard(
      query: 'new songs 2026 official',
      title: 'New Music 2026',
      artist: 'Fally Ipupa',
      coverVideoId: '3Xl2N5OQKME',
    ),
    AlbumCard(
      query: 'latest bollywood songs 2026',
      title: 'Bollywood Fresh',
      artist: 'Pritam',
      coverVideoId: 'NwgOjWWTwyM',
    ),
    AlbumCard(
      query: 'new pop releases 2026',
      title: 'Pop Radar',
      artist: 'Lumivox',
      coverVideoId: '8lGpmDxT98o',
    ),
    AlbumCard(
      query: 'latest punjabi songs 2026',
      title: 'Punjabi Heat',
      artist: 'Harf Cheema',
      coverVideoId: 'p9EAwHf6XjI',
    ),
    AlbumCard(
      query: 'new hip hop 2026',
      title: 'Hip-Hop Now',
      artist: 'DaBaby',
      coverVideoId: 'ThdQv0PFUsc',
    ),
    AlbumCard(
      query: 'trending lo-fi 2026',
      title: 'Lo-Fi Corner',
      artist: 'Unknown Artist',
      coverVideoId: '0zdlvwZ8yuw',
    ),
  ];

  static const List<ArtistRef> topArtists = <ArtistRef>[
    ArtistRef(
        channelId: 'UCU1JusGzZe0Msn79JB3g46w',
        name: 'B.o.B',
        imageUrl: 'https://i.ytimg.com/vi/YVev0EXDSm0/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UClYV6hHlupm_S_ObS1W-DYw',
        name: 'The Weeknd',
        imageUrl: 'https://i.ytimg.com/vi/J7p4bzqLvCw/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UCo6JijJGA3IvIiPsawDK3Ww',
        name: 'Shakira',
        imageUrl: 'https://i.ytimg.com/vi/lFQdcPTTzSg/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UC48KcV8QzaB761VFbrFZ4YQ',
        name: 'Ricky Rich',
        imageUrl: 'https://i.ytimg.com/vi/9XsXJpYc7pU/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UCOx12K3GqOMcIeyNTNj1Z6Q',
        name: 'Ruth B.',
        imageUrl: 'https://i.ytimg.com/vi/HZbsLxL7GeM/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UCyLlLf_1tSPom7l71lub4BA',
        name: 'Bappi Lahiri',
        imageUrl: 'https://i.ytimg.com/vi/68RLvhxk_4g/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UCYCocSsv6lg9UM8IvY5hMEA',
        name: 'Otilia',
        imageUrl: 'https://i.ytimg.com/vi/cAQtS4vIRQs/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UCgpBsaDW2n_6ruzht3wvP0A',
        name: 'Sam Smith',
        imageUrl: 'https://i.ytimg.com/vi/8VKD-IlvibI/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UClmXPfaYhXOYsNn_QUyheWQ',
        name: 'Ed Sheeran',
        imageUrl: 'https://i.ytimg.com/vi/xTvyyoF_LZY/hqdefault.jpg'),
    ArtistRef(
        channelId: 'UCCK1-D6wWlRuQgaCdIAKsMA',
        name: 'Jaymes Young',
        imageUrl: 'https://i.ytimg.com/vi/WMK3JXG3Fx0/hqdefault.jpg'),
  ];

  /// The 8 mood chips from the site — label plus the query they run.
  static const List<(String, String)> moodGenres = <(String, String)>[
    ('Pop', 'pop hits'),
    ('Lo-Fi', 'lofi beats'),
    ('Workout', 'workout edm'),
    ('Chill', 'chill vibes'),
    ('Classical', 'classical piano'),
    ('Party', 'party dance'),
    ('Focus', 'deep focus instrumental'),
    ('Romance', 'romantic songs'),
  ];

  static const List<String> _trendingQueries = <String>[
    'blinding lights the weeknd',
    'shape of you ed sheeran',
    'dandelions ruth b',
    'unholy sam smith',
    'waka waka shakira',
    'nothin on you b.o.b bruno mars',
    'infinity jaymes young',
    'bilionera otilia',
    'habibi ricky rich',
    'perfect ed sheeran',
  ];

  static const List<String> _madeForYouFallback = <String>[
    'r&b playlist 2026 mix',
    'buddha lounge bar chillout',
    'deep house lounge mix',
    'mega hits 2026 playlist',
    'smooth relaxing jazz songs',
    'summer love songs chill pop',
  ];

  static const List<String> _recommendedFallback = <String>[
    'chill beach vibes playlist',
    'amapiano mixtape',
    'afro soul romantic love songs',
    'tems free mind',
    'sza snooze',
    'kolohe kai cool down',
    'deep house sunset beach mix',
    'freed from desire chill',
  ];

  /// Loads every rail. Safe to call repeatedly — the first call fills the
  /// shelves, later calls only refetch when [force] is set (pull-to-refresh).
  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    if (loading && !force) return;

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

  /// One song per query, fetched in parallel — that is how the site's rails are
  /// built too (each card is a curated search).
  Future<List<Song>> _rail(List<String> queries, int limit) async {
    final List<Song?> results = await Future.wait(<Future<Song?>>[
      for (final String q in queries.take(limit)) _youtube.topSong(q),
    ]);
    return results.whereType<Song>().toList();
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
