import 'package:flutter_test/flutter_test.dart';
import 'package:ifallmusic/core/services/youtube_service.dart';

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

    test('long-form music and Osho still pass, marathon streams still do not', () {
      expect(
        YoutubeService.looksLikeSong(
          title: 'Osho Kundalini Meditation — full 1 hour',
          author: 'Osho International',
          duration: const Duration(hours: 1, minutes: 4),
        ),
        isTrue,
      );
      expect(
        YoutubeService.looksLikeSong(
          title: 'Old Hindi Songs Jukebox | 2 hours non-stop',
          author: 'Bollywood Classics',
          duration: const Duration(hours: 2, minutes: 10),
        ),
        isTrue,
      );
      expect(
        YoutubeService.looksLikeSong(
          title: 'MARATHON GAMEPLAY — 3 hour live stream',
          author: 'SomeGamer',
          duration: const Duration(hours: 3),
        ),
        isFalse,
      );
      expect(
        YoutubeService.looksLikeSong(
          title: 'Full movie HD',
          author: 'Films',
          duration: const Duration(hours: 2),
        ),
        isFalse,
      );
    });
  });
}
