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
    MediaPlatform.youtube,
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

  static bool _hostIs(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  static MediaPlatform detect(String raw) {
    final Uri? uri = Uri.tryParse(raw.trim());
    final String host = (uri?.host ?? raw).toLowerCase();
    if (_hostIs(host, 'instagram.com') || _hostIs(host, 'instagr.am')) {
      return MediaPlatform.instagram;
    }
    if (_hostIs(host, 'pin.it') || host.startsWith('pinterest.') ||
        host.contains('.pinterest.')) return MediaPlatform.pinterest;
    if (_hostIs(host, 'twitter.com') || _hostIs(host, 'x.com') ||
        _hostIs(host, 't.co')) return MediaPlatform.twitter;
    if (_hostIs(host, 'facebook.com') || _hostIs(host, 'fb.watch') ||
        _hostIs(host, 'fb.com')) return MediaPlatform.facebook;
    if (_hostIs(host, 'reddit.com') || _hostIs(host, 'redd.it')) {
      return MediaPlatform.reddit;
    }
    if (_hostIs(host, 'threads.net')) return MediaPlatform.threads;
    if (_hostIs(host, 'tiktok.com')) return MediaPlatform.tiktok;
    if (_hostIs(host, 'twitch.tv')) return MediaPlatform.twitch;
    if (_hostIs(host, 'snapchat.com')) return MediaPlatform.snapchat;
    if (_hostIs(host, 'vimeo.com')) return MediaPlatform.vimeo;
    if (_hostIs(host, 'dailymotion.com') || _hostIs(host, 'dai.ly')) {
      return MediaPlatform.dailymotion;
    }
    if (_hostIs(host, 'soundcloud.com')) return MediaPlatform.soundcloud;
    if (_hostIs(host, 'rumble.com')) return MediaPlatform.rumble;
    if (_hostIs(host, 'imgur.com')) return MediaPlatform.imgur;
    if (_hostIs(host, 'likee.video') || _hostIs(host, 'likee.com')) {
      return MediaPlatform.likee;
    }
    if (_hostIs(host, 'mojapp.in') || _hostIs(host, 'moj.video') ||
        _hostIs(host, 'moj.app')) return MediaPlatform.moj;
    if (_hostIs(host, 'sharechat.com')) return MediaPlatform.sharechat;
    if (_hostIs(host, 'chingari.com')) return MediaPlatform.chingari;
    if (_hostIs(host, 'youtube.com') || _hostIs(host, 'youtu.be')) {
      return MediaPlatform.youtube;
    }
    return MediaPlatform.other;
  }

  static bool isYoutube(String raw) => detect(raw) == MediaPlatform.youtube;

  /// Reject malformed or obviously gated links before sending them to the
  /// downloader. Public YouTube links are supported by bundled yt-dlp;
  /// private/login content is never bypassed.
  static String? blockedReason(String raw) {
    final String value = raw.trim().toLowerCase();
    if (value.isEmpty) return 'Paste a public link first.';
    final Uri? uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'That does not look like a public http(s) link.';
    }
    final String host = uri.host.toLowerCase();
    if (host.isEmpty || !host.contains('.') || host == 'localhost' ||
        host.endsWith('.local') || host.startsWith('127.') ||
        host.startsWith('192.168.') || host.startsWith('10.')) {
      return 'Use a public website link, not a device or local-network address.';
    }
    if (value.contains('/login') ||
        value.contains('/private') ||
        value.contains('paywall') ||
        value.contains('accounts.google') ||
        value.contains('signin')) {
      return 'This looks like a login or paywalled page. Saxify does not bypass those.';
    }
    return null;
  }

  static String normalizeUrl(String raw) {
    final String value = raw.trim();
    if (value.startsWith('https://') || value.startsWith('http://')) return value;
    return value.contains('.') ? 'https://$value' : value;
  }

  static bool looksLikeUrl(String raw) => blockedReason(normalizeUrl(raw)) == null;

  static List<String> splitUrls(String raw) {
    final List<String> out = <String>[];
    final RegExp tokens = RegExp(r"[^\s,;]+", caseSensitive: false);
    for (final RegExpMatch token in tokens.allMatches(raw)) {
      final String candidate = normalizeUrl((token.group(0) ?? '')
          .replaceAll(RegExp(r'[).;]+$'), ''));
      if (looksLikeUrl(candidate) && !out.contains(candidate)) out.add(candidate);
    }
    return out;
  }
}
