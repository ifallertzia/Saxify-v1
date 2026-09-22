/// On-device ranking. No network, no Flutter bindings — safe to unit test.
class RecoTrack {
  const RecoTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.genre,
    this.bpm,
    this.moods = const <String>[],
    this.thumbnailUrl = '',
    this.channelId,
    this.durationMs,
  });

  final String id;
  final String title;
  final String artist;
  final String? genre;
  final int? bpm;
  final List<String> moods;
  final String thumbnailUrl;
  final String? channelId;
  final int? durationMs;
}

class RecoSignals {
  const RecoSignals({
    this.current,
    this.recentIds = const <String>[],
    this.repeatedQueries = const <String>[],
    this.likedIds = const <String>{},
    this.skippedIds = const <String>{},
  });

  final RecoTrack? current;
  final List<String> recentIds;
  final List<String> repeatedQueries;
  final Set<String> likedIds;
  final Set<String> skippedIds;
}

class RecommendationEngine {
  const RecommendationEngine._();

  /// Weights from the v2 brief. Missing bpm/genre simply does not score.
  static const double artistWeight = 0.30;
  static const double genreWeight = 0.25;
  static const double bpmWeight = 0.20;
  static const double moodWeight = 0.25;

  static double similarity(RecoTrack candidate, RecoTrack? current) {
    if (current == null) return 0;
    if (candidate.id == current.id) return -1;
    double score = 0;
    if (_same(candidate.artist, current.artist)) score += artistWeight;
    if (candidate.genre != null &&
        current.genre != null &&
        _same(candidate.genre!, current.genre!)) {
      score += genreWeight;
    }
    if (candidate.bpm != null &&
        current.bpm != null &&
        (candidate.bpm! - current.bpm!).abs() <= 15) {
      score += bpmWeight;
    }
    if (_moodOverlap(candidate.moods, current.moods)) score += moodWeight;
    return score;
  }

  /// 60% similar-to-current, 30% search-driven, 10% discovery.
  /// Never returns the current song or anything in the last 10 plays.
  static List<RecoTrack> mix({
    required List<RecoTrack> similar,
    required List<RecoTrack> searchDriven,
    required List<RecoTrack> discovery,
    required RecoSignals signals,
    int limit = 12,
  }) {
    final Set<String> blocked = <String>{
      if (signals.current != null) signals.current!.id,
      ...signals.recentIds.take(10),
    };

    List<RecoTrack> clean(List<RecoTrack> input) {
      final List<RecoTrack> out = <RecoTrack>[];
      final Set<String> seen = <String>{};
      for (final RecoTrack track in input) {
        if (blocked.contains(track.id) || seen.contains(track.id)) continue;
        if (signals.current != null && track.id == signals.current!.id) continue;
        seen.add(track.id);
        out.add(track);
      }
      out.sort((RecoTrack a, RecoTrack b) {
        final double sb = similarity(b, signals.current) + _boost(b, signals);
        final double sa = similarity(a, signals.current) + _boost(a, signals);
        return sb.compareTo(sa);
      });
      return out;
    }

    final List<RecoTrack> sim = clean(similar);
    final List<RecoTrack> searched = clean(searchDriven);
    final List<RecoTrack> found = clean(discovery);

    final int simCount = (limit * 0.60).round();
    final int searchCount = (limit * 0.30).round();
    final int discCount = limit - simCount - searchCount;

    final List<RecoTrack> picked = <RecoTrack>[];

    // Take by walking each bucket with an explicit cap.
    int added = 0;
    for (final RecoTrack track in sim) {
      if (added >= simCount || picked.length >= limit) break;
      picked.add(track);
      added++;
    }
    added = 0;
    for (final RecoTrack track in searched) {
      if (added >= searchCount || picked.length >= limit) break;
      if (picked.any((RecoTrack p) => p.id == track.id)) continue;
      picked.add(track);
      added++;
    }
    added = 0;
    for (final RecoTrack track in found) {
      if (added >= discCount || picked.length >= limit) break;
      if (picked.any((RecoTrack p) => p.id == track.id)) continue;
      picked.add(track);
      added++;
    }
    // Fill leftovers from any bucket so a thin shelf is never empty.
    for (final RecoTrack track in <RecoTrack>[...sim, ...searched, ...found]) {
      if (picked.length >= limit) break;
      if (picked.any((RecoTrack p) => p.id == track.id)) continue;
      picked.add(track);
    }
    return picked;
  }

  static double _boost(RecoTrack track, RecoSignals signals) {
    double extra = 0;
    if (signals.likedIds.contains(track.id)) extra += 0.15;
    if (signals.skippedIds.contains(track.id)) extra -= 0.25;
    final String blob = '${track.title} ${track.artist}'.toLowerCase();
    for (final String query in signals.repeatedQueries) {
      final String q = query.toLowerCase().trim();
      if (q.length < 2) continue;
      if (blob.contains(q)) extra += 0.20;
    }
    return extra;
  }

  static bool _same(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  static bool _moodOverlap(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return false;
    final Set<String> left = a.map((String m) => m.toLowerCase()).toSet();
    for (final String mood in b) {
      if (left.contains(mood.toLowerCase())) return true;
    }
    return false;
  }
}
