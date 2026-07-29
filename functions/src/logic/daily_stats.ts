import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";

/** The computed summary written to `dailyStats/{date_branch}`. */
export interface DailyStats {
  readonly date: string;
  readonly branchId: string;
  readonly jobsDone: number;
  readonly revenuePaise: number;
  readonly collectionsPaise: number;
}

/**
 * Rolls up a branch's activity for the UTC day starting at [dayStartUtc] into
 * `dailyStats/{YYYY-MM-DD_branchId}` (BUILD_BRIEF §6 `rollupDailyStats`):
 * jobs delivered that day, invoice revenue raised, and payments collected — all
 * in integer paise. TAT / first-time-fix / comeback metrics are seeded to 0 and
 * filled once the richer job signals land (M9). Returns the written summary.
 */
export async function rollupDailyStats(
  db: Firestore,
  branchId: string,
  dayStartUtc: Date,
): Promise<DailyStats> {
  const from = Timestamp.fromDate(dayStartUtc);
  const to = Timestamp.fromDate(
    new Date(dayStartUtc.getTime() + 24 * 60 * 60 * 1000),
  );

  const [payments, invoices, jobs] = await Promise.all([
    db
      .collection("payments")
      .where("branchId", "==", branchId)
      .where("at", ">=", from)
      .where("at", "<", to)
      .get(),
    db
      .collection("invoices")
      .where("branchId", "==", branchId)
      .where("createdAt", ">=", from)
      .where("createdAt", "<", to)
      .get(),
    db
      .collection("jobs")
      .where("branchId", "==", branchId)
      .where("status", "==", "delivered")
      .where("updatedAt", ">=", from)
      .where("updatedAt", "<", to)
      .get(),
  ]);

  const collectionsPaise = sum(payments.docs.map((d) => d.data().amountPaise));
  const revenuePaise = sum(invoices.docs.map((d) => d.data().totalPaise));
  const jobsDone = jobs.size;
  const date = dayStartUtc.toISOString().slice(0, 10);

  const stats: DailyStats = {
    date,
    branchId,
    jobsDone,
    revenuePaise,
    collectionsPaise,
  };
  await db.collection("dailyStats").doc(`${date}_${branchId}`).set(
    {
      ...stats,
      avgTatHrs: 0,
      firstTimeFixPct: 0,
      comebacks: 0,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return stats;
}

function sum(values: Array<unknown>): number {
  return values.reduce<number>(
    (acc, v) => acc + (typeof v === "number" ? v : 0),
    0,
  );
}
