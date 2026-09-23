import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/song.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/services/artwork_cache.dart';
import '../downloader/downloader_page.dart';
import '../home/home_page.dart';
import '../library/library_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import '../settings/update_dialog.dart';
import 'mini_player.dart';
import 'shell_controller.dart';

/// App shell: bottom navigation, the persistent mini player, and the four tabs.
class SaxifyShell extends StatefulWidget {
  const SaxifyShell({super.key});

  @override
  State<SaxifyShell> createState() => _SaxifyShellState();
}

class _SaxifyShellState extends State<SaxifyShell> {
  late final ShellController _shell = context.read<ShellController>();
  String? _shownNotice;
  bool _dbToastShown = false;

  @override
  void initState() {
    super.initState();
    _shell.addListener(_onShellChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlaybackService>().addListener(_onPlaybackChanged);
      context.read<RecommendationService>().addListener(_onRecommendations);
      _onRecommendations();
    });

    // Phase 2: once the UI is up, quietly check GitHub Releases. Only shows a
    // dialog when a newer version actually exists.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      checkAndPromptUpdate(context, silent: true);
    });
  }

  void _onShellChanged() {
    if (mounted) setState(() {});
  }

  /// Surfaces playback notices ("skipped to something similar") once each.
  void _onPlaybackChanged() {
    if (!mounted) return;
    final PlaybackService playback = context.read<PlaybackService>();
    final String? notice = playback.notice;
    if (notice == null || notice == _shownNotice) return;
    _shownNotice = notice;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(notice),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'DISMISS',
            onPressed: playback.dismissNotice,
          ),
        ),
      );
  }

  void _onRecommendations() {
    if (!mounted || _dbToastShown) return;
    if (!context.read<RecommendationService>().store.recovered) return;
    _dbToastShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Local data reset — playlists cloud se restore honge.'),
      ),
    );
  }

  @override
  void dispose() {
    _shell.removeListener(_onShellChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaxifyColors.background,
      extendBody: false,
      body: Column(
        children: <Widget>[
          Expanded(
            child: IndexedStack(
              index: _shell.tab.index,
              children: const <Widget>[
                HomePage(),
                SearchPage(),
                LibraryPage(),
                DownloaderPage(),
                SettingsPage(),
              ],
            ),
          ),
          const _NextArtworkPrecache(),
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _shell.tab.index,
            onDestinationSelected: (int i) =>
                _shell.select(SaxifyTab.values[i]),
            destinations: const <Widget>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.workspace_premium_outlined),
                selectedIcon: Icon(Icons.workspace_premium_rounded),
                label: 'Exclusive',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Warms the next sleeve about 5 seconds before the current track ends.
class _NextArtworkPrecache extends StatefulWidget {
  const _NextArtworkPrecache();

  @override
  State<_NextArtworkPrecache> createState() => _NextArtworkPrecacheState();
}

class _NextArtworkPrecacheState extends State<_NextArtworkPrecache> {
  String? _warmed;

  @override
  Widget build(BuildContext context) {
    final PlaybackService playback = context.watch<PlaybackService>();
    return StreamBuilder<Duration>(
      stream: playback.positionStream,
      builder: (BuildContext context, AsyncSnapshot<Duration> snap) {
        final Song? next = playback.nextUp;
        final Duration left = playback.duration - (snap.data ?? Duration.zero);
        if (next != null &&
            left > Duration.zero &&
            left <= const Duration(seconds: 5) &&
            _warmed != next.id) {
          _warmed = next.id;
          ArtworkCache.precache(context, next.thumbnailUrl);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
