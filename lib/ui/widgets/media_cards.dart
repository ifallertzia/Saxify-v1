import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/song.dart';
import '../../core/services/playback_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import 'artwork.dart';

/// Square grid card used by "Made for you" / "Recommended for you".
class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.song,
    this.width = 158,
    this.onTap,
    this.subtitle,
  });

  final Song song;
  final double width;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final PlaybackService playback = context.watch<PlaybackService>();
    final SaxifyAccent accent = context.accent;
    final bool isCurrent = playback.current?.id == song.id;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => playback.playSong(song),
          borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  Artwork(
                    url: song.thumbnailUrl,
                    width: width,
                    height: width * 0.62,
                    radius: SaxifyTheme.radiusMd,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _PlayFab(accent: accent, active: isCurrent),
                  ),
                  if (song.duration != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          Fmt.duration(song.duration),
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: isCurrent ? accent.primary : SaxifyColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle ?? song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11.5, color: SaxifyColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayFab extends StatelessWidget {
  const _PlayFab({required this.accent, required this.active});

  final SaxifyAccent accent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: accent.gradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.primary.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Icon(
        active ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
        size: 19,
        color: Colors.black,
      ),
    );
  }
}

/// Album sleeve card — the "New releases" shelf.
class AlbumTile extends StatelessWidget {
  const AlbumTile({
    super.key,
    required this.coverUrl,
    required this.title,
    required this.artist,
    required this.onTap,
    this.width = 150,
  });

  final String coverUrl;
  final String title;
  final String artist;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Artwork(
                url: coverUrl,
                width: width,
                height: width,
                radius: SaxifyTheme.radiusMd,
                fallbackIcon: Icons.album_rounded,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: SaxifyColors.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 11.5, color: SaxifyColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular artist bubble — the "Top artists" rail.
class ArtistBubble extends StatelessWidget {
  const ArtistBubble({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.onTap,
    this.size = 104,
    this.caption = 'Artist',
  });

  final String name;
  final String imageUrl;
  final VoidCallback onTap;
  final double size;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: size - 14,
                height: size - 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.accent.primary.withValues(alpha: 0.45), width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: context.accent.primary.withValues(alpha: 0.22),
                      blurRadius: 20,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Artwork(
                    url: imageUrl,
                    size: size - 18,
                    radius: (size - 18) / 2,
                    fallbackIcon: Icons.person_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: SaxifyColors.textPrimary),
                ),
              ),
              Text(
                caption,
                style:
                    const TextStyle(fontSize: 10.5, color: SaxifyColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mood & genre pill — tapping runs its query through search.
class MoodChip extends StatelessWidget {
  const MoodChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SaxifyTheme.radiusXl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SaxifyTheme.radiusXl),
            gradient: LinearGradient(
              colors: <Color>[
                accent.primary.withValues(alpha: 0.16),
                accent.secondary.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: accent.primary.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: accent.primary),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal rail wrapper with the page's standard padding.
class HorizontalRail extends StatelessWidget {
  const HorizontalRail({
    super.key,
    required this.itemCount,
    required this.builder,
    this.height = 200,
    this.spacing = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final int itemCount;
  final Widget Function(BuildContext, int) builder;
  final double height;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (BuildContext c, int i) => SizedBox(width: spacing),
        itemBuilder: builder,
      ),
    );
  }
}
