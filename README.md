# Service Centre Management App

Flutter + Firebase app to run a watch service centre (jobs, customers, inventory,
billing, warranty, messaging, reports). Offline-first. Trilingual (en/mr/hi).

> Source of truth: [`BUILD_BRIEF.md`](BUILD_BRIEF.md) (how to build) and
> [`CLAUDE.md`](CLAUDE.md) (guardrails). Built milestone by milestone (brief §12).

## Status

**M0 — Scaffold & CI: written, pending first-run verification.** Authored without
a local Flutter SDK; not yet `Done` per the Definition of Done (§13) until the
steps below pass.

## First-time setup (run once, after installing Flutter)

```bash
# 1. Generate the platform folders (android/ios/web). Preserves existing lib/.
flutter create . --project-name service_centre_app --org com.saagar \
  --platforms=android,ios,web

# 2. Resolve dependencies + localization.
flutter pub get
flutter gen-l10n

# 3. Verify M0 (acceptance: analyze clean, widget test passes, app boots).
flutter analyze
flutter test
flutter run -d chrome        # should boot to the placeholder home

# 4. Firebase config (human-run; replaces the placeholder firebase_options.dart).
dart pub global activate flutterfire_cli   # if not already
flutterfire configure                       # creates lib/firebase_options.dart
```

## Environment config

Copy `config/dev.example.json` → `config/dev.json` (git-ignored) and fill values.
Run with `--dart-define-from-file=config/dev.json`. Never commit real project IDs
or keys (brief §10).

## Open decisions (must confirm with the owner — see brief §14)

- Sequential `jobNo` scheme
- GST rate(s) / HSN-SAC codes
- WhatsApp BSP choice
- Exact QC checklist items
- Branch list (used for `branchId` everywhere)
