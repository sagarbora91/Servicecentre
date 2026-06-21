// Firestore security-rules tests — M2 acceptance: "rules deny unauthenticated"
// (BUILD_BRIEF §12 M2), plus the role checks that mirror the client guards.
//
// Runs against the Firebase Firestore emulator via @firebase/rules-unit-testing
// with a demo project, so it needs no live Firebase project / flutterfire
// configure. Launched in CI by `firebase emulators:exec --only firestore`.
import { readFileSync } from 'node:fs';
import { after, afterEach, before, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-sc',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

afterEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

/// Seeds a `users/{uid}` profile bypassing rules, so a context can act as that
/// role in the test body.
async function seedUser(uid, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), data);
  });
}

// --- Unauthenticated is denied everywhere (the core M2 acceptance) ---

test('unauthenticated cannot read jobs', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'jobs/j1')));
});

test('unauthenticated cannot write jobs', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(db, 'jobs/j1'), { fault: 'x' }));
});

test('unauthenticated cannot read customers / parts / users', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'customers/c1')));
  await assertFails(getDoc(doc(db, 'parts/p1')));
  await assertFails(getDoc(doc(db, 'users/u1')));
});

// --- Signed-in but not (active) staff is still denied ---

test('signed-in without a profile is not staff (jobs denied)', async () => {
  const db = env.authenticatedContext('ghost').firestore();
  await assertFails(getDoc(doc(db, 'jobs/j1')));
});

test('an inactive account is not staff (jobs denied)', async () => {
  await seedUser('off1', { role: 'counter', active: false });
  const db = env.authenticatedContext('off1').firestore();
  await assertFails(getDoc(doc(db, 'jobs/j1')));
});

// --- Active staff: role-scoped access ---

test('active staff can read and write jobs', async () => {
  await seedUser('tech1', { role: 'technician', active: true });
  const db = env.authenticatedContext('tech1').firestore();
  await assertSucceeds(getDoc(doc(db, 'jobs/j1')));
  await assertSucceeds(setDoc(doc(db, 'jobs/j2'), { fault: 'tick' }));
});

test('technician can read but not write parts; store can write', async () => {
  await seedUser('tech2', { role: 'technician', active: true });
  await seedUser('store1', { role: 'store', active: true });
  const tech = env.authenticatedContext('tech2').firestore();
  const store = env.authenticatedContext('store1').firestore();
  await assertSucceeds(getDoc(doc(tech, 'parts/p1')));
  await assertFails(setDoc(doc(tech, 'parts/p1'), { onHand: 1 }));
  await assertSucceeds(setDoc(doc(store, 'parts/p2'), { onHand: 1 }));
});

test('invoices and payments are finance-only', async () => {
  await seedUser('tech3', { role: 'technician', active: true });
  await seedUser('owner3', { role: 'owner', active: true });
  const tech = env.authenticatedContext('tech3').firestore();
  const owner = env.authenticatedContext('owner3').firestore();
  await assertFails(getDoc(doc(tech, 'invoices/i1')));
  await assertSucceeds(getDoc(doc(owner, 'invoices/i1')));
  await assertFails(getDoc(doc(tech, 'payments/pay1')));
  await assertSucceeds(getDoc(doc(owner, 'payments/pay1')));
});

// --- users: owner-only writes, self-read ---

test('only the owner can write users docs (assign roles)', async () => {
  await seedUser('owner4', { role: 'owner', active: true });
  await seedUser('sup4', { role: 'supervisor', active: true });
  const owner = env.authenticatedContext('owner4').firestore();
  const sup = env.authenticatedContext('sup4').firestore();
  await assertSucceeds(
    setDoc(doc(owner, 'users/new1'), { role: 'counter', active: true }),
  );
  await assertFails(
    setDoc(doc(sup, 'users/new2'), { role: 'counter', active: true }),
  );
});

test('a signed-in user may read their own profile but not others', async () => {
  const db = env.authenticatedContext('self1').firestore();
  await assertSucceeds(getDoc(doc(db, 'users/self1')));
  await assertFails(getDoc(doc(db, 'users/other1')));
});

// --- stockMovements: append-only ledger ---

test('stockMovements can be created by staff but never updated', async () => {
  await seedUser('store2', { role: 'store', active: true });
  const db = env.authenticatedContext('store2').firestore();
  await assertSucceeds(
    setDoc(doc(db, 'stockMovements/m1'), { partId: 'p1', qty: 1 }),
  );
  // Append-only: update/delete are denied for everyone.
  await assertFails(
    setDoc(doc(db, 'stockMovements/m1'), { partId: 'p1', qty: 2 }),
  );
});

// --- activityLog: append-only audit trail ---

test('activityLog: staff append, unauthenticated denied, no edits', async () => {
  await seedUser('tech7', { role: 'technician', active: true });
  const staff = env.authenticatedContext('tech7').firestore();
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(anon, 'activityLog/a1'), { action: 'x' }));
  await assertSucceeds(
    setDoc(doc(staff, 'activityLog/a2'), {
      actor: 'tech7',
      action: 'job.deliver',
      entity: 'jobs',
      entityId: 'j1',
    }),
  );
  // a2 now exists, so a second setDoc is an update -> denied (append-only).
  await assertFails(setDoc(doc(staff, 'activityLog/a2'), { action: 'y' }));
});

// --- jobs: delivery gate mirrored in rules (CLAUDE.md #4 / Golden Rule 8) ---

test('jobs update to delivered needs complete QC + a delivery photo',
  async () => {
    await seedUser('tech8', { role: 'technician', active: true });
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'jobs/jx'), {
        status: 'ready',
        branchId: 'b1',
      });
    });
    const db = env.authenticatedContext('tech8').firestore();
    // Incomplete (no QC / no photo) -> denied.
    await assertFails(updateDoc(doc(db, 'jobs/jx'), { status: 'delivered' }));
    // Complete QC + a delivery photo -> allowed.
    await assertSucceeds(
      updateDoc(doc(db, 'jobs/jx'), {
        status: 'delivered',
        qc: {
          timekeeping: true,
          gasket: true,
          glassClean: true,
          strap: true,
          crown: true,
        },
        deliveryPhotos: ['delivery.jpg'],
      }),
    );
  });

test('jobs update to a non-delivered status needs no QC', async () => {
  await seedUser('tech9', { role: 'technician', active: true });
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'jobs/jy'), {
      status: 'received',
      branchId: 'b1',
    });
  });
  const db = env.authenticatedContext('tech9').firestore();
  await assertSucceeds(updateDoc(doc(db, 'jobs/jy'), { status: 'in_repair' }));
});

// --- counters: jobNo allocation, staff-only ---

test('counters: staff may allocate, unauthenticated denied', async () => {
  await seedUser('tech10', { role: 'technician', active: true });
  const staff = env.authenticatedContext('tech10').firestore();
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(anon, 'counters/MAIN_2606'), { seq: 1 }));
  await assertSucceeds(setDoc(doc(staff, 'counters/MAIN_2606'), { seq: 1 }));
});
