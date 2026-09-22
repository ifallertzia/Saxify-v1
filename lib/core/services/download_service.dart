import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../config/branding.dart';
import '../models/song.dart';
import 'playback_service.dart';
import 'storage_placer.dart';

/// A song saved to the device (the music Downloads list, Part 8.2).
class DownloadedSong {
  const DownloadedSong({
    required this.songId,
    required this.title,
    required this.artist,
    required this.path,
    required this.placement,
    required this.sizeBytes,
    required this.savedAt,
  });

  final String songId;
  final String title;
  final String artist;

  /// Filesystem path (public/app dir) or MediaStore content URI.
  final String path;
  final StoragePlacement placement;
  final int sizeBytes;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'song_id': songId,
        'title': title,
        'artist': artist,
        'path': path,
        'placement': placement.name,
        'size': sizeBytes,
        'at': savedAt.toIso8601String(),
      };

  factory DownloadedSong.fromJson(Map<String, dynamic> json) => DownloadedSong(
        songId: json['song_id'] as String? ?? '',
        title: json['title'] as String? ?? 'Song',
        artist: json['artist'] as String? ?? '',
        path: json['path'] as String? ?? '',
        placement: StoragePlacement.values.firstWhere(
          (StoragePlacement p) => p.name == json['placement'],
          orElse: () => StoragePlacement.appDir,
        ),
        sizeBytes: json['size'] is int ? json['size'] as int : 0,
        savedAt:
            DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Song downloads (Part 8).
///
/// Resolution: **reuses the existing playback engine** —
/// [PlaybackService.resolvePlayableStreamUrl] is the exact same
/// multi-client HEAD-probed resolver the player uses, so a song can be
/// downloaded if and only if it can be played. The download itself is a
/// plain streamed GET into a temp file — it never touches the player, the
/// queue, the audio session or the notification (Rule 6: downloads never
/// interfere with playback).
///
/// Storage (version-aware) lives in [StoragePlacer] and is shared with the
/// Universal Downloader.
class DownloadService {
  DownloadService({required this.playback, http.Client? client})
      : _client = client ?? http.Client();

  final PlaybackService playback;
  final http.Client _client;

  static const String kSongDownloads = 'saxify.song_downloads';
  static const String kPermissionPrompted = 'saxify.storage_permission_prompted';

  // ------------------------------------------------------------ permissions
  /// The Part-8.3 dialog flow. Returns `true` when downloads are allowed,
  /// `false` when the user said "Not now" (or the OS denied).
  ///
  /// On Android 11+ (MediaStore) and on the app-dir fallback, no permission
  /// is required at all — this resolves immediately.
  Future<bool> ensureStoragePermission({
    required Future<bool> Function() showPermissionDialog,
  }) async {
    final StoragePlacement p = await StoragePlacer.placement();
    if (p == StoragePlacement.mediaStore || p == StoragePlacement.appDir) {
      return true;
    }
    try {
      // permission_handler maps this per Android version:
      // storage -> WRITE_EXTERNAL_STORAGE (<=28); API 29 needs nothing
      // because the manifest enables legacy external storage.
      final PermissionStatus status = await Permission.storage.status;
      if (status.isGranted || status.isLimited) return true;
      if (await showPermissionDialog()) {
        final PermissionStatus requested = await Permission.storage.request();
        return requested.isGranted || requested.isLimited;
      }
      return false;
    } catch (e) {
      debugPrint('storage permission flow failed: $e');
      return false;
    }
  }

  Future<void> markPermissionPrompted() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPermissionPrompted, true);
    } catch (_) {}
  }

  Future<bool> wasPermissionPrompted() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kPermissionPrompted) ?? false;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------- download
  /// Download [song] to the device. [onProgress] gets (receivedBytes,
  /// totalBytes?). Never throws for user-facing reasons — the outcome is
  /// returned so the UI can show a clear success/error + retry.
  Future<DownloadOutcome> downloadSong(
    Song song, {
    void Function(int received, int? total)? onProgress,
  }) async {
    try {
      // 1) Resolve via the EXISTING playback engine (the same URL the
      //    player would stream — no second resolution system).
      final String url =
          await playback.resolvePlayableStreamUrl(VideoId(song.id));

      // 2) Stream to a temp file (app data) with progress.
      final Directory tempDir = await getTemporaryDirectory();
      final String safe = safeFileName(song.title);
      final String finalName = '$safe${SaxifyBranding.fileSuffix}.mp3';
      final File temp = File('${tempDir.path}/.saxify_$finalName');

      final http.Request request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 14) Saxify/2.0';
      final http.StreamedResponse response =
          await _client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return DownloadOutcome.error(
            'Download failed: server said HTTP ${response.statusCode}. '
            'The stream may have expired — try again.');
      }

      final int total = response.contentLength ?? 0;
      int received = 0;
      final IOSink sink = temp.openWrite();
      await for (final List<int> chunk in response.stream) {
        received += chunk.length;
        onProgress?.call(received, total > 0 ? total : null);
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      // 3) Empty/corrupt verification.
      final int size = await temp.length();
      if (size < 1024) {
        try { await temp.delete(); } catch (_) {}
        return DownloadOutcome.error(
            'The download came back empty — this can happen with '
            'age-restricted or broken streams. Try another version of the '
            'song.');
      }

      // 4) Move to the version-aware final location (Download/Saxify).
      final StoragePlacement p = await StoragePlacer.placement();
      final String finalLocation =
          await StoragePlacer.placeFile(temp, finalName, placementOverride: p);

      // 5) Record it.
      final DownloadedSong record = DownloadedSong(
        songId: song.id,
        title: song.title,
        artist: song.artist,
        path: finalLocation,
        placement: p,
        sizeBytes: size,
        savedAt: DateTime.now(),
      );
      await _record(record);

      return DownloadOutcome.success(record);
    } on TimeoutException {
      return DownloadOutcome.error(
          'Download timed out. Check your connection and retry.');
    } catch (e) {
      debugPrint('downloadSong failed: $e');
      return DownloadOutcome.error('Download failed: $e');
    }
  }

  // ---------------------------------------------------------------- records
  Future<List<DownloadedSong>> savedSongs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(kSongDownloads);
      if (raw == null || raw.isEmpty) return <DownloadedSong>[];
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <DownloadedSong>[];
      final List<DownloadedSong> out = <DownloadedSong>[];
      for (final dynamic item in decoded) {
        if (item is Map) {
          out.add(DownloadedSong.fromJson(item.cast<String, dynamic>()));
        }
      }
      return out;
    } catch (e) {
      debugPrint('savedSongs read failed: $e');
      return <DownloadedSong>[];
    }
  }

  Future<void> _record(DownloadedSong record) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<DownloadedSong> all = await savedSongs();
      all.removeWhere((DownloadedSong s) => s.songId == record.songId);
      all.insert(0, record);
      if (all.length > 200) {
        all.removeRange(200, all.length);
      }
      await prefs.setString(
          kSongDownloads,
          jsonEncode(all.map((DownloadedSong s) => s.toJson()).toList()));
    } catch (e) {
      debugPrint('song download record failed: $e');
    }
  }

  /// Verify-before-show (Part 8.2): files that vanished from the device are
  /// dropped from the list by the UI.
  Future<bool> fileExists(DownloadedSong song) =>
      StoragePlacer.fileExists(song.path, placement: song.placement);

  /// Delete from device (Part 8.2) — the confirm dialog lives in the UI.
  Future<bool> deleteSong(DownloadedSong song) =>
      StoragePlacer.deleteFile(song.path, placement: song.placement);

  Future<void> removeRecord(String songId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<DownloadedSong> all = await savedSongs();
      all.removeWhere((DownloadedSong s) => s.songId == songId);
      await prefs.setString(
          kSongDownloads,
          jsonEncode(all.map((DownloadedSong s) => s.toJson()).toList()));
    } catch (_) {}
  }

  /// `{title}_saxify` with filesystem-hostile characters removed.
  static String safeFileName(String title) {
    final String s = title
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s.isEmpty ? 'song' : (s.length > 80 ? s.substring(0, 80) : s);
  }

  void dispose() => _client.close();
}

/// Outcome of a download attempt — the UI shows the right SnackBar/error.
class DownloadOutcome {
  const DownloadOutcome.success(this.song) : error = null;
  const DownloadOutcome.error(this.error) : song = null;

  final DownloadedSong? song;
  final String? error;

  bool get isSuccess => song != null;
}
