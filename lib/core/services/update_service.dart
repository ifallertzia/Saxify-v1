import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Everything the Phase-2 "In-App Update" needs:
/// version compare against GitHub Releases, in-app APK download with progress,
/// and hand-off to the system installer.
class UpdateService {
  /// Where releases are published. The primary repo is the one named in the
  /// brief; if it has no releases we fall back to the repo that CI actually
  /// publishes from, so the feature works either way.
  static const List<String> releaseRepos = <String>[
    'dastaanenajdik/sidify-app',
    'dastaanenajdik/testing',
  ];

  static const String _apkAssetName = 'app-release.apk';

  final http.Client _client = http.Client();

  PackageInfo? _packageInfo;

  Future<String> currentVersion() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!.version; // e.g. "1.1.0"
  }

  /// Returns null when we could not reach any release endpoint.
  Future<UpdateInfo?> check() async {
    final String current = await currentVersion();

    for (final String repo in releaseRepos) {
      try {
        final http.Response res = await _client
            .get(
              Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
              headers: const <String, String>{
                'Accept': 'application/vnd.github+json',
              },
            )
            .timeout(const Duration(seconds: 12));

        if (res.statusCode != 200) continue;

        final Map<String, dynamic> json =
            jsonDecode(res.body) as Map<String, dynamic>;
        final String tag = (json['tag_name'] as String? ?? '').trim();
        if (tag.isEmpty) continue;

        final String? apkUrl = _findApkAsset(json);
        final int? size = _findApkSize(json);
        final String notes = json['body'] as String? ?? '';

        return UpdateInfo(
          currentVersion: current,
          latestVersion: _stripV(tag),
          apkUrl: apkUrl,
          notes: notes,
          sizeBytes: size,
          releaseUrl: json['html_url'] as String?,
        );
      } catch (e) {
        debugPrint('update check ($repo) failed: $e');
      }
    }
    return null;
  }

  String? _findApkAsset(Map<String, dynamic> json) {
    final Object? assets = json['assets'];
    if (assets is! List) return null;

    // Prefer the canonical asset name, else any .apk.
    String? fallback;
    for (final Object? a in assets) {
      if (a is! Map) continue;
      final String name = (a['name'] as String? ?? '').toLowerCase();
      final String url = a['browser_download_url'] as String? ?? '';
      if (url.isEmpty) continue;
      if (name == _apkAssetName) return url;
      if (name.endsWith('.apk')) fallback ??= url;
    }
    return fallback;
  }

  int? _findApkSize(Map<String, dynamic> json) {
    final Object? assets = json['assets'];
    if (assets is! List) return null;
    for (final Object? a in assets) {
      if (a is! Map) continue;
      final String name = (a['name'] as String? ?? '').toLowerCase();
      if (name == _apkAssetName || name.endsWith('.apk')) {
        final Object? size = a['size'];
        if (size is int) return size;
      }
    }
    return null;
  }

  static String _stripV(String tag) =>
      tag.startsWith('v') || tag.startsWith('V') ? tag.substring(1) : tag;

  /// Downloads the APK into app storage and streams progress back.
  /// Returns the saved file path.
  Future<String> downloadApk(
    String url, {
    void Function(double fraction, int receivedBytes)? onProgress,
  }) async {
    final Directory dir = await _downloadDir();
    final File file = File('${dir.path}/sidify-update.apk');

    final http.Request request = http.Request('GET', Uri.parse(url));
    final http.StreamedResponse response = await _client.send(request);
    if (response.statusCode != 200) {
      throw HttpException('Download failed: HTTP ${response.statusCode}');
    }

    final int total = response.contentLength ?? 0;
    int received = 0;

    final IOSink sink = file.openWrite();
    await response.stream.map((List<int> chunk) {
      received += chunk.length;
      if (total > 0 && onProgress != null) {
        onProgress((received / total).clamp(0.0, 1.0), received);
      }
      return chunk;
    }).pipe(sink);

    return file.path;
  }

  Future<Directory> _downloadDir() async {
    try {
      final Directory? external = await getExternalStorageDirectory();
      if (external != null) return external;
    } catch (_) {}
    return getTemporaryDirectory();
  }

  /// Hands the downloaded APK to the Android package installer.
  Future<void> install(String path) async {
    await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
  }

  void dispose() => _client.close();

  /// Semantic version compare — true when [latest] is newer than [current].
  static bool isNewer(String current, String latest) {
    final List<int> a = _parse(current);
    final List<int> b = _parse(latest);
    for (int i = 0; i < 3; i++) {
      if (b[i] > a[i]) return true;
      if (b[i] < a[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final List<int> out = <int>[0, 0, 0];
    final List<String> parts = v.split('+').first.split('.');
    for (int i = 0; i < 3 && i < parts.length; i++) {
      out[i] = int.tryParse(parts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return out;
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    this.apkUrl,
    this.notes = '',
    this.sizeBytes,
    this.releaseUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String? apkUrl;
  final String notes;
  final int? sizeBytes;
  final String? releaseUrl;

  bool get hasUpdate => UpdateService.isNewer(currentVersion, latestVersion);
  bool get downloadable => apkUrl != null && apkUrl!.isNotEmpty;

  String get sizeLabel {
    final int? s = sizeBytes;
    if (s == null || s <= 0) return '';
    final double mb = s / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
