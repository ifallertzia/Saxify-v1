/// URL -> platform detection for the Saxify Downloader (Part 11.2).
///
/// Pure, testable, no network. Unknown URLs resolve to [PlatformId.other],
/// which the backend then resolves with yt-dlp's own sniffer (or rejects
/// with a clear "unsupported" error — never a silent failure).
enum PlatformId {
  autoDetect('Auto Detect'),
  instagram('Instagram'),
  pinterest('Pinterest'),
  x('X / Twitter'),
  facebook('Facebook'),
  reddit('Reddit'),
  threads('Threads'),
  tiktok('TikTok'),
  twitch('Twitch'),
  snapchat('Snapchat'),
  vimeo('Vimeo'),
  dailymotion('Dailymotion'),
  soundcloud('SoundCloud'),
  rumble('Rumble'),
  imgur('Imgur'),
  likee('Likee'),
  moj('Moj'),
  sharechat('ShareChat'),
  chingari('Chingari'),
  youtube('YouTube'),
  other('Other');

  const PlatformId(this.label);

  final String label;
}

class PlatformDetection {
  const PlatformDetection(this.platform, {required this.host});

  final PlatformId platform;
  final String host;

  bool get isKnown =>
      platform != PlatformId.other && platform != PlatformId.autoDetect;
}

/// Most-specific host first (vm.tiktok.com before tiktok.com, fb.watch
/// before facebook.com ...).
const Map<String, PlatformId> _hostTable = <String, PlatformId>{
  'vm.tiktok.com': PlatformId.tiktok,
  'vt.tiktok.com': PlatformId.tiktok,
  'fb.watch': PlatformId.facebook,
  'fb.com': PlatformId.facebook,
  'dai.ly': PlatformId.dailymotion,
  'pin.it': PlatformId.pinterest,
  't.co': PlatformId.x,
  'redd.it': PlatformId.reddit,
  'snapchat.tv': PlatformId.snapchat,
  'likee.video': PlatformId.likee,
  'youtu.be': PlatformId.youtube,
  'instagram.com': PlatformId.instagram,
  'instagr.am': PlatformId.instagram,
  'pinterest.com': PlatformId.pinterest,
  'x.com': PlatformId.x,
  'twitter.com': PlatformId.x,
  'facebook.com': PlatformId.facebook,
  'reddit.com': PlatformId.reddit,
  'threads.net': PlatformId.threads,
  'tiktok.com': PlatformId.tiktok,
  'twitch.tv': PlatformId.twitch,
  'snapchat.com': PlatformId.snapchat,
  'vimeo.com': PlatformId.vimeo,
  'dailymotion.com': PlatformId.dailymotion,
  'soundcloud.com': PlatformId.soundcloud,
  'rumble.com': PlatformId.rumble,
  'imgur.com': PlatformId.imgur,
  'likee.com': PlatformId.likee,
  'moj.app': PlatformId.moj,
  'sharechat.com': PlatformId.sharechat,
  'chingari.com': PlatformId.chingari,
  'youtube.com': PlatformId.youtube,
};

/// Detects the platform from a URL string (Part 11.2/11.3 step 2).
PlatformDetection detectPlatform(String rawUrl) {
  final String url = rawUrl.trim();
  Uri? uri;
  try {
    uri = Uri.parse(url.isEmpty ? 'https://$url' : url);
  } catch (_) {
    uri = null;
  }
  final String host = (uri?.host ?? '')
      .toLowerCase()
      .replaceFirst(RegExp(r'^www\.'), '');
  if (host.isEmpty) {
    return const PlatformDetection(PlatformId.other, host: '');
  }

  // Subdomain-agnostic: instagram.com/p/..., m.reddit.com, www.youtube.com ...
  for (final MapEntry<String, PlatformId> entry in _hostTable.entries) {
    final String known = entry.key;
    if (host == known || host.endsWith('.$known')) {
      return PlatformDetection(entry.value, host: known);
    }
  }
  return PlatformDetection(PlatformId.other, host: host);
}

/// Splits a pasted blob (bulk mode) into candidate URLs.
List<String> splitUrls(String raw) {
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final String line in raw.split(RegExp(r'[\s,;]+'))) {
    final String t = line.trim();
    if (t.isEmpty) continue;
    final String candidate =
        t.startsWith('http') ? t : (t.contains('.') ? 'https://$t' : t);
    try {
      final Uri uri = Uri.parse(candidate);
      if (uri.host.isNotEmpty && uri.host.contains('.')) {
        final String normalized =
            uri.scheme.isEmpty ? 'https://${uri.toString()}' : candidate;
        if (seen.add(normalized)) out.add(normalized);
      }
    } catch (_) {/* not a URL — skip */}
  }
  return out;
}

/// Normalizes a pasted URL so it is guaranteed to have a scheme.
String normalizeUrl(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) return t;
  if (t.startsWith('http://') || t.startsWith('https://')) return t;
  if (t.contains('.')) return 'https://$t';
  return t;
}

/// Is this string even shaped like a URL?
bool looksLikeUrl(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) return false;
  try {
    final Uri uri = Uri.parse(t.startsWith('http') ? t : 'https://$t');
    return uri.host.contains('.');
  } catch (_) {
    return false;
  }
}
