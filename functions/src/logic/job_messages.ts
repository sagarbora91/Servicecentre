import { FieldValue, type Firestore } from "firebase-admin/firestore";

/** Job statuses that notify the customer. */
export const NOTIFY_STATUSES = ["received", "ready"] as const;

/** A minimal view of the parts of a job document this logic reads. */
export interface JobView {
  readonly status?: string;
  readonly customerId?: string;
  readonly branchId?: string;
  readonly jobNo?: string;
}

/**
 * Queues a customer message when a job transitions **into** a notifying status
 * (`received` or `ready`). Returns the new `messages/{id}` id, or `null` when no
 * message is warranted (status unchanged, non-notifying status, or the customer
 * is missing/without a phone).
 *
 * Consent (BUILD_BRIEF §14 DLT/consent): WhatsApp is used only when the
 * customer has `consentWhatsApp: true`; otherwise the message falls back to SMS.
 * The actual send happens in the `messages` create trigger via the BSP.
 */
export async function queueJobStatusMessage(
  db: Firestore,
  jobId: string,
  before: JobView | undefined,
  after: JobView,
): Promise<string | null> {
  const status = after.status;
  if (!status || !isNotifying(status)) return null;
  if (before?.status === status) return null; // no transition into the status

  const customerId = after.customerId;
  if (!customerId) return null;

  const customerSnap = await db.collection("customers").doc(customerId).get();
  const customer = customerSnap.data();
  const to = (customer?.phone as string | undefined)?.trim();
  if (!to) return null;

  const channel = customer?.consentWhatsApp === true ? "whatsapp" : "sms";
  const ref = await db.collection("messages").add({
    jobId,
    customerId,
    channel,
    template: `job_${status}`,
    to,
    branchId: after.branchId ?? customer?.branchId ?? null,
    status: "queued",
    createdAt: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

function isNotifying(status: string): boolean {
  return (NOTIFY_STATUSES as readonly string[]).includes(status);
}
