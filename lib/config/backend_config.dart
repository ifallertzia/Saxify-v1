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

  /// Universal downloader. Override in Settings if the deployed host differs.
  /// There is no checked-in secret — this is a public base URL only.
  static const String downloaderBaseDefault =
      'https://saxify-downloader.onrender.com';

  static const String expectedDownloaderApp = SaxifyBranding.downloaderName;
  static const String expectedDownloaderVersion = '1.1.0';

  static const String clientHeader = 'X-Saxify-Client';
  static const String clientValue = 'flutter';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration coldStartTimeout = Duration(seconds: 45);
  static const int maxRetries = 2;

  static Map<String, String> jsonHeaders({String? userAgent}) =>
      <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        clientHeader: clientValue,
        'User-Agent': userAgent ?? SaxifyBranding.userAgent,
      };

  static Map<String, String> downloadHeaders({String? userAgent}) =>
      <String, String>{
        'Accept': '*/*',
        clientHeader: clientValue,
        'User-Agent': userAgent ?? SaxifyBranding.userAgent,
      };
}
