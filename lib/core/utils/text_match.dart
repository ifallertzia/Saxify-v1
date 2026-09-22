/// Lightweight name matching. No extra packages — used for artist routing.
class TextMatch {
  const TextMatch._();

  static String norm(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 1.0 is an exact match. 0.0 is unrelated.
  static double score(String query, String candidate) {
    final String a = norm(query);
    final String b = norm(candidate);
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    if (b.startsWith('$a ') || a.startsWith('$b ')) return 0.92;
    if (b.contains(a) || a.contains(b)) return 0.85;

    final int dist = _levenshtein(a, b);
    final int maxLen = a.length > b.length ? a.length : b.length;
    final double ratio = 1 - (dist / maxLen);
    return ratio.clamp(0.0, 1.0);
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    // Cap work so a pathological title cannot hitch the UI isolate.
    if (a.length > 64) a = a.substring(0, 64);
    if (b.length > 64) b = b.substring(0, 64);

    final List<int> prev = List<int>.generate(b.length + 1, (int i) => i);
    final List<int> curr = List<int>.filled(b.length + 1, 0);
    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final int cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final int del = prev[j] + 1;
        final int ins = curr[j - 1] + 1;
        final int sub = prev[j - 1] + cost;
        int best = del < ins ? del : ins;
        if (sub < best) best = sub;
        curr[j] = best;
      }
      for (int j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }
}
