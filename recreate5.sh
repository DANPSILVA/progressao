#!/bin/bash
set -e

rm -f recreate4.sh
rm -rf src/app/weather src/app/styleguide src/components/weather
rm -f src/components/dashboard/EconomyDonut.tsx

mkdir -p src/components/dashboard src/components/ui src/app/dashboard

cat > "src/components/dashboard/DashboardShell.tsx" << 'EOF_DashboardShell_tsx'
'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { RefreshCw } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import Tabs from '@/components/ui/Tabs';
import StatsGrid from './StatsGrid';
import Filters from './Filters';
import PeriodFilter from './PeriodFilter';
import InteractiveChart from './InteractiveChart';
import BossesDeaths from './BossesDeaths';
import ProgressTarget from './ProgressTarget';
import HuntForm from './HuntForm';
import HuntHistory from './HuntHistory';
import CharacterCard from './CharacterCard';
import XpEvolutionChart from './XpEvolutionChart';
import ProfitPerDayChart from './ProfitPerDayChart';
import XpPerHourSessionChart from './XpPerHourSessionChart';
import FriendsPanel from './FriendsPanel';
import RubinOtRanking from './RubinOtRanking';
import { aggregateByDay, computeSummary, filterByPeriod, perSessionSeries, Character, HuntSession } from '@/lib/dashboard';

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
  const [activeTab, setActiveTab] = useState('overview');

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
  const sessionPoints = useMemo(() => perSessionSeries(windowedHunts), [windowedHunts]);

  if (loading) {
    return (
      <GlassCard>
        <p className="text-muted-300">Carregando seu progresso...</p>
      </GlassCard>
    );
  }

  const header = (
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
        <button
          onClick={() => {
            setShowAddForm(true);
            setActiveTab('history');
          }}
          className="btn-tibia btn-tibia--primary text-sm"
        >
          + Nova hunt
        </button>
      </div>
    </div>
  );

  const overviewTab = (
    <div>
      {header}
      <StatsGrid summary={summary} />

      <div className="mt-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <GlassCard>
            <InteractiveChart data={windowed} showCumulative={showCumulative} />
          </GlassCard>
        </div>

        <div className="space-y-6">
          <BossesDeaths summary={summary} />
          <ProgressTarget data={allSeries} summary={summary} />
        </div>
      </div>
    </div>
  );

  const historyTab = (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-xl font-semibold">Histórico de hunts</div>
        <button onClick={() => setShowAddForm((v) => !v)} className="btn-tibia btn-tibia--primary text-sm">
          {showAddForm ? 'Fechar' : '+ Nova hunt'}
        </button>
      </div>

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
    </div>
  );

  const statsTab = (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-xl font-semibold">Estatísticas</div>
        <PeriodFilter period={period} onChange={setPeriod} />
      </div>
      <XpEvolutionChart data={windowed} />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ProfitPerDayChart data={windowed} />
        <XpPerHourSessionChart data={sessionPoints} />
      </div>
    </div>
  );

  const friendsTab = (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-xl font-semibold">Amigos</div>
        <PeriodFilter period={period} onChange={setPeriod} />
      </div>
      <FriendsPanel period={period} />
    </div>
  );

  return (
    <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }} className="space-y-6">
      {character && <CharacterCard character={character} onChanged={loadData} />}

      <Tabs
        active={activeTab}
        onActiveChange={setActiveTab}
        tabs={[
          { key: 'overview', label: 'Visão Geral', content: <GlassCard>{overviewTab}</GlassCard> },
          { key: 'history', label: 'Histórico de Hunts', content: historyTab },
          { key: 'stats', label: 'Estatísticas', content: statsTab },
          { key: 'friends', label: 'Amigos', content: friendsTab },
          { key: 'ranking', label: 'Ranking RubinOT', content: <RubinOtRanking /> },
        ]}
      />
    </motion.div>
  );
}
EOF_DashboardShell_tsx

cat > "src/components/dashboard/RubinOtRanking.tsx" << 'EOF_RubinOtRanking_tsx'
'use client';

import React from 'react';
import { ExternalLink, Trophy } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';

const HIGHSCORES_URL = 'https://rubinot.com.br/highscores';

export default function RubinOtRanking() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-xl font-semibold">Ranking RubinOT</div>
      </div>

      <GlassCard>
        <div className="flex flex-col items-center text-center gap-4 py-8">
          <div className="w-14 h-14 rounded-full bg-accent/10 flex items-center justify-center">
            <Trophy className="w-7 h-7 text-accent" />
          </div>
          <div className="space-y-1 max-w-md">
            <p className="text-[var(--text-100)] font-medium">Highscores oficiais do RubinOT</p>
            <p className="text-sm text-muted-300">
              O site do RubinOT protege o highscores contra acesso automatizado e carrega os dados apenas depois
              que a página abre no seu navegador, então não é possível trazer o ranking ao vivo para dentro do
              RubinTracker. Use o link abaixo para conferir o ranking atualizado direto na fonte oficial.
            </p>
          </div>
          <a
            href={HIGHSCORES_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-tibia btn-tibia--primary text-sm inline-flex items-center gap-2"
          >
            Abrir highscores no site do RubinOT <ExternalLink className="w-3.5 h-3.5" />
          </a>
        </div>
      </GlassCard>
    </div>
  );
}
EOF_RubinOtRanking_tsx

cat > "src/components/dashboard/HuntForm.tsx" << 'EOF_HuntForm_tsx'
'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import type { z } from 'zod';
import { huntSessionSchema } from '@/lib/validation';
import GlassCard from '@/components/ui/GlassCard';
import { HuntSession } from '@/lib/dashboard';

type FormData = z.infer<typeof huntSessionSchema>;

function toLocalDateTimeInput(date: Date) {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export default function HuntForm({
  hunt,
  onSaved,
  onCancel,
}: {
  hunt?: HuntSession;
  onSaved: () => void;
  onCancel?: () => void;
}) {
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(huntSessionSchema),
    defaultValues: (hunt
      ? {
          startedAt: toLocalDateTimeInput(new Date(hunt.startedAt)),
          durationMin: hunt.durationMin,
          xpGained: hunt.xpGained,
          profit: hunt.profit,
          bosses: hunt.bosses,
          deaths: hunt.deaths,
          levelAfter: hunt.levelAfter ?? undefined,
        }
      : {
          startedAt: toLocalDateTimeInput(new Date()),
          durationMin: 60,
          xpGained: 0,
          profit: 0,
          bosses: 0,
          deaths: 0,
        }) as unknown as FormData,
  });

  const xpGained = Number(watch('xpGained')) || 0;
  const durationMin = Number(watch('durationMin')) || 0;
  const xpPerHourPreview = durationMin > 0 ? Math.round(xpGained / (durationMin / 60)) : 0;

  const onSubmit = async (data: FormData) => {
    setServerError(null);
    const url = hunt ? `/api/hunts/${hunt.id}` : '/api/hunts';
    const method = hunt ? 'PUT' : 'POST';

    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setServerError(body.error ?? 'Não foi possível salvar a hunt');
      return;
    }

    onSaved();
  };

  return (
    <GlassCard title={hunt ? 'Editar hunt' : 'Registrar nova hunt'}>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label-tibia">Início</label>
            <input type="datetime-local" className="input-tibia" {...register('startedAt')} />
            {errors.startedAt && <p className="text-sm text-red-400 mt-1">{errors.startedAt.message}</p>}
          </div>

          <div>
            <label className="label-tibia">Duração (min)</label>
            <input type="number" className="input-tibia" {...register('durationMin')} />
            {errors.durationMin && <p className="text-sm text-red-400 mt-1">{errors.durationMin.message}</p>}
          </div>

          <div>
            <label className="label-tibia">XP ganho</label>
            <input type="number" className="input-tibia" {...register('xpGained')} />
            {errors.xpGained && <p className="text-sm text-red-400 mt-1">{errors.xpGained.message}</p>}
          </div>

          <div>
            <label className="label-tibia">Level após (opcional)</label>
            <input type="number" className="input-tibia" {...register('levelAfter')} />
          </div>

          <div>
            <label className="label-tibia">Profit (gp)</label>
            <input type="number" className="input-tibia" {...register('profit')} />
          </div>

          <div>
            <label className="label-tibia">Bosses</label>
            <input type="number" className="input-tibia" {...register('bosses')} />
          </div>

          <div>
            <label className="label-tibia">Deaths</label>
            <input type="number" className="input-tibia" {...register('deaths')} />
          </div>
        </div>

        <div className="text-sm text-muted-300">
          XP/h calculado automaticamente: <span className="text-accent font-semibold">{xpPerHourPreview.toLocaleString()}</span>
        </div>

        {serverError && <p className="text-sm text-red-400">{serverError}</p>}
        {Object.keys(errors).length > 0 && (
          <p className="text-sm text-red-400">Verifique os campos destacados antes de salvar.</p>
        )}

        <div className="flex gap-3">
          <button type="submit" disabled={isSubmitting} className="btn-tibia btn-tibia--primary">
            {isSubmitting ? 'Salvando...' : hunt ? 'Salvar alterações' : 'Adicionar hunt'}
          </button>
          {onCancel && (
            <button type="button" onClick={onCancel} className="btn-tibia">
              Cancelar
            </button>
          )}
        </div>
      </form>
    </GlassCard>
  );
}
EOF_HuntForm_tsx

cat > "src/components/dashboard/HuntHistory.tsx" << 'EOF_HuntHistory_tsx'
'use client';

import React, { useState } from 'react';
import GlassCard from '@/components/ui/GlassCard';
import { HuntSession } from '@/lib/dashboard';
import HuntForm from './HuntForm';

export default function HuntHistory({ hunts, onChanged }: { hunts: HuntSession[]; onChanged: () => void }) {
  const [editing, setEditing] = useState<HuntSession | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const sorted = [...hunts].sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());

  const handleDelete = async (id: string) => {
    setDeletingId(id);
    await fetch(`/api/hunts/${id}`, { method: 'DELETE' });
    setDeletingId(null);
    onChanged();
  };

  if (editing) {
    return (
      <HuntForm
        hunt={editing}
        onSaved={() => {
          setEditing(null);
          onChanged();
        }}
        onCancel={() => setEditing(null)}
      />
    );
  }

  return (
    <GlassCard title="Histórico de hunts">
      {sorted.length === 0 ? (
        <p className="text-sm text-muted-300">Nenhuma hunt registrada ainda.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-muted-300">
                <th className="py-2 pr-4">Data</th>
                <th className="py-2 pr-4">Duração</th>
                <th className="py-2 pr-4">XP</th>
                <th className="py-2 pr-4">XP/h</th>
                <th className="py-2 pr-4">Profit</th>
                <th className="py-2 pr-4"></th>
              </tr>
            </thead>
            <tbody>
              {sorted.map((h) => {
                const xpPerHour = h.durationMin > 0 ? Math.round(h.xpGained / (h.durationMin / 60)) : 0;
                return (
                  <tr key={h.id} className="border-t border-white/6">
                    <td className="py-2 pr-4">{new Date(h.startedAt).toLocaleString()}</td>
                    <td className="py-2 pr-4">{h.durationMin} min</td>
                    <td className="py-2 pr-4">{h.xpGained.toLocaleString()}</td>
                    <td className="py-2 pr-4 text-accent">{xpPerHour.toLocaleString()}</td>
                    <td className="py-2 pr-4">{h.profit.toLocaleString()} gp</td>
                    <td className="py-2 pr-4 text-right whitespace-nowrap">
                      <button onClick={() => setEditing(h)} className="text-accent mr-3">
                        Editar
                      </button>
                      <button
                        onClick={() => handleDelete(h.id)}
                        disabled={deletingId === h.id}
                        className="text-red-400"
                      >
                        {deletingId === h.id ? 'Excluindo...' : 'Excluir'}
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </GlassCard>
  );
}
EOF_HuntHistory_tsx

cat > "src/components/dashboard/StatsGrid.tsx" << 'EOF_StatsGrid_tsx'
'use client';

import React from 'react';
import { Zap, Clock, Coins, Skull } from 'lucide-react';
import StatCard from './StatCard';
import { SummaryMetrics } from '@/lib/dashboard';

export default function StatsGrid({ summary }: { summary: SummaryMetrics }) {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
      <StatCard title="XP" value={summary.xp} subtitle="Total" icon={Zap} color="var(--series-1)" />
      <StatCard title="XP/H" value={Math.round(summary.xpPerHour)} subtitle="Média" icon={Clock} color="var(--series-2)" />
      <StatCard title="Profit" value={summary.profit} subtitle="Gold" icon={Coins} color="var(--series-3)" />
      <StatCard title="Bosses" value={summary.bosses} subtitle="Derrotados" icon={Skull} color="var(--series-6)" />
    </div>
  );
}
EOF_StatsGrid_tsx

cat > "src/components/ui/Tabs.tsx" << 'EOF_Tabs_tsx'
'use client';

import React, { useState } from 'react';

export type TabItem = {
  key: string;
  label: string;
  content: React.ReactNode;
};

export default function Tabs({
  tabs,
  defaultTab,
  active: controlledActive,
  onActiveChange,
}: {
  tabs: TabItem[];
  defaultTab?: string;
  active?: string;
  onActiveChange?: (key: string) => void;
}) {
  const [internalActive, setInternalActive] = useState(defaultTab ?? tabs[0]?.key);
  const active = controlledActive ?? internalActive;

  const setActive = (key: string) => {
    setInternalActive(key);
    onActiveChange?.(key);
  };

  return (
    <div>
      <div role="tablist" className="flex gap-1 rounded-md bg-[rgba(255,255,255,0.02)] p-1 mb-6 w-fit">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            role="tab"
            aria-selected={active === tab.key}
            onClick={() => setActive(tab.key)}
            className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors ${
              active === tab.key ? 'bg-accent text-black' : 'text-muted-300 hover:text-[var(--text-100)]'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {tabs.map((tab) => (
        <div key={tab.key} role="tabpanel" hidden={active !== tab.key}>
          {active === tab.key && tab.content}
        </div>
      ))}
    </div>
  );
}
EOF_Tabs_tsx

cat > "src/components/Header.tsx" << 'EOF_Header_tsx'
'use client';

import Link from 'next/link';
import { useSession, signOut } from 'next-auth/react';
import ThemeToggle from '@/components/ui/ThemeToggle';

export default function Header() {
  const { data: session, status } = useSession();

  return (
    <header className="w-full border-b border-white/6 bg-gradient-to-b from-[rgba(0,0,0,0.06)] to-transparent">
      <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/" className="logo-mark">
            <img src="/logo-tibia-inspired.svg" alt="RubinTracker" width={36} height={36} />
          </Link>
          <Link href="/" className="text-lg font-semibold tracking-tight">RubinTracker</Link>
        </div>

        <nav className="flex items-center gap-4">
          {status === 'authenticated' ? (
            <>
              <Link href="/dashboard" className="text-sm text-muted-300 hover:text-text-100">Dashboard</Link>
              <span className="text-sm text-muted-300 hidden sm:inline">{session.user?.name ?? session.user?.email}</span>
              <button onClick={() => signOut({ callbackUrl: '/' })} className="btn-tibia text-sm">
                Sair
              </button>
            </>
          ) : status === 'loading' ? null : (
            <>
              <Link href="/login" className="text-sm text-muted-300 hover:text-text-100">Entrar</Link>
              <Link href="/register" className="btn-tibia btn-tibia--primary text-sm">Cadastrar</Link>
            </>
          )}
          <ThemeToggle />
        </nav>
      </div>
    </header>
  );
}
EOF_Header_tsx

cat > "src/app/dashboard/page.tsx" << 'EOF_DashboardPage_tsx'
import { getServerSession } from 'next-auth';
import { redirect } from 'next/navigation';
import Header from '@/components/Header';
import DashboardShell from '@/components/dashboard/DashboardShell';
import { authOptions } from '@/lib/auth';

export const metadata = {
  title: 'RubinTracker — Dashboard',
  description: 'Visualize seus KPIs e evolução — XP, Profit, Bosses e demais métricas.'
};

export default async function DashboardPage() {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    redirect('/login');
  }

  return (
    <div>
      <Header />
      <main className="max-w-6xl mx-auto py-10 px-4">
        <h1 className="text-3xl font-semibold mb-6">Dashboard</h1>
        <DashboardShell />
      </main>
    </div>
  );
}
EOF_DashboardPage_tsx

if [ -f package.json ] && grep -q '"cheerio"' package.json; then
  npm uninstall cheerio
fi

git add -A
git commit -m "Add RubinOT ranking tab, jump to Hunt History on +Nova hunt, remove Loot/Waste/Weather/Styleguide"
git push -u origin claude/user-auth-character-progress-00b5p6
