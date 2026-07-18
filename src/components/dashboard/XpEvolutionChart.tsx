'use client';

import React, { useMemo } from 'react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import GlassCard from '@/components/ui/GlassCard';
import { HourlyPointFull } from '@/lib/dashboard';

export default function XpEvolutionChart({ data }: { data: HourlyPointFull[] }) {
  const cumulative = useMemo(() => {
    const sorted = [...data].sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime());
    let running = 0;
    return sorted.map((d) => {
      running += d.xp;
      return { label: new Date(d.time).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }), xp: running };
    });
  }, [data]);

  return (
    <GlassCard title="Evolução de XP acumulado">
      {cumulative.length === 0 ? (
        <p className="text-sm text-muted-300">Sem dados no período selecionado.</p>
      ) : (
        <div style={{ width: '100%', height: 280 }}>
          <ResponsiveContainer>
            <AreaChart data={cumulative} margin={{ top: 10, right: 20, left: 8, bottom: 0 }}>
              <defs>
                <linearGradient id="xpEvoGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="var(--series-1)" stopOpacity={0.3} />
                  <stop offset="100%" stopColor="var(--series-1)" stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="label" tick={{ fill: 'var(--muted-300)' }} />
              <YAxis
                tick={{ fill: 'var(--muted-300)' }}
                width={56}
                tickFormatter={(v: number) => Intl.NumberFormat('pt-BR', { notation: 'compact' }).format(v)}
              />
              <Tooltip
                formatter={(value: number) => [value.toLocaleString(), 'XP acumulado']}
                contentStyle={{ background: 'var(--bg-800)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8 }}
              />
              <Area type="monotone" dataKey="xp" stroke="var(--series-1)" fill="url(#xpEvoGrad)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
    </GlassCard>
  );
}
