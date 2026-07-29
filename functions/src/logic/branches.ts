import { type Firestore } from "firebase-admin/firestore";

/**
 * The branch ids to process in scheduled jobs, taken from the `settings`
 * documents (one per branch). Falls back to the single pilot branch `MAIN` when
 * none exist yet, so the schedulers still do useful work before any settings
 * doc is created.
 */
export async function activeBranchIds(db: Firestore): Promise<string[]> {
  const snap = await db.collection("settings").get();
  const ids = snap.docs.map((d) => d.id);
  return ids.length > 0 ? ids : ["MAIN"];
}
