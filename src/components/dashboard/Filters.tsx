'use client';

import React from 'react';

export default function Filters({ period, onChange, showCumulative, setShowCumulative }: { period: '24h' | '7d' | '30d' | '90d'; onChange: (p: '24h' | '7d' | '30d' | '90d') => void; showCumulative: boolean; setShowCumulative: (v: boolean) => void }) {
  return (
    <div className="flex items-center gap-3">
      <div className="flex gap-2 rounded-md bg-[rgba(255,255,255,0.02)] p-1">
        {(['24h', '7d', '30d', '90d'] as const).map((p) => (
          <button key={p} onClick={() => onChange(p)} className={`px-3 py-1 rounded-md text-sm ${period === p ? 'bg-accent text-black' : 'text-muted-300'}`}>
            {p}
          </button>
        ))}
      </div>

      <label className="inline-flex items-center gap-2 text-sm text-muted-300">
        <input type="checkbox" checked={showCumulative} onChange={(e) => setShowCumulative(e.target.checked)} className="rounded" />
        Cumulativo
      </label>
    </div>
  );
}
