// Messaging BSP (Business Solution Provider) abstraction.
//
// The real WhatsApp BSP / SMS DLT gateway is chosen by the owner later
// (BUILD_BRIEF §14: "provider keys are human-supplied placeholders; build the
// sendMessage abstraction so the BSP is swappable"). Everything downstream
// depends only on the [Bsp] interface, so swapping in the real provider is a
// one-file change — no trigger logic changes.

/** A message channel. */
export type Channel = "whatsapp" | "sms" | "push";

/** An outbound message handed to the BSP. */
export interface OutboundMessage {
  readonly to: string;
  readonly channel: Channel;
  readonly template: string;
  readonly body?: string;
}

/** The result of a send attempt. */
export interface SendResult {
  readonly ok: boolean;
  /** Provider-side message id, when the send succeeded. */
  readonly providerId?: string;
  /** Failure reason, when the send failed. */
  readonly error?: string;
}

/** A messaging provider. Swap the implementation to change BSP. */
export interface Bsp {
  send(message: OutboundMessage): Promise<SendResult>;
}

/**
 * A no-network stub BSP for the pilot: it "accepts" every message and returns a
 * synthetic provider id, so the queue/delivery pipeline is exercised without
 * real WhatsApp/SMS credentials. Replace with the real provider once the owner
 * supplies BSP keys ([PLACEHOLDER]).
 */
export class StubBsp implements Bsp {
  async send(message: OutboundMessage): Promise<SendResult> {
    if (!message.to || message.to.trim() === "") {
      return { ok: false, error: "missing recipient" };
    }
    return { ok: true, providerId: `stub:${message.channel}:${message.template}` };
  }
}
