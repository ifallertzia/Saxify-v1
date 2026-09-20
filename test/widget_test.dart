import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_beats/main.dart';

void main() {
  testWidgets('App renders home page with search bar', (tester) async {
    await tester.pumpWidget(const HamsterBeatsApp());

    // App title is present
    expect(find.text('🐹 Hamster Beats'), findsOneWidget);

    // Search field placeholder is present
    expect(find.text('Search songs, lofi, artists...'), findsOneWidget);
  });
}
