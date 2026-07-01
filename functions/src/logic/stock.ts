import { FieldValue, type Firestore } from "firebase-admin/firestore";

/** The recomputed stock levels for a part. */
export interface StockLevels {
  readonly onHand: number;
  readonly reserved: number;
}

/**
 * Authoritatively recomputes `parts/{partId}.onHand` and `.reserved` from the
 * full `stockMovements` ledger and writes them in a transaction (BUILD_BRIEF §6
 * `onStockMovement`). Because it *sets* the totals to the ledger sum (rather
 * than applying a delta), it is idempotent and self-healing, and stays correct
 * under concurrency: every movement re-triggers a full recompute, so the final
 * value always equals the sum of all movements — it never double-counts the
 * client's own transactional update.
 *
 * Sign convention mirrors the client (M5): `in`/`grn` add, `out` subtracts,
 * `adjust` adds its signed qty; `reserve`/`release` move `reserved`, not
 * `onHand`. No-ops if the part document does not exist.
 */
export async function recomputeStockLevels(
  db: Firestore,
  partId: string,
): Promise<StockLevels> {
  const movements = await db
    .collection("stockMovements")
    .where("partId", "==", partId)
    .get();

  let onHand = 0;
  let reserved = 0;
  for (const doc of movements.docs) {
    const data = doc.data();
    const qty = typeof data.qty === "number" ? data.qty : 0;
    switch (data.type) {
      case "in":
      case "grn":
      case "adjust":
        onHand += qty;
        break;
      case "out":
        onHand -= qty;
        break;
      case "reserve":
        reserved += qty;
        break;
      case "release":
        reserved -= qty;
        break;
      default:
        break;
    }
  }

  await db.runTransaction(async (tx) => {
    const ref = db.collection("parts").doc(partId);
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    tx.update(ref, {
      onHand,
      reserved,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { onHand, reserved };
}
