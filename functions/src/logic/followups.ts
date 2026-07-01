import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";

/** Workshop statuses (still in for repair): an overdue one is "overdue". */
const IN_WORKSHOP = [
  "received",
  "diagnosed",
  "awaiting_part",
  "in_repair",
  "qc",
] as const;

/** A reminder type raised by the follow-up engine. */
export type ReminderType = "overdue" | "uncollected";

/**
 * Creates follow-up reminders for a branch's jobs that are past their due date
 * (BUILD_BRIEF §6 `scheduledFollowups`, acceptance "creates due reminders"):
 * a `ready` job that has not been collected raises an `uncollected` reminder; a
 * job still in the workshop raises an `overdue` one. Delivered/returned jobs are
 * ignored. Idempotent — a pending reminder of the same (job, type) is not
 * duplicated, so re-running the daily job is safe. Returns the count created.
 */
export async function createDueReminders(
  db: Firestore,
  branchId: string,
  now: Date,
): Promise<number> {
  const overdueJobs = await db
    .collection("jobs")
    .where("branchId", "==", branchId)
    .where("dueAt", "<", Timestamp.fromDate(now))
    .get();

  let created = 0;
  for (const doc of overdueJobs.docs) {
    const job = doc.data();
    const type = reminderTypeFor(job.status as string | undefined);
    if (type === null) continue;

    const existing = await db
      .collection("reminders")
      .where("jobId", "==", doc.id)
      .where("type", "==", type)
      .where("status", "==", "pending")
      .limit(1)
      .get();
    if (!existing.empty) continue;

    await db.collection("reminders").add({
      type,
      jobId: doc.id,
      customerId: job.customerId ?? null,
      branchId,
      dueAt: job.dueAt ?? FieldValue.serverTimestamp(),
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
    });
    created += 1;
  }
  return created;
}

function reminderTypeFor(status: string | undefined): ReminderType | null {
  if (status === "ready") return "uncollected";
  if (status && (IN_WORKSHOP as readonly string[]).includes(status)) {
    return "overdue";
  }
  return null; // delivered / returned / unknown
}
