import assert from "node:assert/strict";
import { test } from "node:test";
import { StubBsp } from "../messaging/bsp";
import { testDb } from "../test_support/emulator";
import { deliverQueuedMessage } from "./deliver_message";

const db = testDb();
const bsp = new StubBsp();

test("delivers a queued message and marks it sent with a provider id", async () => {
  const ref = await db.collection("messages").add({
    status: "queued",
    to: "9990001111",
    channel: "sms",
    template: "job_ready",
  });

  const outcome = await deliverQueuedMessage(
    db,
    bsp,
    ref.id,
    (await ref.get()).data()!,
  );

  assert.equal(outcome, "sent");
  const msg = (await ref.get()).data();
  assert.equal(msg?.status, "sent");
  assert.ok(msg?.providerId);
});

test("marks the message failed when the recipient is missing", async () => {
  const ref = await db.collection("messages").add({
    status: "queued",
    to: "",
    channel: "sms",
    template: "job_ready",
  });

  const outcome = await deliverQueuedMessage(db, bsp, ref.id, {
    status: "queued",
    to: "",
    channel: "sms",
    template: "job_ready",
  });

  assert.equal(outcome, "failed");
  const msg = (await ref.get()).data();
  assert.equal(msg?.status, "failed");
});

test("skips a message that is not queued (idempotent re-invocation)", async () => {
  const outcome = await deliverQueuedMessage(db, bsp, "whatever", {
    status: "sent",
  });
  assert.equal(outcome, "skipped");
});
