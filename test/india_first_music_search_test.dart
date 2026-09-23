import 'package:flutter_test/flutter_test.dart';
import 'package:saxify/core/services/youtube_service.dart';

void main() {
  group('India-first music search', () {
    test('adds an India-first music query to general artist searches', () {
      expect(
        YoutubeService.indianFirstQuery('Arijit Singh'),
        'Hindi song Arijit Singh official audio',
      );
      expect(
        YoutubeService.indianFirstQuery('Punjabi'),
        'Punjabi songs',
      );
    });

    test('filters obvious non-music uploads but allows Osho meditation', () {
      expect(
        YoutubeService.looksLikeSong(
          title: 'A day in my life vlog',
          author: 'Music Records',
          duration: const Duration(minutes: 12),
        ),
        isFalse,
      );
      expect(
        YoutubeService.looksLikeSong(
          title: 'Osho Dynamic Meditation',
          author: 'Osho International',
          duration: const Duration(minutes: 30),
        ),
        isTrue,
      );
    });
  });
}
