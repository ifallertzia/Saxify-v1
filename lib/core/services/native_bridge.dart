import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android bridge for boot safety, scoped Downloads, and the system equalizer.
///
/// iOS / desktop calls no-op. The music player itself is not touched here.
class NativeBridge {
  NativeBridge._();

  static const MethodChannel _channel = MethodChannel('com.saxify.app/bridge');

  static Future<BootSnapshot> bootState() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const BootSnapshot(safeMode: false, fails: 0, sdk: 0);
    }
    try {
      final Object? raw = await _channel
          .invokeMethod<Object>('bootState')
          .timeout(const Duration(seconds: 1));
      if (raw is Map) {
        return BootSnapshot(
          safeMode: raw['safeMode'] == true,
          fails: raw['fails'] is int ? raw['fails'] as int : 0,
          sdk: raw['sdk'] is int ? raw['sdk'] as int : 0,
        );
      }
    } catch (e) {
      debugPrint('[Saxify][Boot] native bootState failed: $e');
    }
    return const BootSnapshot(safeMode: false, fails: 0, sdk: 0);
  }

  static Future<void> markLaunchSuccess() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel
          .invokeMethod<void>('markLaunchSuccess')
          .timeout(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('[Saxify][Boot] markLaunchSuccess failed: $e');
    }
  }

  /// Used for Wi-Fi vs mobile stream quality; only called when resolving.
  static Future<bool> isOnWifi() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isOnWifi') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// A CPU partial wake lock held ONLY while audio is playing. The existing
  /// media-playback foreground service supplies the ongoing notification.
  static Future<void> setPlaybackWakeLock(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setPlaybackWakeLock', <String, bool>{'enabled': enabled});
    } catch (error) {
      debugPrint('Audio wake lock: $error');
    }
  }

  static Future<int> sdkInt() async {
    final BootSnapshot snap = await bootState();
    return snap.sdk;
  }

  static Future<SavedFile?> saveToDownloads({
    required String sourcePath,
    required String displayName,
    required String mime,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final Object? raw = await _channel.invokeMethod<Object>('saveToDownloads', <String, Object>{
      'sourcePath': sourcePath,
      'displayName': displayName,
      'mime': mime,
    });
    if (raw is! Map) return null;
    return SavedFile.fromMap(raw.cast<Object?, Object?>());
  }

  static Future<bool> deleteDownload({String? uri, String? path}) async {
    if (kIsWeb || !Platform.isAndroid) {
      if (path == null) return false;
      final File file = File(path);
      if (file.existsSync()) {
        await file.delete();
        return true;
      }
      return false;
    }
    final Object? raw = await _channel.invokeMethod<Object>('deleteDownload', <String, Object?>{
      'uri': uri,
      'path': path,
    });
    return raw == true;
  }

  static Future<List<SavedFile>> listDownloads() async {
    if (kIsWeb || !Platform.isAndroid) return <SavedFile>[];
    try {
      final Object? raw = await _channel.invokeMethod<Object>('listDownloads');
      if (raw is! List) return <SavedFile>[];
      return raw
          .whereType<Map>()
          .map((Map item) => SavedFile.fromMap(item.cast<Object?, Object?>()))
          .toList();
    } catch (e) {
      debugPrint('[Saxify][Storage] listDownloads failed: $e');
      return <SavedFile>[];
    }
  }

  static Future<void> shareFile({
    required String path,
    required String mime,
    String title = 'Share',
    String? uri,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod<void>('shareFile', <String, Object?>{
      'path': path,
      'mime': mime,
      'title': title,
      'uri': uri,
    });
  }

  static Future<bool> openSupportEmail({
    required String to, required String subject, required String body,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openSupportEmail', <String, String>{
        'to': to, 'subject': subject, 'body': body,
      }) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openContent(String uri, String mime) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openContent', <String, Object>{
      'uri': uri,
      'mime': mime,
    });
  }

  static Future<EqualizerInfo?> eqInit(int sessionId) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final Object? raw = await _channel.invokeMethod<Object>('eqInit', <String, Object>{
        'sessionId': sessionId,
      });
      if (raw is! Map) return null;
      return EqualizerInfo.fromMap(raw.cast<Object?, Object?>());
    } catch (e) {
      debugPrint('[Saxify][EQ] init failed: $e');
      return null;
    }
  }

  static Future<void> eqSetEnabled(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod<void>('eqSetEnabled', <String, Object>{'enabled': enabled});
  }

  static Future<void> eqSetBand(int band, int level) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _channel.invokeMethod<void>('eqSetBand', <String, Object>{
      'band': band,
      'level': level,
    });
  }

  static Future<bool> eqUsePreset(String name) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final Object? raw = await _channel.invokeMethod<Object>('eqUsePreset', <String, Object>{
      'name': name,
    });
    return raw == true;
  }

  static Future<void> eqRelease() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('eqRelease');
    } catch (_) {}
  }
}

class BootSnapshot {
  const BootSnapshot({required this.safeMode, required this.fails, required this.sdk});

  final bool safeMode;
  final int fails;
  final int sdk;
}

class SavedFile {
  const SavedFile({
    required this.displayName,
    this.uri,
    this.path,
    this.size = 0,
    this.modifiedMs = 0,
  });

  final String displayName;
  final String? uri;
  final String? path;
  final int size;
  final int modifiedMs;

  factory SavedFile.fromMap(Map<Object?, Object?> raw) {
    return SavedFile(
      displayName: raw['displayName'] as String? ?? 'file',
      uri: raw['uri'] as String?,
      path: raw['path'] as String?,
      size: raw['size'] is int ? raw['size'] as int : 0,
      modifiedMs: raw['modifiedMs'] is int ? raw['modifiedMs'] as int : 0,
    );
  }
}

class EqualizerInfo {
  const EqualizerInfo({
    required this.bands,
    required this.enabled,
    required this.minLevel,
    required this.maxLevel,
    required this.centersMilliHz,
    required this.levels,
    required this.presets,
  });

  final int bands;
  final bool enabled;
  final int minLevel;
  final int maxLevel;
  final List<int> centersMilliHz;
  final List<int> levels;
  final List<String> presets;

  bool get supported => bands > 0;

  factory EqualizerInfo.fromMap(Map<Object?, Object?> raw) {
    return EqualizerInfo(
      bands: raw['bands'] is int ? raw['bands'] as int : 0,
      enabled: raw['enabled'] == true,
      minLevel: raw['min'] is int ? raw['min'] as int : -1500,
      maxLevel: raw['max'] is int ? raw['max'] as int : 1500,
      centersMilliHz: _ints(raw['centersMilliHz']),
      levels: _ints(raw['levels']),
      presets: (raw['presets'] as List<Object?>? ?? <Object?>[])
          .map((Object? e) => e.toString())
          .toList(),
    );
  }

  static List<int> _ints(Object? raw) {
    if (raw is! List) return <int>[];
    return raw.map((Object? e) => e is int ? e : int.tryParse('$e') ?? 0).toList();
  }
}
