/// Single source of truth for Saxify identity.
///
/// Logo contract: drop a transparent 512×512 PNG at [logoAsset] and run
/// `flutter pub get`. Do not change the filename.
class SaxifyBranding {
  const SaxifyBranding._();

  static const double logoWidth = 512;
  static const double logoHeight = 512;
  static const String logoFormat = 'PNG (transparent background)';
  static const String logoAsset = 'assets/images/saxify_logo.png';
  static const String splashAsset = 'assets/images/saxify_splash.png';
  static const double splashLogoSize = 300;
  static const String appName = 'Saxify';
  static const String downloaderName = 'Saxify Downloader';
  static const String downloadFolderName = 'Saxify';
  static const String fileSuffix = '_saxify';
  static const String author = 'Siddharth IfallertzIa';
  static const String contactEmail = 'dastaanenajdik@gmail.com';
  static const String versionLabel = '2.0.0';
  static const String tagline = 'Stream beyond limits';
  static const String userAgent = 'Saxify/2.0 (Flutter)';
  static const String packageName = 'com.saxify.app';
}
