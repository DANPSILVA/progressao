'use client';

import React from 'react';
import { Skull, HeartCrack } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import { SummaryMetrics } from '@/lib/dashboard';

export default function BossesDeaths({ summary }: { summary: SummaryMetrics }) {
  return (
    <GlassCard title="Bosses & Deaths">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Skull className="w-4 h-4" style={{ color: 'var(--series-6)' }} />
          <div>
            <div className="text-sm text-muted-300">Bosses</div>
            <div className="text-lg font-semibold">{summary.bosses}</div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <div className="text-right">
            <div className="text-sm text-muted-300">Deaths</div>
            <div className="text-lg font-semibold" style={{ color: 'var(--series-8)' }}>
              {summary.deaths}
            </div>
          </div>
          <HeartCrack className="w-4 h-4" style={{ color: 'var(--series-8)' }} />
        </div>
      </div>
    </GlassCard>
  );
}
