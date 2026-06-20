# CLAUDE.md — Service Centre Management App

Guardrails for Claude Code working in this repo. Read this first, then `BUILD_BRIEF.md`.

## What this is
A Flutter + Firebase app to run a watch service centre: jobs, customers, inventory, billing, warranty, messaging, reports. Offline-first. Bilingual (English/Marathi/Hindi). Built milestone by milestone — see `BUILD_BRIEF.md` §12.

## Golden rules (do not violate)
1. **Build in milestone order (M0→M11).** Don't skip ahead; later milestones depend on earlier ones.
2. **Tests are part of every feature.** Model → repo → provider → UI → tests. No feature is "done" without unit + widget tests and an integration test for new flows. Coverage ≥ 80% on `data`+`domain`.
3. **Transactions for stock and money.** Any change to `parts.onHand`/`reserved` or payments runs inside a Firestore transaction. Stock can never go negative.
4. **Delivery is gated.** A job cannot reach `delivered` without a complete QC map and at least one delivery photo.
5. **No secrets in code.** Firebase config, WhatsApp/SMS keys → env/flavors/Secret Manager. Leave `[PLACEHOLDER]` and note it; never invent keys.
6. **Layering is strict.** `domain` has no Firebase imports. `presentation` never touches Firestore directly — only repository interfaces via Riverpod providers.
7. **Money in paise (int). Dates UTC in storage.** Format for display only.
8. **Role checks in UI AND in `firestore.rules`.** Never rely on client checks alone.
9. **Every write logs to `activityLog`.**
10. **Localize all strings** (en/mr/hi). No hardcoded user-facing text.

## Architecture (where things go)
- Feature-first: `lib/features/<feature>/{data,domain,presentation}`.
- `domain`: freezed entities + repository interfaces. `data`: Firestore impls + converters. `presentation`: Riverpod providers + widgets.
- Errors: repositories return `Result<T>` (`Ok`/`Err(Failure)`); UI renders loading/error/empty via `core/widgets`.
- Full structure + schema in `BUILD_BRIEF.md` §3 and §5.

## Commands
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after model/provider changes
flutter analyze                                             # must be clean
flutter test --coverage                                     # must pass
firebase emulators:start                                    # local backend
dart run bootstrap/seed.dart --target=emulator --set=demo   # dummy data
firebase emulators:exec "flutter test integration_test"     # e2e on emulator
firebase deploy --only firestore:rules,firestore:indexes,functions,storage
```

## Definition of Done (check before saying a milestone is complete)
See `BUILD_BRIEF.md` §13. In short: spec met, tests written + passing, coverage ≥80%, analyze clean, rules+indexes updated, all UI states handled, offline works, roles enforced, localized, seed covers edge cases, no secrets.

## Workflow per task
1. Re-read the milestone in `BUILD_BRIEF.md` §12 and its acceptance criteria.
2. Write the model/repo/provider, then the UI, then the tests.
3. Run `flutter analyze` + `flutter test`; for flows, run the emulator integration test.
4. Update `firestore.rules`/`firestore.indexes.json` and seed data for new edge cases.
5. Stop at the end of each milestone and report acceptance status. **Pause after M6 (MVP) for human review before M7.**

## Do NOT
- Add `drift`/`sqflite` unless explicitly told (default storage = Firestore offline persistence).
- Put business logic in widgets, or Firestore calls in `presentation`.
- Use floats for money.
- Build multiple milestones in one pass without tests.
- Hardcode `branchId`, project IDs, or provider keys.

## Ask the human when
You hit an "open decision" from `BUILD_BRIEF.md` §14 (jobNo scheme, GST rates/HSN, WhatsApp BSP, QC items, branch list) — leave a `[PLACEHOLDER]` and flag it rather than guessing.
