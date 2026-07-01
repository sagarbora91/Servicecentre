import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { activeBranchIds } from "./logic/branches";
import { rollupDailyStats } from "./logic/daily_stats";
import { deliverQueuedMessage, type MessageView } from "./logic/deliver_message";
import { createDueReminders } from "./logic/followups";
import { queueJobStatusMessage, type JobView } from "./logic/job_messages";
import { StubBsp } from "./messaging/bsp";

initializeApp();
const db = getFirestore();
const bsp = new StubBsp();

// Mumbai region; cap fan-out so a burst can't scale without bound.
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

/**
 * On a job update, queue a customer message when it transitions into a
 * notifying status (`received`/`ready`). BUILD_BRIEF §6 `onJobStatusChange`.
 */
export const onJobStatusChange = onDocumentUpdated(
  "jobs/{jobId}",
  async (event) => {
    const after = event.data?.after.data() as JobView | undefined;
    if (!after) return;
    const before = event.data?.before.data() as JobView | undefined;
    await queueJobStatusMessage(db, event.params.jobId, before, after);
  },
);

/**
 * On a new `messages/{id}`, deliver it through the BSP and record the outcome.
 * BUILD_BRIEF §6 `sendMessage`.
 */
export const sendMessage = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const data = event.data?.data() as MessageView | undefined;
    if (!data) return;
    await deliverQueuedMessage(db, bsp, event.params.messageId, data);
  },
);

/**
 * Daily: raise follow-up reminders for overdue / uncollected jobs across every
 * branch. BUILD_BRIEF §6 `scheduledFollowups`.
 */
export const scheduledFollowups = onSchedule("every day 08:00", async () => {
  const now = new Date();
  for (const branchId of await activeBranchIds(db)) {
    await createDueReminders(db, branchId, now);
  }
});

/**
 * Daily (end of day): roll up per-branch `dailyStats` for the current UTC day.
 * BUILD_BRIEF §6 `rollupDailyStats`.
 */
export const scheduledDailyStats = onSchedule("every day 23:55", async () => {
  const now = new Date();
  const dayStart = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  for (const branchId of await activeBranchIds(db)) {
    await rollupDailyStats(db, branchId, dayStart);
  }
});
