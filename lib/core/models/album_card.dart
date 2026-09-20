import 'dart:convert';

/// The web app exposes "albums" as `/album/ytq-<base64 JSON>` where the JSON is
/// `{"q": <search query>, "t": <title>, "a": <artist>}`. An album card is really
/// just an encoded YouTube search — the mobile app uses the exact same scheme so
/// links, deep-links and shared state stay interchangeable.
class AlbumCard {
  const AlbumCard({
    required this.query,
    required this.title,
    required this.artist,
    this.coverVideoId,
  });

  final String query;
  final String title;
  final String artist;

  /// YouTube video whose thumbnail is used as the sleeve when known.
  final String? coverVideoId;

  String get encodedId => encode(query: query, title: title, artist: artist);

  String get coverUrl => coverVideoId == null
      ? ''
      : 'https://i.ytimg.com/vi/$coverVideoId/hqdefault.jpg';

  static String encode({
    required String query,
    required String title,
    required String artist,
  }) {
    final String payload = jsonEncode(<String, String>{
      'q': query,
      't': title,
      'a': artist,
    });
    final String b64 = base64.encode(utf8.encode(payload));
    return 'ytq-${b64.replaceAll('=', '')}';
  }

  /// Accepts both `ytq-<b64>` and a bare base64 payload. Returns null when the
  /// payload is not a Sidify album id.
  static AlbumCard? decode(String raw) {
    String payload = raw.trim();
    if (payload.startsWith('ytq-')) payload = payload.substring(4);
    if (payload.isEmpty) return null;

    // Standard base64 without padding — restore it before decoding.
    final int pad = (4 - payload.length % 4) % 4;
    payload = '$payload${'=' * pad}';

    try {
      final Map<String, dynamic> json =
          jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final Object? q = json['q'];
      if (q is! String || q.isEmpty) return null;
      return AlbumCard(
        query: q,
        title: json['t'] is String ? json['t'] as String : q,
        artist: json['a'] is String ? json['a'] as String : 'Various Artists',
      );
    } catch (_) {
      return null;
    }
  }
}
