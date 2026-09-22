import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/album_card.dart';
import '../../core/models/artist.dart';
import '../../core/models/song.dart';
import '../../core/services/home_catalog.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/services/library_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import '../album/album_page.dart';
import '../artist/artist_router.dart';
import '../../data/labels.dart';
import '../brands/brands_page.dart';
import '../settings/settings_page.dart';
import '../shell/shell_controller.dart';
import '../widgets/media_cards.dart';
import '../widgets/neon.dart';
import '../widgets/saxify_logo.dart';
import '../widgets/song_tile.dart';

/// Home — mirrors saxify.vercel.app: hero greeting, Made for you, Mood & genres,
/// Trending now, New releases, Top artists and Recommended for you.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeCatalog>().load();
    });
  }

  void _openAlbum(AlbumCard album) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext c) => AlbumPage(album: album)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final HomeCatalog catalog = context.watch<HomeCatalog>();
    final SettingsService settings = context.watch<SettingsService>();

    return RefreshIndicator(
      color: context.accent.primary,
      backgroundColor: SaxifyColors.surface,
      onRefresh: () => catalog.load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: <Widget>[
          _TopBar(onSettings: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (BuildContext c) => const SettingsPage()),
            );
          }),
          _Hero(name: settings.displayName),
          if (catalog.loading) ...<Widget>[
            const SectionHeader(title: 'Made for you'),
            const LoadingRail(itemCount: 3),
          ] else ...<Widget>[
            if (catalog.error != null && catalog.madeForYou.isEmpty)
              EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Home feed unavailable',
                message: catalog.error,
                actionLabel: 'Retry',
                onAction: () => catalog.load(force: true),
              ),

            // ------------------------------------------------ Made for you
            if (catalog.madeForYou.isNotEmpty) ...<Widget>[
              SectionHeader(
                title: 'Made for you',
                subtitle: 'Picked from what you keep playing',
                actionLabel: 'Explore',
                onAction: () => context.read<ShellController>().goSearch(),
              ),
              HorizontalRail(
                height: 190,
                itemCount: catalog.madeForYou.length,
                builder: (BuildContext c, int i) {
                  final Song song = catalog.madeForYou[i];
                  return SongCard(
                    song: song,
                    onTap: () =>
                        context.read<PlaybackService>().playQueue(
                              catalog.madeForYou,
                              startIndex: i,
                            ),
                  );
                },
              ),
            ],

            // ------------------------------------------------ Mood & genres
            const SectionHeader(
              title: 'Mood & genres',
              subtitle: 'Tap a vibe to start a station',
            ),
            const _MoodGenresRow(),

            // ------------------------------------------------ Trending now
            if (catalog.trending.isNotEmpty) ...<Widget>[
              SectionHeader(
                title: 'Trending now',
                subtitle: 'The most-played tracks this week',
                actionLabel: 'Show all',
                onAction: () =>
                    context.read<ShellController>().goSearch('top hits'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < catalog.trending.length; i++)
                      SongTile(
                        song: catalog.trending[i],
                        rank: i + 1,
                        onTap: () => context
                            .read<PlaybackService>()
                            .playQueue(catalog.trending, startIndex: i),
                      ),
                  ],
                ),
              ),
            ],

            // ------------------------------------------------ New releases
            SectionHeader(
              title: 'New releases',
              subtitle: 'Fresh albums & singles',
              actionLabel: 'Browse',
              onAction: () =>
                  context.read<ShellController>().goSearch('new songs 2026'),
            ),
            HorizontalRail(
              height: 226,
              itemCount: HomeCatalog.newReleases.length,
              builder: (BuildContext c, int i) {
                final AlbumCard album = HomeCatalog.newReleases[i];
                return AlbumTile(
                  coverUrl: album.coverUrl,
                  title: album.title,
                  artist: album.artist,
                  onTap: () => _openAlbum(album),
                );
              },
            ),

            // ------------------------------------------------ Top artists
            SectionHeader(
              title: 'Music brands',
              subtitle: 'Official label channels',
              actionLabel: 'All',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BrandsPage()),
              ),
            ),
            const _BrandRow(),
            SectionHeader(
              title: 'Top artists',
              subtitle: 'Commanding the charts right now',
              actionLabel: 'Library',
              onAction: () => context.read<ShellController>().goLibrary(),
            ),
            HorizontalRail(
              height: 168,
              itemCount: HomeCatalog.topArtists.length,
              builder: (BuildContext c, int i) {
                final ArtistRef artist = HomeCatalog.topArtists[i];
                return ArtistBubble(
                  name: artist.name,
                  imageUrl: artist.imageUrl,
                  onTap: () => openArtistByName(
                        context,
                        name: artist.name,
                        channelId: artist.channelId,
                      ),
                );
              },
            ),

            // ------------------------------------------------ Recommended
            const _SmartRails(),
            if (catalog.recommended.isNotEmpty) ...<Widget>[
              const SectionHeader(
                title: 'Recommended for you',
                subtitle: 'Because of your recent listening',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < catalog.recommended.length; i++)
                      SongTile(
                        song: catalog.recommended[i],
                        subtitle: catalog.recommended[i].artist,
                        onTap: () => context
                            .read<PlaybackService>()
                            .playQueue(catalog.recommended, startIndex: i),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            const _WhatsNewCard(),
          ],
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final LibraryService library = context.watch<LibraryService>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: <Widget>[
          const SaxifyWordmark(logoSize: 32, fontSize: 20, showSubtitle: true),
          const Spacer(),
          IconButton(
            tooltip: 'Your library',
            icon: Badge(
              isLabelVisible: library.likedSongs.isNotEmpty,
              backgroundColor: context.accent.primary,
              child: const Icon(Icons.favorite_border_rounded,
                  color: SaxifyColors.textSecondary),
            ),
            onPressed: () => context.read<ShellController>().goLibrary(),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined,
                color: SaxifyColors.textSecondary),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    final PlaybackService playback = context.read<PlaybackService>();
    final HomeCatalog catalog = context.read<HomeCatalog>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SaxifyTheme.radiusLg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.primary.withValues(alpha: 0.26),
              accent.secondary.withValues(alpha: 0.10),
              SaxifyColors.card,
            ],
          ),
          border: Border.all(color: accent.primary.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: accent.primary.withValues(alpha: 0.18),
                    border:
                        Border.all(color: accent.primary.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'FREE · UNIVERSE PLAN',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: accent.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            RichText(
              text: TextSpan(
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 25,
                  height: 1.18,
                  fontWeight: FontWeight.w700,
                  color: SaxifyColors.textPrimary,
                ),
                children: <InlineSpan>[
                  TextSpan(text: '${Fmt.greeting()}, '),
                  TextSpan(text: '$name. ', style: TextStyle(color: accent.primary)),
                  const TextSpan(
                    text: '\nYour universe of sound awaits.',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: SaxifyColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Instant search, gapless playback, smart auto-next and a neon '
              'theme that keeps changing — all in one app.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.55, color: SaxifyColors.textMuted),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: NeonButton(
                    label: "Play today's mix",
                    icon: Icons.play_arrow_rounded,
                    compact: true,
                    onPressed: () {
                      final List<Song> mix = <Song>[
                        ...catalog.madeForYou,
                        ...catalog.trending,
                        ...catalog.recommended,
                      ];
                      if (mix.isEmpty) {
                        context.read<ShellController>().goSearch();
                        return;
                      }
                      playback.playQueue(mix, startIndex: 0);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeonButton(
                    label: 'Explore music',
                    icon: Icons.search_rounded,
                    filled: false,
                    compact: true,
                    onPressed: () =>
                        context.read<ShellController>().goSearch(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodGenresRow extends StatelessWidget {
  const _MoodGenresRow();

  static const List<IconData> _icons = <IconData>[
    Icons.auto_awesome_rounded,
    Icons.nightlight_round,
    Icons.fitness_center_rounded,
    Icons.spa_rounded,
    Icons.piano_rounded,
    Icons.celebration_rounded,
    Icons.psychology_rounded,
    Icons.volunteer_activism_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          for (int i = 0; i < HomeCatalog.moodGenres.length; i++)
            MoodChip(
              label: HomeCatalog.moodGenres[i].$1,
              icon: _icons[i % _icons.length],
              onTap: () => context
                  .read<ShellController>()
                  .goSearch(HomeCatalog.moodGenres[i].$2),
            ),
        ],
      ),
    );
  }
}

class _SmartRails extends StatelessWidget {
  const _SmartRails();

  @override
  Widget build(BuildContext context) {
    final RecommendationService reco = context.watch<RecommendationService>();
    final PlaybackService playback = context.read<PlaybackService>();
    if (reco.forYou.isEmpty && reco.becauseYouSearched.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: <Widget>[
        if (reco.forYou.isNotEmpty) ...<Widget>[
          const SectionHeader(
            title: 'Recommended for you',
            subtitle: 'On-device mix from what you play and search',
          ),
          HorizontalRail(
            height: 190,
            itemCount: reco.forYou.length,
            builder: (BuildContext c, int i) {
              final Song song = reco.forYou[i];
              return SongCard(
                song: song,
                onTap: () => playback.playQueue(reco.forYou, startIndex: i),
              );
            },
          ),
        ],
        if (reco.becauseQuery != null && reco.becauseYouSearched.isNotEmpty) ...<Widget>[
          SectionHeader(
            title: 'Because you searched ${reco.becauseQuery}',
            subtitle: 'Boosted after 2 searches in 3 days',
          ),
          for (int i = 0; i < reco.becauseYouSearched.length; i++)
            SongTile(
              song: reco.becauseYouSearched[i],
              onTap: () => playback.playQueue(reco.becauseYouSearched, startIndex: i),
            ),
        ],
      ],
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: MusicBrands.all.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final brand = MusicBrands.all[i];
          return ActionChip(
            label: Text(brand.name),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => BrandChannelPage(brand: brand)),
            ),
          );
        },
      ),
    );
  }
}

class _WhatsNewCard extends StatelessWidget {
  const _WhatsNewCard();

  static const List<String> _notes = <String>[
    'Songs now play one after another — when a song ends, a similar song starts on its own.',
    'Playlists, Liked Songs and search results keep rolling to the next song.',
    'The first song you tap starts right away.',
    'Like ❤ works — liked songs are saved and show up in Your Library.',
    '“Add to playlist” works — tap a playlist and the song goes straight in.',
    'Listening history updates while you play, so the History tab is never stale.',
    'Song errors skip ahead to a similar track instead of stopping playback.',
    'Settings now has “Instructions to play in background”.',
  ];

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: NeonCard(
        glow: true,
        onTap: () => _showNotes(context),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: accent.gradient,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Update notice',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: accent.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "What's new in Saxify",
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Playback, likes and playlists are all fixed',
                    style:
                        TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: SaxifyColors.textFaint),
          ],
        ),
      ),
    );
  }

  void _showNotes(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Minor update 1.1',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final String note in _notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.check_circle_rounded,
                          size: 15, color: context.accent.primary),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          note,
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
