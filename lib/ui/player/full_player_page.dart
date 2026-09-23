import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/theme/saxify_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/models/song.dart';
import '../../core/services/library_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import 'equalizer_page.dart';
import '../widgets/artwork.dart';
import '../widgets/song_menu.dart';
import '../widgets/song_tile.dart';

/// The full-screen player.
class FullPlayerPage extends StatefulWidget {
  const FullPlayerPage({super.key});

  @override
  State<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends State<FullPlayerPage> {
  bool _dragging = false;
  double _dragValue = 0;

  Future<void> _showSoundSheet() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.38,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.20),
                  SaxifyColors.surface.withValues(alpha: 0.94),
                  SaxifyColors.background.withValues(alpha: 0.96),
                ],
              ),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.30))),
            ),
            child: SafeArea(top: false,
              child: SoundControlsPanel(controller: controller)),
          ),
        ),
      ),
    ),
  );

  Future<void> _showQueueSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => const _QueueSheet(),
    );
  }

  Future<void> _showSleepSheet(PlaybackService playback) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _SleepSheet(playback: playback),
    );
  }

  Future<void> _showSpeedSheet(PlaybackService playback) {
    const List<double> speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: SaxifyColors.surface,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(SaxifyTheme.radiusLg)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 16),
              Text('Playback speed',
                  style: SaxifyFonts.display(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final double s in speeds)
                ListTile(
                  onTap: () {
                    playback.setSpeed(s);
                    Navigator.of(sheetContext).pop();
                  },
                  title: Text('${s}x'),
                  trailing: playback.speed == s
                      ? Icon(Icons.check_rounded, color: context.accent.primary)
                      : null,
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PlaybackService playback = context.watch<PlaybackService>();
    final LibraryService library = context.watch<LibraryService>();
    final SaxifyAccent accent = context.accent;
    final Song? song = playback.current;

    if (song == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.music_off_rounded,
                  size: 46, color: SaxifyColors.textFaint),
              const SizedBox(height: 14),
              Text('Nothing playing',
                  style: SaxifyFonts.display(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final bool liked = library.isLiked(song.id);
    final Duration total = playback.duration == Duration.zero
        ? (song.duration ?? Duration.zero)
        : playback.duration;

    return Scaffold(
      backgroundColor: SaxifyColors.background,
      body: Stack(
        children: <Widget>[
          // Ambient backdrop.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    accent.primary.withValues(alpha: 0.30),
                    accent.secondary.withValues(alpha: 0.10),
                    SaxifyColors.background,
                    SaxifyColors.background,
                  ],
                  stops: const <double>[0, 0.28, 0.62, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                // ---- top bar -------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 30),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Text(
                              'NOW PLAYING',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w700,
                                color: accent.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'From your queue',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: accent.primary.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded),
                        onPressed: () => showSongSheet(context, song),
                      ),
                    ],
                  ),
                ),

                // ---- artwork -------------------------------------------------
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(SaxifyTheme.radiusLg),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: accent.primary.withValues(alpha: 0.35),
                                blurRadius: 60,
                                offset: const Offset(0, 24),
                                spreadRadius: -14,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 40,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(SaxifyTheme.radiusLg),
                            child: Hero(
                              tag: 'player-artwork-${song.id}',
                              child: Artwork(
                                url: song.thumbnailUrl,
                                radius: SaxifyTheme.radiusLg,
                                size: double.infinity,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ---- title row ----------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 14, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SaxifyFonts.display(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  color: SaxifyColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        iconSize: 24,
                        icon: Icon(
                          liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: liked ? accent.primary : SaxifyColors.textMuted,
                        ),
                        onPressed: () => library.toggleLike(song),
                      ),
                    ],
                  ),
                ),

                // ---- seek ----------------------------------------------------
                StreamBuilder<Duration>(
                  stream: playback.positionStream,
                  initialData: playback.position,
                  builder: (BuildContext context, AsyncSnapshot<Duration> snap) {
                    final Duration position = snap.data ?? Duration.zero;
                    final double fraction = total.inMilliseconds == 0
                        ? 0
                        : (position.inMilliseconds / total.inMilliseconds)
                            .clamp(0.0, 1.0);
                    final double value = _dragging ? _dragValue : fraction;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Column(
                        children: <Widget>[
                          Slider(
                            value: value,
                            onChanged: (double v) =>
                                setState(() {
                                  _dragging = true;
                                  _dragValue = v;
                                }),
                            onChangeEnd: (double v) async {
                              setState(() => _dragging = false);
                              await playback.seekFraction(v);
                            },
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  Fmt.clock(_dragging
                                      ? Duration(
                                          milliseconds:
                                              (total.inMilliseconds * _dragValue)
                                                  .round())
                                      : position),
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: SaxifyColors.textMuted,
                                      fontFeatures: <FontFeature>[
                                        FontFeature.tabularFigures()
                                      ]),
                                ),
                                if (playback.isLoading)
                                  const SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.6),
                                  )
                                  else
                                  Text(
                                    '-${Fmt.clock(total - position)}',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: SaxifyColors.textMuted,
                                        fontFeatures: <FontFeature>[
                                          FontFeature.tabularFigures()
                                        ]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ---- transport ----------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _TransportIcon(
                        icon: Icons.shuffle_rounded,
                        active: playback.shuffleEnabled,
                        onTap: playback.toggleShuffle,
                      ),
                      _TransportIcon(
                        icon: Icons.skip_previous_rounded,
                        size: 36,
                        onTap: playback.previous,
                      ),
                      _PlayButton(
                        playing: playback.isPlaying,
                        loading: playback.isLoading,
                        onTap: playback.togglePlayPause,
                      ),
                      _TransportIcon(
                        icon: Icons.skip_next_rounded,
                        size: 36,
                        onTap: playback.next,
                      ),
                      _TransportIcon(
                        icon: switch (playback.loopMode) {
                          LoopMode.one => Icons.repeat_one_rounded,
                          LoopMode.all => Icons.repeat_rounded,
                          LoopMode.off => Icons.repeat_rounded,
                        },
                        active: playback.loopMode != LoopMode.off,
                        onTap: playback.cycleLoopMode,
                      ),
                    ],
                  ),
                ),

                // ---- extras --------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Sound & equalizer',
                        icon: const Icon(Icons.tune_rounded, size: 22),
                        onPressed: _showSoundSheet,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              _ChipButton(
                                label: '${playback.speed}x',
                                icon: Icons.speed_rounded,
                                onTap: () => _showSpeedSheet(playback),
                              ),
                              _ChipButton(
                                label: playback.sleepRemaining == null
                                    ? 'Sleep' : Fmt.clock(playback.sleepRemaining!),
                                icon: Icons.bedtime_rounded,
                                active: playback.sleepRemaining != null,
                                onTap: () => _showSleepSheet(playback),
                              ),
                              _ChipButton(
                                label: 'Queue',
                                icon: Icons.queue_music_rounded,
                                onTap: _showQueueSheet,
                              ),
                              _ChipButton(
                                label: 'EQ',
                                icon: Icons.graphic_eq_rounded,
                                onTap: _showSoundSheet,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.loading,
    required this.onTap,
  });

  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: accent.gradient,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.primary.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 10),
              spreadRadius: -6,
            ),
          ],
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.black),
              )
            : Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 38,
                color: Colors.black,
              ),
      ),
    );
  }
}

class _TransportIcon extends StatelessWidget {
  const _TransportIcon({
    required this.icon,
    required this.onTap,
    this.size = 24,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return IconButton(
      onPressed: onTap,
      iconSize: size,
      icon: Icon(
        icon,
        color: active ? accent.primary : SaxifyColors.textPrimary,
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SaxifyTheme.radiusXl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SaxifyTheme.radiusXl),
            color: active
                ? accent.primary.withValues(alpha: 0.16)
                : SaxifyColors.surfaceAlt,
            border: Border.all(
              color: active ? accent.primary : SaxifyColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon,
                  size: 14,
                  color: active ? accent.primary : SaxifyColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: active ? accent.primary : SaxifyColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepSheet extends StatelessWidget {
  const _SleepSheet({required this.playback});

  final PlaybackService playback;

  @override
  Widget build(BuildContext context) {
    const List<int> minutes = <int>[15, 30, 45, 60, 90];
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: SaxifyColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(SaxifyTheme.radiusLg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 16),
            Text('Sleep timer',
                style: SaxifyFonts.display(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Pause playback automatically',
                style: TextStyle(fontSize: 12, color: SaxifyColors.textMuted)),
            const SizedBox(height: 10),
            for (final int m in minutes)
              ListTile(
                title: Text('$m minutes'),
                onTap: () {
                  playback.startSleepTimer(Duration(minutes: m));
                  Navigator.of(context).pop();
                },
              ),
            ListTile(
              title: const Text('Until the current track ends'),
              onTap: () {
                final Duration d = playback.duration - playback.position;
                if (d > Duration.zero) {
                  playback.startSleepTimer(d);
                }
                Navigator.of(context).pop();
              },
            ),
            if (playback.sleepRemaining != null)
              ListTile(
                title: const Text('Turn off timer',
                    style: TextStyle(color: SaxifyColors.danger)),
                onTap: () {
                  playback.cancelSleepTimer();
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    final PlaybackService playback = context.watch<PlaybackService>();
    final SaxifyAccent accent = context.accent;
    final List<Song> queue = playback.queue;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: const BoxDecoration(
            color: SaxifyColors.surface,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(SaxifyTheme.radiusLg)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SaxifyColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Up next',
                              style: SaxifyFonts.display(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${queue.length} tracks in the queue',
                            style: const TextStyle(
                                fontSize: 12, color: SaxifyColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Shuffle queue',
                      icon: Icon(Icons.shuffle_rounded,
                          color: playback.shuffleEnabled
                              ? accent.primary
                              : SaxifyColors.textMuted),
                      onPressed: playback.toggleShuffle,
                    ),
                    IconButton(
                      tooltip: 'Clear queue',
                      icon: const Icon(Icons.delete_sweep_rounded,
                          color: SaxifyColors.textMuted),
                      onPressed: playback.clearQueue,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: queue.isEmpty
                    ? const Center(
                        child: Text('Queue is empty',
                            style: TextStyle(color: SaxifyColors.textMuted)),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: queue.length,
                        itemBuilder: (BuildContext c, int i) => QueueTile(
                          song: queue[i],
                          isPlaying: i == playback.currentIndex,
                          onTap: () => playback.skipToIndex(i),
                          onRemove: () => playback.removeFromQueue(i),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
