import 'package:flutter_test/flutter_test.dart';
import 'package:saxify/config/release_notes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bundled What’s new is the published v2.1.0 release text', () async {
    final List<String> notes = await ReleaseNotes.load();
    expect(notes.length, greaterThanOrEqualTo(8));
    expect(notes.first, contains('entirely on your phone'));
    expect(notes.join(' '), contains('Darshan Raval'));
    expect(notes.join(' '), contains('Silver'));
    expect(notes.join(' '), isNot(contains('Render downloader')));
  });
}
