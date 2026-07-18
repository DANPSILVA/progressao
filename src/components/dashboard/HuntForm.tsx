'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import type { z } from 'zod';
import { huntSessionSchema } from '@/lib/validation';
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
  const {
    register,
    handleSubmit,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(huntSessionSchema),
    defaultValues: (hunt
      ? {
          startedAt: toLocalDateTimeInput(new Date(hunt.startedAt)),
          durationMin: hunt.durationMin,
          xpGained: hunt.xpGained,
          profit: hunt.profit,
          bosses: hunt.bosses,
          deaths: hunt.deaths,
          levelAfter: hunt.levelAfter ?? undefined,
        }
      : {
          startedAt: toLocalDateTimeInput(new Date()),
          durationMin: 60,
          xpGained: 0,
          profit: 0,
          bosses: 0,
          deaths: 0,
        }) as unknown as FormData,
  });

  const xpGained = Number(watch('xpGained')) || 0;
  const durationMin = Number(watch('durationMin')) || 0;
  const xpPerHourPreview = durationMin > 0 ? Math.round(xpGained / (durationMin / 60)) : 0;

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
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
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
