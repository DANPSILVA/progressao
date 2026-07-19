'use client';

import React from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import type { z } from 'zod';
import GlassCard from '@/components/ui/GlassCard';
import { characterSchema } from '@/lib/validation';

type FormData = z.infer<typeof characterSchema>;

export default function CreateCharacterForm({ onCreated }: { onCreated: () => void }) {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(characterSchema),
    defaultValues: { level: 8 },
  });

  const onSubmit = async (data: FormData) => {
    await fetch('/api/character', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    onCreated();
  };

  return (
    <GlassCard title="Crie seu personagem">
      <p className="text-sm text-muted-300 mb-4">
        Antes de continuar, conte pra gente qual é o seu personagem no RubinOT.
      </p>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
        <div>
          <label className="label-tibia">Nome do personagem</label>
          <input className="input-tibia" {...register('name')} />
          {errors.name && <p className="text-sm text-red-400 mt-1">{errors.name.message}</p>}
        </div>
        <div>
          <label className="label-tibia">Vocação</label>
          <input className="input-tibia" {...register('vocation')} />
        </div>
        <div>
          <label className="label-tibia">Level</label>
          <input type="number" className="input-tibia" {...register('level')} />
        </div>
        <button type="submit" disabled={isSubmitting} className="btn-tibia btn-tibia--primary">
          {isSubmitting ? 'Salvando...' : 'Começar'}
        </button>
      </form>
    </GlassCard>
  );
}
