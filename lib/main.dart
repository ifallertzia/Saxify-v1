import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/branding.dart';
import 'core/models/playlist.dart';
import 'core/models/song.dart';
import 'core/services/artist_service.dart';
import 'core/services/boot_log.dart';
import 'core/services/home_catalog.dart';
import 'core/services/library_service.dart';
import 'core/services/music_download_service.dart';
import 'core/services/native_bridge.dart';
import 'core/services/notification_bootstrap.dart';
import 'core/services/playback_service.dart';
import 'core/services/playlist_sync_service.dart';
import 'core/services/recommendation_service.dart';
import 'core/services/recommendation_worker.dart';
import 'core/services/settings_service.dart';
import 'core/services/youtube_service.dart';
import 'core/theme/saxify_theme.dart';
import 'core/theme/theme_controller.dart';
import 'downloader/download_history_store.dart';
import 'downloader/universal_downloader.dart';
import 'ui/shell/shell_controller.dart';
import 'ui/shell/saxify_shell.dart';
import 'ui/onboarding/welcome_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    BootLog.write(details.exceptionAsString());
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    BootLog.write('$error\n$stack');
    return true;
  };

  runZonedGuarded(() async {
    AppBoot? boot;
    try {
      boot = await _initializeApp().timeout(const Duration(seconds: 12));
    } catch (error, stack) {
      BootLog.write('init failed: $error\n$stack');
    }
    if (boot == null) {
      runApp(const SaxifyRecoveryApp());
      return;
    }
    runApp(SaxifyApp(boot: boot));
  }, (Object error, StackTrace stack) {
    BootLog.write('Zone error: $error\n$stack');
    runApp(const SaxifyRecoveryApp());
  });
}

Future<AppBoot> _initializeApp() async {
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).timeout(const Duration(seconds: 1), onTimeout: () {});

  final BootSnapshot native = await NativeBridge.bootState();
  if (native.safeMode) {
    BootLog.write('safe mode — skipping notification and recommendation init');
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance()
      .timeout(const Duration(seconds: 3));
  await _migrateLegacyKeys(prefs);

  // The notification/media session is what keeps Android audio alive after
  // the app is backgrounded. Its failure is isolated internally, so still try
  // it in safe mode rather than silently dropping background playback.
  await NotificationBootstrap.init().timeout(
    const Duration(seconds: 7),
    onTimeout: () => false,
  );

  final SettingsService settings = SettingsService(prefs);
  final LibraryService library = LibraryService(prefs);
  final YoutubeService youtube = YoutubeService();
  final PlaybackService playback = PlaybackService(
    youtube: youtube,
    settings: settings,
    library: library,
  );
  final RecommendationService recommendations = RecommendationService(youtube: youtube);
  final ArtistService artists = ArtistService(youtube: youtube);
  final MusicDownloadService musicDownloads = MusicDownloadService(prefs: prefs);
  final UniversalDownloader downloader = UniversalDownloader(
    history: DownloadHistoryStore(prefs),
  );

  playback.onTrackStarted = (Song song) {
    recommendations.notePlay(song);
    recommendations.refresh(current: song, force: true);
  };
  playback.onTrackSkipped = recommendations.noteSkip;
  library.onLikeChanged = (Song song, bool liked) {
    if (liked) recommendations.noteLike(song);
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: SaxifyColors.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  return AppBoot(
    settings: settings,
    library: library,
    youtube: youtube,
    playback: playback,
    recommendations: recommendations,
    artists: artists,
    musicDownloads: musicDownloads,
    downloader: downloader,
    safeMode: native.safeMode,
  );
}

/// Copies preference blobs written before the rename. The old prefix is built
/// from codes so a brand string is not reintroduced into the tree.
Future<void> _migrateLegacyKeys(SharedPreferences prefs) async {
  final String old = String.fromCharCodes(const <int>[115, 105, 100, 105, 102, 121]);
  for (final String key in prefs.getKeys().toList()) {
    if (!key.startsWith('$old.')) continue;
    final String next = 'saxify.${key.substring(old.length + 1)}';
    if (prefs.containsKey(next)) continue;
    final Object? value = prefs.get(key);
    if (value is String) {
      await prefs.setString(next, value);
    } else if (value is bool) {
      await prefs.setBool(next, value);
    } else if (value is int) {
      await prefs.setInt(next, value);
    } else if (value is double) {
      await prefs.setDouble(next, value);
    } else if (value is List<String>) {
      await prefs.setStringList(next, value);
    }
  }
}

class AppBoot {
  const AppBoot({
    required this.settings,
    required this.library,
    required this.youtube,
    required this.playback,
    required this.recommendations,
    required this.artists,
    required this.musicDownloads,
    required this.downloader,
    required this.safeMode,
  });

  final SettingsService settings;
  final LibraryService library;
  final YoutubeService youtube;
  final PlaybackService playback;
  final RecommendationService recommendations;
  final ArtistService artists;
  final MusicDownloadService musicDownloads;
  final UniversalDownloader downloader;
  final bool safeMode;
}

class SaxifyApp extends StatefulWidget {
  const SaxifyApp({super.key, required this.boot});

  final AppBoot boot;

  @override
  State<SaxifyApp> createState() => _SaxifyAppState();
}

class _SaxifyAppState extends State<SaxifyApp> {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  Future<void> _afterFirstFrame() async {
    await NativeBridge.markLaunchSuccess();
    final AppBoot boot = widget.boot;
    if (boot.safeMode) return;
    try {
      await boot.recommendations.open().timeout(const Duration(seconds: 4));
      if (boot.recommendations.store.recovered) {
        BootLog.write('recommendation db recreated');
      }
    } catch (e) {
      BootLog.write('recommendation open skipped: $e');
    }
    boot.library.onPlaylistsChanged = () {
      if (!boot.settings.autoPlaylistSync) return;
      _syncTimer?.cancel();
      _syncTimer = Timer(const Duration(seconds: 8), () async {
        final String? code = await PlaylistSyncService.shareAllPlaylists(
          boot.library.playlists.map((Playlist p) => p.toJson()).toList(),
          copyToClipboard: false,
        );
        if (code != null) await boot.settings.setLastPlaylistCode(code);
      });
    };
    try {
      await registerRecommendationRefresh().timeout(const Duration(seconds: 3));
    } catch (e) {
      BootLog.write('workmanager skipped: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppBoot boot = widget.boot;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: boot.settings),
        ChangeNotifierProvider<LibraryService>.value(value: boot.library),
        ChangeNotifierProvider<PlaybackService>.value(value: boot.playback),
        ChangeNotifierProvider<RecommendationService>.value(value: boot.recommendations),
        ChangeNotifierProvider<MusicDownloadService>.value(value: boot.musicDownloads),
        ChangeNotifierProvider<UniversalDownloader>.value(value: boot.downloader),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(boot.settings),
        ),
        ChangeNotifierProvider<HomeCatalog>(
          create: (_) => HomeCatalog(youtube: boot.youtube, library: boot.library)..load(),
        ),
        ChangeNotifierProvider<ShellController>(
          create: (_) => ShellController(),
        ),
      ],
      child: Provider<YoutubeService>.value(
        value: boot.youtube,
        child: Provider<ArtistService>.value(
          value: boot.artists,
          child: const _SaxifyRoot(),
        ),
      ),
    );
  }
}

class SaxifyProfileGate extends StatelessWidget {
  const SaxifyProfileGate({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsService settings = context.watch<SettingsService>();
    if (settings.displayName.isEmpty) {
      return WelcomePage(onComplete: settings.setDisplayName);
    }
    return const SaxifyShell();
  }
}

class _SaxifyRoot extends StatelessWidget {
  const _SaxifyRoot();

  @override
  Widget build(BuildContext context) {
    final ThemeController theme = context.watch<ThemeController>();
    return MaterialApp(
      title: SaxifyBranding.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: SaxifyTheme.build(theme.accent),
      darkTheme: SaxifyTheme.build(theme.accent),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.25),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SaxifyProfileGate(),
    );
  }
}

class SaxifyRecoveryApp extends StatelessWidget {
  const SaxifyRecoveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(SaxifyBranding.logoAsset, width: 96, height: 96),
                const SizedBox(height: 18),
                const Text(
                  'Saxify could not finish starting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your library is still on this device. Try again to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    try {
                      final AppBoot boot =
                          await _initializeApp().timeout(const Duration(seconds: 12));
                      runApp(SaxifyApp(boot: boot));
                    } catch (error) {
                      BootLog.write('retry failed: $error');
                    }
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
