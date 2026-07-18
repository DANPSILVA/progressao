'use client';

import React from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import GlassCard from '@/components/ui/GlassCard';
import { SessionPoint } from '@/lib/dashboard';

export default function XpPerHourSessionChart({ data }: { data: SessionPoint[] }) {
  return (
    <GlassCard title="XP/h por sessão de hunt">
      {data.length === 0 ? (
        <p className="text-sm text-muted-300">Sem hunts registradas no período selecionado.</p>
      ) : (
        <div style={{ width: '100%', height: 280 }}>
          <ResponsiveContainer>
            <BarChart data={data} margin={{ top: 10, right: 20, left: 8, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="label" tick={{ fill: 'var(--muted-300)' }} />
              <YAxis
                tick={{ fill: 'var(--muted-300)' }}
                width={56}
                tickFormatter={(v: number) => Intl.NumberFormat('pt-BR', { notation: 'compact' }).format(v)}
              />
              <Tooltip
                formatter={(value: number) => [value.toLocaleString(), 'XP/h']}
                contentStyle={{ background: 'var(--bg-800)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8 }}
                cursor={{ fill: 'rgba(255,255,255,0.03)' }}
              />
              <Bar dataKey="xpPerHour" fill="var(--series-2)" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </GlassCard>
  );
}
