import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Freeze-proof boot guard (Part 2).
///
/// Reported bug: app froze on the logo, forced a reinstall, and data was
/// lost. This service attacks every root cause listed in the brief:
///
///  1. blocking await before runApp   -> every init phase is bounded (5 s)
///  2. unhandled exception in splash  -> global handlers in main() + zone
///  3. corrupt local storage          -> every read is wrapped; a corrupt
///                                        blob degrades to an empty state,
///                                        never a crash
///  4. backend timeout, no fallback   -> timeouts + safe-mode fallback
///  5. deprecated plugin init throwing-> each plugin init is isolated in a
///                                        try/catch with its own timeout
///
/// Three-strikes safe mode:
///  * a Dart watchdog armed in main() fires when the first frame is not
///    painted within [watchdogSeconds] (covers "hang before runApp");
///  * the native crash guard (Kotlin, MethodChannel 'saxify/crash_guard')
///    counts uncaught native crashes;
///  * three consecutive failed launches -> next boot starts in SAFE MODE:
///    no network, no catalog loads, no update checks — just a working UI
///    with a banner and a "Reset" button that clears the strikes.
class BootGuard {
  BootGuard._();

  static const String kStartupStrikes = 'saxify.startup_strikes';

  /// The Kotlin crash counter writes this file (context.filesDir).
  /// path_provider's applicationDocumentsDirectory is the same directory on
  /// Android, so no MethodChannel is needed — and nothing that can break
  /// when the Flutter embedding API moves.
  static const String kNativeCrashFile = 'saxify_crash_count';

  /// Hard budget for the whole init phase.
  static const Duration initBudget = Duration(seconds: 5);

  /// Seconds before the "first frame" watchdog declares a failed launch.
  static const int watchdogSeconds = 8;

  static const int strikeLimit = 3;

  /// File where all boot errors are appended (crash-safe, tiny lines).
  static final List<String> _bootLog = <String>[];

  /// Called from main() before runApp. Never throws.
  static Future<BootResult> boot({
    required Future<void> Function() initialize,
  }) async {
    final Stopwatch watch = Stopwatch()..start();

    // Count previous failed launches BEFORE any heavy work so a fresh
    // install / clean state is cheap.
    final int strikes = await _readStrikes();
    final int nativeCrashes = await nativeCrashCount();

    // Arm the watchdog: if the first frame is not painted in time (we cancel
    // it from the app root once the UI is up), count this launch as failed.
    Timer? watchdog;
    watchdog = Timer(Duration(seconds: watchdogSeconds), () {
      _log('watchdog fired: first frame not painted in ${watchdogSeconds}s');
      _recordStrike();
    });
    _armedWatchdog = watchdog;

    try {
      // ---- bounded initialization ---------------------------------------
      // Future.any gives [initialize] the whole budget; the delay alone
      // completing means init was too slow -> safe mode, but the UI still
      // boots (no black screen, ever).
      final bool finishedOnTime = await Future.any(<Future<bool>>[
        initialize().then((void _) => true).catchError((Object e, StackTrace s) {
          _log('init error: $e\n$s');
          return false;
        }),
        Future<bool>.delayed(initBudget).then((void _) => false),
      ]);

      final bool safeMode =
          !finishedOnTime || strikes >= strikeLimit || nativeCrashes >= strikeLimit;

      // Clear strikes when we actually managed to boot with services on.
      if (finishedOnTime && !safeMode && (strikes > 0 || nativeCrashes > 0)) {
        await resetStrikes();
      }
      if (!finishedOnTime) {
        await _recordStrike();
      }

      _log('boot done in ${watch.elapsedMilliseconds}ms safeMode=$safeMode '
          'dartStrikes=$strikes nativeCrashes=$nativeCrashes');
      return BootResult(
        safeMode: safeMode,
        reason: safeMode
            ? (strikes >= strikeLimit || nativeCrashes >= strikeLimit
                ? 'safe mode: $strikeLimit consecutive failed launches'
                : 'init timed out (${initBudget.inSeconds}s budget)')
            : null,
        elapsed: watch.elapsed,
        nativeCrashCount: nativeCrashes,
      );
    } catch (e, s) {
      _log('boot crashed: $e\n$s');
      await _recordStrike();
      return BootResult(
        safeMode: true,
        reason: 'boot error: $e',
        elapsed: watch.elapsed,
      );
    }
  }

  static Timer? _armedWatchdog;

  /// Call from the app root's first frame. Cancels the watchdog.
  static void markFirstFrame() {
    _armedWatchdog?.cancel();
    _armedWatchdog = null;
  }

  // ------------------------------------------------------------- strikes
  /// The current Dart-side slow-start strike count (Settings diagnostics).
  static Future<int> currentStrikes() => _readStrikes();

  static Future<int> _readStrikes() async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      return prefs.getInt(kStartupStrikes) ?? 0;
    } catch (e) {
      _log('could not read strikes: $e');
      return 0;
    }
  }

  static Future<void> _writeStrikes(int value) async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      if (value <= 0) {
        await prefs.remove(kStartupStrikes);
      } else {
        await prefs.setInt(kStartupStrikes, value);
      }
    } catch (e) {
      _log('could not write strikes: $e');
    }
  }

  static Future<void> _recordStrike() async {
    final int current = await _readStrikes();
    await _writeStrikes(current + 1);
  }

  /// "Reset" button in the safe-mode banner: clears Dart + native strikes.
  static Future<void> resetStrikes() async {
    await _writeStrikes(0);
    await _deleteNativeCrashFile();
  }

  /// Native uncaught-crash count (incremented by the Kotlin crash handler).
  static Future<int> nativeCrashCount() async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 2));
      final File f = File('${dir.path}/$kNativeCrashFile');
      if (!await f.exists()) return 0;
      final String raw = await f.readAsString().timeout(const Duration(seconds: 2));
      return int.tryParse(raw.trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _deleteNativeCrashFile() async {
    try {
      final Directory dir =
          await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 2));
      final File f = File('${dir.path}/$kNativeCrashFile');
      if (await f.exists()) await f.delete();
    } catch (_) {/* best effort */}
  }

  // ----------------------------------------------------------------- logs
  static List<String> get bootLog => List<String>.unmodifiable(_bootLog);

  /// Public logging entry point (used by main()'s global handlers).
  static void log(String message) => _log(message);

  static void _log(String message) {
    final String line = '[${DateTime.now().toIso8601String()}] $message';
    _bootLog.add(line);
    if (_bootLog.length > 200) {
      _bootLog.removeRange(0, _bootLog.length - 200);
    }
    debugPrint('[Saxify][Boot] $message');
    _persistLog(line); // fire & forget
  }

  static Future<void> _persistLog(String line) async {
    try {
      final Directory dir = await getApplicationSupportDirectory()
          .timeout(const Duration(seconds: 2));
      final File file = File('${dir.path}/saxify_boot.log');
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString('$line\n', mode: FileMode.append);
      // Keep the log under ~64 KB.
      if (await file.length() > 65536) {
        final String all = await file.readAsString();
        await file.writeAsString(all.substring(all.length - 32768));
      }
    } catch (_) {/* logging must never throw */}
  }
}

/// Result of a guarded boot.
class BootResult {
  const BootResult({
    required this.safeMode,
    this.reason,
    required this.elapsed,
    this.nativeCrashCount = 0,
  });

  final bool safeMode;
  final String? reason;
  final Duration elapsed;
  final int nativeCrashCount;
}
