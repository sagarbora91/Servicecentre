import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase service instances exposed as Riverpod providers, so the only place
/// in `lib/` that imports `firebase_auth`/`cloud_firestore` (besides feature
/// `data/` layers) is here. Tests override these with mocks/fakes.

/// The [FirebaseAuth] instance. Overridden in tests with a mock.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// The [FirebaseFirestore] instance. Overridden in tests with a fake.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
