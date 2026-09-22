import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'recommendation_store.dart';

/// Re-ranks the on-device cache every 6 hours. Does not touch playback.
@pragma('vm:entry-point')
void saxifyRecommendationDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? input) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final RecommendationStore store = RecommendationStore();
      await store.open();
      await store.touchCache();
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> registerRecommendationRefresh() async {
  await Workmanager().initialize(saxifyRecommendationDispatcher);
  await Workmanager().registerPeriodicTask(
    'saxify-reco',
    'refreshRecommendations',
    frequency: const Duration(hours: 6),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
