#!/bin/bash
set -e

mkdir -p prisma/migrations/20260719135000_hunt_session_bigint
mkdir -p prisma/migrations/20260719140000_trigger_full_name_fallback
mkdir -p src/app/auth/callback
mkdir -p src/components/auth
mkdir -p src/components/dashboard

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
  id           String   @id
  name         String?
  email        String   @unique
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

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
  id          String   @id @default(cuid())
  userId      String
  user        User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  startedAt   DateTime
  durationMin Int
  xpGained    BigInt
  profit      BigInt   @default(0)
  waste       BigInt   @default(0)
  loot        BigInt   @default(0)
  bosses      Int      @default(0)
  deaths      Int      @default(0)
  levelAfter  Int?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([userId, startedAt])
}

enum FriendshipStatus {
  PENDING
  ACCEPTED
}

model Friendship {
  id          String           @id @default(cuid())
  fromUserId  String
  fromUser    User             @relation("FriendRequestsSent", fields: [fromUserId], references: [id], onDelete: Cascade)
  toUserId    String
  toUser      User             @relation("FriendRequestsReceived", fields: [toUserId], references: [id], onDelete: Cascade)
  status      FriendshipStatus @default(PENDING)
  createdAt   DateTime         @default(now())
  updatedAt   DateTime         @updatedAt

  @@unique([fromUserId, toUserId])
}
EOF_prisma_schema_prisma_

cat > "prisma/migrations/20260719135000_hunt_session_bigint/migration.sql" << 'EOF_prisma_migrations_20260719135000_hunt_session_bigint_migration_sql_'
-- AlterTable
-- Widened from 32-bit int (max ~2.1B) to 64-bit, since a single hunt's XP or
-- profit can easily exceed that at high character levels.
ALTER TABLE "HuntSession" ALTER COLUMN "xpGained" SET DATA TYPE BIGINT,
ALTER COLUMN "profit" SET DATA TYPE BIGINT,
ALTER COLUMN "waste" SET DATA TYPE BIGINT,
ALTER COLUMN "loot" SET DATA TYPE BIGINT;
EOF_prisma_migrations_20260719135000_hunt_session_bigint_migration_sql_

cat > "prisma/migrations/20260719140000_trigger_full_name_fallback/migration.sql" << 'EOF_prisma_migrations_20260719140000_trigger_full_name_fallback_migration_sql_'
-- Google OAuth populates raw_user_meta_data.full_name (not .name), so fall back to it
-- when the email/password flow's 'name' key isn't present.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public."User" (id, email, name, "createdAt", "updatedAt")
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name'),
    now(),
    now()
  );
  RETURN NEW;
END;
$$;
EOF_prisma_migrations_20260719140000_trigger_full_name_fallback_migration_sql_

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
  };
}
EOF_src_lib_serialize_ts_

cat > "src/app/api/friends/ranking/route.ts" << 'EOF_src_app_api_friends_ranking_route_ts_'
import { NextResponse } from 'next/server';
import { getCurrentUserId } from '@/lib/session';
import { prisma } from '@/lib/prisma';

const PERIODS = ['24h', '7d', '30d', '90d'] as const;
type Period = (typeof PERIODS)[number];

function cutoffFor(period: Period) {
  const now = new Date();
  const start = new Date(now);
  if (period === '24h') start.setDate(now.getDate() - 1);
  if (period === '7d') start.setDate(now.getDate() - 7);
  if (period === '30d') start.setDate(now.getDate() - 30);
  if (period === '90d') start.setDate(now.getDate() - 90);
  return start;
}

export async function GET(req: Request) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const { searchParams } = new URL(req.url);
  const periodParam = searchParams.get('period');
  const period: Period = (PERIODS as readonly string[]).includes(periodParam ?? '') ? (periodParam as Period) : '7d';
  const cutoff = cutoffFor(period);

  const friendships = await prisma.friendship.findMany({
    where: { status: 'ACCEPTED', OR: [{ fromUserId: userId }, { toUserId: userId }] },
  });
  const peerIds = friendships.map((f) => (f.fromUserId === userId ? f.toUserId : f.fromUserId));
  const allIds = [userId, ...peerIds];

  const [characters, hunts] = await Promise.all([
    prisma.character.findMany({ where: { userId: { in: allIds } } }),
    prisma.huntSession.findMany({ where: { userId: { in: allIds }, startedAt: { gte: cutoff } } }),
  ]);

  const ranking = allIds.map((id) => {
    const character = characters.find((c) => c.userId === id);
    const userHunts = hunts.filter((h) => h.userId === id);
    const xp = userHunts.reduce((s, h) => s + Number(h.xpGained), 0);
    const durationMin = userHunts.reduce((s, h) => s + h.durationMin, 0);
    const profit = userHunts.reduce((s, h) => s + Number(h.profit), 0);
    const xpPerHour = durationMin > 0 ? Math.round(xp / (durationMin / 60)) : 0;

    return {
      isMe: id === userId,
      name: character?.name ?? 'Sem personagem',
      level: character?.level ?? null,
      xp,
      xpPerHour,
      profit,
    };
  });

  ranking.sort((a, b) => b.xp - a.xp);

  return NextResponse.json({ period, ranking });
}
EOF_src_app_api_friends_ranking_route_ts_

cat > "src/app/api/hunts/[id]/route.ts" << 'EOF_src_app_api_hunts__id__route_ts_'
import { NextResponse } from 'next/server';
import { getCurrentUserId } from '@/lib/session';
import { prisma } from '@/lib/prisma';
import { huntSessionSchema } from '@/lib/validation';
import { broadcastHuntChange } from '@/lib/supabase/broadcast';
import { serializeHunt } from '@/lib/serialize';

async function requireOwnedHunt(id: string, userId: string) {
  const hunt = await prisma.huntSession.findUnique({ where: { id } });
  if (!hunt || hunt.userId !== userId) return null;
  return hunt;
}

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const existing = await requireOwnedHunt(params.id, userId);
  if (!existing) {
    return NextResponse.json({ error: 'Registro não encontrado' }, { status: 404 });
  }

  const body = await req.json().catch(() => null);
  const parsed = huntSessionSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? 'Dados inválidos' }, { status: 400 });
  }

  const hunt = await prisma.huntSession.update({
    where: { id: params.id },
    data: parsed.data,
  });

  if (parsed.data.levelAfter) {
    await prisma.character.updateMany({
      where: { userId },
      data: { level: parsed.data.levelAfter },
    });
  }

  await broadcastHuntChange(userId);

  return NextResponse.json(serializeHunt(hunt));
}

export async function DELETE(_req: Request, { params }: { params: { id: string } }) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const existing = await requireOwnedHunt(params.id, userId);
  if (!existing) {
    return NextResponse.json({ error: 'Registro não encontrado' }, { status: 404 });
  }

  await prisma.huntSession.delete({ where: { id: params.id } });

  await broadcastHuntChange(userId);

  return NextResponse.json({ ok: true });
}
EOF_src_app_api_hunts__id__route_ts_

cat > "src/app/api/hunts/route.ts" << 'EOF_src_app_api_hunts_route_ts_'
import { NextResponse } from 'next/server';
import { getCurrentUserId } from '@/lib/session';
import { prisma } from '@/lib/prisma';
import { huntSessionSchema } from '@/lib/validation';
import { broadcastHuntChange } from '@/lib/supabase/broadcast';
import { serializeHunt } from '@/lib/serialize';

export async function GET(req: Request) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const { searchParams } = new URL(req.url);
  const since = searchParams.get('since');

  const hunts = await prisma.huntSession.findMany({
    where: {
      userId,
      ...(since ? { startedAt: { gte: new Date(since) } } : {}),
    },
    orderBy: { startedAt: 'asc' },
  });

  return NextResponse.json(hunts.map(serializeHunt));
}

export async function POST(req: Request) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const body = await req.json().catch(() => null);
  const parsed = huntSessionSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? 'Dados inválidos' }, { status: 400 });
  }

  const hunt = await prisma.huntSession.create({
    data: { ...parsed.data, userId },
  });

  if (parsed.data.levelAfter) {
    await prisma.character.updateMany({
      where: { userId },
      data: { level: parsed.data.levelAfter },
    });
  }

  await broadcastHuntChange(userId);

  return NextResponse.json(serializeHunt(hunt), { status: 201 });
}
EOF_src_app_api_hunts_route_ts_

cat > "src/app/auth/callback/route.ts" << 'EOF_src_app_auth_callback_route_ts_'
import { NextResponse } from 'next/server';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  const next = searchParams.get('next') ?? '/dashboard';

  if (code) {
    const supabase = createSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/login?error=oauth`);
}
EOF_src_app_auth_callback_route_ts_

cat > "src/components/auth/GoogleSignInButton.tsx" << 'EOF_src_components_auth_GoogleSignInButton_tsx_'
'use client';

import React, { useMemo, useState } from 'react';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';

export default function GoogleSignInButton() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [loading, setLoading] = useState(false);

  const handleClick = async () => {
    setLoading(true);
    await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: `${window.location.origin}/auth/callback` },
    });
    // Browser navigates away to Google; no need to reset loading here.
  };

  return (
    <button
      type="button"
      onClick={handleClick}
      disabled={loading}
      className="btn-tibia w-full justify-center flex items-center gap-2"
    >
      <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true">
        <path
          fill="#4285F4"
          d="M23.49 12.27c0-.79-.07-1.54-.19-2.27H12v4.51h6.47c-.29 1.48-1.14 2.73-2.4 3.58v3h3.86c2.26-2.09 3.56-5.17 3.56-8.82Z"
        />
        <path
          fill="#34A853"
          d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.86-3c-1.07.72-2.45 1.14-4.07 1.14-3.13 0-5.78-2.11-6.73-4.96H1.29v3.09C3.26 21.3 7.31 24 12 24Z"
        />
        <path
          fill="#FBBC05"
          d="M5.27 14.27a7.2 7.2 0 0 1 0-4.54V6.64H1.29a12 12 0 0 0 0 10.72l3.98-3.09Z"
        />
        <path
          fill="#EA4335"
          d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.94 1.19 15.24 0 12 0 7.31 0 3.26 2.7 1.29 6.64l3.98 3.09C6.22 6.86 8.87 4.75 12 4.75Z"
        />
      </svg>
      {loading ? 'Redirecionando...' : 'Continuar com Google'}
    </button>
  );
}
EOF_src_components_auth_GoogleSignInButton_tsx_

cat > "src/components/auth/LoginForm.tsx" << 'EOF_src_components_auth_LoginForm_tsx_'
'use client';

import React, { useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import GlassCard from '@/components/ui/GlassCard';
import { loginSchema } from '@/lib/validation';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import GoogleSignInButton from './GoogleSignInButton';
import type { z } from 'zod';

type FormData = z.infer<typeof loginSchema>;

export default function LoginForm() {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [serverError, setServerError] = useState<string | null>(null);
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({ resolver: zodResolver(loginSchema) });

  const onSubmit = async (data: FormData) => {
    setServerError(null);
    const { error } = await supabase.auth.signInWithPassword({
      email: data.email,
      password: data.password,
    });

    if (error) {
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

      <div className="flex items-center gap-3 my-4">
        <div className="h-px flex-1 bg-white/10" />
        <span className="text-xs text-muted-300">ou</span>
        <div className="h-px flex-1 bg-white/10" />
      </div>

      <GoogleSignInButton />

      <p className="mt-4 text-sm text-muted-300">
        Não tem conta?{' '}
        <Link href="/register" className="text-accent">
          Cadastre-se
        </Link>
      </p>
    </GlassCard>
  );
}
EOF_src_components_auth_LoginForm_tsx_

cat > "src/components/auth/RegisterForm.tsx" << 'EOF_src_components_auth_RegisterForm_tsx_'
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
EOF_src_components_auth_RegisterForm_tsx_

cat > "src/components/dashboard/CreateCharacterForm.tsx" << 'EOF_src_components_dashboard_CreateCharacterForm_tsx_'
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
EOF_src_components_dashboard_CreateCharacterForm_tsx_

cat > "src/components/dashboard/DashboardShell.tsx" << 'EOF_src_components_dashboard_DashboardShell_tsx_'
'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { RefreshCw } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import Tabs from '@/components/ui/Tabs';
import Sidebar from './Sidebar';
import StatsGrid from './StatsGrid';
import Filters from './Filters';
import PeriodFilter from './PeriodFilter';
import InteractiveChart from './InteractiveChart';
import BossesDeaths from './BossesDeaths';
import ProgressTarget from './ProgressTarget';
import HuntForm from './HuntForm';
import HuntHistory from './HuntHistory';
import CharacterCard from './CharacterCard';
import CreateCharacterForm from './CreateCharacterForm';
import XpEvolutionChart from './XpEvolutionChart';
import ProfitPerDayChart from './ProfitPerDayChart';
import XpPerHourSessionChart from './XpPerHourSessionChart';
import FriendsPanel from './FriendsPanel';
import RubinOtRanking from './RubinOtRanking';
import { aggregateByDay, computeSummary, filterByPeriod, perSessionSeries, Character, HuntSession } from '@/lib/dashboard';

function formatUpdatedAt(date: Date) {
  return date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

export default function DashboardShell() {
  const [period, setPeriod] = useState<'24h' | '7d' | '30d' | '90d'>('7d');
  const [showCumulative, setShowCumulative] = useState(false);
  const [hunts, setHunts] = useState<HuntSession[]>([]);
  const [character, setCharacter] = useState<Character | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [showAddForm, setShowAddForm] = useState(false);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [activeTab, setActiveTab] = useState('overview');

  const loadData = useCallback(async () => {
    setRefreshing(true);
    const [huntsRes, characterRes] = await Promise.all([fetch('/api/hunts'), fetch('/api/character')]);
    if (huntsRes.ok) setHunts(await huntsRes.json());
    if (characterRes.ok) setCharacter(await characterRes.json());
    setLoading(false);
    setRefreshing(false);
    setLastUpdated(new Date());
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const windowedHunts = useMemo(() => filterByPeriod(hunts, period), [hunts, period]);
  const windowed = useMemo(() => aggregateByDay(windowedHunts), [windowedHunts]);
  const allSeries = useMemo(() => aggregateByDay(hunts), [hunts]);
  const summary = useMemo(() => computeSummary(windowedHunts), [windowedHunts]);
  const sessionPoints = useMemo(() => perSessionSeries(windowedHunts), [windowedHunts]);

  if (loading) {
    return (
      <GlassCard>
        <p className="text-muted-300">Carregando seu progresso...</p>
      </GlassCard>
    );
  }

  if (!character) {
    // Google/OAuth sign-ins skip the register form's character-name field.
    return <CreateCharacterForm onCreated={loadData} />;
  }

  const header = (
    <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
      <div>
        <div className="text-sm text-muted-300">Visão geral</div>
        <div className="text-xl font-semibold">Seu progresso — visão rápida</div>
        {lastUpdated && (
          <div className="flex items-center gap-1.5 text-xs text-muted-300 mt-1">
            <span>Última atualização: {formatUpdatedAt(lastUpdated)}</span>
            <button
              onClick={loadData}
              disabled={refreshing}
              aria-label="Atualizar dados"
              className="p-0.5 rounded hover:text-accent disabled:opacity-50"
            >
              <RefreshCw className={`w-3 h-3 ${refreshing ? 'animate-spin' : ''}`} />
            </button>
          </div>
        )}
      </div>
      <div className="flex items-center gap-3">
        <Filters period={period} onChange={setPeriod} showCumulative={showCumulative} setShowCumulative={setShowCumulative} />
        <button
          onClick={() => {
            setShowAddForm(true);
            setActiveTab('history');
          }}
          className="btn-tibia btn-tibia--primary text-sm"
        >
          + Nova hunt
        </button>
      </div>
    </div>
  );

  const overviewTab = (
    <div>
      {header}
      <StatsGrid summary={summary} />

      <div className="mt-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <GlassCard>
            <InteractiveChart data={windowed} showCumulative={showCumulative} />
          </GlassCard>
        </div>

        <div className="space-y-6">
          <BossesDeaths summary={summary} />
          <ProgressTarget data={allSeries} summary={summary} />
        </div>
      </div>
    </div>
  );

  const historyTab = (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-xl font-semibold">Histórico de hunts</div>
        <button onClick={() => setShowAddForm((v) => !v)} className="btn-tibia btn-tibia--primary text-sm">
          {showAddForm ? 'Fechar' : '+ Nova hunt'}
        </button>
      </div>

      {showAddForm && (
        <HuntForm
          onSaved={() => {
            setShowAddForm(false);
            loadData();
          }}
          onCancel={() => setShowAddForm(false)}
        />
      )}

      <HuntHistory hunts={hunts} onChanged={loadData} />
    </div>
  );

  const statsTab = (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-xl font-semibold">Estatísticas</div>
        <PeriodFilter period={period} onChange={setPeriod} />
      </div>
      <XpEvolutionChart data={windowed} />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ProfitPerDayChart data={windowed} />
        <XpPerHourSessionChart data={sessionPoints} />
      </div>
    </div>
  );

  const friendsTab = (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-xl font-semibold">Amigos</div>
        <PeriodFilter period={period} onChange={setPeriod} />
      </div>
      <FriendsPanel period={period} />
    </div>
  );

  const panels: Record<string, React.ReactNode> = {
    overview: <GlassCard>{overviewTab}</GlassCard>,
    history: historyTab,
    stats: statsTab,
    ranking: <RubinOtRanking />,
    friends: friendsTab,
  };

  return (
    <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }} className="space-y-6">
      {character && <CharacterCard character={character} onChanged={loadData} />}

      {/* Mobile: keep a simple tab strip since the sidebar is desktop-only. */}
      <div className="md:hidden">
        <Tabs
          active={activeTab}
          onActiveChange={setActiveTab}
          tabs={[
            { key: 'overview', label: 'Visão Geral', content: panels.overview },
            { key: 'history', label: 'Histórico de Hunts', content: panels.history },
            { key: 'stats', label: 'Estatísticas', content: panels.stats },
            { key: 'ranking', label: 'Ranking RubinOT', content: panels.ranking },
            { key: 'friends', label: 'Amigos', content: panels.friends },
          ]}
        />
      </div>

      <div className="hidden md:flex gap-6 items-start">
        <Sidebar active={activeTab} onChange={setActiveTab} />
        <div className="flex-1 min-w-0">{panels[activeTab]}</div>
      </div>
    </motion.div>
  );
}
EOF_src_components_dashboard_DashboardShell_tsx_

git add -A
git commit -m "Widen HuntSession xp/gold to BigInt, add Google OAuth sign-in"
git push -u origin claude/user-auth-character-progress-00b5p6
