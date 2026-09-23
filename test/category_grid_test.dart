import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saxify/core/theme/category_palette.dart';
import 'package:saxify/ui/widgets/media_cards.dart';

void main() {
  testWidgets('Browse categories are solid, distinct, and open their search',
      (WidgetTester tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: <Widget>[
          MoodGenreGrid(
            items: const <(String, String)>[
              ('Osho', 'Osho meditation music'),
              ('Workout', 'Hindi workout songs'),
            ],
            onSelected: (String query) => selected = query,
          ),
        ]),
      ),
    ));
    final Iterable<Material> tiles = tester.widgetList<Material>(find.byType(Material));
    expect(tiles.any((Material m) => m.color == CategoryPalette.at(0)), isTrue);
    expect(tiles.any((Material m) => m.color == CategoryPalette.at(1)), isTrue);
    expect(CategoryPalette.at(0), isNot(CategoryPalette.at(1)));
    await tester.tap(find.text('Osho'));
    expect(selected, 'Osho meditation music');
  });
}
