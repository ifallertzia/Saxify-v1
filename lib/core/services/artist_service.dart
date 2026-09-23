import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/branding.dart';
import '../utils/text_match.dart';
import 'youtube_service.dart';

/// Artist photos. Priority: Deezer → iTunes → YouTube channel logo → app logo.
///
/// This does not replace music search. Top songs still come from [YoutubeService].
class ArtistProfile {
  const ArtistProfile({
    required this.name,
    required this.imageUrl,
    required this.matchScore,
    required this.source,
    this.deezerId,
    this.fanCount,
  });

  final String name;
  final String imageUrl;
  final double matchScore;
  final String source;
  final String? deezerId;
  final int? fanCount;

  bool get confident => matchScore >= 0.8 && imageUrl.isNotEmpty && source != 'fallback';
}

class ArtistService {
  ArtistService({YoutubeService? youtube, http.Client? client})
      : _youtube = youtube,
        _client = client ?? http.Client();

  final YoutubeService? _youtube;
  final http.Client _client;
  final Map<String, ArtistProfile> _memory = <String, ArtistProfile>{};

  final Map<String, Future<ArtistProfile>> _inFlight = <String, Future<ArtistProfile>>{};

  Future<ArtistProfile> resolve(String name) {
    final String key = TextMatch.norm(name);
    final ArtistProfile? cached = _memory[key];
    if (cached != null) return Future<ArtistProfile>.value(cached);
    final Future<ArtistProfile>? pending = _inFlight[key];
    if (pending != null) return pending;
    final Future<ArtistProfile> future = _find(name);
    _inFlight[key] = future;
    return future.whenComplete(() { _inFlight.remove(key); });
  }

  Future<ArtistProfile> _find(String name) async {
    // Do not accept the FIRST similar-looking Deezer result blindly; a wrong
    // face is worse than a fallback. Only cache high-confidence portraits.
    ArtistProfile? found = await _deezer(name);
    if (found?.confident != true) found = await _itunes(name);
    if (found?.confident != true) found = await _youtubeLogo(name);
    if (found?.confident != true) {
      return ArtistProfile(name: name, imageUrl: '', matchScore: 0, source: 'fallback');
    }
    _memory[TextMatch.norm(name)] = found!;
    return found;
  }

  Future<ArtistProfile?> _deezer(String name) async {
    try {
      final Uri uri = Uri.parse(
        'https://api.deezer.com/search/artist?q=${Uri.encodeQueryComponent(name)}',
      );
      final http.Response res =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final Object? decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final Object? data = decoded['data'];
      if (data is! List || data.isEmpty) return null;

      ArtistProfile? best;
      double bestScore = 0;
      for (final Object? item in data.take(5)) {
        if (item is! Map) continue;
        final String artist = item['name']?.toString() ?? '';
        final double score = TextMatch.score(name, artist);
        if (score <= bestScore) continue;
        final String xl = item['picture_xl']?.toString() ?? '';
        final String medium = item['picture_medium']?.toString() ?? '';
        bestScore = score;
        best = ArtistProfile(
          name: artist.isEmpty ? name : artist,
          imageUrl: xl.isNotEmpty ? xl : medium,
          matchScore: score,
          source: 'deezer',
          deezerId: item['id']?.toString(),
          fanCount: item['nb_fan'] is int ? item['nb_fan'] as int : null,
        );
      }
      return best;
    } catch (e) {
      debugPrint('[Saxify][Artist] deezer: $e');
      return null;
    }
  }

  Future<ArtistProfile?> _itunes(String name) async {
    try {
      final Uri uri = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeQueryComponent(name)}&entity=musicArtist&limit=5',
      );
      final http.Response res =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final Object? decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final Object? results = decoded['results'];
      if (results is! List || results.isEmpty) return null;

      ArtistProfile? best;
      double bestScore = 0;
      for (final Object? item in results) {
        if (item is! Map) continue;
        final String artist = item['artistName']?.toString() ?? '';
        final double score = TextMatch.score(name, artist);
        if (score <= bestScore) continue;
        String art = item['artworkUrl100']?.toString() ?? '';
        art = art.replaceAll('100x100', '600x600');
        bestScore = score;
        best = ArtistProfile(
          name: artist.isEmpty ? name : artist,
          imageUrl: art,
          matchScore: score,
          source: 'itunes',
        );
      }
      return best;
    } catch (e) {
      debugPrint('[Saxify][Artist] itunes: $e');
      return null;
    }
  }

  Future<ArtistProfile?> _youtubeLogo(String name) async {
    final YoutubeService? youtube = _youtube;
    if (youtube == null) return null;
    try {
      final songs = await youtube.searchSongs(name, limit: 5);
      for (final song in songs) {
        if (TextMatch.score(name, song.artist) < 0.8) continue;
        final String? channelId = song.channelId;
        if (channelId == null || channelId.isEmpty) continue;
        final channel = await youtube.channel(channelId);
        if (TextMatch.score(name, channel.title) < 0.8) continue;
        if (channel.logoUrl.isEmpty) continue;
        return ArtistProfile(
          name: channel.title,
          imageUrl: channel.logoUrl,
          matchScore: TextMatch.score(name, channel.title),
          source: 'youtube',
        );
      }
    } catch (e) {
      debugPrint('[Saxify][Artist] youtube logo: $e');
    }
    return null;
  }

  String fallbackAsset() => SaxifyBranding.logoAsset;
}
