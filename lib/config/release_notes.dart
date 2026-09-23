import 'package:flutter/services.dart';

/// The same RELEASE_NOTES.md is bundled with the app and used for the GitHub
/// release, so the home dialog cannot advertise an old downloader/backend.
class ReleaseNotes {
  const ReleaseNotes._();

  static Future<List<String>> load() async =>
      parse(await rootBundle.loadString('RELEASE_NOTES.md'));

  static List<String> parse(String markdown) {
    final List<String> notes = <String>[];
    bool inside = false;
    for (final String line in markdown.split('\n')) {
      if (line.startsWith('## ')) {
        inside = line == '## What’s new';
      } else if (inside && line.startsWith('- ')) {
        notes.add(line.substring(2));
      }
    }
    return notes;
  }
}
