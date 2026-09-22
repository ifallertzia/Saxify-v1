import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saxify/core/models/album_card.dart';
import 'package:saxify/core/theme/saxify_accents.dart';
import 'package:saxify/core/utils/format.dart';
import 'package:saxify/ui/widgets/saxify_logo.dart';

void main() {
  group('AlbumCard ytq codec', () {
    test('decode matches the web site format', () {
      const String encoded =
          'ytq-eyJxIjoibmV3IHNvbmdzIDIwMjYgb2ZmaWNpYWwiLCJ0IjoiTmV3IE11c2ljIDIwMjYiLCJhIjoiRmFsbHkgSXB1cGEifQ';
      final AlbumCard? album = AlbumCard.decode(encoded);
      expect(album, isNotNull);
      expect(album!.query, 'new songs 2026 official');
      expect(album.title, 'New Music 2026');
      expect(album.artist, 'Fally Ipupa');
    });

    test('encode/decode roundtrip', () {
      final String id = AlbumCard.encode(
        query: 'lofi beats',
        title: 'Lo-Fi Corner',
        artist: 'Unknown Artist',
      );
      final AlbumCard? album = AlbumCard.decode(id);
      expect(album, isNotNull);
      expect(album!.query, 'lofi beats');
      expect(album.title, 'Lo-Fi Corner');
      expect(album.artist, 'Unknown Artist');
    });

    test('rejects garbage', () {
      expect(AlbumCard.decode('not-base64!!!'), isNull);
      expect(AlbumCard.decode(''), isNull);
    });
  });

  group('formatting', () {
    test('duration renders m:ss and h:mm:ss', () {
      expect(Fmt.duration(const Duration(minutes: 4, seconds: 33)), '4:33');
      expect(
          Fmt.duration(const Duration(hours: 1, minutes: 2, seconds: 7)),
          '1:02:07');
      expect(Fmt.duration(null), '--:--');
    });

    test('count shortens large numbers', () {
      expect(Fmt.count(1500000), '1.5M');
      expect(Fmt.count(20000), '20K');
      expect(Fmt.count(400), '400');
    });
  });

  group('accents', () {
    test('six accents ship and byId falls back', () {
      expect(SaxifyAccents.all.length, 6);
      expect(SaxifyAccents.byId('neon-violet'), SaxifyAccents.neonViolet);
      expect(SaxifyAccents.byId('nope'), SaxifyAccents.neonViolet);
    });
  });

  group('branding', () {
    testWidgets('logo renders without a network font', (WidgetTester tester) async {
      await tester.pumpWidget(
        Theme(
          data: ThemeData.dark(),
          child: const Center(child: SaxifyLogo(size: 40)),
        ),
      );
      expect(find.byType(SaxifyLogo), findsOneWidget);
      expect(find.byType(CustomPaint, skipOffstage: false), findsWidgets);
    });
  });
}
