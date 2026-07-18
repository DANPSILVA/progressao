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
        <AreaChart data={source} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="g1" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--accent)" stopOpacity={0.18} />
              <stop offset="100%" stopColor="var(--accent)" stopOpacity={0.02} />
            </linearGradient>
          </defs>
          <XAxis dataKey="timeLabel" tick={{ fill: 'var(--muted-300)' }} />
          <YAxis yAxisId="left" tick={{ fill: 'var(--muted-300)' }} />
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.02)" />
          <Tooltip formatter={(value: any) => value.toLocaleString?.() ?? value} />
          <Area yAxisId="left" type="monotone" dataKey="xp" stroke="var(--accent)" fill="url(#g1)" strokeWidth={2} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
