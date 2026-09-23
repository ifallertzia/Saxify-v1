import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local signals for the recommendation engine.
///
/// On open failure the file is deleted and recreated. Callers should surface
/// [recovered] — playlists themselves live in preferences, not this database.
class RecommendationStore {
  Database? _db;
  bool recovered = false;
  bool get ready => _db != null;

  Future<void> open() async {
    if (_db != null) return;
    final String dir = (await getApplicationDocumentsDirectory()).path;
    final String path = '$dir/saxify_reco.db';
    try {
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: _create,
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[IfallMusic][Reco] open failed, recreating: $e');
      try {
        await deleteDatabase(path);
        _db = await openDatabase(path, version: 1, onCreate: _create)
            .timeout(const Duration(seconds: 3));
        recovered = true;
      } catch (e2) {
        debugPrint('[IfallMusic][Reco] recreate failed: $e2');
      }
    }
    await _purgeOldSearches();
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE play_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id TEXT NOT NULL,
        title TEXT,
        artist TEXT,
        genre TEXT,
        bpm INTEGER,
        mood_tags TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE skip_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id TEXT NOT NULL,
        skipped_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE like_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE reco_cache (
        id INTEGER PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> recordPlay({
    required String songId,
    required String title,
    required String artist,
    String? genre,
    int? bpm,
    List<String> moods = const <String>[],
  }) async {
    final Database? db = _db;
    if (db == null) return;
    await db.insert('play_history', <String, Object?>{
      'song_id': songId,
      'title': title,
      'artist': artist,
      'genre': genre,
      'bpm': bpm,
      'mood_tags': moods.join(','),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> recordSearch(String query) async {
    final Database? db = _db;
    if (db == null) return;
    final String q = query.trim();
    if (q.isEmpty) return;
    await db.insert('search_history', <String, Object?>{
      'query': q,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> recordSkip(String songId) async {
    final Database? db = _db;
    if (db == null) return;
    await db.insert('skip_events', <String, Object?>{
      'song_id': songId,
      'skipped_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> recordLike(String songId) async {
    final Database? db = _db;
    if (db == null) return;
    await db.insert('like_events', <String, Object?>{
      'song_id': songId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<String>> recentPlayedIds({int limit = 10}) async {
    final Database? db = _db;
    if (db == null) return <String>[];
    final List<Map<String, Object?>> rows = await db.query(
      'play_history',
      columns: <String>['song_id'],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map((Map<String, Object?> r) => r['song_id'] as String? ?? '').where((String id) => id.isNotEmpty).toList();
  }

  Future<Map<String, Object?>?> latestPlay() async {
    final Database? db = _db;
    if (db == null) return null;
    final List<Map<String, Object?>> rows = await db.query(
      'play_history',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Queries typed at least twice in the last 3 days, newest first.
  Future<List<String>> repeatedQueries({int withinDays = 3}) async {
    final Database? db = _db;
    if (db == null) return <String>[];
    final int since = DateTime.now()
        .subtract(Duration(days: withinDays))
        .millisecondsSinceEpoch;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT query, COUNT(*) AS n, MAX(timestamp) AS latest
      FROM search_history
      WHERE timestamp >= ?
      GROUP BY LOWER(query)
      HAVING n >= 2
      ORDER BY latest DESC
      LIMIT 8
      ''',
      <Object>[since],
    );
    return rows.map((Map<String, Object?> r) => r['query'] as String? ?? '').where((String q) => q.isNotEmpty).toList();
  }

  Future<Set<String>> skippedIds({int limit = 40}) async {
    final Database? db = _db;
    if (db == null) return <String>{};
    final List<Map<String, Object?>> rows = await db.query(
      'skip_events',
      columns: <String>['song_id'],
      orderBy: 'skipped_at DESC',
      limit: limit,
    );
    return rows.map((Map<String, Object?> r) => r['song_id'] as String? ?? '').where((String id) => id.isNotEmpty).toSet();
  }

  Future<Set<String>> likedIds() async {
    final Database? db = _db;
    if (db == null) return <String>{};
    final List<Map<String, Object?>> rows = await db.query(
      'like_events',
      columns: <String>['song_id'],
      orderBy: 'timestamp DESC',
      limit: 80,
    );
    return rows.map((Map<String, Object?> r) => r['song_id'] as String? ?? '').toSet();
  }

  Future<void> saveCache(String payload) async {
    final Database? db = _db;
    if (db == null) return;
    await db.insert(
      'reco_cache',
      <String, Object?>{
        'id': 1,
        'payload': payload,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> readCache() async {
    final Database? db = _db;
    if (db == null) return null;
    final List<Map<String, Object?>> rows =
        await db.query('reco_cache', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['payload'] as String?;
  }

  /// Re-rank is local: touch the cache timestamp so a background tick is real
  /// work even when the network is unavailable.
  Future<bool> touchCache() async {
    final Database? db = _db;
    if (db == null) return false;
    final int n = await db.update(
      'reco_cache',
      <String, Object?>{'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = 1',
    );
    return n > 0;
  }

  Future<void> _purgeOldSearches() async {
    final Database? db = _db;
    if (db == null) return;
    final int cutoff = DateTime.now()
        .subtract(const Duration(days: 90))
        .millisecondsSinceEpoch;
    try {
      await db.delete('search_history', where: 'timestamp < ?', whereArgs: <Object>[cutoff]);
    } catch (e) {
      debugPrint('[IfallMusic][Reco] purge failed: $e');
    }
  }
}
