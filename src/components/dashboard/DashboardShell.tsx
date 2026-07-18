'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import GlassCard from '@/components/ui/GlassCard';
import StatsGrid from './StatsGrid';
import Filters from './Filters';
import InteractiveChart from './InteractiveChart';
import LootProfit from './LootProfit';
import BossesDeaths from './BossesDeaths';
import ProgressTarget from './ProgressTarget';
import HuntForm from './HuntForm';
import HuntHistory from './HuntHistory';
import CharacterCard from './CharacterCard';
import { aggregateByDay, computeSummary, filterByPeriod, Character, HuntSession } from '@/lib/dashboard';

export default function DashboardShell() {
  const [period, setPeriod] = useState<'24h' | '7d' | '30d' | '90d'>('7d');
  const [showCumulative, setShowCumulative] = useState(false);
  const [hunts, setHunts] = useState<HuntSession[]>([]);
  const [character, setCharacter] = useState<Character | null>(null);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);

  const loadData = useCallback(async () => {
    const [huntsRes, characterRes] = await Promise.all([fetch('/api/hunts'), fetch('/api/character')]);
    if (huntsRes.ok) setHunts(await huntsRes.json());
    if (characterRes.ok) setCharacter(await characterRes.json());
    setLoading(false);
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
            <LootProfit summary={summary} />
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
