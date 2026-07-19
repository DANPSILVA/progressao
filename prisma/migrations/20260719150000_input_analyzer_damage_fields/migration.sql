-- AlterTable
ALTER TABLE "HuntSession" ADD COLUMN     "damageReceived" BIGINT,
ADD COLUMN     "damageSources" JSONB,
ADD COLUMN     "damageTypes" JSONB,
ADD COLUMN     "maxDps" INTEGER;
