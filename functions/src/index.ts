import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { deliverQueuedMessage, type MessageView } from "./logic/deliver_message";
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
