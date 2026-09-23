import 'package:flutter_test/flutter_test.dart';
import 'package:saxify/core/models/artist_profile.dart';
import 'package:saxify/core/models/download_item.dart';
import 'package:saxify/core/models/media_format.dart';
import 'package:saxify/downloader/platform_detect.dart';

void main() {
  group('platform detection (Part 11.2)', () {
    test('detects the 20 supported platforms from plain hosts', () {
      expect(PlatformDetect.detect('https://instagram.com/reel/abc'),
          MediaPlatform.instagram);
      expect(PlatformDetect.detect('https://pinterest.com/pin/123'),
          MediaPlatform.pinterest);
      expect(PlatformDetect.detect('https://x.com/user/status/1'),
          MediaPlatform.twitter);
      expect(PlatformDetect.detect('https://twitter.com/user/status/1'),
          MediaPlatform.twitter);
      expect(PlatformDetect.detect('https://facebook.com/watch?v=1'),
          MediaPlatform.facebook);
      expect(PlatformDetect.detect('https://reddit.com/r/flutter/comments/1'),
          MediaPlatform.reddit);
      expect(PlatformDetect.detect('https://threads.net/@user/post/1'),
          MediaPlatform.threads);
      expect(PlatformDetect.detect('https://tiktok.com/@user/video/1'),
          MediaPlatform.tiktok);
      expect(PlatformDetect.detect('https://twitch.tv/channel'),
          MediaPlatform.twitch);
      expect(PlatformDetect.detect('https://snapchat.com/t/abc'),
          MediaPlatform.snapchat);
      expect(PlatformDetect.detect('https://vimeo.com/123456'),
          MediaPlatform.vimeo);
      expect(
          PlatformDetect.detect('https://dailymotion.com/video/x8abc'),
          MediaPlatform.dailymotion);
      expect(PlatformDetect.detect('https://soundcloud.com/user/track'),
          MediaPlatform.soundcloud);
      expect(PlatformDetect.detect('https://rumble.com/c/123'),
          MediaPlatform.rumble);
      expect(PlatformDetect.detect('https://imgur.com/a/abc'),
          MediaPlatform.imgur);
      expect(PlatformDetect.detect('https://likee.video/@user/video/1'),
          MediaPlatform.likee);
      expect(PlatformDetect.detect('https://moj.app/@user/video/1'),
          MediaPlatform.moj);
      expect(PlatformDetect.detect('https://sharechat.com/v/123'),
          MediaPlatform.sharechat);
      expect(PlatformDetect.detect('https://chingari.com/@user/1'),
          MediaPlatform.chingari);
      expect(PlatformDetect.detect('https://youtube.com/watch?v=abc'),
          MediaPlatform.youtube);
    });

    test('handles subdomains and short links', () {
      expect(PlatformDetect.detect('https://www.instagram.com/p/Cxyz'),
          MediaPlatform.instagram);
      expect(PlatformDetect.detect('https://vm.tiktok.com/ZM1/'),
          MediaPlatform.tiktok);
      expect(PlatformDetect.detect('https://m.reddit.com/r/x'),
          MediaPlatform.reddit);
      expect(PlatformDetect.detect('https://fb.watch/xYz/'),
          MediaPlatform.facebook);
      expect(PlatformDetect.detect('https://youtu.be/abc123'),
          MediaPlatform.youtube);
      expect(PlatformDetect.detect('https://t.co/abc123'), MediaPlatform.twitter);
    });

    test('unknown hosts fall to other, never throw', () {
      expect(PlatformDetect.detect('https://example.com/video'),
          MediaPlatform.other);
      expect(PlatformDetect.detect('not a url'), MediaPlatform.other);
      expect(PlatformDetect.detect('https://notyoutube.com/watch?v=abc'),
          MediaPlatform.other);
      expect(PlatformDetect.detect(''), MediaPlatform.other);
    });
  });

  group('bulk url splitting (Part 11.6)', () {
    test('splits on whitespace, adds https, de-dupes', () {
      final List<String> urls = PlatformDetect.splitUrls(
          'https://instagram.com/a\ninstagram.com/b, tiktok.com/c; x.com/d\n'
          'https://instagram.com/a');
      expect(urls, <String>[
        'https://instagram.com/a',
        'https://instagram.com/b',
        'https://tiktok.com/c',
        'https://x.com/d',
      ]);
    });

    test('skips garbage lines', () {
      final List<String> urls = PlatformDetect.splitUrls('hello world\ninstagram.com/ok');
      expect(urls, <String>['https://instagram.com/ok']);
    });
  });

  group('url normalization (Part 11.3)', () {
    test('normalizeUrl adds https when missing', () {
      expect(PlatformDetect.normalizeUrl('instagram.com/p/1'), 'https://instagram.com/p/1');
      expect(PlatformDetect.normalizeUrl('https://x.com/1'), 'https://x.com/1');
      expect(PlatformDetect.normalizeUrl('  https://x.com/1  '), 'https://x.com/1');
    });

    test('looksLikeUrl rejects non-urls', () {
      expect(PlatformDetect.looksLikeUrl('https://instagram.com/reel/1'), isTrue);
      expect(PlatformDetect.looksLikeUrl('just some text'), isFalse);
      expect(PlatformDetect.looksLikeUrl(''), isFalse);
    });
  });

  group('quality picking (Part 11.5)', () {
    FetchInfo info() => FetchInfo.fromJson(<String, dynamic>{
          'title': 'T',
          'thumbnail': '',
          'duration': 30,
          'formats': <dynamic>[
            <String, dynamic>{
              'format_id': 'v1080',
              'ext': 'mp4',
              'kind': 'video',
              'resolution': '1080p',
              'bitrate': 4000,
            },
            <String, dynamic>{
              'format_id': 'v720',
              'ext': 'mp4',
              'kind': 'video',
              'resolution': '720p',
              'bitrate': 2000,
            },
            <String, dynamic>{
              'format_id': 'a192',
              'ext': 'mp3',
              'kind': 'audio',
              'bitrate': 192,
            },
            <String, dynamic>{
              'format_id': 'a128',
              'ext': 'mp3',
              'kind': 'audio',
              'bitrate': 128,
            },
          ],
        });

    test('bestAvailable prefers MP4 video (11.5: MP4 preferred)', () {
      final MediaFormat? best = info().bestAvailable();
      expect(best, isNotNull);
      expect(best!.formatId, 'v1080');
      expect(best.ext, 'mp4');
    });

    test('audio preference picks the highest bitrate MP3', () {
      final List<MediaFormat> audio =
          info().formats.where((MediaFormat f) => f.isAudio).toList()
            ..sort((MediaFormat a, MediaFormat b) =>
                (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
      expect(audio.first.formatId, 'a192');
      expect(audio.first.label, 'MP3 192 kbps (mp3)');
    });
  });

  group('download history codec (Part 11.5)', () {
    test('encode/decode roundtrip keeps every field', () {
      final DownloadItem item = DownloadItem(
        id: 'dl_1',
        url: 'https://instagram.com/p/1',
        platform: 'instagram',
        title: 'Beach day',
        thumbnail: 'https://i.imgur.com/x.jpg',
        mediaType: 'video',
        quality: '1080p (mp4)',
        sizeBytes: 1234567,
        localPath: '/storage/emulated/0/Download/Saxify/beach_saxify.mp4',
        status: 'done',
        createdAt: DateTime.utc(2026, 9, 1, 12),
      );
      final List<DownloadItem> back =
          DownloadItem.decodeAll(DownloadItem.encodeAll(<DownloadItem>[item]));
      expect(back.length, 1);
      expect(back.first.id, 'dl_1');
      expect(back.first.url, 'https://instagram.com/p/1');
      expect(back.first.title, 'Beach day');
      expect(back.first.sizeBytes, 1234567);
      expect(back.first.filePresent, isTrue);
      expect(back.first.createdAt, DateTime.utc(2026, 9, 1, 12));
    });

    test('decodeAll tolerates garbage', () {
      expect(DownloadItem.decodeAll('not json'), isEmpty);
      expect(DownloadItem.decodeAll(''), isEmpty);
      expect(DownloadItem.decodeAll('{"a":1}'), isEmpty);
    });
  });

  group('artist match scoring (Part 5)', () {
    test('close names score high, unrelated names score low', () {
      expect(ArtistProfile.matchScore('Arijit Singh', 'Arijit Singh'), 1.0);
      expect(ArtistProfile.matchScore('arijit singh', 'ARIJIT SINGH'), 1.0);
      expect(
          ArtistProfile.matchScore('Arijit Singh', 'Arijit Singh Official'),
          greaterThanOrEqualTo(ArtistProfile.matchThreshold));
      expect(
          ArtistProfile.matchScore('Arijit Singh', 'Someone Else'),
          lessThan(ArtistProfile.matchThreshold));
    });
  });
}
