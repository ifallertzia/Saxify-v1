import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/playback_service.dart';
import '../../core/theme/sidify_theme.dart';
import '../home/home_page.dart';
import '../library/library_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';
import '../settings/update_dialog.dart';
import 'mini_player.dart';
import 'shell_controller.dart';

/// App shell: bottom navigation, the persistent mini player, and the four tabs.
class SidifyShell extends StatefulWidget {
  const SidifyShell({super.key});

  @override
  State<SidifyShell> createState() => _SidifyShellState();
}

class _SidifyShellState extends State<SidifyShell> {
  late final ShellController _shell = context.read<ShellController>();
  String? _shownNotice;

  @override
  void initState() {
    super.initState();
    _shell.addListener(_onShellChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlaybackService>().addListener(_onPlaybackChanged);
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

  @override
  void dispose() {
    _shell.removeListener(_onShellChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SidifyColors.background,
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
                SettingsPage(),
              ],
            ),
          ),
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _shell.tab.index,
            onDestinationSelected: (int i) =>
                _shell.select(SidifyTab.values[i]),
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
