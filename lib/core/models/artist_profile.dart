/// A real music-industry artist profile resolved from public metadata
/// (Deezer first, iTunes fallback). Used by the Artist Profile screen —
/// complementary to the YouTube channel pages the app already has.
class ArtistProfile {
  const ArtistProfile({
    required this.name,
    this.photoUrl,
    this.deezerId,
    this.topSongTitles = const <String>[],
    this.albumTitles = const <String>[],
    this.webUrl,
    this.source,
  });

  final String name;

  /// 600x600 preferred (Deezer picture_xl / iTunes 600x600).
  final String? photoUrl;

  /// Deezer artist id when resolved from Deezer (top songs come from there).
  final int? deezerId;

  /// 5-10 headline track titles (for "Top songs").
  final List<String> topSongTitles;

  /// A few album titles (for "Albums").
  final List<String> albumTitles;

  /// Public page to open in the browser when playing there makes sense.
  final String? webUrl;

  /// `deezer`, `itunes` or `youtube` — where the profile data came from.
  final String? source;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (photoUrl != null) 'photo': photoUrl,
        if (deezerId != null) 'deezer_id': deezerId,
        'top': topSongTitles,
        'albums': albumTitles,
        if (webUrl != null) 'web': webUrl,
        if (source != null) 'source': source,
      };

  factory ArtistProfile.fromJson(Map<String, dynamic> json) {
    return ArtistProfile(
      name: json['name'] as String? ?? 'Artist',
      photoUrl: json['photo'] as String?,
      deezerId: json['deezer_id'] is int ? json['deezer_id'] as int : null,
      topSongTitles: (json['top'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      albumTitles: (json['albums'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
      webUrl: json['web'] as String?,
      source: json['source'] as String?,
    );
  }

  /// Normalized similarity (0..1) between [a] and [b] — token overlap with
  /// a small prefix bonus. Above [matchThreshold] we consider it the same
  /// artist.
  static double matchScore(String a, String b) {
    final List<String> ta = _tokens(a);
    final List<String> tb = _tokens(b);
    if (ta.isEmpty || tb.isEmpty) return 0;
    final Set<String> sa = ta.toSet();
    final Set<String> sb = tb.toSet();
    int common = 0;
    for (final String t in sa) {
      if (sb.contains(t)) common++;
    }
    double score = common / (sa.union(sb).length);
    // "Arijit Singh" vs "Arijit Singh Official" -> strong prefix match.
    final String na = a.trim().toLowerCase();
    final String nb = b.trim().toLowerCase();
    if (na.length >= 4 && (nb.startsWith(na) || na.startsWith(nb))) {
      score = score.clamp(0.8, 1.0);
    }
    return score;
  }

  static const double matchThreshold = 0.8;

  static List<String> _tokens(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((String t) => t.isNotEmpty && t.length > 1)
      .toList();
}
