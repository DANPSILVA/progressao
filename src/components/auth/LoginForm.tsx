'use client';

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { signIn } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import GlassCard from '@/components/ui/GlassCard';
import { loginSchema } from '@/lib/validation';
import type { z } from 'zod';

type FormData = z.infer<typeof loginSchema>;

export default function LoginForm() {
  const router = useRouter();
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({ resolver: zodResolver(loginSchema) });

  const onSubmit = async (data: FormData) => {
    setServerError(null);
    const res = await signIn('credentials', {
      redirect: false,
      email: data.email,
      password: data.password,
    });

    if (res?.error) {
      setServerError('Email ou senha inválidos');
      return;
    }

    router.push('/dashboard');
    router.refresh();
  };

  return (
    <GlassCard title="Entrar">
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
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
          {isSubmitting ? 'Entrando...' : 'Entrar'}
        </button>
      </form>

      <p className="mt-4 text-sm text-muted-300">
        Não tem conta?{' '}
        <Link href="/register" className="text-accent">
          Cadastre-se
        </Link>
      </p>
    </GlassCard>
  );
}
