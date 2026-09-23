/// A music label / brand shown in the Music Brands section.
///
/// Tapping a brand opens its official YouTube channel. We deliberately use a
/// channel *handle* (never a hardcoded channel id that can go stale) and
/// fall back to a YouTube search for the label when no handle is known —
/// so the app never dead-links to an unrelated channel.
class MusicBrand {
  const MusicBrand({
    required this.id,
    required this.name,
    required this.region,
    this.handle,
    this.monogram = '',
    this.color = 0xFFA855F7,
  });

  final String id;
  final String name;
  final String region; // 'india' | 'international'

  /// YouTube handle without the @ (e.g. `TSeries`).
  final String? handle;

  /// One/two letters drawn on the card when no channel logo is fetched.
  final String monogram;

  /// Neon accent for the monogram tile.
  final int color;

  String get channelUrl =>
      handle == null || handle!.isEmpty
          ? ''
          : 'https://www.youtube.com/@$handle';

  /// Fallback: search YouTube for the label — always lands on relevant
  /// content, never a random unrelated channel.
  String get searchUrl =>
      'https://www.youtube.com/results?search_query='
      '${Uri.encodeQueryComponent('$name official songs')}';
}
