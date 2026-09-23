import 'package:flutter_test/flutter_test.dart';
import 'package:saxify/downloader/downloader_models.dart';
import 'package:saxify/downloader/platform_detect.dart';

void main() {
  group('universal downloader public URL policy', () {
    test('eligible public YouTube links are allowed through to local yt-dlp', () {
      expect(
        PlatformDetect.detect('https://www.youtube.com/watch?v=abc').name,
        'youtube',
      );
      expect(
        PlatformDetect.blockedReason('https://www.youtube.com/watch?v=abc'),
        isNull,
      );
      expect(
        PlatformDetect.blockedReason('https://youtu.be/abc'),
        isNull,
      );
    });

    test('rejects malformed and visibly login-gated URLs', () {
      expect(PlatformDetect.blockedReason(''), isNotNull);
      expect(PlatformDetect.blockedReason('just text'), isNotNull);
      expect(
        PlatformDetect.blockedReason('https://youtube.com/login?next=/watch'),
        contains('login'),
      );
      expect(
        PlatformDetect.blockedReason('https://example.com/paywall/watch'),
        contains('paywalled'),
      );
      expect(
        PlatformDetect.blockedReason('https://example.com/private/video'),
        contains('login or paywalled'),
      );
    });
  });

  group('yt-dlp format metadata', () {
    test('identifies video-only, combined, and audio formats', () {
      final MediaFormat videoOnly = MediaFormat.fromJson(<String, dynamic>{
        'format_id': '137',
        'ext': 'mp4',
        'vcodec': 'avc1.640028',
        'acodec': 'none',
        'height': 1080,
      });
      final MediaFormat combined = MediaFormat.fromJson(<String, dynamic>{
        'format_id': '22',
        'ext': 'mp4',
        'vcodec': 'avc1.42001E',
        'acodec': 'mp4a.40.2',
        'height': 720,
      });
      final MediaFormat audio = MediaFormat.fromJson(<String, dynamic>{
        'format_id': '140',
        'ext': 'm4a',
        'vcodec': 'none',
        'acodec': 'mp4a.40.2',
      });

      expect(videoOnly.hasVideo, isTrue);
      expect(videoOnly.hasAudio, isFalse);
      expect(combined.hasVideo, isTrue);
      expect(combined.hasAudio, isTrue);
      expect(audio.hasVideo, isFalse);
      expect(audio.hasAudio, isTrue);
    });

    test('recognizes type fields when codec metadata is omitted', () {
      final MediaFormat videoOnly = MediaFormat.fromJson(<String, dynamic>{
        'format_id': 'v1',
        'kind': 'video_only',
      });
      final MediaFormat audio = MediaFormat.fromJson(<String, dynamic>{
        'format_id': 'a1',
        'kind': 'audio',
        'ext': 'mp3',
      });
      expect(videoOnly.hasVideo, isTrue);
      expect(videoOnly.hasAudio, isFalse);
      expect(audio.hasVideo, isFalse);
      expect(audio.hasAudio, isTrue);
    });
  });

  test('persists the video-only download choice', () {
    final DownloadRecord record = DownloadRecord(
      id: 'dl_1',
      url: 'https://youtube.com/watch?v=abc',
      title: 'Example',
      platform: MediaPlatform.youtube,
      kind: DownloadKind.videoOnly,
      quality: '1080p',
      createdAt: DateTime.utc(2026, 9, 23),
    );
    final DownloadRecord decoded = DownloadRecord.fromJson(record.toJson());
    expect(decoded.kind, DownloadKind.videoOnly);
  });
}
