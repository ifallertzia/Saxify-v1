import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/artist_service.dart';
import '../../core/theme/category_palette.dart';
import '../../core/theme/saxify_fonts.dart';
import '../../core/models/song.dart';
import '../../core/services/playback_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import 'artwork.dart';
import 'song_download_button.dart';

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
                  Positioned(
                    right: 8,
                    top: 8,
                    child: SongDownloadButton(song: song, size: 34, floating: true),
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
                style: SaxifyFonts.display(
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

/// Fetches a real portrait on the rail itself, not only on the artist page.
/// Placeholder appears only until we know an image cannot be resolved.
class ArtistPortrait extends StatefulWidget {
  const ArtistPortrait({super.key, required this.name, this.imageUrl = '', this.size = 86});

  final String name;
  final String imageUrl;
  final double size;

  @override
  State<ArtistPortrait> createState() => _ArtistPortraitState();
}

class _ArtistPortraitState extends State<ArtistPortrait> {
  Future<ArtistProfile>? _photo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.imageUrl.isEmpty) {
      _photo ??= context.read<ArtistService>().resolve(widget.name);
    }
  }

  @override
  void didUpdateWidget(covariant ArtistPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.imageUrl != widget.imageUrl) {
      _photo = widget.imageUrl.isEmpty
          ? context.read<ArtistService>().resolve(widget.name) : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ArtistProfile>(
      future: _photo,
      builder: (BuildContext context, AsyncSnapshot<ArtistProfile> snap) {
        final String url = widget.imageUrl.isNotEmpty
            ? widget.imageUrl : snap.data?.imageUrl ?? '';
        if (url.isEmpty && snap.connectionState != ConnectionState.done) {
          return Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SaxifyColors.cardHover,
              shape: BoxShape.circle,
              border: Border.all(color: context.accent.primary.withValues(alpha: 0.18)),
            ),
            child: Icon(Icons.person_rounded, color: context.accent.primary, size: widget.size * 0.4),
          );
        }
        return ClipOval(
          child: Artwork(
            url: url,
            size: widget.size,
            radius: widget.size / 2,
            fallbackIcon: Icons.person_rounded,
          ),
        );
      },
    );
  }
}

/// Circular artist bubble — the Top artists and label artist rails.
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
                child: ArtistPortrait(name: name, imageUrl: imageUrl, size: size - 18),
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
              Text(caption, style: const TextStyle(fontSize: 10.5, color: SaxifyColors.textFaint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Solid, Spotify-style mood and genre tiles. Each tile is a real search action.
class MoodGenreGrid extends StatelessWidget {
  const MoodGenreGrid({
    super.key,
    required this.items,
    required this.onSelected,
    this.horizontalPadding = 20,
  });

  final List<(String, String)> items;
  final ValueChanged<String> onSelected;
  final double horizontalPadding;

  static const List<IconData> _icons = <IconData>[
    Icons.movie_creation_outlined,
    Icons.graphic_eq_rounded,
    Icons.album_outlined,
    Icons.headphones_rounded,
    Icons.auto_awesome_rounded,
    Icons.fitness_center_rounded,
    Icons.spa_rounded,
    Icons.nightlight_round,
    Icons.favorite_rounded,
    Icons.self_improvement_rounded,
    Icons.mic_rounded,
    Icons.record_voice_over_rounded,
    Icons.history_rounded,
    Icons.piano_rounded,
    Icons.celebration_rounded,
    Icons.psychology_rounded,
    Icons.directions_car_rounded,
    Icons.music_note_rounded,
    Icons.music_note_rounded,
    Icons.music_note_rounded,
    Icons.music_note_rounded,
    Icons.self_improvement_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 520
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 54,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (BuildContext context, int index) {
            final (String, String) item = items[index];
            final BorderRadius radius = BorderRadius.circular(14);
            final Color tile = CategoryPalette.at(index);
            final Color foreground = CategoryPalette.on(tile);
            return Material(
              color: tile,
              borderRadius: radius,
              child: InkWell(
                onTap: () => onSelected(item.$2),
                borderRadius: radius,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: foreground.withValues(alpha: 0.20),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(_icons[index % _icons.length], size: 18, color: foreground),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_outward_rounded, size: 15, color: foreground.withValues(alpha: 0.75)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Compact version used in small secondary shelves.
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
    final Color tile = CategoryPalette.forKey(label);
    final Color foreground = CategoryPalette.on(tile);
    return Material(
      color: tile,
      borderRadius: BorderRadius.circular(SaxifyTheme.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SaxifyTheme.radiusXl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 7),
              ],
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: foreground)),
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
