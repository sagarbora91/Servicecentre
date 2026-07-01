import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { activeBranchIds } from "./logic/branches";
import { rollupDailyStats } from "./logic/daily_stats";
import { deliverQueuedMessage, type MessageView } from "./logic/deliver_message";
import { createDueReminders } from "./logic/followups";
import { queueJobStatusMessage, type JobView } from "./logic/job_messages";
import {
  InvalidRoleError,
  PermissionError,
  setUserRoleLogic,
  type ClaimSetter,
  type Role,
} from "./logic/set_user_role";
import { recomputeStockLevels } from "./logic/stock";
import { StubBsp } from "./messaging/bsp";

initializeApp();
const db = getFirestore();
const bsp = new StubBsp();

/** Real claim setter backed by the Auth admin SDK. */
const adminClaims: ClaimSetter = {
  async setRole(uid: string, role: Role): Promise<void> {
    await getAuth().setCustomUserClaims(uid, { role });
  },
};

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

/**
 * On a new stock movement, authoritatively recompute the part's on-hand/reserved
 * from the ledger in a transaction. BUILD_BRIEF §6 `onStockMovement`.
 */
export const onStockMovement = onDocumentCreated(
  "stockMovements/{movementId}",
  async (event) => {
    const partId = event.data?.data().partId as string | undefined;
    if (!partId) return;
    await recomputeStockLevels(db, partId);
  },
);

/**
 * Callable (owner-only): set a staff member's role — updates the Auth custom
 * claim and mirrors it into `users/{uid}`. BUILD_BRIEF §6 `setUserRole`.
 */
export const setUserRole = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const uid = request.data?.uid as string | undefined;
  const role = request.data?.role as string | undefined;
  if (!uid || !role) {
    throw new HttpsError("invalid-argument", "uid and role are required.");
  }
  try {
    await setUserRoleLogic(db, adminClaims, callerUid, uid, role);
  } catch (error) {
    if (error instanceof PermissionError) {
      throw new HttpsError("permission-denied", error.message);
    }
    if (error instanceof InvalidRoleError) {
      throw new HttpsError("invalid-argument", error.message);
    }
    throw new HttpsError("internal", "Failed to set role.");
  }
  return { ok: true };
});
