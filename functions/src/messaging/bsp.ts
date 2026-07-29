// Messaging BSP (Business Solution Provider) abstraction.

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
  readonly providerId?: string;
  readonly error?: string;
}

/** A messaging provider. Swap the implementation to change BSP. */
export interface Bsp {
  send(message: OutboundMessage): Promise<SendResult>;
}

/** Minimal injectable fetch contract used by the webhook provider. */
export type FetchLike = (
  input: string,
  init: RequestInit,
) => Promise<Pick<Response, "ok" | "status" | "json" | "text">>;

/** No-network provider used until the owner configures a real BSP. */
export class StubBsp implements Bsp {
  async send(message: OutboundMessage): Promise<SendResult> {
    if (!message.to || message.to.trim() === "") {
      return { ok: false, error: "missing recipient" };
    }
    return { ok: true, providerId: `stub:${message.channel}:${message.template}` };
  }
}

/**
 * Provider-neutral HTTPS adapter. Configure a BSP/automation webhook that
 * accepts `{to, channel, template, body}` and returns `{id}`. Credentials stay
 * in Firebase Secret Manager; no vendor key or URL is committed.
 */
export class WebhookBsp implements Bsp {
  constructor(
    private readonly endpoint: string,
    private readonly token: string,
    private readonly fetcher: FetchLike = fetch,
  ) {}

  async send(message: OutboundMessage): Promise<SendResult> {
    if (!message.to || message.to.trim() === "") {
      return { ok: false, error: "missing recipient" };
    }
    try {
      const response = await this.fetcher(this.endpoint, {
        method: "POST",
        headers: {
          "authorization": `Bearer ${this.token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(message),
      });
      if (!response.ok) {
        return { ok: false, error: `provider HTTP ${response.status}` };
      }
      const payload = await response.json() as { id?: unknown };
      return {
        ok: true,
        providerId: typeof payload.id === "string" ? payload.id : undefined,
      };
    } catch (error) {
      return { ok: false, error: String(error) };
    }
  }
}

/** Runtime configuration for choosing a provider without changing code. */
export interface BspConfig {
  readonly provider: "stub" | "webhook";
  readonly endpoint?: string;
  readonly token?: string;
}

/** Builds the configured provider, failing closed on incomplete credentials. */
export function createBsp(config: BspConfig, fetcher?: FetchLike): Bsp {
  if (config.provider === "stub") return new StubBsp();
  if (!config.endpoint || !config.token) {
    throw new Error("Webhook BSP requires endpoint and token secrets");
  }
  return new WebhookBsp(config.endpoint, config.token, fetcher);
}
