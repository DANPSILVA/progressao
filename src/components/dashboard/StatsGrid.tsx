'use client';

import React from 'react';
import { Zap, Clock, Coins, TrendingDown, Gem, Skull } from 'lucide-react';
import StatCard from './StatCard';
import { SummaryMetrics } from '@/lib/dashboard';

export default function StatsGrid({ summary }: { summary: SummaryMetrics }) {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
      <StatCard title="XP" value={summary.xp} subtitle="Total" icon={Zap} color="var(--series-1)" />
      <StatCard title="XP/H" value={Math.round(summary.xpPerHour)} subtitle="Média" icon={Clock} color="var(--series-2)" />
      <StatCard title="Profit" value={summary.profit} subtitle="Gold" icon={Coins} color="var(--series-3)" />
      <StatCard title="Waste" value={summary.waste} subtitle="Despesas" icon={TrendingDown} color="var(--series-4)" />
      <StatCard title="Loot" value={summary.loot} subtitle="Itens" icon={Gem} color="var(--series-5)" />
      <StatCard title="Bosses" value={summary.bosses} subtitle="Derrotados" icon={Skull} color="var(--series-6)" />
    </div>
  );
}
