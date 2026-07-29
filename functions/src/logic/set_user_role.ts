import { FieldValue, type Firestore } from "firebase-admin/firestore";

/** The staff roles that can be assigned (mirrors the Flutter UserRole enum). */
export const ROLES = [
  "owner",
  "supervisor",
  "counter",
  "technician",
  "store",
] as const;

/** A staff role. */
export type Role = (typeof ROLES)[number];

/**
 * Sets an Auth custom claim. Injected so the authorization + Firestore logic can
 * be tested against the emulator without the Auth emulator; the real
 * implementation (index.ts) calls `admin.auth().setCustomUserClaims`.
 */
export interface ClaimSetter {
  setRole(uid: string, role: Role): Promise<void>;
}

/** Thrown when the caller is not permitted to assign roles. */
export class PermissionError extends Error {}

/** Thrown when the requested role is not a known [ROLES] value. */
export class InvalidRoleError extends Error {}

/**
 * Assigns [role] to [targetUid]: sets the Auth custom claim (via [claims]) and
 * mirrors it into `users/{targetUid}.role`. Only an **active owner** (per their
 * `users` doc) may call this (BUILD_BRIEF §6 `setUserRole`, owner-only). Throws
 * [PermissionError] otherwise and [InvalidRoleError] for an unknown role.
 */
export async function setUserRoleLogic(
  db: Firestore,
  claims: ClaimSetter,
  callerUid: string,
  targetUid: string,
  role: string,
): Promise<void> {
  const caller = (await db.collection("users").doc(callerUid).get()).data();
  if (!caller || caller.active !== true || caller.role !== "owner") {
    throw new PermissionError("only an active owner may set roles");
  }
  if (!isRole(role)) {
    throw new InvalidRoleError(`unknown role: ${role}`);
  }
  await claims.setRole(targetUid, role);
  await db
    .collection("users")
    .doc(targetUid)
    .set({ role, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
}

function isRole(value: string): value is Role {
  return (ROLES as readonly string[]).includes(value);
}
