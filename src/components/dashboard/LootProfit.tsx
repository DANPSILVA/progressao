'use client';

import React from 'react';
import { SummaryMetrics } from '@/lib/dashboard';
import GlassCard from '@/components/ui/GlassCard';

export default function LootProfit({ summary }: { summary: SummaryMetrics }) {
  return (
    <GlassCard title="Loot & Profit">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-sm text-muted-300">Loot total</div>
          <div className="text-lg font-semibold">{summary.loot.toLocaleString()}</div>
        </div>
        <div className="text-right">
          <div className="text-sm text-muted-300">Profit</div>
          <div className="text-lg font-semibold">{summary.profit.toLocaleString()} gp</div>
        </div>
      </div>
    </GlassCard>
  );
}
