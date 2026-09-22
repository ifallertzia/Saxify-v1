import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import 'library_service.dart';
import 'playlist_sync_service.dart';

/// Part 3.2 — cloud auto-sync of playlists.
///
/// Once the user has successfully shared at least one backup (a code is
/// stored), every *playlist* change re-uploads the full playlist set in the
/// background — fire-and-forget, 20 s timeout, no error UI. The cloud is a
/// safety net; a failed upload must never surface a failure to the user.
///
/// Likes/history/artist changes do NOT trigger an upload (only playlists,
/// per the brief: "auto cloud sync of playlists on every playlist change").
class PlaylistAutoSync {
  PlaylistAutoSync({required LibraryService library, http.Client? client})
      : _library = library,
        _client = client ?? http.Client() {
    _library.addListener(_onLibraryChanged);
    _lastSignature = _signature();
  }

  final LibraryService _library;
  final http.Client _client;

  static const String kLastBackupCode = 'saxify.last_backup_code';

  Timer? _debounce;
  String? _lastSignature;
  bool _uploading = false;

  /// Remember a successful share code (called from the share UI).
  static Future<void> rememberCode(String? code) async {
    if (code == null || code.isEmpty) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLastBackupCode, code);
    } catch (e) {
      debugPrint('[AutoSync] rememberCode failed: $e');
    }
  }

  static Future<String?> lastCode() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(kLastBackupCode);
    } catch (_) {
      return null;
    }
  }

  void _onLibraryChanged() {
    final String signature = _signature();
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    // Debounce — a rename+shuffle burst should upload once.
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), _maybeUpload);
  }

  /// Fingerprint of the playlist set (names + ids + song ids + counts).
  String _signature() {
    final List<Playlist> playlists = _library.playlists;
    final StringBuffer sb = StringBuffer();
    for (final Playlist p in playlists) {
      sb
        ..write(p.id)
        ..write('|')
        ..write(p.name)
        ..write('|')
        ..write(p.count);
      for (final Song s in p.songs) {
        sb
          ..write(';')
          ..write(s.id);
      }
    }
    return sb.toString();
  }

  Future<void> _maybeUpload() async {
    if (_uploading) return;
    final String? code = await lastCode();
    if (code == null || code.isEmpty) return; // never auto-synced before
    _uploading = true;
    try {
      final List<Map<String, dynamic>> payload = _library.playlists
          .map((Playlist p) => p.toJson())
          .toList();
      // Fire-and-forget with a hard 20 s ceiling — the brief is explicit
      // that a failed auto-sync shows nothing.
      await PlaylistSyncService.shareAllPlaylists(payload, client: _client);
    } catch (e) {
      debugPrint('[AutoSync] upload failed (silent by design): $e');
    } finally {
      _uploading = false;
    }
  }

  void dispose() {
    _debounce?.cancel();
    _library.removeListener(_onLibraryChanged);
    _client.close();
  }
}

/// Re-exports the backup-shape helper the Settings/Library UIs use to wrap
/// a playlist-only payload for [LibraryService.importBackup].
String playlistsOnlyBackupJson(List<Map<String, dynamic>> playlists) =>
    jsonEncode(<String, dynamic>{
      'app': 'saxify',
      'version': 1,
      'playlists': playlists,
    });
