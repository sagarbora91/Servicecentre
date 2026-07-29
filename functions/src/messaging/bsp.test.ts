import assert from "node:assert/strict";
import test from "node:test";
import { createBsp, type FetchLike } from "./bsp";

const message = {
  to: "919999999999",
  channel: "whatsapp" as const,
  template: "job_ready",
};

test("stub remains the no-network default", async () => {
  const result = await createBsp({ provider: "stub" }).send(message);
  assert.equal(result.ok, true);
  assert.match(result.providerId ?? "", /^stub:/);
});

test("webhook sends provider-neutral JSON with bearer auth", async () => {
  let captured: { input?: string; init?: RequestInit } = {};
  const fetcher: FetchLike = async (input, init) => {
    captured = { input, init };
    return {
      ok: true,
      status: 200,
      json: async () => ({ id: "provider-1" }),
      text: async () => "",
    };
  };
  const bsp = createBsp(
    { provider: "webhook", endpoint: "https://example.test/send", token: "x" },
    fetcher,
  );

  const result = await bsp.send(message);

  assert.equal(result.providerId, "provider-1");
  assert.equal(captured.input, "https://example.test/send");
  assert.equal((captured.init?.headers as Record<string, string>).authorization,
    "Bearer x");
  assert.deepEqual(JSON.parse(captured.init?.body as string), message);
});

test("webhook maps provider errors and rejects incomplete config", async () => {
  assert.throws(
    () => createBsp({ provider: "webhook" }),
    /requires endpoint and token/,
  );
  const fetcher: FetchLike = async () => ({
    ok: false,
    status: 503,
    json: async () => ({}),
    text: async () => "unavailable",
  });
  const result = await createBsp(
    { provider: "webhook", endpoint: "https://example.test", token: "x" },
    fetcher,
  ).send(message);
  assert.deepEqual(result, { ok: false, error: "provider HTTP 503" });
});
