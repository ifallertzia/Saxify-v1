import 'package:flutter/material.dart';
import '../../core/theme/saxify_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/song.dart';
import '../../core/services/library_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../player/full_player_page.dart';
import '../widgets/artwork.dart';

/// The persistent mini player. Sits above the bottom nav on every screen,
/// exactly like the site's docked player.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaybackService playback = context.watch<PlaybackService>();
    final LibraryService library = context.watch<LibraryService>();
    final SaxifyAccent accent = context.accent;
    final Song? song = playback.current;

    if (song == null) return const SizedBox.shrink();

    final bool liked = library.isLiked(song.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (BuildContext c) => const FullPlayerPage()),
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
              gradient: LinearGradient(
                colors: <Color>[
                  accent.primary.withValues(alpha: 0.34),
                  SaxifyColors.card,
                  SaxifyColors.card,
                ],
              ),
              border: Border.all(color: accent.primary.withValues(alpha: 0.48)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.primary.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // hairline progress
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(SaxifyTheme.radiusMd)),
                  child: StreamBuilder<Duration>(
                    stream: playback.positionStream,
                    initialData: playback.position,
                    builder: (BuildContext c, AsyncSnapshot<Duration> snap) {
                      final Duration total = playback.duration == Duration.zero
                          ? (song.duration ?? Duration.zero)
                          : playback.duration;
                      final Duration pos = snap.data ?? Duration.zero;
                      final double fraction = total.inMilliseconds == 0
                          ? 0
                          : (pos.inMilliseconds / total.inMilliseconds)
                              .clamp(0.0, 1.0);
                      return SizedBox(
                        height: 2,
                        child: LinearProgressIndicator(
                          value: fraction,
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
                  child: Row(
                    children: <Widget>[
                      Hero(
                        tag: 'player-artwork-${song.id}',
                        flightShuttleBuilder: (BuildContext flightContext,
                                Animation<double> animation,
                                HeroFlightDirection flightDirection,
                                BuildContext fromHeroContext,
                                BuildContext toHeroContext) =>
                            Artwork(url: song.thumbnailUrl, size: 46, radius: 8),
                        child: Artwork(url: song.thumbnailUrl, size: 46, radius: 8),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SaxifyFonts.display(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: SaxifyColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: SaxifyColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 19,
                          color: liked ? accent.primary : SaxifyColors.textFaint,
                        ),
                        onPressed: () => library.toggleLike(song),
                      ),
                      playback.isLoading
                          ? const SizedBox(
                              width: 34,
                              height: 34,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 30,
                              icon: Icon(
                                playback.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: accent.primary,
                              ),
                              onPressed: playback.togglePlayPause,
                            ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.skip_next_rounded,
                            size: 24, color: SaxifyColors.textSecondary),
                        onPressed: playback.next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
