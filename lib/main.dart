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
  Video? _currentVideo;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  Future<void> _searchSongs(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
    });
    try {
      var results = await _yt.search.search(query);
      setState(() {
        _searchResults = results.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _playSong(Video video) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(video.id);
      var audioStreamUrl = manifest.audioOnly.withHighestBitrate().url.toString();

      await _audioPlayer.setUrl(audioStreamUrl);
      await _audioPlayer.play();

      setState(() {
        _currentVideo = video;
      });
    } catch (e) {
      // Handle error if stream fails
    }
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
              child: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final video = _searchResults[index];
                  return ListTile(
                    leading: Image.network(
                      video.thumbnails.highResUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                    title: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      video.author,
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.deepOrange),
                      onPressed: () => _playSong(video),
                    ),
                  );
                },
              ),
            ),
          if (_currentVideo != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black87,
              child: Row(
                children: [
                  Image.network(
                    _currentVideo!.thumbnails.highResUrl,
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _currentVideo!.author,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                    onPressed: () {
                      if (_isPlaying) {
                        _audioPlayer.pause();
                      } else {
                        _audioPlayer.play();
                      }
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}