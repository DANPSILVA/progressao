'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import type { z } from 'zod';
import GlassCard from '@/components/ui/GlassCard';
import { characterSchema } from '@/lib/validation';
import { Character } from '@/lib/dashboard';

type FormData = z.infer<typeof characterSchema>;

export default function CharacterCard({ character, onChanged }: { character: Character; onChanged: () => void }) {
  const [editing, setEditing] = useState(false);
  const {
    register,
    handleSubmit,
    formState: { isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(characterSchema),
    defaultValues: { name: character.name, vocation: character.vocation ?? '', level: character.level },
  });

  const onSubmit = async (data: FormData) => {
    await fetch('/api/character', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    setEditing(false);
    onChanged();
  };

  if (editing) {
    return (
      <GlassCard title="Editar personagem">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
          <div>
            <label className="label-tibia">Nome</label>
            <input className="input-tibia" {...register('name')} />
          </div>
          <div>
            <label className="label-tibia">Vocação</label>
            <input className="input-tibia" {...register('vocation')} />
          </div>
          <div>
            <label className="label-tibia">Level</label>
            <input type="number" className="input-tibia" {...register('level')} />
          </div>
          <div className="flex gap-3">
            <button type="submit" disabled={isSubmitting} className="btn-tibia btn-tibia--primary">
              Salvar
            </button>
            <button type="button" onClick={() => setEditing(false)} className="btn-tibia">
              Cancelar
            </button>
          </div>
        </form>
      </GlassCard>
    );
  }

  return (
    <GlassCard title="Personagem">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-xl font-semibold">{character.name}</div>
          <div className="text-sm text-muted-300">{character.vocation ?? 'Sem vocação definida'}</div>
        </div>
        <div className="text-right">
          <div className="text-sm text-muted-300">Level</div>
          <div className="text-2xl font-semibold text-accent">{character.level}</div>
        </div>
      </div>
      <button onClick={() => setEditing(true)} className="btn-tibia mt-4 text-sm">
        Editar
      </button>
    </GlassCard>
  );
}
