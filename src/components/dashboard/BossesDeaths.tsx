'use client';

import React from 'react';
import GlassCard from '@/components/ui/GlassCard';
import { SummaryMetrics } from '@/lib/dashboard';

export default function BossesDeaths({ summary }: { summary: SummaryMetrics }) {
  return (
    <GlassCard title="Bosses & Deaths">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-sm text-muted-300">Bosses</div>
          <div className="text-lg font-semibold">{summary.bosses}</div>
        </div>
        <div className="text-right">
          <div className="text-sm text-muted-300">Deaths</div>
          <div className="text-lg font-semibold text-danger">{summary.deaths}</div>
        </div>
      </div>
    </GlassCard>
  );
}
