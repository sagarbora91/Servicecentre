import { FieldValue, type Firestore } from "firebase-admin/firestore";
import type { Bsp, Channel } from "../messaging/bsp";

/** A minimal view of a `messages/{id}` document. */
export interface MessageView {
  readonly status?: string;
  readonly to?: string;
  readonly channel?: string;
  readonly template?: string;
  readonly body?: string;
}

/**
 * Delivers a freshly-created queued message through the [bsp] and records the
 * outcome on the `messages/{id}` doc (`sent` + `providerId`, or `failed` +
 * `error`). No-ops for any message not in `queued` state, so re-invocation is
 * idempotent and a status write never triggers a re-send.
 */
export async function deliverQueuedMessage(
  db: Firestore,
  bsp: Bsp,
  messageId: string,
  data: MessageView,
): Promise<"sent" | "failed" | "skipped"> {
  if (data.status !== "queued") return "skipped";

  const result = await bsp.send({
    to: data.to ?? "",
    channel: (data.channel as Channel | undefined) ?? "sms",
    template: data.template ?? "",
    body: data.body,
  });

  await db.collection("messages").doc(messageId).update({
    status: result.ok ? "sent" : "failed",
    providerId: result.providerId ?? null,
    error: result.error ?? null,
    sentAt: FieldValue.serverTimestamp(),
  });
  return result.ok ? "sent" : "failed";
}
