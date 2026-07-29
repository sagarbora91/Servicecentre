import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_activity_repository.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/repositories/activity_repository.dart';

/// The app's [ActivityRepository]. Override this (or `firestoreProvider`) in
/// tests.
final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => FirestoreActivityRepository(firestore: ref.watch(firestoreProvider)),
);

/// Streams the most recent activity-log entries (newest first, capped at 100).
final recentActivityProvider = StreamProvider<List<ActivityEntry>>(
  (ref) => ref.watch(activityRepositoryProvider).watchRecent(100),
);
