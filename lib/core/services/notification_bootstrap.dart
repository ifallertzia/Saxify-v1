import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';

/// Lock-screen / Bluetooth controls via audio_service (through just_audio_background).
///
/// Init is optional. If it fails, the existing [AudioPlayer] path still works.
class NotificationBootstrap {
  NotificationBootstrap._();

  static bool active = false;
  static bool _asked = false;

  static Future<bool> init() async {
    if (active) return true;
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.saxify.app.audio',
        androidNotificationChannelName: 'Saxify playback',
        androidNotificationChannelDescription: 'Play, pause, skip and seek',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
        preloadArtwork: true,
      ).timeout(const Duration(seconds: 6));
      active = true;
      return true;
    } catch (e) {
      debugPrint('[Saxify][Notify] init skipped: $e');
      active = false;
      return false;
    }
  }

  /// Android 13+. Denied permission still leaves in-app playback working.
  static Future<void> requestOnFirstPlay() async {
    if (_asked || kIsWeb || !Platform.isAndroid) return;
    _asked = true;
    try {
      final PermissionStatus status = await Permission.notification.status;
      if (status.isGranted || status.isLimited) return;
      await Permission.notification.request();
    } catch (e) {
      debugPrint('[Saxify][Notify] permission: $e');
    }
  }
}
