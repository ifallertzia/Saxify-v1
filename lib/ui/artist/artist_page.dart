import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/models/artist.dart';
import '../../core/models/song.dart';
import '../../core/services/library_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import '../widgets/artwork.dart';
import '../widgets/neon.dart';
import '../widgets/song_tile.dart';

/// The site's `/artist/<channelId>` route.
class ArtistPage extends StatefulWidget {
  const ArtistPage({
    super.key,
    required this.channelId,
    this.fallbackName,
    this.fallbackImageUrl,
  });

  final String channelId;
  final String? fallbackName;
  final String? fallbackImageUrl;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  late final Future<_ArtistData> _future = _load();

  Future<_ArtistData> _load() async {
    final YoutubeService youtube = context.read<YoutubeService>();
    final Channel channel = await youtube.channel(widget.channelId);
    List<Song> uploads = <Song>[];
    try {
      uploads = await youtube.channelUploads(widget.channelId, limit: 40);
    } catch (e) {
      debugPrint('Artist uploads unavailable: $e');
    }
    if (uploads.isEmpty) {
      final String artist = widget.fallbackName?.trim().isNotEmpty == true
          ? widget.fallbackName!.trim()
          : channel.title;
      uploads = await youtube.searchSongs('$artist Hindi songs', limit: 30);
    }
    return _ArtistData(channel: channel, uploads: uploads);
  }

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;

    return Scaffold(
      body: FutureBuilder<_ArtistData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_ArtistData> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _ArtistSkeleton();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return SafeArea(
              child: EmptyState(
                icon: Icons.person_off_rounded,
                title: 'Artist unavailable',
                message:
                    'We could not load this channel. Pull back and try again.',
                actionLabel: 'Go back',
                onAction: () => Navigator.of(context).maybePop(),
              ),
            );
          }

          final _ArtistData data = snapshot.data!;
          final LibraryService library = context.watch<LibraryService>();
          final PlaybackService playback = context.read<PlaybackService>();

          final ArtistRef ref = ArtistRef(
            channelId: widget.channelId,
            name: data.channel.title,
            imageUrl: data.channel.logoUrl,
            subscribers: data.channel.subscribersCount?.toString(),
          );
          final bool following = library.isFollowing(widget.channelId);

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: SaxifyColors.background,
                foregroundColor: SaxifyColors.textPrimary,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Artwork(
                        url: data.channel.bannerUrl,
                        radius: 0,
                        fit: BoxFit.cover,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.35),
                              SaxifyColors.background.withValues(alpha: 0.92),
                              SaxifyColors.background,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 18,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: accent.primary.withValues(alpha: 0.6),
                                    width: 2),
                              ),
                              child: ClipOval(
                                child: Artwork(
                                  url: data.channel.logoUrl,
                                  size: 80,
                                  radius: 40,
                                  fallbackIcon: Icons.person_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'ARTIST',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      letterSpacing: 1.6,
                                      fontWeight: FontWeight.w700,
                                      color: accent.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    data.channel.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                                  if (data.channel.subscribersCount != null) ...<Widget>[
                                    const SizedBox(height: 5),
                                    Text(
                                      '${Fmt.count(data.channel.subscribersCount)} followers',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: SaxifyColors.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: <Widget>[
                      NeonButton(
                        label: 'Play all',
                        icon: Icons.play_arrow_rounded,
                        expand: true,
                        onPressed: data.uploads.isEmpty
                            ? null
                            : () =>
                                playback.playQueue(data.uploads, startIndex: 0),
                      ),
                      const SizedBox(width: 10),
                      _IconButtonTile(
                        icon: following
                            ? Icons.check_rounded
                            : Icons.person_add_alt_1_rounded,
                        active: following,
                        tooltip: following ? 'Following' : 'Follow',
                        onTap: () => library.toggleFollow(ref),
                      ),
                      const SizedBox(width: 10),
                      _IconButtonTile(
                        icon: Icons.shuffle_rounded,
                        tooltip: 'Shuffle',
                        onTap: data.uploads.isEmpty
                            ? null
                            : () async {
                                await playback.playQueue(data.uploads,
                                    startIndex: 0);
                                if (!playback.shuffleEnabled) {
                                  await playback.toggleShuffle();
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Latest releases',
                  subtitle: '${data.uploads.length} tracks',
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                ),
              ),
              if (data.uploads.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.music_off_rounded,
                    title: 'No uploads found',
                    message: 'This channel has not published anything we can read.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 140),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext c, int i) {
                        final Song song = data.uploads[i];
                        return SongTile(
                          song: song,
                          rank: i + 1,
                          showArtwork: true,
                          onTap: () =>
                              playback.playQueue(data.uploads, startIndex: i),
                        );
                      },
                      childCount: data.uploads.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IconButtonTile extends StatelessWidget {
  const _IconButtonTile({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: SaxifyColors.surfaceAlt,
              border: Border.all(
                color: active ? accent.primary : SaxifyColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? accent.primary : SaxifyColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistData {
  const _ArtistData({required this.channel, required this.uploads});

  final Channel channel;
  final List<Song> uploads;
}

class _ArtistSkeleton extends StatelessWidget {
  const _ArtistSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 300,
            child: ColoredBox(color: SaxifyColors.surfaceAlt),
          ),
          SizedBox(height: 20),
          LoadingRail(itemCount: 6, height: 64),
        ],
      ),
    );
  }
}
