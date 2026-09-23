import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/music_brand.dart';
import '../../core/models/song.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../widgets/neon.dart';
import '../widgets/song_tile.dart';

/// Part 5.4 — Music Brands detail.
///
/// A brand (label) is shown as its official YouTube channel when we have a
/// verified handle, otherwise as a live YouTube search for
/// "{name} official songs" — the same content engine the rest of the app
/// uses (Rule 2: no new search API), so label hits are always real and
/// playable.
class BrandPage extends StatefulWidget {
  const BrandPage({super.key, required this.brand});

  final MusicBrand brand;

  @override
  State<BrandPage> createState() => _BrandPageState();
}

class _BrandPageState extends State<BrandPage> {
  late final Future<List<Song>> _future = _load();

  Future<List<Song>> _load() async {
    final YoutubeService youtube = context.read<YoutubeService>();
    try {
      return await youtube.searchSongs(
          '${widget.brand.name} official songs', limit: 30);
    } catch (e) {
      debugPrint('brand search failed: $e');
      return <Song>[];
    }
  }

  Future<void> _openChannel() async {
    final String url =
        widget.brand.channelUrl.isNotEmpty ? widget.brand.channelUrl : widget.brand.searchUrl;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('open channel failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    final Color color = Color(widget.brand.color);

    return Scaffold(
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<Song>> snapshot) {
          final bool loading =
              snapshot.connectionState != ConnectionState.done;
          final List<Song> songs =
              (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data! : <Song>[];
          final bool failed = snapshot.hasError ||
              (snapshot.connectionState == ConnectionState.done &&
                  songs.isEmpty);

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: SaxifyColors.background,
                foregroundColor: SaxifyColors.textPrimary,
                title: Text(
                  'MUSIC BRAND',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                    color: accent.primary,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          color.withValues(alpha: 0.35),
                          SaxifyColors.surface,
                          SaxifyColors.background,
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[color, color.withValues(alpha: 0.55)],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              widget.brand.monogram,
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.brand.name,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.brand.region == 'india'
                            ? 'Indian label · official channel'
                            : 'International label · official channel',
                        style: const TextStyle(
                            fontSize: 12.5, color: SaxifyColors.textMuted),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: NeonButton(
                              label: 'Play label hits',
                              icon: Icons.play_arrow_rounded,
                              expand: true,
                              onPressed: songs.isEmpty
                                  ? null
                                  : () => context
                                      .read<PlaybackService>()
                                      .playQueue(songs, startIndex: 0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: NeonButton(
                              label: widget.brand.channelUrl.isNotEmpty
                                  ? 'Open channel'
                                  : 'Find on YouTube',
                              icon: Icons.open_in_new_rounded,
                              filled: false,
                              expand: true,
                              onPressed: _openChannel,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Label hits',
                  subtitle:
                      loading ? 'Loading…' : '${songs.length} official tracks',
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                ),
              ),
              if (loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      height: 72,
                      child: Center(
                          child:
                              CircularProgressIndicator(strokeWidth: 2.5)),
                    ),
                  ),
                )
              else if (failed)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.music_off_rounded,
                    title: 'No label hits found',
                    message:
                        'We could not load this label right now. Pull back and try again.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 140),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext c, int i) {
                        final Song song = songs[i];
                        return SongTile(
                          song: song,
                          rank: i + 1,
                          showArtwork: true,
                          onTap: () => context
                              .read<PlaybackService>()
                              .playQueue(songs, startIndex: i),
                        );
                      },
                      childCount: songs.length,
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
