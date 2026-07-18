#!/bin/bash
set -e
rm -f src/components/dashboard/LootProfit.tsx

cat > "src/components/dashboard/BossesDeaths.tsx" << 'EOF_src_components_dashboard_BossesDeaths_tsx_'
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
EOF_src_components_dashboard_BossesDeaths_tsx_

cat > "src/components/dashboard/DashboardShell.tsx" << 'EOF_src_components_dashboard_DashboardShell_tsx_'
'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { RefreshCw } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import StatsGrid from './StatsGrid';
import Filters from './Filters';
import InteractiveChart from './InteractiveChart';
import EconomyDonut from './EconomyDonut';
import BossesDeaths from './BossesDeaths';
import ProgressTarget from './ProgressTarget';
import HuntForm from './HuntForm';
import HuntHistory from './HuntHistory';
import CharacterCard from './CharacterCard';
import { aggregateByDay, computeSummary, filterByPeriod, Character, HuntSession } from '@/lib/dashboard';

function formatUpdatedAt(date: Date) {
  return date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

export default function DashboardShell() {
  const [period, setPeriod] = useState<'24h' | '7d' | '30d' | '90d'>('7d');
  const [showCumulative, setShowCumulative] = useState(false);
  const [hunts, setHunts] = useState<HuntSession[]>([]);
  const [character, setCharacter] = useState<Character | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const loadData = useCallback(async () => {
    setRefreshing(true);
    const [huntsRes, characterRes] = await Promise.all([fetch('/api/hunts'), fetch('/api/character')]);
    if (huntsRes.ok) setHunts(await huntsRes.json());
    if (characterRes.ok) setCharacter(await characterRes.json());
    setLoading(false);
    setRefreshing(false);
    setLastUpdated(new Date());
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const windowedHunts = useMemo(() => filterByPeriod(hunts, period), [hunts, period]);
  const windowed = useMemo(() => aggregateByDay(windowedHunts), [windowedHunts]);
  const allSeries = useMemo(() => aggregateByDay(hunts), [hunts]);
  const summary = useMemo(() => computeSummary(windowedHunts), [windowedHunts]);

  if (loading) {
    return (
      <GlassCard>
        <p className="text-muted-300">Carregando seu progresso...</p>
      </GlassCard>
    );
  }

  return (
    <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }} className="space-y-6">
      {character && <CharacterCard character={character} onChanged={loadData} />}

      <GlassCard>
        <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
          <div>
            <div className="text-sm text-muted-300">Visão geral</div>
            <div className="text-xl font-semibold">Seu progresso — visão rápida</div>
            {lastUpdated && (
              <div className="flex items-center gap-1.5 text-xs text-muted-300 mt-1">
                <span>Última atualização: {formatUpdatedAt(lastUpdated)}</span>
                <button
                  onClick={loadData}
                  disabled={refreshing}
                  aria-label="Atualizar dados"
                  className="p-0.5 rounded hover:text-accent disabled:opacity-50"
                >
                  <RefreshCw className={`w-3 h-3 ${refreshing ? 'animate-spin' : ''}`} />
                </button>
              </div>
            )}
          </div>
          <div className="flex items-center gap-3">
            <Filters period={period} onChange={setPeriod} showCumulative={showCumulative} setShowCumulative={setShowCumulative} />
            <button onClick={() => setShowAddForm((v) => !v)} className="btn-tibia btn-tibia--primary text-sm">
              {showAddForm ? 'Fechar' : '+ Nova hunt'}
            </button>
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
            <EconomyDonut summary={summary} />
            <BossesDeaths summary={summary} />
            <ProgressTarget data={allSeries} summary={summary} />
          </div>
        </div>
      </GlassCard>

      {showAddForm && (
        <HuntForm
          onSaved={() => {
            setShowAddForm(false);
            loadData();
          }}
          onCancel={() => setShowAddForm(false)}
        />
      )}

      <HuntHistory hunts={hunts} onChanged={loadData} />
    </motion.div>
  );
}
EOF_src_components_dashboard_DashboardShell_tsx_

cat > "src/components/dashboard/EconomyDonut.tsx" << 'EOF_src_components_dashboard_EconomyDonut_tsx_'
'use client';

import React, { useMemo } from 'react';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts';
import GlassCard from '@/components/ui/GlassCard';
import { SummaryMetrics } from '@/lib/dashboard';

const SLICES = [
  { key: 'profit', label: 'Profit', color: 'var(--series-3)' },
  { key: 'waste', label: 'Waste', color: 'var(--series-4)' },
] as const;

export default function EconomyDonut({ summary }: { summary: SummaryMetrics }) {
  const data = useMemo(
    () =>
      SLICES.map((s) => ({
        name: s.label,
        value: summary[s.key],
        color: s.color,
      })).filter((d) => d.value > 0),
    [summary]
  );

  const total = data.reduce((sum, d) => sum + d.value, 0);

  return (
    <GlassCard title="Economia (Profit / Waste)">
      {total === 0 ? (
        <p className="text-sm text-muted-300">Sem dados no período selecionado.</p>
      ) : (
        <div className="flex items-center gap-4">
          <div style={{ width: 120, height: 120 }} className="shrink-0">
            <ResponsiveContainer>
              <PieChart>
                <Pie data={data} dataKey="value" nameKey="name" innerRadius={36} outerRadius={56} paddingAngle={2} stroke="none">
                  {data.map((d) => (
                    <Cell key={d.name} fill={d.color} />
                  ))}
                </Pie>
                <Tooltip
                  formatter={(value: number, name: string) => [value.toLocaleString(), name]}
                  contentStyle={{ background: 'var(--bg-800)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8 }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>
          <ul className="space-y-2 text-sm min-w-0">
            {data.map((d) => (
              <li key={d.name} className="flex items-center gap-2">
                <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: d.color }} />
                <span className="text-muted-300">{d.name}</span>
                <span className="ml-auto font-semibold text-[var(--text-100)]">
                  {((d.value / total) * 100).toFixed(1)}%
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </GlassCard>
  );
}
EOF_src_components_dashboard_EconomyDonut_tsx_

cat > "src/components/dashboard/InteractiveChart.tsx" << 'EOF_src_components_dashboard_InteractiveChart_tsx_'
'use client';

import React from 'react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, AreaChart, Area, CartesianGrid, Bar, BarChart } from 'recharts';
import { HourlyPointFull } from '@/lib/dashboard';

export default function InteractiveChart({ data, showCumulative }: { data: HourlyPointFull[]; showCumulative: boolean }) {
  // map to chart-friendly
  const mapped = data.map((d) => ({ timeLabel: new Date(d.time).toLocaleDateString(), xp: d.xp, profit: d.profit }));

  const cumulative = mapped.reduce<{ timeLabel: string; xp: number; profit: number }[]>((acc, cur, i) => {
    const prev = acc[i - 1];
    acc.push({ timeLabel: cur.timeLabel, xp: cur.xp + (prev ? prev.xp : 0), profit: cur.profit + (prev ? prev.profit : 0) });
    return acc;
  }, []);

  const source = showCumulative ? cumulative : mapped;

  return (
    <div style={{ width: '100%', height: 360 }}>
      <ResponsiveContainer>
        <AreaChart data={source} margin={{ top: 10, right: 30, left: 8, bottom: 0 }}>
          <defs>
            <linearGradient id="g1" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--accent)" stopOpacity={0.18} />
              <stop offset="100%" stopColor="var(--accent)" stopOpacity={0.02} />
            </linearGradient>
          </defs>
          <XAxis dataKey="timeLabel" tick={{ fill: 'var(--muted-300)' }} />
          <YAxis
            yAxisId="left"
            tick={{ fill: 'var(--muted-300)' }}
            width={56}
            tickFormatter={(v: number) => Intl.NumberFormat('pt-BR', { notation: 'compact' }).format(v)}
          />
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.02)" />
          <Tooltip formatter={(value: any) => value.toLocaleString?.() ?? value} />
          <Area yAxisId="left" type="monotone" dataKey="xp" stroke="var(--accent)" fill="url(#g1)" strokeWidth={2} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
EOF_src_components_dashboard_InteractiveChart_tsx_

cat > "src/components/dashboard/StatCard.tsx" << 'EOF_src_components_dashboard_StatCard_tsx_'
'use client';

import React from 'react';
import { motion } from 'framer-motion';
import type { LucideIcon } from 'lucide-react';

export default function StatCard({
  title,
  value,
  subtitle,
  icon: Icon,
  color = 'var(--series-1)',
}: {
  title: string;
  value: number | string;
  subtitle?: string;
  icon?: LucideIcon;
  color?: string;
}) {
  return (
    <motion.div whileHover={{ y: -4 }} className="theme-glass p-4 rounded-md flex items-center gap-3">
      {Icon && (
        <div
          className="flex items-center justify-center w-9 h-9 rounded-full shrink-0"
          style={{ backgroundColor: `color-mix(in srgb, ${color} 18%, transparent)`, color }}
        >
          <Icon className="w-4 h-4" />
        </div>
      )}
      <div className="min-w-0">
        <div className="text-xs text-muted-300 truncate">{title}</div>
        <div className="text-lg font-semibold text-[var(--text-100)] truncate">
          {typeof value === 'number' ? value.toLocaleString() : value}
        </div>
        {subtitle && <div className="text-xs text-muted-300 truncate">{subtitle}</div>}
      </div>
    </motion.div>
  );
}
EOF_src_components_dashboard_StatCard_tsx_

cat > "src/components/dashboard/StatsGrid.tsx" << 'EOF_src_components_dashboard_StatsGrid_tsx_'
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
EOF_src_components_dashboard_StatsGrid_tsx_

cat > "src/components/ui/ThemeToggle.tsx" << 'EOF_src_components_ui_ThemeToggle_tsx_'
'use client';

import { useEffect, useState } from 'react';
import { Sun, Moon } from 'lucide-react';

export default function ThemeToggle() {
  const [isDark, setIsDark] = useState(true);

  useEffect(() => {
    setIsDark(document.documentElement.classList.contains('dark'));
  }, []);

  useEffect(() => {
    if (isDark) document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');
  }, [isDark]);

  return (
    <button
      onClick={() => setIsDark((s) => !s)}
      className="px-3 py-2 rounded-md bg-white/6 focus-ring"
      aria-label="Alternar tema"
    >
      {isDark ? <Moon className="w-4 h-4 text-accent" /> : <Sun className="w-4 h-4 text-muted-300" />}
    </button>
  );
}
EOF_src_components_ui_ThemeToggle_tsx_

cat > "src/styles/tibia.css" << 'EOF_src_styles_tibia_css_'
/* Tibia-inspired theme utilities and tokens */
:root{
  --bg-900:#081014;
  --bg-800:#0b1a1a;
  --glass: rgba(255,255,255,0.03);
  --accent: #E8B93D;
  --accent-2: #F0C24B;
  --neon: #00E0FF;
  --muted-300: #9aa6a6;
  --text-100:#E6F3FF;
  --radius-md: 12px;
  --card-shadow: 0 10px 30px rgba(2,6,23,0.55);

  /* Categorical series colors (validated order for CVD-safety on --bg-900 — keep this exact sequence) */
  --series-1: #3987e5; /* blue */
  --series-2: #008300; /* green */
  --series-3: #d55181; /* magenta */
  --series-4: #c98500; /* gold */
  --series-5: #199e70; /* aqua */
  --series-6: #d95926; /* orange */
  --series-7: #9085e9; /* violet */
  --series-8: #e66767; /* red */
}

/* Glassmorphism base */
.theme-glass {
  background: linear-gradient(180deg, rgba(255,255,255,0.02), rgba(0,0,0,0.02));
  border: 1px solid rgba(255,255,255,0.04);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  box-shadow: var(--card-shadow);
  border-radius: var(--radius-md);
}

/* Tibia-like panel trim (wood-ish) */
.panel-trim {
  background-image: linear-gradient(180deg, rgba(0,0,0,0.12), rgba(255,255,255,0.02));
  border: 1px solid rgba(0,0,0,0.6);
}

/* Soft glow accent */
.glow-accent {
  box-shadow: 0 6px 20px rgba(155,214,107,0.06), inset 0 -2px 10px rgba(0,0,0,0.25);
}

/* Buttons */
.btn-tibia{
  display:inline-flex;align-items:center;gap:8px;padding:8px 12px;border-radius:10px;border:1px solid rgba(255,255,255,0.04);background:linear-gradient(180deg, rgba(255,255,255,0.02), rgba(0,0,0,0.02));color:var(--text-100);font-weight:600;box-shadow:0 6px 18px rgba(2,6,23,0.6);
}
.btn-tibia--primary{background:linear-gradient(180deg,var(--accent), #7bb14f);color:#09210a;border:1px solid rgba(0,0,0,0.4)}
.btn-tibia:disabled{opacity:0.5;cursor:not-allowed}

/* Form inputs */
.input-tibia{
  width:100%;padding:8px 12px;border-radius:10px;border:1px solid rgba(255,255,255,0.08);
  background:rgba(0,0,0,0.2);color:var(--text-100);outline:none;
}
.input-tibia:focus{border-color:var(--accent)}
.label-tibia{display:block;font-size:0.8rem;color:var(--muted-300);margin-bottom:4px}

/* Logo wrapper */
.logo-mark{display:inline-flex;align-items:center;gap:10px}
.logo-mark svg{filter: drop-shadow(0 6px 20px rgba(0,0,0,0.5))}

/* reduced motion */
@media (prefers-reduced-motion: reduce){
  * { animation-duration: 0.001ms !important; transition-duration: 0.001ms !important; }
}
EOF_src_styles_tibia_css_

cat > "tailwind.config.cjs" << 'EOF_tailwind_config_cjs_'
module.exports = {
  content: [
    './app/**/*.{ts,tsx,js,jsx,mdx}',
    './src/**/*.{ts,tsx,js,jsx,mdx}',
    './components/**/*.{ts,tsx,js,jsx}'
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        // Tibia-inspired palette (warm, earthy + modern accents)
        'bg-900': '#081014',
        'bg-800': '#0b1a1a',
        'surface-700': 'rgba(255,255,255,0.02)',
        'glass': 'rgba(255,255,255,0.03)',
        'accent': '#E8B93D', // trophy gold accent
        'accent-2': '#F0C24B', // lighter gold
        'neon': '#00E0FF',
        'muted-300': '#9aa6a6',
        'text-100': '#E6F3FF',
        'series-1': '#3987e5',
        'series-2': '#008300',
        'series-3': '#d55181',
        'series-4': '#c98500',
        'series-5': '#199e70',
        'series-6': '#d95926',
        'series-7': '#9085e9',
        'series-8': '#e66767'
      },
      borderRadius: {
        sm: '8px',
        md: '12px',
        lg: '16px',
        xl: '22px'
      },
      boxShadow: {
        low: '0 6px 20px rgba(2,6,23,0.55)',
        glow: '0 10px 30px rgba(155,214,107,0.06)'
      },
      keyframes: {
        'pop': {
          '0%': { transform: 'scale(0.985)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' }
        }
      },
      animation: {
        pop: 'pop 180ms cubic-bezier(.2,.9,.2,1)'
      }
    }
  },
  plugins: []
};
EOF_tailwind_config_cjs_

git add -A
git commit -m "Restyle dashboard with RubinOT-inspired visual (gold accent, categorical stat colors)"
git push -u origin claude/user-auth-character-progress-00b5p6
