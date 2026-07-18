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
