import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Artwork byte cache (Part 7 — thumbnail bug fix).
///
/// Root cause of the "mini player -> full player shows blank artwork" bug:
/// `Image.network` refetches (or cache-misses in the image cache) when the
/// route rebuilds, flashing a white placeholder.
///
/// Fix: the app owns the bytes. [bytesFor] fetches once (in-flight requests
/// are de-duplicated), keeps an in-memory LRU and a disk copy under the app
/// support dir, and every Artwork widget decodes from memory. Route pushes
/// never touch the network again, and [precache] lets the player warm the
/// next track's artwork ~5 s before the current one ends.
class ImageCacheService {
  ImageCacheService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  final Map<String, Uint8List> _mem = <String, Uint8List>{};
  final Map<String, Future<Uint8List>> _inFlight = <String, Future<Uint8List>>{};
  int _memBytes = 0;

  /// ~12 MB in-memory cap (thumbnails are small; a few hundred fit easily).
  static const int _memCapBytes = 12 * 1024 * 1024;
  static const int _memCapEntries = 400;

  Directory? _diskDir;

  Future<Directory> _disk() async {
    final Directory? dir = _diskDir;
    if (dir != null) return dir;
    final Directory base = await getApplicationSupportDirectory();
    final Directory d = Directory('${base.path}/saxify_image_cache');
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    _diskDir = d;
    return d;
  }

  String _diskName(String url) {
    final String hash = url.hashCode.toRadixString(36);
    final String last = Uri.tryParse(url)?.path.split('/').last ?? 'img';
    final String safe = last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$hash$safe';
  }

  /// Returns the artwork bytes; null when the url is empty or unfetchable.
  Future<Uint8List?> bytesFor(String url) async {
    if (url.isEmpty) return null;
    final Uint8List? hit = _mem[url];
    if (hit != null) {
      // LRU touch: move to the end.
      _mem.remove(url);
      _mem[url] = hit;
      return hit;
    }
        final Future<Uint8List>? pending = _inFlight[url];
    if (pending != null) {
      try {
        return await pending;
      } catch (_) {
        return null;
      }
    }

    final Future<Uint8List> task = _fetch(url);
    _inFlight[url] = task;
    try {
      return await task;
    } catch (e) {
      debugPrint('image fetch failed ($url): $e');
      return null;
    } finally {
      _inFlight.remove(url);
    }
  }

  Future<Uint8List> _fetch(String url) async {
    // 1) disk
    try {
      final Directory dir = await _disk();
      final File f = File('${dir.path}/${_diskName(url)}');
      if (await f.exists()) {
        final Uint8List bytes = await f.readAsBytes();
        if (bytes.isNotEmpty) {
          _put(url, bytes);
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('image disk read failed: $e');
    }
    // 2) network
    final http.Response res = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw HttpException('HTTP ${res.statusCode} for $url');
    }
    final Uint8List bytes = res.bodyBytes;
    _put(url, bytes);
    _writeDisk(url, bytes); // fire & forget
    return bytes;
  }

  void _put(String url, Uint8List bytes) {
    _mem[url] = bytes;
    _memBytes += bytes.length;
    while (_memBytes > _memCapBytes || _mem.length > _memCapEntries) {
      final String oldest = _mem.keys.first;
      _memBytes -= _mem[oldest]!.length;
      _mem.remove(oldest);
    }
  }

  Future<void> _writeDisk(String url, Uint8List bytes) async {
    try {
      final Directory dir = await _disk();
      final File f = File('${dir.path}/${_diskName(url)}');
      await f.writeAsBytes(bytes, flush: false);
    } catch (e) {
      debugPrint('image disk write failed: $e');
    }
  }

  /// Warm a url without caring about the result (precache next track).
  void precache(String url) {
    if (url.isEmpty || _mem.containsKey(url) || _inFlight.containsKey(url)) {
      return;
    }
    bytesFor(url).catchError((Object e) {
      debugPrint('precache $url failed: $e');
      return null;
    });
  }

  /// Is the url already served from memory?
  bool isInMemory(String url) => _mem.containsKey(url);

  void dispose() {
    _client.close();
    _mem.clear();
    _memBytes = 0;
  }
}
