'use client';

import React, { useMemo } from 'react';
import GlassCard from '@/components/ui/GlassCard';
import { HourlyPointFull, SummaryMetrics } from '@/lib/dashboard';

export default function ProgressTarget({ data, summary }: { data: HourlyPointFull[]; summary: SummaryMetrics }) {
  // simplistic: assume next level requires fixed XP (e.g., 200k), compute remaining
  const nextLevelXP = 200000;
  const remaining = Math.max(0, nextLevelXP - summary.xp);
  const hoursNeeded = Math.ceil(remaining / Math.max(1, Math.round(summary.xpPerHour)));

  return (
    <GlassCard title="Meta de Level">
      <div className="space-y-3">
        <div>
          <div className="text-sm text-muted-300">Próximo level</div>
          <div className="text-xl font-semibold">{nextLevelXP.toLocaleString()} XP</div>
        </div>

        <div className="flex items-center justify-between">
          <div className="text-sm text-muted-300">Faltam</div>
          <div className="text-lg font-semibold">{remaining.toLocaleString()} XP</div>
        </div>

        <div className="flex items-center justify-between">
          <div className="text-sm text-muted-300">Estimativa</div>
          <div className="text-lg font-semibold">{hoursNeeded} horas</div>
        </div>
      </div>
    </GlassCard>
  );
}
