import assert from "node:assert/strict";
import { test } from "node:test";
import { testDb } from "../test_support/emulator";
import { queueJobStatusMessage } from "./job_messages";

const db = testDb();

test("queues a WhatsApp message when a job becomes ready and consent is on", async () => {
  await db
    .collection("customers")
    .doc("c1")
    .set({ phone: "9990001111", consentWhatsApp: true, branchId: "MAIN" });

  const id = await queueJobStatusMessage(
    db,
    "j1",
    { status: "in_repair" },
    { status: "ready", customerId: "c1", branchId: "MAIN" },
  );

  assert.ok(id);
  const msg = (await db.collection("messages").doc(id!).get()).data();
  assert.equal(msg?.status, "queued");
  assert.equal(msg?.channel, "whatsapp");
  assert.equal(msg?.template, "job_ready");
  assert.equal(msg?.to, "9990001111");
});

test("falls back to SMS when the customer has not consented to WhatsApp", async () => {
  await db
    .collection("customers")
    .doc("c2")
    .set({ phone: "8880002222", consentWhatsApp: false });

  const id = await queueJobStatusMessage(
    db,
    "j2",
    { status: "diagnosed" },
    { status: "received", customerId: "c2" },
  );

  assert.ok(id);
  const msg = (await db.collection("messages").doc(id!).get()).data();
  assert.equal(msg?.channel, "sms");
});

test("does not queue when the status did not change", async () => {
  const id = await queueJobStatusMessage(
    db,
    "j3",
    { status: "ready" },
    { status: "ready", customerId: "c1" },
  );
  assert.equal(id, null);
});

test("does not queue for a non-notifying status", async () => {
  const id = await queueJobStatusMessage(
    db,
    "j4",
    { status: "received" },
    { status: "in_repair", customerId: "c1" },
  );
  assert.equal(id, null);
});

test("does not queue when the customer has no phone", async () => {
  await db.collection("customers").doc("c3").set({ consentWhatsApp: false });
  const id = await queueJobStatusMessage(
    db,
    "j5",
    undefined,
    { status: "received", customerId: "c3" },
  );
  assert.equal(id, null);
});
