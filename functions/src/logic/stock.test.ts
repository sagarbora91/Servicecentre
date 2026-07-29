import assert from "node:assert/strict";
import { test } from "node:test";
import { testDb } from "../test_support/emulator";
import { recomputeStockLevels } from "./stock";

const db = testDb();

async function seedMovement(partId: string, type: string, qty: number): Promise<void> {
  await db.collection("stockMovements").add({ partId, type, qty });
}

test("recomputes onHand from the ledger, healing a drifted value", async () => {
  const partId = "sp1";
  // Deliberately wrong stored onHand; the ledger is authoritative.
  await db.collection("parts").doc(partId).set({ reference: "SR626", onHand: 999 });
  await seedMovement(partId, "in", 100);
  await seedMovement(partId, "out", 30);
  await seedMovement(partId, "adjust", -5);

  const levels = await recomputeStockLevels(db, partId);

  assert.equal(levels.onHand, 65); // 100 - 30 - 5
  const part = (await db.collection("parts").doc(partId).get()).data();
  assert.equal(part?.onHand, 65);
});

test("tracks reserved separately from onHand", async () => {
  const partId = "sp2";
  await db.collection("parts").doc(partId).set({ reference: "BATT", onHand: 0 });
  await seedMovement(partId, "in", 10);
  await seedMovement(partId, "reserve", 4);
  await seedMovement(partId, "release", 1);

  const levels = await recomputeStockLevels(db, partId);

  assert.equal(levels.onHand, 10);
  assert.equal(levels.reserved, 3); // 4 - 1
});

test("stays correct under concurrent recomputes (idempotent set)", async () => {
  const partId = "sp3";
  await db.collection("parts").doc(partId).set({ reference: "STRAP", onHand: 0 });
  await seedMovement(partId, "in", 50);
  await seedMovement(partId, "out", 20);

  // Simulate the trigger firing several times at once.
  const results = await Promise.all([
    recomputeStockLevels(db, partId),
    recomputeStockLevels(db, partId),
    recomputeStockLevels(db, partId),
  ]);

  for (const r of results) assert.equal(r.onHand, 30);
  const part = (await db.collection("parts").doc(partId).get()).data();
  assert.equal(part?.onHand, 30);
});

test("no-ops when the part document is missing", async () => {
  await seedMovement("ghost", "in", 5);
  const levels = await recomputeStockLevels(db, "ghost");
  assert.equal(levels.onHand, 5); // computed
  const part = await db.collection("parts").doc("ghost").get();
  assert.equal(part.exists, false); // but not created
});
