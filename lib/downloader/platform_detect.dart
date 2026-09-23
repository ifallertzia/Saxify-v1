enum MediaPlatform {
  auto,
  instagram,
  pinterest,
  twitter,
  facebook,
  reddit,
  threads,
  tiktok,
  twitch,
  snapchat,
  vimeo,
  dailymotion,
  soundcloud,
  rumble,
  imgur,
  likee,
  moj,
  sharechat,
  chingari,
  youtube,
  other,
}

class PlatformDetect {
  const PlatformDetect._();

  static const List<MediaPlatform> manual = <MediaPlatform>[
    MediaPlatform.auto,
    MediaPlatform.instagram,
    MediaPlatform.pinterest,
    MediaPlatform.twitter,
    MediaPlatform.facebook,
    MediaPlatform.reddit,
    MediaPlatform.threads,
    MediaPlatform.tiktok,
    MediaPlatform.twitch,
    MediaPlatform.snapchat,
    MediaPlatform.vimeo,
    MediaPlatform.dailymotion,
    MediaPlatform.soundcloud,
    MediaPlatform.rumble,
    MediaPlatform.imgur,
    MediaPlatform.likee,
    MediaPlatform.moj,
    MediaPlatform.sharechat,
    MediaPlatform.chingari,
    MediaPlatform.other,
  ];

  static String label(MediaPlatform platform) {
    switch (platform) {
      case MediaPlatform.auto:
        return 'Auto Detect';
      case MediaPlatform.twitter:
        return 'X / Twitter';
      case MediaPlatform.youtube:
        return 'YouTube';
      default:
        final String raw = platform.name;
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  static MediaPlatform detect(String raw) {
    final Uri? uri = Uri.tryParse(raw.trim());
    final String host = (uri?.host ?? raw).toLowerCase();
    if (host.contains('instagram.com') || host.contains('instagr.am')) {
      return MediaPlatform.instagram;
    }
    if (host.contains('pinterest.')) return MediaPlatform.pinterest;
    if (host.contains('twitter.com') || host.contains('x.com') || host.contains('t.co')) {
      return MediaPlatform.twitter;
    }
    if (host.contains('facebook.com') || host.contains('fb.watch') || host.contains('fb.com')) {
      return MediaPlatform.facebook;
    }
    if (host.contains('reddit.com') || host.contains('redd.it')) return MediaPlatform.reddit;
    if (host.contains('threads.net')) return MediaPlatform.threads;
    if (host.contains('tiktok.com')) return MediaPlatform.tiktok;
    if (host.contains('twitch.tv')) return MediaPlatform.twitch;
    if (host.contains('snapchat.com')) return MediaPlatform.snapchat;
    if (host.contains('vimeo.com')) return MediaPlatform.vimeo;
    if (host.contains('dailymotion.com') || host.contains('dai.ly')) {
      return MediaPlatform.dailymotion;
    }
    if (host.contains('soundcloud.com')) return MediaPlatform.soundcloud;
    if (host.contains('rumble.com')) return MediaPlatform.rumble;
    if (host.contains('imgur.com')) return MediaPlatform.imgur;
    if (host.contains('likee.')) return MediaPlatform.likee;
    if (host.contains('mojapp.in') || host.contains('moj.video')) return MediaPlatform.moj;
    if (host.contains('sharechat.com')) return MediaPlatform.sharechat;
    if (host.contains('chingari')) return MediaPlatform.chingari;
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      return MediaPlatform.youtube;
    }
    if (host.contains('.')) return MediaPlatform.other;
    return MediaPlatform.other;
  }

  static bool isYoutube(String raw) => detect(raw) == MediaPlatform.youtube;

  /// Reject malformed or obviously gated links before sending them to the
  /// downloader. YouTube links are supported by the configured yt-dlp backend;
  /// private/login content is never bypassed.
  static String? blockedReason(String raw) {
    final String value = raw.trim().toLowerCase();
    if (value.isEmpty) return 'Paste a public link first.';
    final Uri? uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'That does not look like a public http(s) link.';
    }
    if (uri.host.isEmpty) return 'That link is missing a website host.';
    if (value.contains('/login') ||
        value.contains('/private') ||
        value.contains('paywall') ||
        value.contains('accounts.google') ||
        value.contains('signin')) {
      return 'This looks like a login or paywalled page. Saxify does not bypass those.';
    }
    return null;
  }

  static List<String> splitUrls(String raw) {
    final RegExp link = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final Iterable<RegExpMatch> matches = link.allMatches(raw);
    final List<String> out = <String>[];
    for (final RegExpMatch match in matches) {
      var url = match.group(0) ?? '';
      url = url.replaceAll(RegExp(r'[),.;]+$'), '');
      if (url.isNotEmpty && !out.contains(url)) out.add(url);
    }
    if (out.isEmpty && raw.trim().isNotEmpty) out.add(raw.trim());
    return out;
  }
}
