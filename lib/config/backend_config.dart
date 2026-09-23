import '../config/branding.dart';

/// Every remote URL the app talks to, outside the existing music engine.
///
/// The YouTube search / stream resolver is intentionally NOT configured here.
/// It stays inside [YoutubeService] and [PlaybackService].
class BackendConfig {
  const BackendConfig._();

  /// Playlist share / restore. Confirmed in the v2 brief.
  static const String playlistBase =
      'https://saxifyappbackend-for-playlist.onrender.com';

  static const String clientHeader = 'X-Saxify-Client';
  static const String clientValue = 'flutter';

  static Map<String, String> jsonHeaders({String? userAgent}) =>
      <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        clientHeader: clientValue,
        'User-Agent': userAgent ?? SaxifyBranding.userAgent,
      };

}
