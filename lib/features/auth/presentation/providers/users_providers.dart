import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/firestore_users_repository.dart';
import '../../domain/repositories/users_repository.dart';

/// The app's [UsersRepository], backing the owner-only "manage staff" admin.
///
/// Override this (or the Firebase providers in
/// `core/firebase/firebase_providers.dart`) in tests.
final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => FirestoreUsersRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);
