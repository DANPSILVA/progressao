'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { signIn } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import GlassCard from '@/components/ui/GlassCard';
import { registerSchema } from '@/lib/validation';
import type { z } from 'zod';

type FormData = z.infer<typeof registerSchema>;

export default function RegisterForm() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({ resolver: zodResolver(registerSchema) });

  const onSubmit = async (data: FormData) => {
    setServerError(null);

    const res = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setServerError(body.error ?? 'Não foi possível criar a conta');
      return;
    }

    const signInRes = await signIn('credentials', {
      redirect: false,
      email: data.email,
      password: data.password,
    });

    if (signInRes?.error) {
      router.push('/login');
      return;
    }

    router.push('/dashboard');
    router.refresh();
  };

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

      <p className="mt-4 text-sm text-muted-300">
        Já tem conta?{' '}
        <Link href="/login" className="text-accent">
          Entrar
        </Link>
      </p>
    </GlassCard>
  );
}
