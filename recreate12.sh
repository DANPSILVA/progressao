#!/bin/bash
set -e

cat > "src/lib/huntAnalyzerParser.ts" << 'EOF_src_lib_huntAnalyzerParser_ts_'
/** Parses the text RubinOT's in-game "Hunt Analyzer" window produces via its
 *  "Copy to Clipboard" button. Only extracts the fields our HuntSession model
 *  tracks — everything else (Charm/Imbuement/Item Upgrade data, killed monsters,
 *  looted items) is ignored rather than treated as an error, since the format
 *  has more sections than we need and may vary between sessions. */

export type ParsedHuntAnalyzer = {
  startedAt: string; // yyyy-MM-ddTHH:mm, ready for a <input type="datetime-local">
  durationMin: number;
  xpGained: number;
  profit: number;
  waste: number;
  loot: number;
  deaths: number;
};

function parseAmount(raw: string): number {
  // RubinOT formats amounts with "." as the thousands separator (e.g. "220.076").
  const cleaned = raw.replace(/[^\d-]/g, '');
  const value = parseInt(cleaned, 10);
  return Number.isNaN(value) ? 0 : value;
}

function toDateTimeLocal(dateStr: string): string | null {
  // "2026-07-19, 11:44:12" -> "2026-07-19T11:44"
  const match = dateStr.trim().match(/^(\d{4}-\d{2}-\d{2}),\s*(\d{2}:\d{2})/);
  if (!match) return null;
  return `${match[1]}T${match[2]}`;
}

export function parseHuntAnalyzer(text: string): ParsedHuntAnalyzer | null {
  const sessionMatch = text.match(/^Session data:\s*From\s+([\d-]+,\s*[\d:]+)\s+to\s+([\d-]+,\s*[\d:]+)/m);
  const durationMatch = text.match(/^Session:\s*(\d+):(\d+)h/m);
  const xpGainMatch = text.match(/^XP Gain:\s*([\d.,]+)/m);
  const lootMatch = text.match(/^Loot:\s*([\d.,]+)/m);
  const suppliesMatch = text.match(/^Supplies:\s*([\d.,]+)/m);
  const balanceMatch = text.match(/^Balance:\s*(-?[\d.,]+)/m);
  const deathsMatch = text.match(/^Deaths:\s*(\d+)/m);

  // Require at minimum a recognizable session window and an XP figure — anything
  // less means this probably isn't a Hunt Analyzer paste at all.
  if (!durationMatch || !xpGainMatch) return null;

  const startedAt = sessionMatch ? toDateTimeLocal(sessionMatch[1]) : null;

  return {
    startedAt: startedAt ?? '',
    durationMin: parseInt(durationMatch[1], 10) * 60 + parseInt(durationMatch[2], 10),
    xpGained: parseAmount(xpGainMatch[1]),
    profit: balanceMatch ? parseAmount(balanceMatch[1]) : 0,
    loot: lootMatch ? parseAmount(lootMatch[1]) : 0,
    waste: suppliesMatch ? parseAmount(suppliesMatch[1]) : 0,
    deaths: deathsMatch ? parseInt(deathsMatch[1], 10) : 0,
  };
}
EOF_src_lib_huntAnalyzerParser_ts_

cat > "src/components/dashboard/HuntForm.tsx" << 'EOF_src_components_dashboard_HuntForm_tsx_'
'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import type { z } from 'zod';
import { huntSessionSchema } from '@/lib/validation';
import { parseHuntAnalyzer } from '@/lib/huntAnalyzerParser';
import GlassCard from '@/components/ui/GlassCard';
import { HuntSession } from '@/lib/dashboard';

type FormData = z.infer<typeof huntSessionSchema>;

function toLocalDateTimeInput(date: Date) {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export default function HuntForm({
  hunt,
  onSaved,
  onCancel,
}: {
  hunt?: HuntSession;
  onSaved: () => void;
  onCancel?: () => void;
}) {
  const [serverError, setServerError] = useState<string | null>(null);
  const [analyzerText, setAnalyzerText] = useState('');
  const [analyzerStatus, setAnalyzerStatus] = useState<'idle' | 'ok' | 'error'>('idle');
  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(huntSessionSchema),
    defaultValues: (hunt
      ? {
          startedAt: toLocalDateTimeInput(new Date(hunt.startedAt)),
          durationMin: hunt.durationMin,
          xpGained: hunt.xpGained,
          profit: hunt.profit,
          waste: hunt.waste,
          loot: hunt.loot,
          bosses: hunt.bosses,
          deaths: hunt.deaths,
          levelAfter: hunt.levelAfter ?? undefined,
        }
      : {
          startedAt: toLocalDateTimeInput(new Date()),
          durationMin: 60,
          xpGained: 0,
          profit: 0,
          waste: 0,
          loot: 0,
          bosses: 0,
          deaths: 0,
        }) as unknown as FormData,
  });

  const xpGained = Number(watch('xpGained')) || 0;
  const durationMin = Number(watch('durationMin')) || 0;
  const xpPerHourPreview = durationMin > 0 ? Math.round(xpGained / (durationMin / 60)) : 0;

  const handleDetect = () => {
    const parsed = parseHuntAnalyzer(analyzerText);
    if (!parsed) {
      setAnalyzerStatus('error');
      return;
    }

    if (parsed.startedAt) setValue('startedAt', parsed.startedAt as unknown as FormData['startedAt']);
    setValue('durationMin', parsed.durationMin as FormData['durationMin']);
    setValue('xpGained', parsed.xpGained as FormData['xpGained']);
    setValue('profit', parsed.profit as FormData['profit']);
    setValue('waste', parsed.waste as FormData['waste']);
    setValue('loot', parsed.loot as FormData['loot']);
    setValue('deaths', parsed.deaths as FormData['deaths']);
    setAnalyzerStatus('ok');
  };

  const onSubmit = async (data: FormData) => {
    setServerError(null);
    const url = hunt ? `/api/hunts/${hunt.id}` : '/api/hunts';
    const method = hunt ? 'PUT' : 'POST';

    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setServerError(body.error ?? 'Não foi possível salvar a hunt');
      return;
    }

    onSaved();
  };

  return (
    <GlassCard title={hunt ? 'Editar hunt' : 'Registrar nova hunt'}>
      <div className="mb-5 pb-5 border-b border-white/6">
        <label className="label-tibia">Colar Hunt Analyzer (opcional)</label>
        <textarea
          className="input-tibia w-full h-28 font-mono text-xs"
          placeholder="Cole aqui o texto copiado do Hunt Analyzer do jogo..."
          value={analyzerText}
          onChange={(e) => {
            setAnalyzerText(e.target.value);
            setAnalyzerStatus('idle');
          }}
        />
        <div className="flex items-center gap-3 mt-2">
          <button type="button" onClick={handleDetect} className="btn-tibia text-sm" disabled={!analyzerText.trim()}>
            Detectar dados
          </button>
          {analyzerStatus === 'ok' && (
            <span className="text-sm text-accent">Dados detectados! Confira os campos abaixo.</span>
          )}
          {analyzerStatus === 'error' && (
            <span className="text-sm text-red-400">Não reconheci esse texto — confira se é o do Hunt Analyzer.</span>
          )}
        </div>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
        <input type="hidden" {...register('waste')} />
        <input type="hidden" {...register('loot')} />
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label-tibia">Início</label>
            <input type="datetime-local" className="input-tibia" {...register('startedAt')} />
            {errors.startedAt && <p className="text-sm text-red-400 mt-1">{errors.startedAt.message}</p>}
          </div>

          <div>
            <label className="label-tibia">Duração (min)</label>
            <input type="number" className="input-tibia" {...register('durationMin')} />
            {errors.durationMin && <p className="text-sm text-red-400 mt-1">{errors.durationMin.message}</p>}
          </div>

          <div>
            <label className="label-tibia">XP ganho</label>
            <input type="number" className="input-tibia" {...register('xpGained')} />
            {errors.xpGained && <p className="text-sm text-red-400 mt-1">{errors.xpGained.message}</p>}
          </div>

          <div>
            <label className="label-tibia">Level após (opcional)</label>
            <input type="number" className="input-tibia" {...register('levelAfter')} />
          </div>

          <div>
            <label className="label-tibia">Profit (gp)</label>
            <input type="number" className="input-tibia" {...register('profit')} />
          </div>

          <div>
            <label className="label-tibia">Bosses</label>
            <input type="number" className="input-tibia" {...register('bosses')} />
          </div>

          <div>
            <label className="label-tibia">Deaths</label>
            <input type="number" className="input-tibia" {...register('deaths')} />
          </div>
        </div>

        <div className="text-sm text-muted-300">
          XP/h calculado automaticamente: <span className="text-accent font-semibold">{xpPerHourPreview.toLocaleString()}</span>
        </div>

        {serverError && <p className="text-sm text-red-400">{serverError}</p>}
        {Object.keys(errors).length > 0 && (
          <p className="text-sm text-red-400">Verifique os campos destacados antes de salvar.</p>
        )}

        <div className="flex gap-3">
          <button type="submit" disabled={isSubmitting} className="btn-tibia btn-tibia--primary">
            {isSubmitting ? 'Salvando...' : hunt ? 'Salvar alterações' : 'Adicionar hunt'}
          </button>
          {onCancel && (
            <button type="button" onClick={onCancel} className="btn-tibia">
              Cancelar
            </button>
          )}
        </div>
      </form>
    </GlassCard>
  );
}
EOF_src_components_dashboard_HuntForm_tsx_

git add -A
git commit -m "Add Hunt Analyzer paste-and-auto-detect to the new hunt form"
git push -u origin claude/user-auth-character-progress-00b5p6
