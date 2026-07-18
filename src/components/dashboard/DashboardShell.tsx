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
import EconomyDonut from './EconomyDonut';
import BossesDeaths from './BossesDeaths';
import ProgressTarget from './ProgressTarget';
import HuntForm from './HuntForm';
import HuntHistory from './HuntHistory';
import CharacterCard from './CharacterCard';
import XpEvolutionChart from './XpEvolutionChart';
import ProfitPerDayChart from './ProfitPerDayChart';
import XpPerHourSessionChart from './XpPerHourSessionChart';
import FriendsPanel from './FriendsPanel';
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
        <button onClick={() => setShowAddForm((v) => !v)} className="btn-tibia btn-tibia--primary text-sm">
          {showAddForm ? 'Fechar' : '+ Nova hunt'}
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
          <EconomyDonut summary={summary} />
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
        tabs={[
          { key: 'overview', label: 'Visão Geral', content: <GlassCard>{overviewTab}</GlassCard> },
          { key: 'history', label: 'Histórico de Hunts', content: historyTab },
          { key: 'stats', label: 'Estatísticas', content: statsTab },
          { key: 'friends', label: 'Amigos', content: friendsTab },
        ]}
      />
    </motion.div>
  );
}
