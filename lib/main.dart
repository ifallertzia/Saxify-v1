import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/home_catalog.dart';
import 'core/services/library_service.dart';
import 'core/services/playback_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/youtube_service.dart';
import 'core/theme/sidify_theme.dart';
import 'core/theme/theme_controller.dart';
import 'ui/shell/shell_controller.dart';
import 'ui/shell/sidify_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: SidifyColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final SettingsService settings = SettingsService(prefs);
  final LibraryService library = LibraryService(prefs);
  final YoutubeService youtube = YoutubeService();
  final PlaybackService playback = PlaybackService(
    youtube: youtube,
    settings: settings,
    library: library,
  );

  runApp(
    SidifyApp(
      settings: settings,
      library: library,
      youtube: youtube,
      playback: playback,
    ),
  );
}

/// Sidify — Stream beyond limits.
class SidifyApp extends StatelessWidget {
  const SidifyApp({
    super.key,
    required this.settings,
    required this.library,
    required this.youtube,
    required this.playback,
  });

  final SettingsService settings;
  final LibraryService library;
  final YoutubeService youtube;
  final PlaybackService playback;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settings),
        ChangeNotifierProvider<LibraryService>.value(value: library),
        Provider<YoutubeService>.value(value: youtube),
        ChangeNotifierProvider<PlaybackService>.value(value: playback),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(settings),
        ),
        ChangeNotifierProvider<HomeCatalog>(
          create: (_) => HomeCatalog(youtube: youtube, library: library),
        ),
        ChangeNotifierProvider<ShellController>(
          create: (_) => ShellController(),
        ),
      ],
      child: const _SidifyRoot(),
    );
  }
}

class _SidifyRoot extends StatelessWidget {
  const _SidifyRoot();

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.watch<ThemeController>();

    return MaterialApp(
      title: 'Sidify',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: SidifyTheme.build(theme.accent),
      darkTheme: SidifyTheme.build(theme.accent),
      home: const SidifyShell(),
    );
  }
}
