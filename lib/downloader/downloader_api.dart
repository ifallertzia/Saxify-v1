import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';
import 'downloader_models.dart';

class DownloaderApi {
  DownloaderApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? BackendConfig.downloaderBaseDefault;

  final http.Client _client;
  String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final String root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$root$path').replace(queryParameters: query);
  }

  Future<DownloaderHealth> health() async {
    try {
      final http.Response res = await _client
          .get(_uri('/api/health'), headers: BackendConfig.jsonHeaders())
          .timeout(BackendConfig.coldStartTimeout);
      if (res.statusCode != 200) {
        return DownloaderHealth(
          ok: false,
          app: '',
          version: '',
          raw: res.body,
          error: 'Health check returned HTTP ${res.statusCode}',
        );
      }
      final Object? decoded = jsonDecode(res.body);
      final Map<String, dynamic> json =
          decoded is Map ? decoded.cast<String, dynamic>() : <String, dynamic>{};
      return DownloaderHealth(
        ok: (json['status']?.toString().toLowerCase() == 'ok') ||
            json['status']?.toString().toLowerCase() == 'healthy',
        app: json['app']?.toString() ?? '',
        version: json['version']?.toString() ?? '',
        ffmpeg: json['ffmpeg'] is bool ? json['ffmpeg'] as bool : null,
        ytDlp: json['yt_dlp'] is bool
            ? json['yt_dlp'] as bool
            : json['ytdlp'] is bool
                ? json['ytdlp'] as bool
                : null,
        raw: res.body,
      );
    } catch (e) {
      return DownloaderHealth(
        ok: false,
        app: '',
        version: '',
        error: classifyDownloadError(e),
      );
    }
  }

  Future<MediaInfo> fetchInfo(String url) async {
    Object? last;
    for (int attempt = 0; attempt <= BackendConfig.maxRetries; attempt++) {
      try {
        final http.Response res = await _client
            .post(
              _uri('/api/fetch-info'),
              headers: BackendConfig.jsonHeaders(),
              body: jsonEncode(<String, String>{'url': url}),
            )
            .timeout(BackendConfig.coldStartTimeout);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final Object? decoded = jsonDecode(res.body);
          if (decoded is Map) {
            return MediaInfo.fromJson(decoded.cast<String, dynamic>(), url);
          }
          throw Exception('Server returned an unexpected info payload');
        }
        throw Exception(classifyDownloadError(
          'HTTP ${res.statusCode}',
          status: res.statusCode,
          body: res.body,
        ));
      } catch (e) {
        last = e;
        if (attempt == BackendConfig.maxRetries) break;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw Exception(classifyDownloadError(last ?? 'fetch failed'));
  }

  Uri downloadUri({
    required String url,
    required String type,
    String? formatId,
  }) {
    return _uri('/api/download', <String, String>{
      'url': url,
      'type': type,
      if (formatId != null && formatId.isNotEmpty) 'format_id': formatId,
    });
  }
}
