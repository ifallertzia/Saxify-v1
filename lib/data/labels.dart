/// Official label channels. Taps open that channel — never a random artist.
class MusicBrand {
  const MusicBrand({
    required this.name,
    required this.handle,
    this.channelId,
    required this.region,
  });

  final String name;
  final String handle;
  final String? channelId;
  final String region;

  String get youtubeUrl => channelId == null
      ? 'https://www.youtube.com/@$handle'
      : 'https://www.youtube.com/channel/$channelId';

  String? get rssUrl => channelId == null
      ? null
      : 'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId';

  String get searchQuery => '$name official songs';
}

class MusicBrands {
  const MusicBrands._();

  static const List<MusicBrand> all = <MusicBrand>[
    MusicBrand(
      name: 'T-Series',
      handle: 'tseries',
      channelId: 'UCq-Fj5jknLsUf-MWSy4_brA',
      region: 'India',
    ),
    MusicBrand(
      name: 'Zee Music Company',
      handle: 'zeemusiccompany',
      channelId: 'UCFFbwnve3yF62-tVXkTyHqg',
      region: 'India',
    ),
    MusicBrand(
      name: 'Sony Music India',
      handle: 'SonyMusicIndia',
      channelId: 'UC56gTxA3uTQqKqHCejS3g9A',
      region: 'India',
    ),
    MusicBrand(
      name: 'YRF Music',
      handle: 'YRF',
      channelId: 'UCbTLwN10NoCU4WDzLf1JMOA',
      region: 'India',
    ),
    MusicBrand(
      name: 'Saregama Music',
      handle: 'SaregamaMusic',
      channelId: 'UC_A7K2dXFsTMAojm4w8HiAg',
      region: 'India',
    ),
    MusicBrand(
      name: 'Speed Records',
      handle: 'SpeedRecords',
      region: 'India',
    ),
    MusicBrand(
      name: 'Geet MP3',
      handle: 'GeetMP3',
      region: 'India',
    ),
    MusicBrand(
      name: 'Desi Music Factory',
      handle: 'DesiMusicFactory',
      region: 'India',
    ),
    MusicBrand(
      name: 'Universal Music Group',
      handle: 'UniversalMusicGroup',
      region: 'Global',
    ),
    MusicBrand(
      name: 'Sony Music',
      handle: 'SonyMusic',
      region: 'Global',
    ),
    MusicBrand(
      name: 'Warner Music',
      handle: 'WarnerMusicGroup',
      region: 'Global',
    ),
  ];

  static MusicBrand? matchChannel(String? channelId) {
    if (channelId == null || channelId.isEmpty) return null;
    for (final MusicBrand brand in all) {
      if (brand.channelId == channelId) return brand;
    }
    return null;
  }

  static List<MusicBrand> filter(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((MusicBrand b) =>
            b.name.toLowerCase().contains(q) || b.handle.toLowerCase().contains(q))
        .toList();
  }
}
