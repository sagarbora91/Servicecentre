import assert from "node:assert/strict";
import { test } from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import { testDb } from "../test_support/emulator";
import { rollupDailyStats } from "./daily_stats";

const db = testDb();

test("rolls up collections, revenue and jobs done for the day", async () => {
  const branchId = "DS1";
  const dayStart = new Date("2026-07-01T00:00:00Z");
  const inDay = Timestamp.fromDate(new Date("2026-07-01T10:00:00Z"));
  const nextDay = Timestamp.fromDate(new Date("2026-07-02T10:00:00Z"));

  // Two payments in the day + one the next day (excluded).
  await db
    .collection("payments")
    .add({ branchId, amountPaise: 50000, at: inDay });
  await db
    .collection("payments")
    .add({ branchId, amountPaise: 25000, at: inDay });
  await db
    .collection("payments")
    .add({ branchId, amountPaise: 99999, at: nextDay });
  // One invoice raised in the day.
  await db
    .collection("invoices")
    .add({ branchId, totalPaise: 118000, createdAt: inDay });
  // One job delivered in the day + one delivered next day (excluded).
  await db
    .collection("jobs")
    .add({ branchId, status: "delivered", updatedAt: inDay });
  await db
    .collection("jobs")
    .add({ branchId, status: "delivered", updatedAt: nextDay });

  const stats = await rollupDailyStats(db, branchId, dayStart);

  assert.equal(stats.collectionsPaise, 75000);
  assert.equal(stats.revenuePaise, 118000);
  assert.equal(stats.jobsDone, 1);

  const doc = await db.collection("dailyStats").doc(`2026-07-01_${branchId}`).get();
  assert.ok(doc.exists);
  assert.equal(doc.data()?.collectionsPaise, 75000);
});
