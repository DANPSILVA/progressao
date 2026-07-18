'use client';

import React from 'react';

export default function PeriodFilter({
  period,
  onChange,
}: {
  period: '24h' | '7d' | '30d' | '90d';
  onChange: (p: '24h' | '7d' | '30d' | '90d') => void;
}) {
  return (
    <div className="flex gap-2 rounded-md bg-[rgba(255,255,255,0.02)] p-1">
      {(['24h', '7d', '30d', '90d'] as const).map((p) => (
        <button key={p} onClick={() => onChange(p)} className={`px-3 py-1 rounded-md text-sm ${period === p ? 'bg-accent text-black' : 'text-muted-300'}`}>
          {p}
        </button>
      ))}
    </div>
  );
}
