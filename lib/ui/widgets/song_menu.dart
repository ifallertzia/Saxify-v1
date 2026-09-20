import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/artist.dart';
import '../../core/models/song.dart';
import '../../core/services/library_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/theme/sidify_theme.dart';
import '../../core/utils/format.dart';
import '../artist/artist_page.dart';
import 'add_to_playlist_sheet.dart';
import 'artwork.dart';

/// The overflow sheet behind every track row.
Future<void> showSongSheet(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => _SongSheet(song: song),
  );
}

class _SongSheet extends StatelessWidget {
  const _SongSheet({required this.song});

  final Song song;

  Future<void> _openArtist(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final YoutubeService youtube = context.read<YoutubeService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    String? channelId = song.channelId;
    String artistName = song.artist;

    if (channelId == null || channelId.isEmpty) {
      final ArtistRef? artist = await youtube.artistForVideo(song.id);
      if (artist != null) {
        channelId = artist.channelId;
        artistName = artist.name;
      }
    }

    if (channelId == null || channelId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not find this artist right now')),
      );
      return;
    }
    navigator.push(MaterialPageRoute<void>(
      builder: (BuildContext c) =>
          ArtistPage(channelId: channelId!, fallbackName: artistName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final LibraryService library = context.watch<LibraryService>();
    final PlaybackService playback = context.read<PlaybackService>();
    final bool liked = library.isLiked(song.id);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: SidifyColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SidifyTheme.radiusLg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SidifyColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Row(
                children: <Widget>[
                  Artwork(url: song.thumbnailUrl, size: 54, radius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${song.artist} · ${Fmt.duration(song.duration)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: SidifyColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _Action(
              icon: Icons.play_circle_outline_rounded,
              label: 'Play now',
              onTap: () {
                Navigator.of(context).pop();
                playback.playSong(song);
              },
            ),
            _Action(
              icon: Icons.playlist_add_rounded,
              label: 'Play next',
              onTap: () {
                Navigator.of(context).pop();
                playback.playNext(song);
                _toast(context, 'Playing next');
              },
            ),
            _Action(
              icon: Icons.queue_music_rounded,
              label: 'Add to queue',
              onTap: () {
                Navigator.of(context).pop();
                playback.addToQueue(song);
                _toast(context, 'Added to queue');
              },
            ),
            _Action(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
              onTap: () {
                library.toggleLike(song);
                Navigator.of(context).pop();
              },
            ),
            _Action(
              icon: Icons.playlist_add_check_circle_outlined,
              label: 'Add to playlist',
              onTap: () {
                Navigator.of(context).pop();
                showAddToPlaylistSheet(context, song);
              },
            ),
            _Action(
              icon: Icons.person_outline_rounded,
              label: 'Go to artist',
              onTap: () {
                Navigator.of(context).pop();
                _openArtist(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 21, color: SidifyColors.textSecondary),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
    );
  }
}
