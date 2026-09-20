import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/song.dart';
import '../../core/services/library_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/theme/sidify_accents.dart';
import '../../core/theme/sidify_theme.dart';
import '../shell/shell_controller.dart';
import '../widgets/neon.dart';
import '../widgets/song_tile.dart';

/// Search — same `_yt.search` backend as before, site-styled results.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Song> _results = <Song>[];
  bool _loading = false;
  String? _error;
  String _activeQuery = '';
  int _lastNonce = -1;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ShellController shell = context.read<ShellController>();
    if (shell.queryNonce != _lastNonce && shell.pendingQuery != null) {
      _lastNonce = shell.queryNonce;
      final String q = shell.pendingQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.text = q;
        _runSearch(q);
      });
    }
  }

  Future<void> _runSearch(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _activeQuery = q;
    });
    _focusNode.unfocus();

    try {
      final YoutubeService youtube = context.read<YoutubeService>();
      final LibraryService library = context.read<LibraryService>();
      final List<Song> results = await youtube.searchSongs(q, limit: 24);
      await library.rememberSearch(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed: $e';
        _results = <Song>[];
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryService library = context.watch<LibraryService>();
    final SidifyAccent accent = context.accent;
    final PlaybackService playback = context.read<PlaybackService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _runSearch,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Songs, artists, albums, moods…',
                        prefixIcon: Icon(Icons.search_rounded,
                            color: accent.primary),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: SidifyColors.textFaint),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() {
                                    _results = <Song>[];
                                    _activeQuery = '';
                                  });
                                },
                              ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    icon: Icon(Icons.arrow_forward_rounded,
                        color: accent.primary),
                    onPressed: () => _runSearch(_controller.text),
                  ),
                ],
              ),
            ),

            // Recent searches while idle
            if (_results.isEmpty && !_loading && library.recentSearches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'RECENT SEARCHES',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                            color: accent.primary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: library.clearSearchHistory,
                          child: const Text('Clear',
                              style: TextStyle(
                                  fontSize: 12, color: SidifyColors.textMuted)),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final String q in library.recentSearches.take(10))
                          ActionChip(
                            label: Text(q, style: const TextStyle(fontSize: 12)),
                            avatar: const Icon(Icons.history_rounded, size: 14),
                            onPressed: () {
                              _controller.text = q;
                              _runSearch(q);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Something went wrong',
                          message: _error,
                          actionLabel: 'Try again',
                          onAction: () => _runSearch(_activeQuery),
                        )
                      : _results.isEmpty
                          ? EmptyState(
                              icon: Icons.travel_explore_rounded,
                              title: 'Search Sidify',
                              message:
                                  'Find any song, artist or mood. Tap a result to '
                                  'start playing — the queue keeps the music going.',
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(6, 4, 6, 140),
                              children: <Widget>[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          '${_results.length} results for "$_activeQuery"',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: SidifyColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () =>
                                            playback.playQueue(_results),
                                        icon: const Icon(Icons.play_arrow_rounded,
                                            size: 18),
                                        label: const Text('Play all',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                      IconButton(
                                        tooltip: 'Shuffle',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.shuffle_rounded,
                                            size: 18),
                                        onPressed: () async {
                                          await playback.playQueue(_results);
                                          if (!playback.shuffleEnabled) {
                                            await playback.toggleShuffle();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                for (int i = 0; i < _results.length; i++)
                                  SongTile(
                                    song: _results[i],
                                    onTap: () =>
                                        playback.playQueue(_results, startIndex: i),
                                  ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
