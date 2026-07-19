#!/bin/bash
set -e

mkdir -p prisma/migrations/20260719150000_input_analyzer_damage_fields

cat > "prisma/schema.prisma" << 'EOF_prisma_schema_prisma_'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}

// id has no default: it must equal the corresponding auth.users.id in Supabase.
// The row itself is created by the handle_new_user() trigger (see migration.sql).
model User {
  id        String   @id
  name      String?
  email     String   @unique
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  character    Character?
  huntSessions HuntSession[]

  friendRequestsSent     Friendship[] @relation("FriendRequestsSent")
  friendRequestsReceived Friendship[] @relation("FriendRequestsReceived")
}

model Character {
  id        String   @id @default(cuid())
  userId    String   @unique
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  name      String
  vocation  String?
  level     Int      @default(8)
  avatarUrl String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model HuntSession {
  id             String   @id @default(cuid())
  userId         String
  user           User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  startedAt      DateTime
  durationMin    Int
  xpGained       BigInt
  profit         BigInt   @default(0)
  waste          BigInt   @default(0)
  loot           BigInt   @default(0)
  bosses         Int      @default(0)
  deaths         Int      @default(0)
  levelAfter     Int?
  // From the Input Analyzer: total damage taken, peak DPS, and the elemental/monster
  // breakdown as-is (both are variable-length lists, so JSON avoids a join for data
  // that's only ever displayed, never filtered/aggregated by).
  damageReceived BigInt?
  maxDps         Int?
  damageTypes    Json?
  damageSources  Json?
  createdAt      DateTime @default(now())
  updatedAt      DateTime @updatedAt

  @@index([userId, startedAt])
}

enum FriendshipStatus {
  PENDING
  ACCEPTED
}

model Friendship {
  id         String           @id @default(cuid())
  fromUserId String
  fromUser   User             @relation("FriendRequestsSent", fields: [fromUserId], references: [id], onDelete: Cascade)
  toUserId   String
  toUser     User             @relation("FriendRequestsReceived", fields: [toUserId], references: [id], onDelete: Cascade)
  status     FriendshipStatus @default(PENDING)
  createdAt  DateTime         @default(now())
  updatedAt  DateTime         @updatedAt

  @@unique([fromUserId, toUserId])
}
EOF_prisma_schema_prisma_

cat > "prisma/migrations/20260719150000_input_analyzer_damage_fields/migration.sql" << 'EOF_prisma_migrations_20260719150000_input_analyzer_damage_fields_migration_sql_'
-- AlterTable
ALTER TABLE "HuntSession" ADD COLUMN     "damageReceived" BIGINT,
ADD COLUMN     "damageSources" JSONB,
ADD COLUMN     "damageTypes" JSONB,
ADD COLUMN     "maxDps" INTEGER;
EOF_prisma_migrations_20260719150000_input_analyzer_damage_fields_migration_sql_

cat > "src/lib/dashboard.ts" << 'EOF_src_lib_dashboard_ts_'
export type DamageTypeEntry = { type: string; amount: number; percentage: number };
export type DamageSourceEntry = { name: string; amount: number; percentage: number };

export type HuntSession = {
  id: string;
  startedAt: string;
  durationMin: number;
  xpGained: number;
  profit: number;
  waste: number;
  loot: number;
  bosses: number;
  deaths: number;
  levelAfter: number | null;
  damageReceived: number | null;
  maxDps: number | null;
  damageTypes: DamageTypeEntry[] | null;
  damageSources: DamageSourceEntry[] | null;
};

export type Character = {
  id: string;
  name: string;
  vocation: string | null;
  level: number;
  avatarUrl: string | null;
};

export type HourlyPointFull = {
  time: string;
  xp: number;
  profit: number;
  waste: number;
  loot: number;
  bosses: number;
  deaths: number;
};

export type SummaryMetrics = {
  xp: number;
  xpPerHour: number;
  profit: number;
  waste: number;
  loot: number;
  bosses: number;
  deaths: number;
  hours: number;
};

export function filterByPeriod(hunts: HuntSession[], period: '24h' | '7d' | '30d' | '90d'): HuntSession[] {
  const now = new Date();
  const start = new Date(now);
  if (period === '24h') start.setDate(now.getDate() - 1);
  if (period === '7d') start.setDate(now.getDate() - 7);
  if (period === '30d') start.setDate(now.getDate() - 30);
  if (period === '90d') start.setDate(now.getDate() - 90);
  return hunts.filter((h) => new Date(h.startedAt) >= start);
}

export function aggregateByDay(hunts: HuntSession[]): HourlyPointFull[] {
  const byDay = new Map<string, HourlyPointFull>();

  const sorted = [...hunts].sort((a, b) => new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime());

  for (const h of sorted) {
    const dayKey = new Date(h.startedAt).toISOString().slice(0, 10);
    const existing = byDay.get(dayKey) ?? { time: dayKey, xp: 0, profit: 0, waste: 0, loot: 0, bosses: 0, deaths: 0 };
    existing.xp += h.xpGained;
    existing.profit += h.profit;
    existing.waste += h.waste;
    existing.loot += h.loot;
    existing.bosses += h.bosses;
    existing.deaths += h.deaths;
    byDay.set(dayKey, existing);
  }

  return Array.from(byDay.values());
}

export type SessionPoint = {
  label: string;
  xpPerHour: number;
  xp: number;
  profit: number;
};

/** One point per individual hunt (not day-aggregated) — for spotting variance across sessions. */
export function perSessionSeries(hunts: HuntSession[]): SessionPoint[] {
  return [...hunts]
    .sort((a, b) => new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime())
    .map((h) => ({
      label: new Date(h.startedAt).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }),
      xpPerHour: h.durationMin > 0 ? Math.round(h.xpGained / (h.durationMin / 60)) : 0,
      xp: h.xpGained,
      profit: h.profit,
    }));
}

/** XP/h is derived automatically from total XP gained divided by total hunting time — never entered manually. */
export function computeSummary(hunts: HuntSession[]): SummaryMetrics {
  const xp = hunts.reduce((s, h) => s + h.xpGained, 0);
  const durationMin = hunts.reduce((s, h) => s + h.durationMin, 0);
  const hours = durationMin / 60;
  const xpPerHour = hours > 0 ? xp / hours : 0;
  const profit = hunts.reduce((s, h) => s + h.profit, 0);
  const waste = hunts.reduce((s, h) => s + h.waste, 0);
  const loot = hunts.reduce((s, h) => s + h.loot, 0);
  const bosses = hunts.reduce((s, h) => s + h.bosses, 0);
  const deaths = hunts.reduce((s, h) => s + h.deaths, 0);

  return { xp, xpPerHour, profit, waste, loot, bosses, deaths, hours };
}
EOF_src_lib_dashboard_ts_

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

export type ParsedInputAnalyzer = {
  damageReceived: number;
  maxDps: number;
  damageTypes: { type: string; amount: number; percentage: number }[];
  damageSources: { name: string; amount: number; percentage: number }[];
};

/** Input Analyzer text has no session/XP/loot data at all — it's purely a damage-taken
 *  breakdown ("Total"/"Max-DPS" plus per-element and per-monster lists), so it never
 *  contributes startedAt/durationMin the way the other two formats do. */
export function parseInputAnalyzer(text: string): ParsedInputAnalyzer | null {
  const totalMatch = text.match(/^Total:\s*([\d.,]+)/m);
  const maxDpsMatch = text.match(/^Max-DPS:\s*([\d.,]+)/m);
  if (!totalMatch || !maxDpsMatch) return null;

  const damageTypes: { type: string; amount: number; percentage: number }[] = [];
  const damageSources: { name: string; amount: number; percentage: number }[] = [];
  let section: 'types' | 'sources' | null = null;
  const entryPattern = /^(.+?)\s+([\d.,]+)\s+\(([\d.]+)%\)$/;

  for (const rawLine of text.split('\n')) {
    const trimmed = rawLine.trim();
    if (!trimmed) continue;
    if (trimmed === 'Damage Types') {
      section = 'types';
      continue;
    }
    if (trimmed === 'Damage Sources') {
      section = 'sources';
      continue;
    }
    if (/^(Received Damage|Total:|Max-DPS:)/.test(trimmed)) continue;

    const match = trimmed.match(entryPattern);
    if (!match) continue;
    const [, name, amountRaw, pctRaw] = match;
    const amount = parseAmount(amountRaw);
    const percentage = parseFloat(pctRaw);

    if (section === 'types') damageTypes.push({ type: name, amount, percentage });
    else if (section === 'sources') damageSources.push({ name, amount, percentage });
  }

  return {
    damageReceived: parseAmount(totalMatch[1]),
    maxDps: parseAmount(maxDpsMatch[1]),
    damageTypes,
    damageSources,
  };
}
EOF_src_lib_huntAnalyzerParser_ts_

cat > "src/lib/serialize.ts" << 'EOF_src_lib_serialize_ts_'
import type { HuntSession } from '@prisma/client';

/** xpGained/profit/waste/loot are BigInt in Postgres (to hold values past 2.1B) but the
 *  app only ever needs plain numbers — JS numbers are exact up to 2^53, far past any
 *  realistic XP/gold value, and BigInt doesn't survive JSON.stringify on its own. */
export function serializeHunt(hunt: HuntSession) {
  return {
    ...hunt,
    xpGained: Number(hunt.xpGained),
    profit: Number(hunt.profit),
    waste: Number(hunt.waste),
    loot: Number(hunt.loot),
    damageReceived: hunt.damageReceived === null ? null : Number(hunt.damageReceived),
  };
}
EOF_src_lib_serialize_ts_

cat > "src/lib/validation.ts" << 'EOF_src_lib_validation_ts_'
import { z } from 'zod';

export const registerSchema = z.object({
  name: z.string().min(2, 'Nome muito curto').max(60),
  characterName: z.string().min(2, 'Nome do personagem muito curto').max(60),
  email: z.string().email('Email inválido'),
  password: z.string().min(8, 'Senha deve ter ao menos 8 caracteres'),
});

export const loginSchema = z.object({
  email: z.string().email('Email inválido'),
  password: z.string().min(1, 'Senha obrigatória'),
});

const emptyToUndefined = (val: unknown) => (val === '' || val === null || val === undefined ? undefined : val);

export const damageTypeEntrySchema = z.object({
  type: z.string(),
  amount: z.number(),
  percentage: z.number(),
});

export const damageSourceEntrySchema = z.object({
  name: z.string(),
  amount: z.number(),
  percentage: z.number(),
});

export const huntSessionSchema = z.object({
  startedAt: z.coerce.date(),
  durationMin: z.coerce.number().int().positive('Duração deve ser maior que zero'),
  xpGained: z.coerce.number().int().min(0),
  profit: z.coerce.number().int().default(0),
  waste: z.coerce.number().int().default(0),
  loot: z.coerce.number().int().default(0),
  bosses: z.coerce.number().int().min(0).default(0),
  deaths: z.coerce.number().int().min(0).default(0),
  levelAfter: z.preprocess(emptyToUndefined, z.coerce.number().int().positive().optional()),
  damageReceived: z.preprocess(emptyToUndefined, z.coerce.number().int().min(0).optional()),
  maxDps: z.preprocess(emptyToUndefined, z.coerce.number().int().min(0).optional()),
  damageTypes: z.preprocess(emptyToUndefined, z.array(damageTypeEntrySchema).optional()),
  damageSources: z.preprocess(emptyToUndefined, z.array(damageSourceEntrySchema).optional()),
});

export const characterSchema = z.object({
  name: z.string().min(2).max(60),
  vocation: z.string().max(40).optional().nullable(),
  level: z.coerce.number().int().positive(),
  avatarUrl: z.string().url().optional().nullable(),
});

export const friendRequestSchema = z.object({
  email: z.string().email('Email inválido'),
});
EOF_src_lib_validation_ts_

cat > "src/components/dashboard/HuntForm.tsx" << 'EOF_src_components_dashboard_HuntForm_tsx_'
'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import type { z } from 'zod';
import { huntSessionSchema } from '@/lib/validation';
import {
  parseHuntAnalyzer,
  parsePartyHunt,
  parseInputAnalyzer,
  ParsedPartyHuntMember,
  ParsedInputAnalyzer,
} from '@/lib/huntAnalyzerParser';
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
  const [inputAnalyzer, setInputAnalyzer] = useState<ParsedInputAnalyzer | null>(null);
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
          damageReceived: hunt.damageReceived ?? undefined,
          maxDps: hunt.maxDps ?? undefined,
          damageTypes: hunt.damageTypes ?? undefined,
          damageSources: hunt.damageSources ?? undefined,
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
    let matched = false;
    let needsPartyPick = false;

    const solo = parseHuntAnalyzer(analyzerText);
    if (solo) {
      matched = true;
      setPartyMembers(null);
      if (solo.startedAt) setValue('startedAt', solo.startedAt as unknown as FormData['startedAt']);
      setValue('durationMin', solo.durationMin as FormData['durationMin']);
      setValue('xpGained', solo.xpGained as FormData['xpGained']);
      setValue('profit', solo.profit as FormData['profit']);
      setValue('waste', solo.waste as FormData['waste']);
      setValue('loot', solo.loot as FormData['loot']);
      setValue('deaths', solo.deaths as FormData['deaths']);
    } else {
      const party = parsePartyHunt(analyzerText);
      if (party) {
        matched = true;
        needsPartyPick = true;
        if (party.startedAt) setValue('startedAt', party.startedAt as unknown as FormData['startedAt']);
        setValue('durationMin', party.durationMin as FormData['durationMin']);
        setPartyMembers(party.members);
      } else {
        setPartyMembers(null);
      }
    }

    // Input Analyzer (damage taken) data can show up on its own or alongside either of
    // the above, so it's checked independently rather than as another "else if" branch.
    const input = parseInputAnalyzer(analyzerText);
    if (input) {
      matched = true;
      setValue('damageReceived', input.damageReceived as FormData['damageReceived']);
      setValue('maxDps', input.maxDps as FormData['maxDps']);
      setValue('damageTypes', input.damageTypes as FormData['damageTypes']);
      setValue('damageSources', input.damageSources as FormData['damageSources']);
      setInputAnalyzer(input);
    } else {
      setInputAnalyzer(null);
    }

    setAnalyzerStatus(!matched ? 'error' : needsPartyPick ? 'party' : 'ok');
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
        <label className="label-tibia">Colar Hunt Analyzer / Party Hunt / Input Analyzer (opcional)</label>
        <textarea
          className="input-tibia w-full h-28 font-mono text-xs"
          placeholder="Cole aqui o texto copiado de um dos analisadores do jogo..."
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
            <span className="text-sm text-red-400">
              Não reconheci esse texto — confira se é do Hunt Analyzer, Party Hunt ou Input Analyzer.
            </span>
          )}
        </div>

        {inputAnalyzer && (
          <p className="text-xs text-muted-300 mt-2">
            Dano recebido detectado: {inputAnalyzer.damageReceived.toLocaleString()} (pico de DPS:{' '}
            {inputAnalyzer.maxDps.toLocaleString()})
          </p>
        )}

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

cat > "src/components/dashboard/HuntHistory.tsx" << 'EOF_src_components_dashboard_HuntHistory_tsx_'
'use client';

import React, { useState } from 'react';
import { ChevronDown, ChevronRight } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import { HuntSession } from '@/lib/dashboard';
import HuntForm from './HuntForm';

export default function HuntHistory({ hunts, onChanged }: { hunts: HuntSession[]; onChanged: () => void }) {
  const [editing, setEditing] = useState<HuntSession | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const sorted = [...hunts].sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());

  const handleDelete = async (id: string) => {
    setDeletingId(id);
    await fetch(`/api/hunts/${id}`, { method: 'DELETE' });
    setDeletingId(null);
    onChanged();
  };

  if (editing) {
    return (
      <HuntForm
        hunt={editing}
        onSaved={() => {
          setEditing(null);
          onChanged();
        }}
        onCancel={() => setEditing(null)}
      />
    );
  }

  return (
    <GlassCard title="Histórico de hunts">
      {sorted.length === 0 ? (
        <p className="text-sm text-muted-300">Nenhuma hunt registrada ainda.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-muted-300">
                <th className="py-2 pr-4"></th>
                <th className="py-2 pr-4">Data</th>
                <th className="py-2 pr-4">Duração</th>
                <th className="py-2 pr-4">XP</th>
                <th className="py-2 pr-4">XP/h</th>
                <th className="py-2 pr-4">Profit</th>
                <th className="py-2 pr-4">Dano recebido</th>
                <th className="py-2 pr-4"></th>
              </tr>
            </thead>
            <tbody>
              {sorted.map((h) => {
                const xpPerHour = h.durationMin > 0 ? Math.round(h.xpGained / (h.durationMin / 60)) : 0;
                const hasDamageDetail = h.damageReceived !== null;
                const isExpanded = expandedId === h.id;
                return (
                  <React.Fragment key={h.id}>
                    <tr className="border-t border-white/6">
                      <td className="py-2 pr-2">
                        {hasDamageDetail && (
                          <button
                            onClick={() => setExpandedId(isExpanded ? null : h.id)}
                            aria-label={isExpanded ? 'Recolher detalhes de dano' : 'Ver detalhes de dano'}
                            className="text-muted-300 hover:text-accent"
                          >
                            {isExpanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                          </button>
                        )}
                      </td>
                      <td className="py-2 pr-4">{new Date(h.startedAt).toLocaleString()}</td>
                      <td className="py-2 pr-4">{h.durationMin} min</td>
                      <td className="py-2 pr-4">{h.xpGained.toLocaleString()}</td>
                      <td className="py-2 pr-4 text-accent">{xpPerHour.toLocaleString()}</td>
                      <td className="py-2 pr-4">{h.profit.toLocaleString()} gp</td>
                      <td className="py-2 pr-4">{hasDamageDetail ? h.damageReceived!.toLocaleString() : '—'}</td>
                      <td className="py-2 pr-4 text-right whitespace-nowrap">
                        <button onClick={() => setEditing(h)} className="text-accent mr-3">
                          Editar
                        </button>
                        <button
                          onClick={() => handleDelete(h.id)}
                          disabled={deletingId === h.id}
                          className="text-red-400"
                        >
                          {deletingId === h.id ? 'Excluindo...' : 'Excluir'}
                        </button>
                      </td>
                    </tr>
                    {isExpanded && hasDamageDetail && (
                      <tr className="border-t border-white/6 bg-white/[0.02]">
                        <td></td>
                        <td colSpan={7} className="py-3 pr-4">
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <div>
                              <div className="text-xs text-muted-300 mb-1">
                                Pico de DPS: {h.maxDps?.toLocaleString() ?? '—'}
                              </div>
                              {h.damageTypes && h.damageTypes.length > 0 && (
                                <>
                                  <div className="text-xs text-muted-300 mb-1 mt-2">Tipos de dano</div>
                                  <ul className="space-y-0.5">
                                    {h.damageTypes.map((d) => (
                                      <li key={d.type} className="flex justify-between text-xs">
                                        <span>{d.type}</span>
                                        <span className="text-muted-300">
                                          {d.amount.toLocaleString()} ({d.percentage}%)
                                        </span>
                                      </li>
                                    ))}
                                  </ul>
                                </>
                              )}
                            </div>
                            {h.damageSources && h.damageSources.length > 0 && (
                              <div>
                                <div className="text-xs text-muted-300 mb-1">Fontes de dano</div>
                                <ul className="space-y-0.5">
                                  {h.damageSources.map((s) => (
                                    <li key={s.name} className="flex justify-between text-xs">
                                      <span>{s.name}</span>
                                      <span className="text-muted-300">
                                        {s.amount.toLocaleString()} ({s.percentage}%)
                                      </span>
                                    </li>
                                  ))}
                                </ul>
                              </div>
                            )}
                          </div>
                        </td>
                      </tr>
                    )}
                  </React.Fragment>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </GlassCard>
  );
}
EOF_src_components_dashboard_HuntHistory_tsx_

git add -A
git commit -m "Add Input Analyzer (damage received) parsing and storage"
git push -u origin claude/user-auth-character-progress-00b5p6
