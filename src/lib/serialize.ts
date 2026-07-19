import type { HuntSession } from '@prisma/client';

/** xpGained/profit/waste/loot are BigInt in Postgres (to hold values past 2.1B) but the
 *  app only ever needs plain numbers — JS numbers are exact up to 2^53, far past any
 *  realistic XP/gold value, and BigInt doesn't survive JSON.stringify on its own. */
export function serializeHunt(hunt: HuntSession) {
  return {
    ...hunt,
    xpGained: Number(hunt.xpGained),
    profit: Number(hunt.profit),
    waste: Number(hunt.waste),
    loot: Number(hunt.loot),
  };
}
