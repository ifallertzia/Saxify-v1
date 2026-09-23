/// Orders already bitrate-sorted streams. Low and medium really request less
/// data; high tries the best playable bitrate first. Failed URLs still fall
/// through to the other qualities before skipping the song.
List<T> preferStreamQuality<T>(List<T> bestFirst, String quality) {
  if (quality == 'low') return bestFirst.reversed.toList();
  if (quality != 'medium' || bestFirst.length < 3) return bestFirst;
  final int middle = bestFirst.length ~/ 2;
  return <T>[
    bestFirst[middle],
    for (int step = 1; step < bestFirst.length; step++) ...<T>[
      if (middle - step >= 0) bestFirst[middle - step],
      if (middle + step < bestFirst.length) bestFirst[middle + step],
    ],
  ];
}
