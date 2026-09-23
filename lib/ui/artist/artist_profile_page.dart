import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/song.dart';
import '../../core/services/artist_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import '../widgets/artwork.dart';
import '../widgets/neon.dart';
import '../widgets/search_fab.dart';
import '../widgets/song_tile.dart';

/// Profile opened only after a confident name match. Songs still come from
/// the existing YouTube search.
class ArtistProfilePage extends StatefulWidget {
  const ArtistProfilePage({
    super.key,
    required this.queryName,
    required this.profile,
  });

  final String queryName;
  final ArtistProfile profile;

  @override
  State<ArtistProfilePage> createState() => _ArtistProfilePageState();
}

class _ArtistProfilePageState extends State<ArtistProfilePage> {
  late final Future<List<Song>> _songs = _load();

  Future<List<Song>> _load() {
    final String name = widget.profile.name;
    return context.read<YoutubeService>().searchSongs('$name songs', limit: 20);
  }

  Future<void> _youtube() async {
    final Uri uri = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent('${widget.profile.name} songs')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    final ArtistProfile profile = widget.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: const <Widget>[SaxifySearchButton()],
      ),
      body: FutureBuilder<List<Song>>(
        future: _songs,
        builder: (BuildContext context, AsyncSnapshot<List<Song>> snap) {
          final List<Song> songs = snap.data ?? <Song>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 140),
            children: <Widget>[
              const SizedBox(height: 18),
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.primary, width: 2),
                  ),
                  child: ClipOval(
                    child: Artwork(
                      url: profile.imageUrl,
                      size: 120,
                      radius: 60,
                      fallbackIcon: Icons.person_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  profile.fanCount == null
                      ? 'Photo via ${profile.source}'
                      : '${Fmt.count(profile.fanCount)} fans · ${profile.source}',
                  style: const TextStyle(fontSize: 12, color: SaxifyColors.textMuted),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: <Widget>[
                    NeonButton(
                      label: 'Play top songs',
                      icon: Icons.play_arrow_rounded,
                      expand: true,
                      onPressed: songs.isEmpty
                          ? null
                          : () => context.read<PlaybackService>().playQueue(songs),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Play on YouTube',
                      onPressed: _youtube,
                      icon: const Icon(Icons.smart_display_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: SaxifyColors.surfaceAlt,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ],
                ),
              ),
              if (snap.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (songs.isEmpty)
                const EmptyState(
                  icon: Icons.music_off_rounded,
                  title: 'No songs found',
                  message: 'Try Play on YouTube, or search the name again.',
                )
              else
                for (int i = 0; i < songs.length; i++)
                  SongTile(
                    song: songs[i],
                    rank: i + 1,
                    onTap: () => context.read<PlaybackService>().playQueue(songs, startIndex: i),
                  ),
            ],
          );
        },
      ),
    );
  }
}
