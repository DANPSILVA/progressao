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
