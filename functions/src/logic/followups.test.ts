import assert from "node:assert/strict";
import { test } from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import { testDb } from "../test_support/emulator";
import { createDueReminders } from "./followups";

const db = testDb();

const past = Timestamp.fromDate(new Date("2020-01-01T00:00:00Z"));
const now = new Date("2020-02-01T00:00:00Z");

test("raises overdue and uncollected reminders, and is idempotent", async () => {
  const branchId = "FUP1";
  // A late in-workshop job (overdue), a late ready job (uncollected), a late
  // delivered job (ignored), and an on-time job (ignored).
  await db
    .collection("jobs")
    .doc("fj1")
    .set({ branchId, status: "in_repair", dueAt: past, customerId: "c1" });
  await db
    .collection("jobs")
    .doc("fj2")
    .set({ branchId, status: "ready", dueAt: past, customerId: "c2" });
  await db
    .collection("jobs")
    .doc("fj3")
    .set({ branchId, status: "delivered", dueAt: past, customerId: "c3" });
  await db.collection("jobs").doc("fj4").set({
    branchId,
    status: "in_repair",
    dueAt: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z")),
    customerId: "c4",
  });

  const created = await createDueReminders(db, branchId, now);
  assert.equal(created, 2);

  const reminders = await db
    .collection("reminders")
    .where("branchId", "==", branchId)
    .get();
  const byJob = new Map(
    reminders.docs.map((d) => [d.data().jobId as string, d.data().type]),
  );
  assert.equal(byJob.get("fj1"), "overdue");
  assert.equal(byJob.get("fj2"), "uncollected");
  assert.equal(byJob.has("fj3"), false);
  assert.equal(byJob.has("fj4"), false);

  // Re-running does not duplicate the pending reminders.
  const again = await createDueReminders(db, branchId, now);
  assert.equal(again, 0);
  const after = await db
    .collection("reminders")
    .where("branchId", "==", branchId)
    .get();
  assert.equal(after.size, 2);
});
