'use client';

import React, { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import GlassCard from '@/components/ui/GlassCard';
import { registerSchema } from '@/lib/validation';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import GoogleSignInButton from './GoogleSignInButton';
import type { z } from 'zod';

type FormData = z.infer<typeof registerSchema>;

export default function RegisterForm() {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [serverError, setServerError] = useState<string | null>(null);
  const [confirmationSent, setConfirmationSent] = useState(false);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({ resolver: zodResolver(registerSchema) });

  const onSubmit = async (data: FormData) => {
    setServerError(null);

    const { data: signUpData, error } = await supabase.auth.signUp({
      email: data.email,
      password: data.password,
      options: { data: { name: data.name } },
    });

    if (error) {
      setServerError(
        error.message.toLowerCase().includes('already registered')
          ? 'Este email já está cadastrado'
          : error.message
      );
      return;
    }

    if (!signUpData.session) {
      // Email confirmation is enabled on the Supabase project — no session yet.
      setConfirmationSent(true);
      return;
    }

    await fetch('/api/character', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: data.characterName, level: 8 }),
    });

    router.push('/dashboard');
    router.refresh();
  };

  if (confirmationSent) {
    return (
      <GlassCard title="Confirme seu email">
        <p className="text-sm text-muted-300">
          Enviamos um link de confirmação para o seu email. Clique nele para ativar a conta e depois volte aqui
          para entrar.
        </p>
        <p className="mt-4 text-sm text-muted-300">
          <Link href="/login" className="text-accent">
            Ir para o login
          </Link>
        </p>
      </GlassCard>
    );
  }

  return (
    <GlassCard title="Criar conta">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <div>
          <label className="label-tibia">Seu nome</label>
          <input type="text" className="input-tibia" {...register('name')} />
          {errors.name && <p className="text-sm text-red-400 mt-1">{errors.name.message}</p>}
        </div>

        <div>
          <label className="label-tibia">Nome do personagem</label>
          <input type="text" className="input-tibia" {...register('characterName')} />
          {errors.characterName && <p className="text-sm text-red-400 mt-1">{errors.characterName.message}</p>}
        </div>

        <div>
          <label className="label-tibia">Email</label>
          <input type="email" className="input-tibia" {...register('email')} />
          {errors.email && <p className="text-sm text-red-400 mt-1">{errors.email.message}</p>}
        </div>

        <div>
          <label className="label-tibia">Senha</label>
          <input type="password" className="input-tibia" {...register('password')} />
          {errors.password && <p className="text-sm text-red-400 mt-1">{errors.password.message}</p>}
        </div>

        {serverError && <p className="text-sm text-red-400">{serverError}</p>}

        <button type="submit" disabled={isSubmitting} className="btn-tibia btn-tibia--primary w-full justify-center">
          {isSubmitting ? 'Criando conta...' : 'Criar conta'}
        </button>
      </form>

      <div className="flex items-center gap-3 my-4">
        <div className="h-px flex-1 bg-white/10" />
        <span className="text-xs text-muted-300">ou</span>
        <div className="h-px flex-1 bg-white/10" />
      </div>

      <GoogleSignInButton />

      <p className="mt-4 text-sm text-muted-300">
        Já tem conta?{' '}
        <Link href="/login" className="text-accent">
          Entrar
        </Link>
      </p>
    </GlassCard>
  );
}
