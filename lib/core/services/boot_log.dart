import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Best-effort startup log. Never throws, never blocks the UI for long.
class BootLog {
  const BootLog._();

  static Future<void> write(String message) async {
    debugPrint('[IfallMusic][Boot] $message');
    try {
      final Directory dir = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 1));
      final File file = File('${dir.path}/saxify_boot.log');
      await file
          .writeAsString(
            '${DateTime.now().toIso8601String()} $message\n',
            mode: FileMode.append,
          )
          .timeout(const Duration(seconds: 1));
    } catch (_) {
      // Logging must never be the thing that freezes startup.
    }
  }

  static Future<String> tail({int maxChars = 4000}) async {
    try {
      final Directory dir = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 1));
      final File file = File('${dir.path}/saxify_boot.log');
      if (!file.existsSync()) return '';
      final String raw = await file.readAsString().timeout(const Duration(seconds: 1));
      if (raw.length <= maxChars) return raw;
      return raw.substring(raw.length - maxChars);
    } catch (_) {
      return '';
    }
  }
}
