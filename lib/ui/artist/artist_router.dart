import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/artist_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/utils/text_match.dart';
import '../../data/labels.dart';
import '../brands/brands_page.dart';
import '../shell/shell_controller.dart';
import 'artist_page.dart';
import 'artist_profile_page.dart';

/// Artist tap never opens a random channel.
///
/// Deezer match above 0.8 opens a profile. A channel is opened only when its
/// title matches the artist. Otherwise we search "{name} songs", and if the
/// video came from a known label we open that label — not someone else.
Future<void> openArtistByName(
  BuildContext context, {
  required String name,
  String? channelId,
}) async {
  final String artist = name.trim();
  if (artist.isEmpty) return;
  final NavigatorState navigator = Navigator.of(context);
  final ArtistService artists = context.read<ArtistService>();
  final YoutubeService youtube = context.read<YoutubeService>();
  final ShellController shell = context.read<ShellController>();

  final ArtistProfile profile = await artists.resolve(artist);
  if (!context.mounted) return;

  if (profile.confident) {
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ArtistProfilePage(queryName: artist, profile: profile),
      ),
    );
    return;
  }

  if (channelId != null && channelId.isNotEmpty) {
    final MusicBrand? label = MusicBrands.matchChannel(channelId);
    if (label != null) {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => BrandChannelPage(brand: label)),
      );
      return;
    }
    try {
      final channel = await youtube.channel(channelId);
      if (!context.mounted) return;
      if (TextMatch.score(artist, channel.title) > 0.8) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ArtistPage(
              channelId: channelId,
              fallbackName: channel.title,
              fallbackImageUrl: channel.logoUrl,
            ),
          ),
        );
        return;
      }
    } catch (_) {}
  }

  shell.goSearch('$artist songs');
  navigator.popUntil((Route<dynamic> route) => route.isFirst);
}
