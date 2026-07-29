// The broad catch in [bootstrap] is intentional: during M0 the Firebase config
// is a placeholder, so initialization is expected to throw and is tolerated so
// the app still boots. M1 makes Firebase init mandatory and revisits this.
// ignore_for_file: avoid_catches_without_on_clauses
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Initializes Firebase and App Check before the app runs.
///
/// During M0 the Firebase config is a placeholder
/// ([DefaultFirebaseOptions]), so initialization is attempted but any failure
/// is tolerated — the app still boots to its placeholder home. Real config
/// arrives in M1 via `flutterfire configure`, after which it is mandatory.
///
/// Firestore offline persistence is enabled here (M5, BUILD_BRIEF.md §5): the
/// app is offline-first, so reads are served from the local cache and writes
/// are queued and synced automatically when connectivity returns. On
/// Android/iOS persistence is the platform default; setting it explicitly also
/// covers web and documents the intent. End-to-end offline verification needs a
/// real device (the emulator/CI cannot toggle connectivity), so it is exercised
/// during device QA rather than in CI.
Future<void> bootstrap() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await FirebaseAppCheck.instance.activate(
      // [PLACEHOLDER] Debug providers for dev; real providers (Play Integrity /
      // DeviceCheck / reCAPTCHA) are wired for staging+prod in §10.
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } catch (error, stackTrace) {
    // Expected until `flutterfire configure` is run. Log and continue so M0
    // still boots; M1 makes Firebase initialization mandatory.
    debugPrint('Firebase init skipped (placeholder config): $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
