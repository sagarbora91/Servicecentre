import assert from "node:assert/strict";
import { test } from "node:test";
import { testDb } from "../test_support/emulator";
import {
  InvalidRoleError,
  PermissionError,
  setUserRoleLogic,
  type ClaimSetter,
  type Role,
} from "./set_user_role";

const db = testDb();

/** A claim setter that records the calls it received (no Auth emulator needed). */
class RecordingClaims implements ClaimSetter {
  readonly calls: Array<{ uid: string; role: Role }> = [];
  async setRole(uid: string, role: Role): Promise<void> {
    this.calls.push({ uid, role });
  }
}

test("an owner sets a role: claim set + users doc updated", async () => {
  await db.collection("users").doc("owner1").set({ role: "owner", active: true });
  await db.collection("users").doc("staff1").set({ role: "counter", active: true });
  const claims = new RecordingClaims();

  await setUserRoleLogic(db, claims, "owner1", "staff1", "supervisor");

  assert.deepEqual(claims.calls, [{ uid: "staff1", role: "supervisor" }]);
  const staff = (await db.collection("users").doc("staff1").get()).data();
  assert.equal(staff?.role, "supervisor");
});

test("a non-owner is rejected and nothing changes", async () => {
  await db.collection("users").doc("sup2").set({ role: "supervisor", active: true });
  await db.collection("users").doc("staff2").set({ role: "counter", active: true });
  const claims = new RecordingClaims();

  await assert.rejects(
    () => setUserRoleLogic(db, claims, "sup2", "staff2", "owner"),
    PermissionError,
  );
  assert.equal(claims.calls.length, 0);
  const staff = (await db.collection("users").doc("staff2").get()).data();
  assert.equal(staff?.role, "counter");
});

test("an inactive owner is rejected", async () => {
  await db.collection("users").doc("owner3").set({ role: "owner", active: false });
  const claims = new RecordingClaims();

  await assert.rejects(
    () => setUserRoleLogic(db, claims, "owner3", "staff3", "counter"),
    PermissionError,
  );
});

test("an unknown role is rejected", async () => {
  await db.collection("users").doc("owner4").set({ role: "owner", active: true });
  const claims = new RecordingClaims();

  await assert.rejects(
    () => setUserRoleLogic(db, claims, "owner4", "staff4", "wizard"),
    InvalidRoleError,
  );
  assert.equal(claims.calls.length, 0);
});
