import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";

/**
 * Returns an admin [Firestore] pointed at the local emulator. `emulators:exec`
 * sets `FIRESTORE_EMULATOR_HOST`, so the admin SDK connects to the emulator with
 * no credentials. `initializeApp` is guarded because `node --test` may run every
 * test file in one process.
 */
export function testDb(): Firestore {
  if (getApps().length === 0) initializeApp({ projectId: "demo-sc" });
  return getFirestore();
}

/** Deletes every document in [name] (test isolation). */
export async function clearCollection(
  db: Firestore,
  name: string,
): Promise<void> {
  const snap = await db.collection(name).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}
