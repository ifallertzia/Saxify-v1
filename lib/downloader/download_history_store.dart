import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'downloader_models.dart';

/// Local-only download history. Cloud backup is opt-in and not wired here.
class DownloadHistoryStore {
  DownloadHistoryStore(this._prefs);

  final SharedPreferences _prefs;
  static const String _key = 'saxify.downloader.history';

  List<DownloadRecord> read() {
    final String? raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <DownloadRecord>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <DownloadRecord>[];
      return decoded
          .whereType<Map>()
          .map((Map item) => DownloadRecord.fromJson(item.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return <DownloadRecord>[];
    }
  }

  Future<void> write(List<DownloadRecord> items, {int max = 120}) async {
    final List<DownloadRecord> clipped =
        items.length > max ? items.sublist(0, max) : items;
    await _prefs.setString(
      _key,
      jsonEncode(clipped.map((DownloadRecord r) => r.toJson()).toList()),
    );
  }
}
