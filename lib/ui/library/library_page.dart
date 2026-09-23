import 'package:flutter/material.dart';
import '../../core/theme/saxify_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../core/services/library_service.dart';
import '../../core/services/music_download_service.dart';
import '../../core/services/playback_service.dart';
import '../../core/theme/saxify_accents.dart';
import '../../core/theme/saxify_theme.dart';
import '../../core/utils/format.dart';
import '../artist/artist_router.dart';
import '../settings/backup_sheet.dart';
import '../settings/playlist_sync_sheet.dart';
import '../widgets/artwork.dart';
import '../widgets/neon.dart';
import '../widgets/song_tile.dart';
import 'playlist_detail_page.dart';

/// Your Library — Songs, Liked Songs, Playlists, Artists and History.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LibraryHeader(),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: SaxifyColors.border,
                tabs: <Widget>[
                  Tab(text: 'Liked'),
                  Tab(text: 'Playlists'),
                  Tab(text: 'Songs'),
                  Tab(text: 'Artists'),
                  Tab(text: 'Downloads'),
                  Tab(text: 'History'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _LikedTab(),
                    _PlaylistsTab(),
                    _SongsTab(),
                    _ArtistsTab(),
                    _DownloadsTab(),
                    _HistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'Your Library',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: SaxifyColors.textPrimary,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Backup / import library JSON',
            onPressed: () => showBackupSheet(
              context,
              context.read<LibraryService>(),
            ),
            icon: const Icon(Icons.backup_outlined),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Liked Songs
class _LikedTab extends StatelessWidget {
  const _LikedTab();

  @override
  Widget build(BuildContext context) {
    final LibraryService library = context.watch<LibraryService>();
    final PlaybackService playback = context.read<PlaybackService>();
    final List<Song> songs = library.likedSongs;

    if (songs.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'No liked songs yet',
          message:
              'Tap the heart on any track and it will live here, saved on this device.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 140),
      children: <Widget>[
        _CollectionHeader(
          label: 'PLAYLIST',
          title: 'Liked Songs',
          subtitle: '${songs.length} songs',
          coverUrl: songs.first.thumbnailUrl,
          icon: Icons.favorite_rounded,
          onPlay: () => playback.playQueue(songs),
          onShuffle: () async {
            await playback.playQueue(songs);
            if (!playback.shuffleEnabled) await playback.toggleShuffle();
          },
        ),
        for (int i = 0; i < songs.length; i++)
          SongTile(
            song: songs[i],
            onTap: () => playback.playQueue(songs, startIndex: i),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Playlists
class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab();

  Future<void> _create(BuildContext context, LibraryService library) async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Create playlist',
            style: SaxifyFonts.display(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (String v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await library.createPlaylist(name);
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext c) => PlaylistDetailPage(playlistId: playlist.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LibraryService library = context.watch<LibraryService>();
    final SaxifyAccent accent = context.accent;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
      children: <Widget>[
        NeonCard(
          glow: true,
          onTap: () => _create(context, library),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: accent.gradient,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.black),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Create playlist',
                        style: SaxifyFonts.display(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text(
                      'Build your own universe of sound',
                      style: TextStyle(
                          fontSize: 12, color: SaxifyColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent.primary),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: TextButton(
                onPressed: () => shareAllPlaylistCodes(context),
                child: const Text('Generate all'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => showImportCodeSheet(context),
                child: const Text('Import code'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (library.playlists.isEmpty)
          const EmptyState(
            icon: Icons.queue_music_rounded,
            title: 'No playlists yet',
            message:
                'Create one above, then use “Add to playlist” from any song menu.',
          )
        else
          for (final Playlist playlist in library.playlists)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeonCard(
                padding: const EdgeInsets.all(12),
                onTap: () => _openPlaylist(context, playlist),
                child: Row(
                  children: <Widget>[
                    Artwork(
                      url: playlist.artwork,
                      size: 56,
                      radius: 10,
                      fallbackIcon: Icons.queue_music_rounded,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SaxifyFonts.display(
                                  fontSize: 14.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                            '${playlist.count} songs · ${Fmt.date(playlist.createdAt)}',
                            style: const TextStyle(
                                fontSize: 11.5, color: SaxifyColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded,
                          size: 20, color: SaxifyColors.textFaint),
                      onPressed: () => _playlistMenu(context, library, playlist),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  void _playlistMenu(
      BuildContext context, LibraryService library, Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SaxifyColors.surface,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final TextEditingController controller =
                    TextEditingController(text: playlist.name);
                final String? name = await showDialog<String>(
                  context: context,
                  builder: (BuildContext dialogContext) => AlertDialog(
                    title: const Text('Rename playlist'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'New name'),
                      onSubmitted: (String v) =>
                          Navigator.of(dialogContext).pop(v),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(controller.text),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
                if (name != null && name.trim().isNotEmpty) {
                  await library.renamePlaylist(playlist.id, name);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: SaxifyColors.danger),
              title: const Text('Delete playlist',
                  style: TextStyle(color: SaxifyColors.danger)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) => AlertDialog(
                    title: const Text('Delete playlist?'),
                    content: Text(
                        '"${playlist.name}" and its ${playlist.count} songs will be removed.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) await library.deletePlaylist(playlist.id);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Songs
class _SongsTab extends StatelessWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context) {
    final LibraryService library = context.watch<LibraryService>();
    final PlaybackService playback = context.read<PlaybackService>();
    final List<Song> songs = library.songs;

    if (songs.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          icon: Icons.library_music_outlined,
          title: 'Nothing saved yet',
          message:
              'Songs you add to the library from the song menu will collect here.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 140),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text('${songs.length} saved songs',
                    style: const TextStyle(
                        fontSize: 12.5, color: SaxifyColors.textMuted)),
              ),
              TextButton.icon(
                onPressed: () => playback.playQueue(songs),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play all', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        for (int i = 0; i < songs.length; i++)
          SongTile(
            song: songs[i],
            onTap: () => playback.playQueue(songs, startIndex: i),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Artists
class _ArtistsTab extends StatelessWidget {
  const _ArtistsTab();

  static const List<String> _indianArtists = <String>[
    'Arijit Singh',
    'Shreya Ghoshal',
    'A. R. Rahman',
    'Sonu Nigam',
    'Lata Mangeshkar',
    'Kishore Kumar',
    'Asha Bhosle',
    'Udit Narayan',
    'Mohammed Rafi',
    'Kumar Sanu',
    'Jubin Nautiyal',
    'Armaan Malik',
    'Neha Kakkar',
    'Sunidhi Chauhan',
    'Vishal Mishra',
    'Mohit Chauhan',
    'Javed Ali',
    'Kailash Kher',
    'Papon',
    'Monali Thakur',
    'Palak Muchhal',
    'Sukhwinder Singh',
    'B Praak',
    'Diljit Dosanjh',
    'Sidhu Moose Wala',
    'AP Dhillon',
    'Guru Randhawa',
    'Badshah',
    'Yo Yo Honey Singh',
    'Shankar Mahadevan',
    'Vishal-Shekhar',
    'Pritam',
    'Amit Trivedi',
    'Anirudh Ravichander',
    'Sid Sriram',
    'S. P. Balasubrahmanyam',
    'K. S. Chithra',
    'Ilaiyaraaja',
    'Devi Sri Prasad',
    'Benny Dayal',
    'Hariharan',
    'Jasleen Royal',
    'Prateek Kuhad',
    'Ritviz',
    'Nucleya',
  ];

  @override
  Widget build(BuildContext context) {
    final LibraryService library = context.watch<LibraryService>();
    final List<ArtistRef> followed = library.artists;
    final Color accent = context.accent.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 140),
      children: <Widget>[
        const SectionHeader(
          title: 'Indian artists',
          subtitle: 'Hindi and regional artists · tap a name for songs',
          padding: EdgeInsets.fromLTRB(8, 14, 8, 8),
        ),
        for (final String name in _indianArtists)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            leading: CircleAvatar(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              child: Text(
                name.trim().substring(0, 1),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded, color: SaxifyColors.textFaint),
            onTap: () => openArtistByName(context, name: name),
          ),
        if (followed.isNotEmpty) ...<Widget>[
          SectionHeader(
            title: 'Followed artists',
            subtitle: '${followed.length} saved on this device',
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          ),
          for (final ArtistRef artist in followed)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              leading: ClipOval(
                child: Artwork(url: artist.imageUrl, size: 48, radius: 24),
              ),
              title: Text(artist.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                artist.subscribers ?? 'Artist',
                style: const TextStyle(fontSize: 11.5, color: SaxifyColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: SaxifyColors.textFaint),
              onTap: () => openArtistByName(
                context,
                name: artist.name,
                channelId: artist.channelId,
              ),
            ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------- Downloads
class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context) {
    final MusicDownloadService downloads = context.watch<MusicDownloadService>();
    final PlaybackService playback = context.read<PlaybackService>();
    final List<MusicDownloadJob> saved = downloads.downloaded;
    final List<Song> songs = saved.map((MusicDownloadJob job) => job.song).toList();
    final Map<String, String> sources = <String, String>{
      for (final MusicDownloadJob job in saved)
        if (job.offlinePath != null) job.song.id: job.offlinePath!,
    };
    final List<MusicDownloadJob> active = downloads.jobs
        .where((MusicDownloadJob job) =>
            job.phase == MusicDownloadPhase.running || job.phase == MusicDownloadPhase.idle)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 140),
      children: <Widget>[
        const SectionHeader(
          title: 'Your Downloads',
          subtitle: 'Saved on this phone · available offline',
          padding: EdgeInsets.fromLTRB(8, 12, 8, 8),
        ),
        for (final MusicDownloadJob job in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(job.song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: job.phase == MusicDownloadPhase.running ? job.fraction : null,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    job.phase == MusicDownloadPhase.running
                        ? 'Downloading · ${(job.fraction * 100).round()}%'
                        : 'Waiting in queue',
                    style: const TextStyle(fontSize: 11.5, color: SaxifyColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        if (saved.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text('${saved.length} songs saved',
                      style: const TextStyle(fontSize: 12.5, color: SaxifyColors.textMuted)),
                ),
                TextButton.icon(
                  onPressed: () => playback.playOfflineQueue(songs, sources),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Play all'),
                ),
              ],
            ),
          ),
        if (saved.isEmpty && active.isEmpty)
          const EmptyState(
            icon: Icons.download_outlined,
            title: 'No songs downloaded yet',
            message: 'Tap the download icon beside any song. Your files stay on this device and play offline.',
          ),
        for (int i = 0; i < saved.length; i++)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            leading: Artwork(url: saved[i].song.thumbnailUrl, size: 48, radius: 8),
            title: Text(saved[i].song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${saved[i].song.artist} · ${(saved[i].size / (1024 * 1024)).toStringAsFixed(1)} MB',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: SaxifyColors.textMuted),
            ),
            trailing: IconButton(
              tooltip: 'Delete download',
              onPressed: () => downloads.delete(saved[i], playback: playback),
              icon: const Icon(Icons.delete_outline_rounded, color: SaxifyColors.danger),
            ),
            onTap: saved[i].offlinePath == null
                ? null
                : () => playback.playOfflineSong(saved[i].song, saved[i].offlinePath!),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ History
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final LibraryService library = context.watch<LibraryService>();
    final PlaybackService playback = context.read<PlaybackService>();

    if (library.history.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyState(
          icon: Icons.history_rounded,
          title: 'No listening history',
          message: 'Play something and it will show up here automatically.',
        ),
      );
    }

    final List<Song> ordered =
        library.history.map((HistoryEntry e) => e.song).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 140),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${library.history.length} recently played',
                  style: const TextStyle(
                      fontSize: 12.5, color: SaxifyColors.textMuted),
                ),
              ),
              TextButton.icon(
                onPressed: () => playback.playQueue(ordered),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Play all', style: TextStyle(fontSize: 12)),
              ),
              IconButton(
                tooltip: 'Clear history',
                icon: const Icon(Icons.delete_sweep_rounded,
                    size: 20, color: SaxifyColors.textFaint),
                onPressed: library.clearHistory,
              ),
            ],
          ),
        ),
        for (int i = 0; i < library.history.length; i++)
          SongTile(
            song: library.history[i].song,
            subtitle:
                '${library.history[i].song.artist} · ${Fmt.relative(library.history[i].playedAt)}',
            onTap: () => playback.playQueue(ordered, startIndex: i),
          ),
      ],
    );
  }
}

/// Shared gradient header for a song collection.
class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.icon,
    required this.onPlay,
    required this.onShuffle,
  });

  final String label;
  final String title;
  final String subtitle;
  final String coverUrl;
  final IconData icon;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final SaxifyAccent accent = context.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
                  gradient: accent.gradient,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent.primary.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: coverUrl.isEmpty
                    ? Icon(icon, size: 40, color: Colors.black87)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(SaxifyTheme.radiusMd),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Artwork(url: coverUrl, radius: 0),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(icon, size: 20, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: accent.primary)),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SaxifyFonts.display(
                          fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: SaxifyColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: NeonButton(
                label: 'Play',
                icon: Icons.play_arrow_rounded,
                expand: true,
                onPressed: onPlay,
              ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: onShuffle,
                icon: const Icon(Icons.shuffle_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: SaxifyColors.surfaceAlt,
                  foregroundColor: SaxifyColors.textPrimary,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
