'use client';

import React, { useMemo } from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import GlassCard from '@/components/ui/GlassCard';
import { HourlyPointFull } from '@/lib/dashboard';

export default function ProfitPerDayChart({ data }: { data: HourlyPointFull[] }) {
  const mapped = useMemo(
    () =>
      [...data]
        .sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime())
        .map((d) => ({ label: new Date(d.time).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }), profit: d.profit })),
    [data]
  );

  return (
    <GlassCard title="Lucro por dia">
      {mapped.length === 0 ? (
        <p className="text-sm text-muted-300">Sem dados no período selecionado.</p>
      ) : (
        <div style={{ width: '100%', height: 280 }}>
          <ResponsiveContainer>
            <BarChart data={mapped} margin={{ top: 10, right: 20, left: 8, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="label" tick={{ fill: 'var(--muted-300)' }} />
              <YAxis
                tick={{ fill: 'var(--muted-300)' }}
                width={56}
                tickFormatter={(v: number) => Intl.NumberFormat('pt-BR', { notation: 'compact' }).format(v)}
              />
              <Tooltip
                formatter={(value: number) => [value.toLocaleString() + ' gp', 'Profit']}
                contentStyle={{ background: 'var(--bg-800)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8 }}
                cursor={{ fill: 'rgba(255,255,255,0.03)' }}
              />
              <Bar dataKey="profit" fill="var(--series-3)" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </GlassCard>
  );
}
