import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  runApp(const HamsterBeatsApp());
}

class HamsterBeatsApp extends StatelessWidget {
  const HamsterBeatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hamster Beats',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepOrange,
      ),
      home: const MusicHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Video> _searchResults = [];
  bool _isLoading = false;
  bool _isSongLoading = false;
  Video? _currentVideo;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    // Keep play/pause icon in sync with real player state.
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing &&
            state.processingState != ProcessingState.completed;
      });
    });
  }

  Future<void> _searchSongs(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final VideoSearchList results = await _yt.search.search(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results.toList();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Search error: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Search failed: $e');
    }
  }

  Future<void> _playSong(Video video) async {
    if (_isSongLoading) return; // prevent double-tap race
    setState(() {
      _isSongLoading = true;
      _currentVideo = video; // show mini-player immediately for responsive UI
    });

    try {
      // Stop any currently playing track before starting a new one.
      await _audioPlayer.stop();

      // Use YouTube clients that are NOT affected by the Android PO-Token /
      // anti-bot changes (ios + androidVr return audio-only streams that
      // resolve without HTTP 403).
      // NOTE: no `const` here — YoutubeApiClient.ios is `static final`, so a
      // const list would be a compile-time error.
      final StreamManifest manifest = await _yt.videos.streams.getManifest(
        video.id,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
        ],
      );

      // Pick the highest-bitrate audio-only stream.
      final List<AudioOnlyStreamInfo> audioStreams =
          manifest.audioOnly.toList()
            ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
      if (audioStreams.isEmpty) {
        throw Exception('No audio-only streams available for this video');
      }
      final AudioOnlyStreamInfo streamInfo = audioStreams.first;
      final String audioStreamUrl = streamInfo.url.toString();

      debugPrint('Playing: ${video.title}');
      debugPrint('Stream URL length: ${audioStreamUrl.length} | '
          'Bitrate: ${streamInfo.bitrate} | Container: ${streamInfo.container}');

      // Load the stream URL into just_audio.
      await _audioPlayer.setUrl(audioStreamUrl);
      await _audioPlayer.play();

      if (!mounted) return;
      setState(() {
        _currentVideo = video;
        _isPlaying = true;
      });
    } catch (e, stackTrace) {
      // ---- NO MORE SILENT FAILURE ----
      // Log to console so developers can diagnose in `flutter logs`.
      debugPrint('Playback error: $e\n$stackTrace');

      if (!mounted) return;
      setState(() {
        // If we failed, don't leave the broken track in the mini-player.
        _isPlaying = false;
      });
      _showErrorSnackBar('Unable to play "${video.title}": $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSongLoading = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_currentVideo == null) return;
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _yt.close();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐹 Hamster Beats'),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search songs, lofi, artists...',
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.deepOrange),
                  onPressed: () => _searchSongs(_searchController.text),
                ),
              ),
              onSubmitted: _searchSongs,
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: Colors.deepOrange),
              ),
            )
          else if (_searchResults.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note, size: 72, color: Colors.grey[700]),
                    const SizedBox(height: 12),
                    Text(
                      'Search for a song to start listening!',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final Video video = _searchResults[index];
                  final bool isCurrent = _currentVideo?.id == video.id;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        video.thumbnails.highResUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[800],
                          child: const Icon(Icons.music_note, color: Colors.white54),
                        ),
                      ),
                    ),
                    title: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? Colors.deepOrange : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      video.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: _isSongLoading && isCurrent
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.deepOrange,
                              strokeWidth: 2.5,
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              isCurrent && _isPlaying
                                  ? Icons.bar_chart // subtle "now playing" indicator
                                  : Icons.play_arrow,
                              color: Colors.deepOrange,
                            ),
                            onPressed: () => _playSong(video),
                          ),
                    onTap: () => _playSong(video),
                  );
                },
              ),
            ),
          // ======= MINI-PLAYER BAR (always visible when a track is loaded) =======
          if (_currentVideo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                border: Border(
                  top: BorderSide(color: Colors.deepOrange.withOpacity(0.4), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        _currentVideo!.thumbnails.highResUrl,
                        width: 45,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 45,
                          height: 45,
                          color: Colors.grey[800],
                          child: const Icon(Icons.music_note, color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentVideo!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentVideo!.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (_isSongLoading)
                      const SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            color: Colors.deepOrange,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.deepOrange,
                          size: 36,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
