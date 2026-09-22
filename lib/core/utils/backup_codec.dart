import 'dart:convert';

/// Returns an error message, or null when the blob is a usable library backup.
String? validateBackupJson(String raw) {
  if (raw.trim().isEmpty) return 'Paste a backup first.';
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return 'That is not a Saxify backup. Expected a JSON object.';
    const List<String> keys = <String>['liked', 'songs', 'playlists', 'history', 'artists'];
    final bool any = keys.any(decoded.containsKey);
    if (!any) {
      return 'Missing library data. Need liked, songs, playlists, history, or artists.';
    }
    return null;
  } catch (_) {
    return 'Invalid JSON. Check the paste and try again.';
  }
}
