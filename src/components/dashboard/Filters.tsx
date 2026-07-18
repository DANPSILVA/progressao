'use client';

import React from 'react';
import PeriodFilter from './PeriodFilter';

export default function Filters({ period, onChange, showCumulative, setShowCumulative }: { period: '24h' | '7d' | '30d' | '90d'; onChange: (p: '24h' | '7d' | '30d' | '90d') => void; showCumulative: boolean; setShowCumulative: (v: boolean) => void }) {
  return (
    <div className="flex items-center gap-3">
      <PeriodFilter period={period} onChange={onChange} />

      <label className="inline-flex items-center gap-2 text-sm text-muted-300">
        <input type="checkbox" checked={showCumulative} onChange={(e) => setShowCumulative(e.target.checked)} className="rounded" />
        Cumulativo
      </label>
    </div>
  );
}
