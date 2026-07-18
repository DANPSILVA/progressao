'use client';

import React from 'react';
import StatCard from './StatCard';
import { SummaryMetrics } from '@/lib/dashboardMock';

export default function StatsGrid({ summary }: { summary: SummaryMetrics }) {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-4">
      <StatCard title="XP" value={summary.xp} subtitle="Total" accent />
      <StatCard title="XP/H" value={Math.round(summary.xpPerHour)} subtitle="Média" />
      <StatCard title="Profit" value={summary.profit} subtitle="Gold" />
      <StatCard title="Waste" value={summary.waste} subtitle="Despesas" />
      <StatCard title="Loot" value={summary.loot} subtitle="Itens" />
      <StatCard title="Bosses" value={summary.bosses} subtitle="Derrotados" />
    </div>
  );
}
