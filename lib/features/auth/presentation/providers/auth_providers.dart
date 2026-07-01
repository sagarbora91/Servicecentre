import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// The app's [AuthRepository]. Override this (or the Firebase providers in
/// `core/firebase/firebase_providers.dart`) in tests.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);

/// Streams the signed-in UID (or `null`). Drives router redirects.
final authUidProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Streams the current user's `users/{uid}` profile, or `null` when signed out
/// or when no/invalid profile exists.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authUidProvider).valueOrNull;
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUser(uid);
});
