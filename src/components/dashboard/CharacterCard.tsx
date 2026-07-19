'use client';

import React, { useMemo, useRef, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import type { z } from 'zod';
import GlassCard from '@/components/ui/GlassCard';
import { characterSchema } from '@/lib/validation';
import { Character } from '@/lib/dashboard';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';

type FormData = z.infer<typeof characterSchema>;

const AVATAR_BUCKET = 'avatars';

function Avatar({ character }: { character: Character }) {
  if (character.avatarUrl) {
    return (
      <img
        src={character.avatarUrl}
        alt={character.name}
        className="w-14 h-14 rounded-full object-cover border border-white/10"
      />
    );
  }
  return (
    <div className="w-14 h-14 rounded-full bg-accent/10 flex items-center justify-center text-lg font-semibold text-accent">
      {character.name.slice(0, 1).toUpperCase()}
    </div>
  );
}

export default function CharacterCard({ character, onChanged }: { character: Character; onChanged: () => void }) {
  const [editing, setEditing] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  const {
    register,
    handleSubmit,
    formState: { isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(characterSchema),
    defaultValues: {
      name: character.name,
      vocation: character.vocation ?? '',
      level: character.level,
      avatarUrl: character.avatarUrl,
    },
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

  const handleAvatarPick = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;

    setUploadError(null);
    setUploading(true);

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      setUploadError('Sessão expirada, entre novamente.');
      setUploading(false);
      return;
    }

    const ext = file.name.split('.').pop() ?? 'png';
    const path = `${user.id}/avatar.${ext}`;

    const { error: uploadErr } = await supabase.storage.from(AVATAR_BUCKET).upload(path, file, {
      upsert: true,
      cacheControl: '3600',
    });

    if (uploadErr) {
      setUploadError('Não foi possível enviar a imagem.');
      setUploading(false);
      return;
    }

    const {
      data: { publicUrl },
    } = supabase.storage.from(AVATAR_BUCKET).getPublicUrl(path);

    await fetch('/api/character', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: character.name,
        vocation: character.vocation,
        level: character.level,
        avatarUrl: `${publicUrl}?t=${Date.now()}`,
      }),
    });

    setUploading(false);
    onChanged();
  };

  if (editing) {
    return (
      <GlassCard title="Editar personagem">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-3">
          <input type="hidden" {...register('avatarUrl')} />
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
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="relative shrink-0 disabled:opacity-60"
            aria-label="Trocar foto do personagem"
            title="Trocar foto do personagem"
          >
            <Avatar character={character} />
          </button>
          <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarPick} />
          <div>
            <div className="text-xl font-semibold">{character.name}</div>
            <div className="text-sm text-muted-300">{character.vocation ?? 'Sem vocação definida'}</div>
          </div>
        </div>
        <div className="text-right">
          <div className="text-sm text-muted-300">Level</div>
          <div className="text-2xl font-semibold text-accent">{character.level}</div>
        </div>
      </div>
      {uploading && <p className="text-xs text-muted-300 mt-2">Enviando foto...</p>}
      {uploadError && <p className="text-xs text-red-400 mt-2">{uploadError}</p>}
      <button onClick={() => setEditing(true)} className="btn-tibia mt-4 text-sm">
        Editar
      </button>
    </GlassCard>
  );
}
