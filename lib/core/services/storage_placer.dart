import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/branding.dart';

/// Where a downloaded file ends up, decided per Android version (Part 8.1).
///
/// Shared by the music DownloadService (songs) and the Universal Downloader
/// (videos/audio) so both land in the same, version-correct place.
enum StoragePlacement {
  /// Android 11+ (API 30+): MediaStore.Downloads -> visible in the Files
  /// app under Download/Saxify. No runtime permission needed.
  mediaStore,

  /// Android 9 and below: classic /storage/emulated/0/Download/Saxify
  /// (WRITE_EXTERNAL_STORAGE, granted at install time on API <=28).
  publicDir,

  /// Android 10 (API 29) with legacy external storage.
  legacy,

  /// Non-Android platforms / last resort: app external files dir.
  appDir,
}

class StoragePlacer {
  StoragePlacer._();

  static final MediaStore _mediaStore = MediaStore();
  static int? _sdkInt;
  static bool _mediaStoreReady = false;

  /// The Android SDK int this device runs (0 when not Android / unknown).
  static Future<int> sdkInt() async {
    final int? cached = _sdkInt;
    if (cached != null) return cached;
    if (!Platform.isAndroid) {
      _sdkInt = 0;
      return 0;
    }
    try {
      await MediaStore.ensureInitialized();
      _mediaStoreReady = true;
      _sdkInt = await _mediaStore.getPlatformSDKInt();
    } catch (e) {
      debugPrint('StoragePlacer.sdkInt failed: $e');
      _sdkInt = 0;
    }
    return _sdkInt!;
  }

  /// Which strategy this device supports.
  static Future<StoragePlacement> placement() async {
    if (!Platform.isAndroid) return StoragePlacement.appDir;
    final int sdk = await sdkInt();
    if (!_mediaStoreReady) return StoragePlacement.appDir;
    if (sdk >= 30) return StoragePlacement.mediaStore;
    if (sdk == 29) return StoragePlacement.legacy;
    if (sdk > 0) return StoragePlacement.publicDir;
    return StoragePlacement.appDir;
  }

  /// Human label for Settings ("Download location/status").
  static Future<String> placementLabel() async {
    final StoragePlacement p = await StoragePlacer.placement();
    switch (p) {
      case StoragePlacement.mediaStore:
        return 'Download/${SaxifyBranding.downloadFolderName} '
            '(MediaStore, Android 11+)';
      case StoragePlacement.publicDir:
      case StoragePlacement.legacy:
        return '/Download/${SaxifyBranding.downloadFolderName} '
            '(shared storage)';
      case StoragePlacement.appDir:
        return 'App storage (Download/${SaxifyBranding.downloadFolderName})';
    }
  }

  /// Move a completed [temp] file into its final, version-aware location.
  /// Returns the final path (or content:// URI for MediaStore).
  static Future<String> placeFile(
    File temp,
    String name, {
    StoragePlacement? placementOverride,
  }) async {
    final StoragePlacement p =
        placementOverride ?? await StoragePlacer.placement();

    switch (p) {
      case StoragePlacement.mediaStore:
        try {
          final SaveInfo? info = await _mediaStore.saveFile(
            tempFilePath: temp.path,
            dirType: DirType.download,
            dirName: DirName.download,
            relativePath: SaxifyBranding.downloadFolderName,
          );
          if (info != null) {
            return info.uri.toString();
          }
        } catch (e) {
          debugPrint('MediaStore save failed ($e) — using app dir');
        }
        return _toAppDir(temp, name);

      case StoragePlacement.publicDir:
      case StoragePlacement.legacy:
        try {
          final Directory publicDir = Directory(
              '/storage/emulated/0/Download/${SaxifyBranding.downloadFolderName}');
          if (!await publicDir.exists()) {
            await publicDir.create(recursive: true);
          }
          final File target = File('${publicDir.path}/$name');
          if (await target.exists()) {
            await target.delete();
          }
          await temp.rename(target.path).catchError((Object _) async {
            await target.writeAsBytes(await temp.readAsBytes());
            return target;
          });
          return target.path;
        } catch (e) {
          debugPrint('public dir save failed ($e) — using app dir');
          return _toAppDir(temp, name);
        }

      case StoragePlacement.appDir:
        return _toAppDir(temp, name);
    }
  }

  static Future<String> _toAppDir(File temp, String name) async {
    Directory? dir;
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();
    final Directory targetDir =
        Directory('${dir.path}/Download/${SaxifyBranding.downloadFolderName}');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final File target = File('${targetDir.path}/$name');
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(target.path).catchError((Object _) async {
      await target.writeAsBytes(await temp.readAsBytes());
      return target;
    });
    return target.path;
  }

  /// Does a recorded file still exist? (verify-before-show, Part 8.2)
  static Future<bool> fileExists(String pathOrUri,
      {StoragePlacement? placement}) async {
    try {
      final StoragePlacement defaultPlacement = await StoragePlacer.placement();
      final StoragePlacement p = placement ??
          (pathOrUri.startsWith('content://')
              ? StoragePlacement.mediaStore
              : defaultPlacement);
      if (p == StoragePlacement.mediaStore && pathOrUri.startsWith('content://')) {
        return await _mediaStore.isFileUriExist(uriString: pathOrUri);
      }
      return await File(pathOrUri).exists();
    } catch (e) {
      debugPrint('fileExists check failed: $e');
      return false;
    }
  }

  /// Resolve a content:// URI to a real path when possible (opening files).
  static Future<String?> resolvePath(String pathOrUri) async {
    if (!pathOrUri.startsWith('content://')) return pathOrUri;
    try {
      return await _mediaStore.getFilePathFromUri(uriString: pathOrUri);
    } catch (e) {
      debugPrint('resolvePath failed: $e');
      return null;
    }
  }

  /// Delete a recorded file (Part 8.2 / 11.5).
  static Future<bool> deleteFile(String pathOrUri,
      {StoragePlacement? placement}) async {
    try {
      final StoragePlacement p =
          placement ?? await StoragePlacer.placement();
      if (p == StoragePlacement.mediaStore && pathOrUri.startsWith('content://')) {
        return await _mediaStore.deleteFileUsingUri(uriString: pathOrUri);
      }
      final File f = File(pathOrUri);
      if (await f.exists()) await f.delete();
      return true;
    } catch (e) {
      debugPrint('deleteFile failed: $e');
      return false;
    }
  }
}
