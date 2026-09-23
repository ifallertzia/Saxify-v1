import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'notification_bootstrap.dart';
import 'native_bridge.dart';
import 'stream_quality.dart';

import '../models/song.dart';
import 'library_service.dart';
import 'settings_service.dart';
import 'youtube_service.dart';

/// The playback engine.
///
/// The stream-resolution algorithm below is **exactly** the one that shipped in
/// `main.dart` (HEAD-probe + androidSdkless → ios → androidVr fallback, the
/// youtube_explode_dart #332 workaround). It was moved here unchanged; what is
/// new around it is the queue, auto-next, related-track refill and error
/// recovery so a song never silently kills playback.
class PlaybackService extends ChangeNotifier {
  PlaybackService({
    required YoutubeService youtube,
    required SettingsService settings,
    required LibraryService library,
  })  : _youtube = youtube,
        _settings = settings,
        _library = library {
    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);
    // just_audio 0.9.x emits mid-stream errors through playbackEventStream.
    // playerStateStream swallows those errors, and play() alone can miss them.
    _errorSub = _player.playbackEventStream.listen(
      (PlaybackEvent _) {}, onError: _handlePlaybackError);
    _positionSub = _player.positionStream.listen(_onPosition);
    _durationSub = _player.durationStream.listen((Duration? d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
  }

  final YoutubeService _youtube;
  final SettingsService _settings;
  final LibraryService _library;
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlaybackEvent>? _errorSub;

  // ------------------------------------------------------------------- state
  final List<Song> _queue = <Song>[];
  int _index = -1;
  Song? _current;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _shuffle = false;
  LoopMode _loopMode = LoopMode.off;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _notice;
  Timer? _sleepTimer;
  Duration? _sleepRemaining;
  Timer? _sleepTicker;
  int _consecutiveFailures = 0;
  int _lastSavedSecond = -1;
  int _generation = 0;
  int _streamRetries = 0;
  bool _recoveringStream = false;
  int _recoveryToken = 0;
  Duration? _recoveredAt;
  bool _expectPlayback = false;
  bool _completionHandled = false;

  /// Fired after a track really starts. Recommendations listen; playback does not wait.
  void Function(Song song)? onTrackStarted;

  /// Fired when the listener skips a track that barely started.
  void Function(Song song)? onTrackSkipped;

  /// Stream URLs resolved ahead of time for the next track (gapless).
  final Map<String, String> _prewarmed = <String, String>{};

  /// Device-local file URIs registered from Your Downloads.
  final Map<String, String> _offlineSources = <String, String>{};

  /// Tracks that already failed once — never retry them in the same session.
  final Set<String> _failedIds = <String>{};

  // ------------------------------------------------------------------ getters
  AudioPlayer get player => _player;
  List<Song> get queue => List<Song>.unmodifiable(_queue);
  int get currentIndex => _index;
  Song? get current => _current;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get shuffleEnabled => _shuffle;
  LoopMode get loopMode => _loopMode;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get notice => _notice;
  bool get hasTrack => _current != null;
  Duration? get sleepRemaining => _sleepRemaining;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  double get progress {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Song? get nextUp {
    if (_queue.isEmpty) return null;
    final int i = _index + 1;
    if (i < _queue.length) return _queue[i];
    if (_loopMode == LoopMode.all) return _queue.first;
    return null;
  }

  Song? get previousUp {
    if (_queue.isEmpty) return null;
    final int i = _index - 1;
    if (i >= 0) return _queue[i];
    if (_loopMode == LoopMode.all) return _queue.last;
    return null;
  }

  // -------------------------------------------------------------- public API
  /// Replace the whole queue and start at [startIndex].
  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _queue
      ..clear()
      ..addAll(songs);
    _failedIds.clear();
    _consecutiveFailures = 0;
    _notice = null;
    await _startSong(startIndex.clamp(0, _queue.length - 1));
  }

  /// Play a single track right now, keeping the rest of the queue as "up next".
  Future<void> playSong(Song song) async {
    final int existing = _queue.indexWhere((Song s) => s.id == song.id);
    if (existing >= 0) {
      await _startSong(existing);
      return;
    }
    _queue.insert(0, song);
    _failedIds.clear();
    _consecutiveFailures = 0;
    _notice = null;
    await _startSong(0);
  }

  Future<void> playNext(Song song) async {
    _queue.insert(_index + 1, song);
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    _queue.add(song);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    if (index == _index) return; // never pull the track that is playing
    _queue.removeAt(index);
    if (index < _index) _index--;
    notifyListeners();
  }

  void clearQueue() {
    final Song? keep = _current;
    _queue.clear();
    if (keep != null) _queue.add(keep);
    _index = 0;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    final Song? song = _current;
    if (song == null) return;
    if (_player.playing) {
      _expectPlayback = false;
      await _player.pause();
    } else {
      _startPlayerPlayback(song);
    }
  }

  Future<void> pause() {
    _expectPlayback = false;
    return _player.pause();
  }

  Future<void> resume() async {
    final Song? song = _current;
    if (song != null) _startPlayerPlayback(song);
  }

  /// Play saved music without resolving a network URL. A local source is
  /// preferred for that song until its download is removed.
  Future<void> playOfflineSong(Song song, String pathOrUri) =>
      playOfflineQueue(<Song>[song], <String, String>{song.id: pathOrUri});

  Future<void> playOfflineQueue(
    List<Song> songs,
    Map<String, String> sources, {
    int startIndex = 0,
  }) async {
    for (final MapEntry<String, String> entry in sources.entries) {
      _offlineSources[entry.key] = _asLocalUri(entry.value);
    }
    await playQueue(songs, startIndex: startIndex);
  }

  void forgetOfflineSong(String songId) {
    _offlineSources.remove(songId);
  }

  String _asLocalUri(String pathOrUri) {
    final Uri? parsed = Uri.tryParse(pathOrUri);
    if (parsed != null && parsed.hasScheme) return parsed.toString();
    return Uri.file(pathOrUri).toString();
  }

  Future<void> seekTo(Duration position) => _player.seek(position);

  Future<void> seekFraction(double fraction) {
    if (_duration <= Duration.zero) return Future<void>.value();
    final double clamped = fraction.clamp(0.0, 1.0);
    return _player.seek(Duration(
        milliseconds: (_duration.inMilliseconds * clamped).round()));
  }

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));
  double get volume => _player.volume;

  Future<void> setSpeed(double v) async {
    await _settings.setPlaybackSpeed(v);
    await _player.setSpeed(v);
  }

  double get speed => _player.speed;

  Future<void> toggleShuffle() async {
    _shuffle = !_shuffle;
    await _player.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  Future<void> cycleLoopMode() async {
    _loopMode = switch (_loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(_loopMode);
    notifyListeners();
  }

  Future<void> next() {
    final Song? song = _current;
    if (song != null && _position < const Duration(seconds: 20)) {
      try {
        onTrackSkipped?.call(song);
      } catch (e) {
        debugPrint('onTrackSkipped failed: $e');
      }
    }
    return _advance(manual: true);
  }

  Future<void> previous() async {
    // Like every other player: rewind first, jump back only when we're near
    // the start.
    if (_position > const Duration(seconds: 4)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_queue.isEmpty) return;
    if (_shuffle && _queue.length > 1) {
      await _startSong(_randomIndex(excluding: _index));
      return;
    }
    final int target = _index - 1;
    if (target >= 0) {
      await _startSong(target);
    } else if (_loopMode == LoopMode.all) {
      await _startSong(_queue.length - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _startSong(index);
  }

  /// Sleep timer: pauses playback when it runs out.
  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepRemaining = duration;
    _sleepTimer = Timer(duration, () async {
      _expectPlayback = false;
      await _player.pause();
      _sleepRemaining = null;
      _sleepTicker?.cancel();
      notifyListeners();
    });
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepRemaining == null) return;
      _sleepRemaining = _sleepRemaining! - const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepRemaining = null;
    notifyListeners();
  }

  void dismissNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  // ============================================================ the engine
  //
  // Stream resolution with playback pre-validation.
  //
  // Under YouTube's 2026 anti-bot rules, getManifest() still succeeds but some
  // of the returned stream URLs (usually the highest-bitrate ones) return
  // HTTP 403 the moment the player fetches them — the player then fails with
  // "(0) source error" (youtube_explode_dart issue #332).
  //
  // Strategy:
  //  1. Ask each client (highest success rate first) for a manifest.
  //  2. Sort audio-only streams by bitrate (desc) and HEAD-probe each URL;
  //     use the first one that actually responds 200/206.
  //  3. If no audio-only stream is playable, try muxed (A/V) streams — they
  //     still play fine as audio.
  //  4. If a whole client yields nothing usable, fall through to the next.
  // ============================================================
  static final List<(String, YoutubeApiClient)> _streamClients =
      <(String, YoutubeApiClient)>[
    ('androidSdkless', YoutubeApiClient.androidSdkless), // v3 default, no PO-token
    ('ios', YoutubeApiClient.ios), // no PO-token, no deciphering
    ('androidVr', YoutubeApiClient.androidVr), // no PO-token
  ];

  Future<String> resolvePlayableStreamUrl(VideoId videoId) async {
    final String quality = _settings.qualityForConnection(wifi: await NativeBridge.isOnWifi());
    Object? lastError;

    for (final (String name, YoutubeApiClient client) in _streamClients) {
      try {
        final StreamManifest manifest = await _youtube.client.videos.streams
            .getManifest(videoId, ytClients: [client]);

        final StreamInfo? playable =
            await _firstPlayable(preferStreamQuality(
              _sortByBitrateDesc(manifest.audioOnly), quality)) ??
                await _firstPlayable(preferStreamQuality(
                  _sortByBitrateDesc(manifest.muxed), quality));

        if (playable != null) {
          debugPrint('[$name] using itag ${playable.tag} '
              '(${playable.container}, ${playable.bitrate})');
          return playable.url.toString();
        }
        debugPrint('[$name] manifest OK but no playable stream, '
            'falling back to next client...');
      } catch (e) {
        lastError = e;
        debugPrint('[$name] getManifest failed: $e');
      }
    }

    throw Exception('No playable stream found for this video '
        '(all clients/streams rejected)${lastError != null ? ' | last error: $lastError' : ''}');
  }

  List<T> _sortByBitrateDesc<T extends StreamInfo>(Iterable<T> streams) =>
      streams.toList()..sort((StreamInfo a, StreamInfo b) => b.bitrate.compareTo(a.bitrate));

  /// Returns the first stream whose URL is actually fetchable right now.
  ///
  /// We probe with a HEAD request — the exact same validity check
  /// youtube_explode_dart itself uses internally — because under the 2026
  /// anti-bot rules some URLs (usually the highest-bitrate ones) return 403
  /// and the player would fail with "(0) source error" (issue #332).
  Future<StreamInfo?> _firstPlayable(List<StreamInfo> candidates) async {
    if (candidates.isEmpty) return null;

    final HttpClient httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      for (final StreamInfo candidate in candidates) {
        try {
          final HttpClientRequest request =
              await httpClient.headUrl(candidate.url);
          final HttpClientResponse response =
              await request.close().timeout(const Duration(seconds: 6));
          await response.drain<void>().timeout(const Duration(seconds: 6));

          if (response.statusCode == HttpStatus.ok ||
              response.statusCode == HttpStatus.partialContent) {
            return candidate;
          }
          debugPrint('itag ${candidate.tag} -> HTTP ${response.statusCode}, '
              'trying next stream');
        } catch (e) {
          debugPrint('itag ${candidate.tag} probe failed: $e');
        }
      }
    } finally {
      httpClient.close(force: true);
    }
    return null;
  }

  // ----------------------------------------------------------- queue control
  AudioSource _sourceFor(Song song, String url) {
    final Uri? art = Uri.tryParse(song.thumbnailUrl);
    return AudioSource.uri(
      Uri.parse(url),
      tag: MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.subtitle ?? 'Saxify',
        artUri: art != null && art.hasScheme ? art : null,
        duration: song.duration,
      ),
    );
  }

  Future<void> _startSong(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final int generation = ++_generation;
    _recoveringStream = false;
    _recoveryToken++;
    _recoveredAt = null;
    _streamRetries = 0;
    _completionHandled = false;
    _expectPlayback = false;
    final Song song = _queue[index];
    await _flushPosition();
    if (generation != _generation) return;

    _index = index;
    _current = song;
    _isLoading = true;
    _position = Duration.zero;
    _duration = song.duration ?? Duration.zero;
    _lastSavedSecond = -1;
    notifyListeners();

    try {
      final String? local = _offlineSources[song.id];
      final String? cached = _prewarmed.remove(song.id);
      final String url = local ?? cached ?? await resolvePlayableStreamUrl(VideoId(song.id));
      if (generation != _generation) return;
      await _player.setAudioSource(_sourceFor(song, url));
      if (generation != _generation) return;
      await _player.setSpeed(_settings.playbackSpeed);

      final Duration? resume = _settings.resumePositionFor(song.id);
      if (resume != null && resume < (_player.duration ?? Duration.zero)) {
        await _player.seek(resume);
      }
      if (generation != _generation) return;
      // play() resolves on pause/end, not at the start of the track.
      _isLoading = false;
      _consecutiveFailures = 0;
      _notice = null;
      _startPlayerPlayback(song, generation);
      notifyListeners();

      _prewarmNext();
      try {
        await _library.recordPlay(song);
      } catch (e) {
        debugPrint('recordPlay failed: $e');
      }
      try {
        onTrackStarted?.call(song);
      } catch (e) {
        debugPrint('onTrackStarted failed: $e');
      }
      NotificationBootstrap.requestOnFirstPlay();
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      debugPrint('Playback load failed: $error\n$stackTrace');
      _isLoading = false;
      _consecutiveFailures++;
      _failedIds.add(song.id);
      notifyListeners();
      await _recover(song);
    }
  }

  void _startPlayerPlayback(Song song, [int? generation]) {
    _expectPlayback = true;
    final int startedFor = generation ?? _generation;
    try {
      // The play future catches only some errors; mid-stream ExoPlayer failures
      // also arrive on playbackEventStream and use the same guarded recovery.
      unawaited(_player.play().catchError((Object error, StackTrace stack) {
        if (startedFor == _generation) _handlePlaybackError(error);
      }));
    } catch (error) {
      _handlePlaybackError(error);
    }
  }

  void _handlePlaybackError(Object error) {
    final Song? song = _current;
    if (song == null || !_expectPlayback || _isLoading || _recoveringStream) return;
    final int generation = _generation;
    final Duration resumeAt = _player.position > _position ? _player.position : _position;
    _recoveringStream = true; // event stream and play().catchError can BOTH fire
    final int token = ++_recoveryToken;
    _isLoading = true;
    _notice = 'Connection interrupted — resuming from ${resumeAt.inSeconds}s…';
    debugPrint('Playback stream interrupted: $error');
    notifyListeners();
    unawaited(_retryInterruptedSong(song, resumeAt, generation, token));
  }

  Future<void> _retryInterruptedSong(
      Song song, Duration resumeAt, int generation, int token) async {
    try {
      // A new resolution avoids retrying the expired URL. Allow two attempts
      // with a short backoff before advancing to a playable queue item.
      while (_streamRetries < 2 && generation == _generation && _expectPlayback) {
        _streamRetries++;
        try {
          final String url = _offlineSources[song.id] ??
              await resolvePlayableStreamUrl(VideoId(song.id));
          if (generation != _generation || !_expectPlayback) return;
          await _player.setAudioSource(_sourceFor(song, url));
          if (generation != _generation || !_expectPlayback) return;
          final Duration length = _player.duration ?? song.duration ?? Duration.zero;
          final Duration seek = length > const Duration(seconds: 1) && resumeAt >= length
              ? length - const Duration(seconds: 1) : resumeAt;
          await _player.seek(seek);
          await _player.setSpeed(_settings.playbackSpeed);
          if (generation != _generation || !_expectPlayback) return;
          _isLoading = false;
          _notice = null;
          _recoveredAt = seek;
          // The replacement play() may fail synchronously. Allow its error
          // handler to start a second retry instead of swallowing the event.
          _recoveringStream = false;
          _startPlayerPlayback(song, generation);
          notifyListeners();
          return;
        } catch (error) {
          debugPrint('Stream re-resolve failed: $error');
          if (_streamRetries < 2) await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (generation == _generation && _expectPlayback) {
        _isLoading = false;
        _consecutiveFailures++;
        _failedIds.add(song.id);
        await _recover(song);
      }
    } finally {
      if (generation == _generation && token == _recoveryToken) {
        _recoveringStream = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Something went wrong with [failed] — move on instead of stopping.
  Future<void> _recover(Song failed) async {
    if (_consecutiveFailures >= 6) {
      _notice = 'Playback paused — too many tracks failed to stream. '
          'Check your connection and try again.';
      notifyListeners();
      return;
    }

    _notice = 'Couldn\'t stream "${_shortTitle(failed.title)}" — skipping to '
        'something similar';
    notifyListeners();

    final int nextIndex = _index + 1;
    if (nextIndex < _queue.length) {
      await _startSong(nextIndex);
      return;
    }

    final List<Song> similar = await _fetchMoreLike(failed);
    if (similar.isEmpty) {
      _notice = 'Nothing similar came back for "${_shortTitle(failed.title)}".';
      notifyListeners();
      return;
    }
    _queue.addAll(similar);
    notifyListeners();
    await _startSong(_index + 1);
  }

  void _onPlayerState(PlayerState state) {
    final bool playing =
        state.playing && state.processingState != ProcessingState.completed;
    final bool completed = state.processingState == ProcessingState.completed;

    if (playing != _isPlaying) {
      _isPlaying = playing;
      NativeBridge.setPlaybackWakeLock(playing);
      notifyListeners();
    }
    if (completed && _expectPlayback && !_isLoading &&
        !_completionHandled && !_recoveringStream) {
      _completionHandled = true;
      _expectPlayback = false;
      _isPlaying = false;
      NativeBridge.setPlaybackWakeLock(false);
      notifyListeners();
      _onTrackCompleted();
    }
  }

  void _onPosition(Duration p) {
    _position = p;
    // One interruption should not exhaust the retry budget for the entire
    // song. Once the recovered stream actually advances, allow a later blip.
    final Duration? recoveredAt = _recoveredAt;
    if (recoveredAt != null && p > recoveredAt + const Duration(seconds: 3)) {
      _streamRetries = 0;
      _recoveredAt = null;
    }
    // Persist a resume point every ~10 s instead of on every tick.
    final int second = p.inSeconds;
    if (second > 0 && second % 10 == 0 && second != _lastSavedSecond) {
      _lastSavedSecond = second;
      final Song? song = _current;
      if (song != null) _settings.saveResumePosition(song.id, p);
    }
  }

  Future<void> _flushPosition() async {
    final Song? song = _current;
    if (song == null) return;
    if (_position.inSeconds < 5) return;
    await _settings.saveResumePosition(song.id, _position);
  }

  Future<void> _onTrackCompleted() async {
    await _flushPosition();
    if (_loopMode == LoopMode.one) {
      await _player.seek(Duration.zero);
      _completionHandled = false;
      final Song? song = _current;
      if (song != null) _startPlayerPlayback(song);
      return;
    }
    await _advance(manual: false);
  }

  /// Move to the next track. When the queue runs out we pull related videos so
  /// the music keeps going, exactly like the web app.
  Future<void> _advance({required bool manual}) async {
    if (_queue.isEmpty) return;

    if (_shuffle && _queue.length > 1) {
      await _startSong(_randomIndex(excluding: _index));
      return;
    }

    final int nextIndex = _index + 1;
    if (nextIndex < _queue.length) {
      await _startSong(nextIndex);
      return;
    }

    if (_loopMode == LoopMode.all) {
      await _startSong(0);
      return;
    }

    if (!manual && !_settings.autoplay) {
      _expectPlayback = false;
      await _player.stop();
      return;
    }

    // Queue exhausted → keep the vibe going with related tracks.
    final Song? anchor = _current ?? (_queue.isEmpty ? null : _queue.last);
    if (anchor == null) return;

    _notice = 'Queue finished — loading similar tracks';
    notifyListeners();

    final List<Song> similar = await _fetchMoreLike(anchor);
    if (similar.isEmpty) {
      _notice = null;
      await _player.stop();
      notifyListeners();
      return;
    }
    _queue.addAll(similar);
    _notice = null;
    notifyListeners();
    await _startSong(_index + 1);
  }

  int _randomIndex({int excluding = -1}) {
    if (_queue.length <= 1) return 0;
    int candidate = _random.nextInt(_queue.length);
    int guard = 0;
    while (candidate == excluding && guard < 8) {
      candidate = _random.nextInt(_queue.length);
      guard++;
    }
    return candidate;
  }

  Future<List<Song>> _fetchMoreLike(Song anchor) async {
    final Set<String> known = <String>{
      ..._failedIds,
      ..._queue.map((Song s) => s.id),
    };

    List<Song> result = <Song>[];
    try {
      result = await _youtube.similarSongs(anchor.id, limit: 12, exclude: known);
    } catch (e) {
      debugPrint('similarSongs(${anchor.id}) failed: $e');
    }

    if (result.isEmpty) {
      // Fall back to a plain search for the same artist / title.
      try {
        result = await _youtube.searchSongs('${anchor.artist} mixes', limit: 12);
      } catch (e) {
        debugPrint('fallback search failed: $e');
      }
    }

    return result.where((Song s) => !known.contains(s.id)).toList();
  }

  /// Resolve the next track's URL while the current one plays, so the changeover
  /// is instant (the app's "gapless playback" setting).
  void _prewarmNext() {
    if (!_settings.gapless) return;
    final int nextIndex = _index + 1;
    if (nextIndex < 0 || nextIndex >= _queue.length) return;
    final Song song = _queue[nextIndex];
    if (_prewarmed.containsKey(song.id) || _offlineSources.containsKey(song.id)) return;

    () async {
      try {
        final String url = await resolvePlayableStreamUrl(VideoId(song.id));
        _prewarmed[song.id] = url;
        if (_prewarmed.length > 3) {
          _prewarmed.remove(_prewarmed.keys.first);
        }
      } catch (e) {
        debugPrint('prewarm ${song.id} failed: $e');
      }
    }();
  }

  static String _shortTitle(String title) =>
      title.length <= 34 ? title : '${title.substring(0, 34)}…';

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    NativeBridge.setPlaybackWakeLock(false);
    _errorSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
