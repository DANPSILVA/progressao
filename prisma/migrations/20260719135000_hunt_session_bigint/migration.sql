-- AlterTable
-- Widened from 32-bit int (max ~2.1B) to 64-bit, since a single hunt's XP or
-- profit can easily exceed that at high character levels.
ALTER TABLE "HuntSession" ALTER COLUMN "xpGained" SET DATA TYPE BIGINT,
ALTER COLUMN "profit" SET DATA TYPE BIGINT,
ALTER COLUMN "waste" SET DATA TYPE BIGINT,
ALTER COLUMN "loot" SET DATA TYPE BIGINT;
