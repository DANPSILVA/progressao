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
  // RubinOT uses "." as the thousands separator on the solo Hunt Analyzer but "," on
  // the Party Hunt one — stripping every non-digit character handles both.
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

export type ParsedPartyHuntMember = {
  name: string;
  loot: number;
  waste: number;
  profit: number;
};

export type ParsedPartyHunt = {
  startedAt: string;
  durationMin: number;
  members: ParsedPartyHuntMember[];
};

function isPartyHuntTopLevelLine(trimmed: string): boolean {
  return /^(Session data:|Session:|Loot Type:|Loot:|Supplies:|Balance:)/.test(trimmed);
}

/** Party Hunt analyzer text has no XP figure at all — instead it breaks Loot/
 *  Supplies/Balance (plus Damage/Healing, which we don't track) down per member.
 *  Since there's no way to know which member is "you", the caller shows a picker
 *  and re-derives loot/waste/profit from whichever member gets selected. */
export function parsePartyHunt(text: string): ParsedPartyHunt | null {
  const sessionMatch = text.match(/Session data:\s*From\s+([\d-]+,\s*[\d:]+)\s+to\s+([\d-]+,\s*[\d:]+)/);
  const durationMatch = text.match(/Session:\s*(\d+):(\d+)h/);
  if (!durationMatch) return null;

  const startedAt = sessionMatch ? toDateTimeLocal(sessionMatch[1]) : null;
  const durationMin = parseInt(durationMatch[1], 10) * 60 + parseInt(durationMatch[2], 10);

  const members: ParsedPartyHuntMember[] = [];
  let current: Partial<ParsedPartyHuntMember> | null = null;

  const flush = () => {
    if (current?.name) {
      members.push({
        name: current.name,
        loot: current.loot ?? 0,
        waste: current.waste ?? 0,
        profit: current.profit ?? 0,
      });
    }
    current = null;
  };

  for (const rawLine of text.split('\n')) {
    const line = rawLine.replace(/\s+$/, '');
    const trimmed = line.trim();
    if (!trimmed) continue;

    if (!/^[\t ]/.test(line)) {
      if (isPartyHuntTopLevelLine(trimmed)) continue;
      flush();
      current = { name: trimmed.replace(/\s*\(Leader\)\s*$/, '') };
      continue;
    }

    if (!current) continue;

    const loot = trimmed.match(/^Loot:\s*(-?[\d.,]+)/);
    const supplies = trimmed.match(/^Supplies:\s*(-?[\d.,]+)/);
    const balance = trimmed.match(/^Balance:\s*(-?[\d.,]+)/);

    if (loot) current.loot = parseAmount(loot[1]);
    else if (supplies) current.waste = parseAmount(supplies[1]);
    else if (balance) current.profit = parseAmount(balance[1]);
  }
  flush();

  if (members.length === 0) return null;

  return { startedAt: startedAt ?? '', durationMin, members };
}
EOF_src_lib_huntAnalyzerParser_ts_

cat > "src/components/dashboard/HuntForm.tsx" << 'EOF_src_components_dashboard_HuntForm_tsx_'
'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import type { z } from 'zod';
import { huntSessionSchema } from '@/lib/validation';
import { parseHuntAnalyzer, parsePartyHunt, ParsedPartyHuntMember } from '@/lib/huntAnalyzerParser';
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
  const [analyzerStatus, setAnalyzerStatus] = useState<'idle' | 'ok' | 'error' | 'party'>('idle');
  const [partyMembers, setPartyMembers] = useState<ParsedPartyHuntMember[] | null>(null);
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
    const solo = parseHuntAnalyzer(analyzerText);
    if (solo) {
      setPartyMembers(null);
      if (solo.startedAt) setValue('startedAt', solo.startedAt as unknown as FormData['startedAt']);
      setValue('durationMin', solo.durationMin as FormData['durationMin']);
      setValue('xpGained', solo.xpGained as FormData['xpGained']);
      setValue('profit', solo.profit as FormData['profit']);
      setValue('waste', solo.waste as FormData['waste']);
      setValue('loot', solo.loot as FormData['loot']);
      setValue('deaths', solo.deaths as FormData['deaths']);
      setAnalyzerStatus('ok');
      return;
    }

    const party = parsePartyHunt(analyzerText);
    if (party) {
      if (party.startedAt) setValue('startedAt', party.startedAt as unknown as FormData['startedAt']);
      setValue('durationMin', party.durationMin as FormData['durationMin']);
      setPartyMembers(party.members);
      setAnalyzerStatus('party');
      return;
    }

    setPartyMembers(null);
    setAnalyzerStatus('error');
  };

  const handlePickPartyMember = (memberName: string) => {
    const member = partyMembers?.find((m) => m.name === memberName);
    if (!member) return;
    setValue('profit', member.profit as FormData['profit']);
    setValue('waste', member.waste as FormData['waste']);
    setValue('loot', member.loot as FormData['loot']);
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
            <span className="text-sm text-red-400">Não reconheci esse texto — confira se é do Hunt Analyzer ou Party Hunt.</span>
          )}
        </div>

        {analyzerStatus === 'party' && partyMembers && (
          <div className="mt-3">
            <label className="label-tibia">Qual desses é o seu personagem?</label>
            <select className="input-tibia" defaultValue="" onChange={(e) => handlePickPartyMember(e.target.value)}>
              <option value="" disabled>
                Selecione...
              </option>
              {partyMembers.map((m) => (
                <option key={m.name} value={m.name}>
                  {m.name}
                </option>
              ))}
            </select>
            <p className="text-xs text-muted-300 mt-1">
              Esse formato não traz XP ganho por membro — preencha esse campo manualmente abaixo.
            </p>
          </div>
        )}
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
git commit -m "Add Party Hunt Analyzer parsing with a member picker"
git push -u origin claude/user-auth-character-progress-00b5p6
