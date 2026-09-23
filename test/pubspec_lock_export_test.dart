// Temporary test: prints Flutter's generated resolution in CI so a local
// workspace without a Flutter SDK can check in its reproducible pubspec.lock.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export resolved lockfile from Flutter runner', () {
    if (Platform.environment['GITHUB_ACTIONS'] != 'true') return;
    final String encoded = base64Encode(utf8.encode(File('pubspec.lock').readAsStringSync()));
    for (int index = 0; index < encoded.length; index += 800) {
      final int end = (index + 800).clamp(0, encoded.length);
      // ignore: avoid_print
      print('SAXIFY_LOCK_${(index ~/ 800).toString().padLeft(3, '0')}: '
          '${encoded.substring(index, end)}');
    }
  });
}
