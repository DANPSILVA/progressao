'use client';

import React, { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import GlassCard from '@/components/ui/GlassCard';
import StatsGrid from './StatsGrid';
import Filters from './Filters';
import InteractiveChart from './InteractiveChart';
import LootProfit from './LootProfit';
import BossesDeaths from './BossesDeaths';
import ProgressTarget from './ProgressTarget';
import { generateMockSeries, SummaryMetrics } from '@/lib/dashboardMock';

export default function DashboardShell() {
  const [period, setPeriod] = useState<'24h' | '7d' | '30d' | '90d'>('7d');
  const [showCumulative, setShowCumulative] = useState(false);

  // generate mock data — in a real app, fetch from your API
  const data = useMemo(() => generateMockSeries(90), []);

  const windowed = useMemo(() => {
    const now = new Date();
    let start = new Date();
    if (period === '24h') start.setDate(now.getDate() - 1);
    if (period === '7d') start.setDate(now.getDate() - 7);
    if (period === '30d') start.setDate(now.getDate() - 30);
    if (period === '90d') start.setDate(now.getDate() - 90);
    return data.filter((d) => new Date(d.time) >= start);
  }, [data, period]);

  const summary: SummaryMetrics = useMemo(() => {
    // compute aggregated metrics for the selected window
    const xp = windowed.reduce((s, p) => s + p.xp, 0);
    const hours = Math.max(1, windowed.length);
    const xpPerHour = xp / hours;
    const profit = windowed.reduce((s, p) => s + p.profit, 0);
    const waste = windowed.reduce((s, p) => s + p.waste, 0);
    const loot = windowed.reduce((s, p) => s + p.loot, 0);
    const bosses = windowed.reduce((s, p) => s + p.bosses, 0);
    const deaths = windowed.reduce((s, p) => s + p.deaths, 0);

    return { xp, xpPerHour, profit, waste, loot, bosses, deaths };
  }, [windowed]);

  return (
    <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }}>
      <GlassCard>
        <div className="flex items-center justify-between mb-6">
          <div>
            <div className="text-sm text-muted-300">Visão geral</div>
            <div className="text-xl font-semibold">Seu progresso — visão rápida</div>
          </div>
          <div className="flex items-center gap-3">
            <Filters period={period} onChange={setPeriod} showCumulative={showCumulative} setShowCumulative={setShowCumulative} />
          </div>
        </div>

        <StatsGrid summary={summary} />

        <div className="mt-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <GlassCard>
              <InteractiveChart data={windowed} showCumulative={showCumulative} />
            </GlassCard>
          </div>

          <div className="space-y-6">
            <LootProfit summary={summary} />
            <BossesDeaths summary={summary} />
            <ProgressTarget data={data} summary={summary} />
          </div>
        </div>
      </GlassCard>
    </motion.div>
  );
}
