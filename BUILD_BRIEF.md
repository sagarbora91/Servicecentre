# Service Centre Management App — Engineering Build Brief

> Build-ready specification for **Claude Code**. Companion to `CLAUDE.md` (agent guardrails) and the product plan (`Service_Centre_App_Plan_v2`). This document is the source of truth for *how* to build.

---

## 0. How Claude Code should use this brief

1. Read `CLAUDE.md` first (conventions + guardrails), then this file.
2. Build **milestone by milestone** (§12), in order. Do not skip ahead — later milestones depend on earlier ones.
3. For every feature: write the model → repository → provider → UI → **tests**, in that order.
4. After each milestone: run `flutter analyze` and `flutter test` (and emulator tests where relevant). A milestone is **not done** until its acceptance criteria (§12) and Definition of Done (§13) pass.
5. Never invent secrets, API keys, or Firebase config — read from env/flavors (§10) and leave `[PLACEHOLDER]` where a human must supply a value.
6. When a package version is unknown, run `flutter pub add <pkg>` to resolve the latest compatible version; versions below are indicative.

---

## 1. Stack & versions (indicative — resolve latest stable)

| Layer | Choice |
|---|---|
| Language / SDK | Dart 3.x, Flutter 3.x (stable channel) |
| State management | `flutter_riverpod` + `riverpod_annotation` (codegen) |
| Routing | `go_router` |
| Models / immutability | `freezed` + `json_serializable` |
| Local (offline-first) | Cloud Firestore offline persistence (SQLite-backed). Optional `drift` only if raw SQL needed — **default: Firestore persistence** |
| Backend | Firebase: Auth, Firestore, Storage, Cloud Functions (TypeScript), FCM, App Check, Crashlytics, Analytics, Remote Config |
| Functions runtime | Node.js 20, TypeScript, `firebase-functions` v2 |
| Testing | `flutter_test`, `mocktail`, `fake_cloud_firestore`, `firebase_auth_mocks`, `integration_test`, `golden_toolkit` |
| Tooling | `very_good_analysis` (lints), `build_runner`, `melos` (optional if multi-package) |
| CI | GitHub Actions |

---

## 2. Repository & project setup

```bash
# 1. Scaffold
flutter create --org com.saagar --platforms=android,ios,web service_centre_app
cd service_centre_app

# 2. Core deps
flutter pub add flutter_riverpod riverpod_annotation go_router freezed_annotation json_annotation \
  firebase_core firebase_auth cloud_firestore firebase_storage cloud_functions firebase_messaging \
  firebase_app_check firebase_crashlytics firebase_analytics firebase_remote_config \
  intl uuid collection cached_network_image flutter_image_compress image_picker \
  csv file_picker share_plus pdf printing qr_flutter mobile_scanner fl_chart \
  google_sign_in googleapis connectivity_plus
flutter pub add -d build_runner freezed json_serializable riverpod_generator very_good_analysis \
  mocktail fake_cloud_firestore firebase_auth_mocks golden_toolkit

# 3. Firebase
dart pub global activate flutterfire_cli
flutterfire configure        # creates firebase_options.dart  (human runs once)
firebase init firestore functions storage emulators

# 4. Codegen (run after model/provider changes)
dart run build_runner build --delete-conflicting-outputs
```

**Flavors / environments:** `dev`, `staging`, `prod` (see §10). Use `--dart-define-from-file` for config; never hardcode project IDs or keys.

---

## 3. Architecture & folder structure

**Pattern:** feature-first, 3 layers per feature (`data` → `domain` → `presentation`). Repository pattern. Riverpod for DI + state. No business logic in widgets.

```
lib/
  main.dart                      # bootstrap: Firebase init, App Check, ProviderScope, runApp
  app/
    app.dart                     # MaterialApp.router, theme, localization
    router.dart                  # GoRouter config + route guards (role-based)
    theme.dart
    l10n/                        # ARB files: app_en.arb, app_mr.arb, app_hi.arb
  core/
    errors/                      # Failure types, AppException, Result<T>
    firebase/                    # firestore refs, converters, transaction helpers
    network/                     # connectivity, offline status provider
    utils/                       # formatters (date, currency ₹), validators, id gen
    widgets/                     # shared widgets (loaders, error views, empty states)
    constants/                   # collection names, enums, roles
  features/
    auth/        {data,domain,presentation}
    jobs/        {data,domain,presentation}     # job lifecycle + board (core)
    customers/   {data,domain,presentation}
    inventory/   {data,domain,presentation}
    billing/     {data,domain,presentation}
    warranty/    {data,domain,presentation}
    reports/     {data,domain,presentation}
    messaging/   {data,domain,presentation}     # whatsapp/sms triggers (client side)
    settings/    {data,domain,presentation}
  bootstrap/
    seed.dart                    # dev/demo seed (see §9)
functions/                       # Cloud Functions (TypeScript)
  src/
    index.ts
    reminders/   followups.ts
    messaging/   whatsapp.ts  sms.ts
    inventory/   stock.ts  grn.ts
    stats/       dailyStats.ts
    backup/      driveExport.ts
test/
  unit/        # domain + repositories
  widget/      # screens/widgets
  golden/      # golden images
integration_test/
  flows/       # end-to-end flows on emulator
firestore.rules
firestore.indexes.json
storage.rules
.github/workflows/ci.yml
```

**Layer rules**

- `domain`: entities (freezed), repository **interfaces**, use-cases (optional). No Firebase imports.
- `data`: repository **implementations**, DTOs/converters, datasources (Firestore/Storage). Maps Firebase ↔ domain.
- `presentation`: Riverpod providers/notifiers + widgets/screens. Talks only to repository interfaces via providers.

---

## 4. Coding standards & conventions

- **Lints:** `very_good_analysis` in `analysis_options.yaml`; CI fails on warnings.
- **Naming:** files `snake_case`; classes `PascalCase`; providers `<thing>Provider`; notifiers `<Thing>Notifier`.
- **Immutability:** all models are `freezed`; no mutable public fields.
- **Errors:** repositories return `Result<T>` (`sealed class Result` = `Ok<T>` | `Err(Failure)`). UI maps `Failure` → user message. Never `throw` across layers; log via Crashlytics in `data`.
- **Async UI:** use `AsyncValue` from Riverpod; always render loading/error/empty states (use `core/widgets`).
- **Money:** store amounts as integer **paise** (avoid float); format with a `₹` helper.
- **Dates:** UTC in storage; local display via `intl`.
- **No business logic in widgets.** No direct Firestore access from `presentation`.
- **Git:** conventional commits (`feat:`, `fix:`, `test:`, `chore:`); one feature per branch; PR must pass CI.
- **Security:** every write path re-checks role; never trust client-only checks (mirror in Firestore rules).

---

## 5. Data layer & schema

**Strategy:** Firestore is the system of record; offline persistence ON (`Settings(persistenceEnabled: true)`), so the app works offline and syncs automatically. All writes that change stock or money use **Firestore transactions**.

### 5.1 Collections (field : type)

> Every doc also has: `branchId: string`, `createdAt: Timestamp`, `createdBy: string (uid)`, `updatedAt: Timestamp`.

```
users/{uid}
  name:string  role:enum[owner,supervisor,counter,technician]  phone:string  active:bool

customers/{id}
  name:string  phone:string  email:string?  address:string?
  serviceCount:int  consentWhatsApp:bool  lastVisitAt:Timestamp?

watches/{id}
  customerId:ref  brand:string  model:string  serial:string?
  warrantyUntil:Timestamp?  photos:[string]

jobs/{id}
  jobNo:string(unique, sequential per branch)  customerId:ref  watchId:ref?
  sourceStore:string?                         # inter-store flow
  status:enum[received,diagnosed,awaiting_part,in_repair,qc,ready,delivered,returned]
  fault:string  workRequested:string
  assignedTo:uid?  tatTargetHrs:int  dueAt:Timestamp
  intakePhotos:[string]  deliveryPhotos:[string]
  qc:map{timekeeping:bool, gasket:bool, glassClean:bool, strap:bool, crown:bool}?
  partsUsed:[map{partId:ref, qty:int, ref:string}]
  outcome:enum[repaired,declined,beyond_repair,returned]?
  warrantyType:enum[in_warranty,paid,goodwill]?
  isRework:bool  parentJobId:ref?
  amountPaise:int?  paymentStatus:enum[unbilled,unpaid,partial,paid]
  statusHistory:[map{status, at, by}]

estimates/{id}    jobId:ref  lines:[map{desc,amountPaise}]  totalPaise:int
                  status:enum[draft,sent,approved,declined]  approvedVia:string?  approvedAt:Timestamp?
invoices/{id}     jobId:ref  number:string  lines:[map{desc,hsn,qty,ratePaise,gstPct}]
                  taxablePaise:int  taxPaise:int  totalPaise:int  paymentStatus:enum
payments/{id}     invoiceId:ref  amountPaise:int  mode:enum[cash,upi,card]  ref:string?  at:Timestamp  by:uid

parts/{id}        category:string  reference:string  size:string?  binCode:string
                  onHand:int  reserved:int  minLevel:int  reorderPoint:int
                  serviceOnly:bool  mfgDate:Timestamp?  costPaise:int  mrpPaise:int
stockMovements/{id}  partId:ref  type:enum[in,out,adjust,grn,reserve,release]  qty:int
                     jobId:ref?  orderId:ref?  at:Timestamp  by:uid
suppliers/{id}    name:string  type:enum[titan,strap,other]  contact:string?
orders/{id}       supplierId:ref  status:enum[draft,placed,partial,received,cancelled]
                  items:[map{partId,qtyOrdered,qtyReceived,model}]  placedBy:uid  approvedBy:uid?
                  expectedAt:Timestamp?  receipts:[map{at,by,lines}]
stockTakes/{id}   date:Timestamp  branchId:string  lines:[map{partId,counted,system,variance}]  by:uid
warranties/{id}   jobId:ref  type:enum  titanClaimNo:string?  status:enum  repairWarrantyUntil:Timestamp?
messages/{id}     jobId:ref?  customerId:ref  channel:enum[whatsapp,sms,push]
                  template:string  to:string  status:enum[queued,sent,delivered,failed]  sentAt:Timestamp?
reminders/{id}    type:enum[battery,overdue,uncollected,order_delay,approval]
                  dueAt:Timestamp  jobId:ref?  customerId:ref?  status:enum[pending,done,cancelled]
attachments/{id}  jobId:ref  kind:string  storagePath:string  by:uid  at:Timestamp
feedback/{id}     jobId:ref  rating:int(1-5)  comment:string?  at:Timestamp
activityLog/{id}  actor:uid  action:string  entity:string  entityId:string  before:map?  after:map?  at:Timestamp
dailyStats/{date_branch}  jobsDone:int  avgTatHrs:num  firstTimeFixPct:num  comebacks:int
                          revenuePaise:int  collectionsPaise:int
settings/{branchId}  categories:[string]  tatTargets:map  rateCard:map  taxRates:map  templates:map
```

### 5.2 Indexes (`firestore.indexes.json`)

Composite indexes (create as features are built):
- `jobs`: `branchId ASC, status ASC, dueAt ASC` (board)
- `jobs`: `branchId ASC, customerId ASC, createdAt DESC` (history)
- `parts`: `branchId ASC, category ASC, reference ASC`
- `stockMovements`: `partId ASC, at DESC`
- `reminders`: `status ASC, dueAt ASC` (functions)

### 5.3 Security rules (skeleton — `firestore.rules`)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function role() { return get(/databases/$(db)/documents/users/$(request.auth.uid)).data.role; }
    function signedIn() { return request.auth != null; }
    function isStaff() { return signedIn() && role() in ['owner','supervisor','counter','technician']; }
    function canFinance() { return role() in ['owner','supervisor']; }

    match /jobs/{id}   { allow read: if isStaff(); allow write: if isStaff(); }
    match /invoices/{id}{ allow read, write: if canFinance(); }
    match /payments/{id}{ allow read, write: if canFinance(); }
    match /parts/{id}  { allow read: if isStaff();
                          allow write: if role() in ['owner','supervisor','store']; }
    match /users/{id}  { allow read: if isStaff(); allow write: if role()=='owner'; }
    // default deny
    match /{document=**} { allow read, write: if false; }
  }
}
```

### 5.4 Model + repository pattern (example)

```dart
// domain/entities/job.dart
@freezed
class Job with _$Job {
  const factory Job({ required String id, required String jobNo, required JobStatus status, /* ... */ }) = _Job;
  factory Job.fromJson(Map<String,dynamic> j) => _$JobFromJson(j);
}

// domain/repositories/jobs_repository.dart
abstract interface class JobsRepository {
  Stream<List<Job>> watchBoard(String branchId);
  Future<Result<Job>> create(JobDraft draft);
  Future<Result<void>> moveStatus(String id, JobStatus to, String uid);
  Future<Result<void>> deliver(String id, DeliveryData d);   // gated on QC + photo
}

// data/repositories/firestore_jobs_repository.dart  -> implements JobsRepository
// presentation/providers/jobs_providers.dart        -> @riverpod board(...) => repo.watchBoard()
```

---

## 6. Cloud Functions (TypeScript, v2)

| Function | Trigger | Does |
|---|---|---|
| `onJobStatusChange` | Firestore `jobs` update | writes `activityLog`, queues `messages` (received/ready) |
| `scheduledFollowups` | scheduler (daily) | scans `reminders`/jobs → queues battery/overdue/uncollected/order-delay/approval messages |
| `sendMessage` | Firestore `messages` create | calls WhatsApp BSP / SMS gateway; updates status |
| `onStockMovement` | Firestore `stockMovements` create | recomputes `parts.onHand`/`reserved` in a transaction |
| `rollupDailyStats` | scheduler (daily) | writes `dailyStats` summaries |
| `driveExport` | callable / scheduler | exports CSV/PDF to the owner's Drive folder |
| `setUserRole` | callable (owner only) | sets Auth custom claim `role` |

Run locally with the **Firebase Emulator Suite**; functions are covered by emulator integration tests (§8).

---

## 7. Feature specs (MVP modules — screens, providers, acceptance)

> Format per module: **Screens** · **Key providers/repo methods** · **Acceptance criteria**. Build only MVP modules in M3–M6; later modules in their milestones.

**Jobs & board**
- Screens: Board (Kanban columns by `status`), Job detail, New job (intake).
- Providers: `boardProvider(branchId)` (stream), `jobControllerProvider`. Repo: `watchBoard`, `create`, `moveStatus`, `deliver`.
- Acceptance: create job → appears in `received`; drag/move updates status + `statusHistory`; **cannot move to `delivered` unless QC map complete AND ≥1 delivery photo**; search finds it (§ search).

**Customers & watches**
- Screens: Customer search/list, Customer detail (+ service history), Add/edit.
- Acceptance: phone de-dupe on create; opening a customer lists their past jobs (most recent first).

**Inventory (basic)**
- Screens: Parts list (filter by category/bin), Part detail, Stock adjust.
- Acceptance: logging `partsUsed` on a job **decrements `onHand` in a transaction**; cannot go below 0; movement recorded.

**Intake photos + offline**
- Acceptance: capture/compress/upload intake & delivery photos; **works fully offline** (create a job with no network, see it sync when back online).

**Search + QR box-label**
- Acceptance: search by phone/jobNo/serial/name returns the job < 1s; print a label with `jobNo` + customer + QR; scanning the QR opens the job.

---

## 8. Testing strategy

**Pyramid & targets:** ~70% unit, ~20% widget, ~10% integration. **Coverage gate: ≥ 80% on `domain` + `data`.** Every bug fix adds a regression test.

### 8.1 Unit (domain + repositories) — `mocktail`, `fake_cloud_firestore`

```dart
test('logging parts decrements stock and never goes negative', () async {
  final fs = FakeFirebaseFirestore();
  await fs.collection('parts').doc('p1').set({'onHand': 1, 'reserved': 0});
  final repo = FirestoreInventoryRepository(fs);
  final r1 = await repo.consume(partId: 'p1', qty: 1, jobId: 'j1');
  expect(r1.isOk, true);
  final r2 = await repo.consume(partId: 'p1', qty: 1, jobId: 'j2');
  expect(r2.isErr, true);            // insufficient stock
  final p = await fs.collection('parts').doc('p1').get();
  expect(p['onHand'], 0);
});
```

### 8.2 Widget tests — `flutter_test`, `ProviderScope` overrides

```dart
testWidgets('deliver button disabled until QC complete + photo', (t) async {
  await t.pumpWidget(ProviderScope(
    overrides: [jobProvider('j1').overrideWith((_) => jobAwaitingQc())],
    child: const MaterialApp(home: JobDetailScreen(id: 'j1')),
  ));
  expect(tester.widget<ElevatedButton>(find.byKey(const Key('deliverBtn'))).onPressed, isNull);
});
```

### 8.3 Integration (`integration_test/`) — on Firebase Emulator

Cover end-to-end flows: **intake → repair → QC → deliver**, **order → GRN → stock up**, **offline create → reconnect → sync**, **login per role → see allowed screens only**.

### 8.4 Golden tests — board column, job card, invoice PDF layout.

### 8.5 Cloud Functions tests — `firebase-functions-test` + emulator; assert `sendMessage` queues correctly and `onStockMovement` keeps `onHand` correct under concurrent writes.

### 8.6 Commands

```bash
flutter analyze
flutter test --coverage
firebase emulators:exec "flutter test integration_test"
cd functions && npm test
```

---

## 9. Dummy / seed data (for dev & testing)

**Goal:** one command populates the emulator (or a dev project) with realistic data so every screen has content and flows are testable without manual entry.

- **Seeder:** `bootstrap/seed.dart` (run against emulator) + `functions` emulator seed. Generates with a small faker util.
- **Volumes (default demo set):**
  - 4 users (one per role) · 30 customers · 45 watches
  - 100 jobs spread across **all statuses** (incl. 8 `awaiting_part`, 5 `ready` uncollected > 7 days, 3 rework) with intake photos (placeholder asset)
  - 60 parts across the SOP categories (incl. some below reorder point, some service-only, one **half-strap incomplete**)
  - 10 suppliers/orders (incl. 1 partially received), 20 invoices/payments (mix of paid/partial/unpaid)
  - reminders due today (battery, overdue, uncollected) so the follow-up engine has work
- **Builders for tests:** typed fixtures, e.g. `JobFixture.awaitingQc()`, `PartFixture.lowStock()`, used by unit/widget tests (don't hand-roll maps in tests).
- **Demo mode:** `--dart-define=DEMO=true` seeds an in-memory/emulator dataset on first run and shows a "DEMO" banner.

```bash
# seed the emulator
firebase emulators:start &
dart run bootstrap/seed.dart --target=emulator --set=demo
```

**Edge cases the seed must include (so tests catch them):** stock at exactly reorder point; a job with no watch record; an offline-created job; a half/incomplete strap; an invoice with GST split; a customer with WhatsApp consent = false.

---

## 10. Environments & config

| Env | Firebase project | Use |
|---|---|---|
| dev | `[scsa-dev]` + emulators | local development & tests |
| staging | `[scsa-stg]` | pilot at one counter |
| prod | `[scsa-prod]` | live |

- Flutter **flavors** `dev/staging/prod`; config via `--dart-define-from-file=config/<env>.json` (git-ignored).
- Secrets (WhatsApp/SMS keys) live in **Cloud Functions config / Secret Manager**, never in the app.
- App Check enforced in staging/prod.

---

## 11. CI/CD (`.github/workflows/ci.yml`)

```yaml
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test --coverage
      - run: dart pub global activate coverage && # enforce >=80% on lib/features/**/{data,domain}
  functions:
    runs-on: ubuntu-latest
    steps: [ checkout, setup-node@20, "cd functions && npm ci && npm run lint && npm test" ]
```
Deploy (manual/protected): `firebase deploy --only firestore:rules,firestore:indexes,functions,storage`.

---

## 12. Implementation milestones (build in this order)

> Each milestone: **Goal · Tasks · Tests · Acceptance · Depends-on**. A milestone ships only when acceptance + DoD (§13) pass.

**M0 — Scaffold & CI**
Tasks: project, folders (§3), lints, theme, l10n base (en/mr/hi), `firebase_options`, App Check, ProviderScope, CI green. · Tests: a trivial widget test runs in CI. · Acceptance: app boots to a placeholder home; `flutter analyze` clean; CI passes. · Depends: —

**M1 — Auth & roles**
Tasks: email/phone sign-in, `users` doc, `setUserRole` function, route guards by role. · Tests: unit (auth repo with `firebase_auth_mocks`), widget (login), integration (each role sees only allowed routes). · Acceptance: 4 roles log in; guards block disallowed routes. · Depends: M0

**M2 — Data layer & models**
Tasks: freezed models for all §5 entities, Firestore converters, repository interfaces + impls (jobs, customers, parts first), `Result`/`Failure`, transaction helpers, security rules + indexes for those collections, emulator wiring. · Tests: repo unit tests with `fake_cloud_firestore` (CRUD + transactional stock). · Acceptance: repos pass tests; rules deny unauthenticated. · Depends: M1

**M3 — Jobs & board (core)**
Tasks: board (Kanban), intake screen, job detail, status moves + history, **delivery gate (QC+photo)**, search, QR box-label. · Tests: unit (status/gate logic), widget (deliver disabled), golden (board card), integration (intake→deliver). · Acceptance: §7 Jobs acceptance. · Depends: M2

**M4 — Customers & watches**
Tasks: customer search/list/detail + history, watch profiles, phone de-dupe. · Tests: unit (de-dupe), widget (history list). · Acceptance: §7 Customers. · Depends: M2

**M5 — Inventory (basic) + offline**
Tasks: parts list/detail, stock adjust, parts-on-job consumption (transactional), offline persistence verified. · Tests: unit (no-negative stock), integration (offline create→sync). · Acceptance: §7 Inventory + offline. · Depends: M2

**M6 — Photos, slips, CSV import, Drive backup**
Tasks: intake/delivery photo capture+compress+upload, job-slip PDF, **CSV import (customers/parts) with validation report**, owner Drive backup. · Tests: unit (CSV parser + validation), widget (PDF preview), integration (import 50-row CSV). · Acceptance: migration import works with an error report; backup file lands in Drive. · Depends: M3–M5

**M7 — Billing, GST, payments**
Tasks: estimate→approval, GST invoice, UPI/cash/card payments (paise, transactional), day-book reconciliation, accountant CSV export. · Tests: unit (GST math, payment totals), golden (invoice PDF). · Acceptance: invoice tax split correct; partial payments update status; day-book balances. · Depends: M3

**M8 — Functions: messaging, reminders, stats**
Tasks: `onJobStatusChange`, `sendMessage` (WhatsApp/SMS via BSP — keys as placeholders), `scheduledFollowups`, `onStockMovement`, `rollupDailyStats`, consent/DLT handling. · Tests: functions tests on emulator (queue + stock integrity under concurrency). · Acceptance: status change queues a message; follow-up engine creates due reminders. · Depends: M3, M7

**M9 — Reports & dashboard**
Tasks: KPI dashboard from `dailyStats`, report engine (date-range, filter, PDF/Excel/CSV export, GST report), scheduled reports. · Tests: unit (KPI calc), golden (dashboard). · Acceptance: TAT/first-time-fix/comeback/uncollected match seeded data; export opens in Excel. · Depends: M8

**M10 — Inventory advanced + warranty + audit log + inter-store**
Tasks: GRN/suppliers, stock-take/reconciliation, reservation; warranty vs paid + claim + repair-warranty; `activityLog` surfaced; inter-store job flow. · Tests: unit (GRN partial receipt, stock-take variance), integration (order→GRN). · Acceptance: partial GRN updates stock; stock-take produces variance; warranty type drives billing. · Depends: M5, M7

**M11 — Localization, feedback, hardening**
Tasks: full mr/hi translations, customer feedback, accessibility pass, performance (paginate board), Crashlytics, error states everywhere. · Tests: golden in 3 languages; perf check. · Acceptance: UI switches language; board paginates; no untranslated strings. · Depends: all

> P3 items (customer track-your-watch, barcode intake, thermal printing, multi-branch at scale, audit-scoring module) follow as M12+.

---

## 13. Definition of Done (every milestone & feature)

- [ ] Models/repos/providers/UI implemented per spec; no Firebase imports in `domain`.
- [ ] Unit + widget tests written; integration test for any new flow; **coverage ≥ 80%** on `data`+`domain`.
- [ ] `flutter analyze` clean; CI green; security rules + indexes updated and tested.
- [ ] All states handled (loading/error/empty); works offline where applicable.
- [ ] Role checks enforced in UI **and** rules; activity logged for writes.
- [ ] Strings localized (en/mr/hi); money in paise; dates UTC-stored.
- [ ] Seed data covers the feature's edge cases (§9); demo screen renders with seed.
- [ ] No secrets in code; placeholders documented for human input.

---

## 14. Notes & open decisions for the agent

- **Storage:** default to Firestore offline persistence (Option A). Do **not** add `drift` unless explicitly told — it doubles the data layer.
- **WhatsApp/SMS:** provider keys are human-supplied placeholders; build the `sendMessage` abstraction so the BSP is swappable.
- **Scope:** ship **M0–M6 (MVP)** and pause for a pilot before M7+. Don't build all milestones in one pass.
- **Unknowns to confirm with the owner:** sequential `jobNo` scheme, GST rate(s)/HSN-SAC codes, WhatsApp BSP choice, exact QC checklist items, branch list.
