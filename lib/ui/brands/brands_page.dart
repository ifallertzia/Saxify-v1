import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/song.dart';
import '../../core/services/playback_service.dart';
import '../../core/services/youtube_service.dart';
import '../../core/theme/category_palette.dart';
import '../../core/theme/saxify_theme.dart';
import '../../data/labels.dart';
import '../artist/artist_router.dart';
import '../shell/shell_controller.dart';
import '../widgets/media_cards.dart';
import '../widgets/neon.dart';
import '../widgets/search_fab.dart';
import '../widgets/song_tile.dart';

class _BrandGroup {
  const _BrandGroup(this.name, this.subtitle, this.labels, this.artists);
  final String name;
  final String subtitle;
  final List<String> labels;
  final List<String> artists;

  List<MusicBrand> get brands => MusicBrands.all
      .where((MusicBrand brand) => labels.contains(brand.name)).toList();
}

const List<_BrandGroup> _groups = <_BrandGroup>[
  _BrandGroup('Bollywood & Hindi', 'Film hits · new releases',
      <String>['T-Series', 'Zee Music Company', 'Sony Music India', 'YRF Music'],
      <String>['Arijit Singh', 'Shreya Ghoshal', 'Darshan Raval', 'Jubin Nautiyal', 'Vishal Mishra']),
  _BrandGroup('Punjabi & Indie', 'Regional sounds · fresh voices',
      <String>['Speed Records', 'Geet MP3', 'Desi Music Factory'],
      <String>['Diljit Dosanjh', 'AP Dhillon', 'Guru Randhawa', 'B Praak', 'Jasleen Royal']),
  _BrandGroup('Classics & Devotional', 'Timeless · bhakti · ghazal',
      <String>['Saregama Music', 'T-Series', 'Zee Music Company'],
      <String>['Lata Mangeshkar', 'Kishore Kumar', 'Sonu Nigam', 'Kailash Kher', 'Asha Bhosle']),
  _BrandGroup('Worldwide', 'International labels',
      <String>['Universal Music Group', 'Sony Music', 'Warner Music'],
      <String>['A. R. Rahman', 'Anirudh Ravichander', 'Prateek Kuhad', 'Sunidhi Chauhan']),
];

class BrandsPage extends StatefulWidget {
  const BrandsPage({super.key});

  @override
  State<BrandsPage> createState() => _BrandsPageState();
}

class _BrandsPageState extends State<BrandsPage> {
  String _filter = '';
  String _selected = _groups.first.name;

  @override
  Widget build(BuildContext context) {
    final String term = _filter.trim().toLowerCase();
    final List<_BrandGroup> groups = term.isEmpty ? _groups : _groups.where((_BrandGroup group) =>
        group.name.toLowerCase().contains(term) ||
        group.artists.any((String artist) => artist.toLowerCase().contains(term)) ||
        group.brands.any((MusicBrand brand) => brand.name.toLowerCase().contains(term))
    ).toList();
    final _BrandGroup? selected = groups.isEmpty ? null : groups.firstWhere(
      (_BrandGroup group) => group.name == _selected,
      orElse: () => groups.first,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Music brands'), actions: const <Widget>[SaxifySearchButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        children: <Widget>[
          TextField(
            decoration: const InputDecoration(
              hintText: 'Find a label or artist', prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (String value) => setState(() => _filter = value),
            onSubmitted: (String value) {
              if (groups.isNotEmpty || value.trim().isEmpty) return;
              context.read<ShellController>().goSearch(value.trim());
              Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
            },
          ),
          const SizedBox(height: 20),
          Text('Browse by sound', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Pick a category to explore its labels and artists.',
            style: TextStyle(color: SaxifyColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const EmptyState(icon: Icons.search_off_rounded, title: 'Nothing found',
              message: 'Try an artist, label or song search instead.')
          else ...<Widget>[
            LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groups.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth > 640 ? 3 : 2,
                  mainAxisExtent: 106, crossAxisSpacing: 10, mainAxisSpacing: 10,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final _BrandGroup group = groups[index];
                  final Color tile = CategoryPalette.at(_groups.indexOf(group) + 5);
                  final Color ink = CategoryPalette.on(tile);
                  return Material(
                    color: tile,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _selected = group.name),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: selected?.name == group.name
                              ? ink.withValues(alpha: 0.85) : ink.withValues(alpha: 0.16), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Icon(Icons.library_music_rounded, color: ink, size: 21),
                            Text(group.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
            if (selected != null) ...<Widget>[
              const SizedBox(height: 24),
              Text(selected.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 3),
              Text(selected.subtitle, style: const TextStyle(color: SaxifyColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Text('Artists', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              HorizontalRail(
                padding: EdgeInsets.zero, height: 160,
                itemCount: selected.artists.length,
                builder: (BuildContext context, int index) {
                  final String name = selected.artists[index];
                  return ArtistBubble(name: name, imageUrl: '',
                    onTap: () => openArtistByName(context, name: name));
                },
              ),
              const SizedBox(height: 10),
              Text('Music labels', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              for (final MusicBrand brand in selected.brands)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NeonCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => BrandChannelPage(brand: brand))),
                    child: Row(children: <Widget>[
                      Container(
                        width: 46, height: 46, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: CategoryPalette.forKey(brand.name),
                          borderRadius: BorderRadius.circular(13)),
                        child: Text(brand.name[0], style: TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 20, color: CategoryPalette.on(CategoryPalette.forKey(brand.name)))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(brand.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${brand.region} · @${brand.handle}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: SaxifyColors.textMuted, fontSize: 12)),
                        ])),
                      const Icon(Icons.chevron_right_rounded),
                    ]),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class BrandChannelPage extends StatefulWidget {
  const BrandChannelPage({super.key, required this.brand});
  final MusicBrand brand;

  @override
  State<BrandChannelPage> createState() => _BrandChannelPageState();
}

class _BrandChannelPageState extends State<BrandChannelPage> {
  late final Future<List<Song>> _future = _load();

  Future<List<Song>> _load() async {
    final YoutubeService youtube = context.read<YoutubeService>();
    final String? channel = widget.brand.channelId;
    if (channel != null) {
      try {
        final List<Song> uploads = await youtube.channelUploads(channel, limit: 24);
        if (uploads.isNotEmpty) return uploads;
      } catch (_) { /* An empty channel is not a dead-end: use music search. */ }
    }
    return youtube.searchSongs(widget.brand.searchQuery, limit: 24);
  }

  Future<void> _openYoutube() =>
      launchUrl(Uri.parse(widget.brand.youtubeUrl), mode: LaunchMode.externalApplication).then((_) {});

  @override
  Widget build(BuildContext context) {
    final _BrandGroup group = _groups.firstWhere(
      (_BrandGroup group) => group.labels.contains(widget.brand.name),
      orElse: () => _groups.first,
    );
    final Color tile = CategoryPalette.forKey(widget.brand.name);
    final Color ink = CategoryPalette.on(tile);
    return Scaffold(
      appBar: AppBar(title: Text(widget.brand.name), actions: <Widget>[
        IconButton(tooltip: 'Open official channel', onPressed: _openYoutube,
          icon: const Icon(Icons.open_in_new_rounded)),
        const SaxifySearchButton(),
      ]),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<Song>> snapshot) {
          final List<Song> songs = snapshot.data ?? <Song>[];
          return ListView(padding: const EdgeInsets.only(bottom: 140), children: <Widget>[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Icon(Icons.album_rounded, color: ink, size: 30),
                const SizedBox(height: 22),
                Text(widget.brand.name, style: TextStyle(color: ink, fontSize: 23, fontWeight: FontWeight.w800)),
                Text('${group.name} · ${widget.brand.region}', style: TextStyle(color: ink.withValues(alpha: 0.8))),
              ]),
            ),
            const SectionHeader(title: 'Artists to explore', subtitle: 'Open their songs and profiles'),
            HorizontalRail(height: 160, itemCount: group.artists.length,
              builder: (BuildContext context, int i) => ArtistBubble(
                name: group.artists[i], imageUrl: '',
                onTap: () => openArtistByName(context, name: group.artists[i]))),
            const SectionHeader(title: 'Label tracks', subtitle: 'Play or save from this label'),
            if (snapshot.connectionState != ConnectionState.done)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (songs.isEmpty)
              EmptyState(icon: Icons.music_off_rounded, title: 'Tracks unavailable right now',
                message: 'Search this label or open its official channel.',
                actionLabel: 'Open channel', onAction: _openYoutube)
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: NeonButton(label: 'Play label tracks', icon: Icons.play_arrow_rounded,
                  expand: true, onPressed: () => context.read<PlaybackService>().playQueue(songs)),
              for (int i = 0; i < songs.length; i++)
                SongTile(song: songs[i], onTap: () => context.read<PlaybackService>()
                    .playQueue(songs, startIndex: i)),
            ],
          ]);
        },
      ),
    );
  }
}
