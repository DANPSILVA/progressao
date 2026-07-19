#!/bin/bash
set -e

# Remove files/dirs that no longer exist in this batch of changes
rm -rf "src/app/api/auth"
rm -rf "src/app/api/register"
rm -rf "src/components/providers"
rm -f "src/lib/auth.ts"

mkdir -p prisma/migrations/20260719120000_supabase_auth_migration
mkdir -p prisma/migrations/20260719121500_avatars_storage_bucket
mkdir -p src/lib/supabase
mkdir -p src/components/dashboard
mkdir -p src/app/dashboard
mkdir -p src/app/api/character
mkdir -p "src/app/api/friends/[id]/accept"
mkdir -p src/app/api/friends/ranking
mkdir -p "src/app/api/hunts/[id]"
mkdir -p src/components/auth

cat > ".env.example" << 'EOF__env_example_'
# Postgres connection string from your Supabase project
# Settings → Database → Connection string → URI (use the "Transaction" pooler string on Vercel)
DATABASE_URL="postgresql://postgres.xxxxxxxx:password@aws-0-xx-xxxx-1.pooler.supabase.com:6543/postgres"

# Supabase project settings
# Settings → API
NEXT_PUBLIC_SUPABASE_URL="https://xxxxxxxx.supabase.co"
NEXT_PUBLIC_SUPABASE_ANON_KEY="replace-with-your-anon-public-key"
EOF__env_example_

cat > "package.json" << 'EOF_package_json_'
{
  "name": "progressao",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "postinstall": "prisma generate",
    "db:migrate": "prisma migrate dev",
    "db:deploy": "prisma migrate deploy",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "@hookform/resolvers": "^3.9.0",
    "@prisma/client": "^5.22.0",
    "@supabase/ssr": "^0.12.3",
    "@supabase/supabase-js": "^2.110.7",
    "framer-motion": "^11.3.19",
    "lucide-react": "^0.400.0",
    "next": "14.2.15",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-hook-form": "^7.52.2",
    "recharts": "^2.12.7",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^20.14.10",
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.19",
    "postcss": "^8.4.39",
    "prisma": "^5.22.0",
    "tailwindcss": "^3.4.6",
    "typescript": "^5.5.4"
  }
}
EOF_package_json_

cat > "prisma/schema.prisma" << 'EOF_prisma_schema_prisma_'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
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
  xpGained    Int
  profit      Int      @default(0)
  waste       Int      @default(0)
  loot        Int      @default(0)
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

cat > "prisma/migrations/20260719120000_supabase_auth_migration/migration.sql" << 'EOF_prisma_migrations_20260719120000_supabase_auth_migration_migration_sql_'
-- AlterTable
ALTER TABLE "Character" ADD COLUMN     "avatarUrl" TEXT;

-- AlterTable
ALTER TABLE "User" DROP COLUMN "passwordHash";

-- Supabase Auth owns auth.users; this trigger keeps public."User" in sync so the
-- app's existing tables (Character, HuntSession, Friendship) can keep referencing
-- a plain public."User".id foreign key exactly as before.
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
    NEW.raw_user_meta_data->>'name',
    now(),
    now()
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
EOF_prisma_migrations_20260719120000_supabase_auth_migration_migration_sql_

cat > "prisma/migrations/20260719121500_avatars_storage_bucket/migration.sql" << 'EOF_prisma_migrations_20260719121500_avatars_storage_bucket_migration_sql_'
-- Creates the "avatars" Storage bucket and RLS policies for it. This only runs
-- meaningfully against a real Supabase project (the storage schema is part of
-- Supabase's managed Postgres, not a plain Postgres install).
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read access for avatars" ON storage.objects;
CREATE POLICY "Public read access for avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
EOF_prisma_migrations_20260719121500_avatars_storage_bucket_migration_sql_

cat > "src/app/api/character/route.ts" << 'EOF_src_app_api_character_route_ts_'
import { NextResponse } from 'next/server';
import { getCurrentUserId } from '@/lib/session';
import { prisma } from '@/lib/prisma';
import { characterSchema } from '@/lib/validation';

export async function GET() {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const character = await prisma.character.findUnique({ where: { userId } });
  return NextResponse.json(character);
}

export async function PUT(req: Request) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const body = await req.json().catch(() => null);
  const parsed = characterSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? 'Dados inválidos' }, { status: 400 });
  }

  const character = await prisma.character.upsert({
    where: { userId },
    update: parsed.data,
    create: { ...parsed.data, userId },
  });

  return NextResponse.json(character);
}
EOF_src_app_api_character_route_ts_

cat > "src/app/api/friends/[id]/accept/route.ts" << 'EOF_src_app_api_friends__id__accept_route_ts_'
import { NextResponse } from 'next/server';
import { getCurrentUserId } from '@/lib/session';
import { prisma } from '@/lib/prisma';

export async function POST(_req: Request, { params }: { params: { id: string } }) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const friendship = await prisma.friendship.findUnique({ where: { id: params.id } });
  if (!friendship || friendship.toUserId !== userId || friendship.status !== 'PENDING') {
    return NextResponse.json({ error: 'Pedido não encontrado' }, { status: 404 });
  }

  const updated = await prisma.friendship.update({
    where: { id: params.id },
    data: { status: 'ACCEPTED' },
  });

  return NextResponse.json(updated);
}
EOF_src_app_api_friends__id__accept_route_ts_

cat > "src/app/api/friends/[id]/route.ts" << 'EOF_src_app_api_friends__id__route_ts_'
import { NextResponse } from 'next/server';
import { getCurrentUserId } from '@/lib/session';
import { prisma } from '@/lib/prisma';

export async function DELETE(_req: Request, { params }: { params: { id: string } }) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const friendship = await prisma.friendship.findUnique({ where: { id: params.id } });
  if (!friendship || (friendship.fromUserId !== userId && friendship.toUserId !== userId)) {
    return NextResponse.json({ error: 'Não encontrado' }, { status: 404 });
  }

  await prisma.friendship.delete({ where: { id: params.id } });

  return NextResponse.json({ ok: true });
}
EOF_src_app_api_friends__id__route_ts_

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
    const xp = userHunts.reduce((s, h) => s + h.xpGained, 0);
    const durationMin = userHunts.reduce((s, h) => s + h.durationMin, 0);
    const profit = userHunts.reduce((s, h) => s + h.profit, 0);
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

cat > "src/app/api/friends/route.ts" << 'EOF_src_app_api_friends_route_ts_'
import { NextResponse } from 'next/server';
import { getCurrentUserId } from '@/lib/session';
import { prisma } from '@/lib/prisma';
import { friendRequestSchema } from '@/lib/validation';

function toPeerSummary(character: { name: string; level: number; vocation: string | null } | null) {
  return {
    name: character?.name ?? 'Sem personagem',
    level: character?.level ?? null,
    vocation: character?.vocation ?? null,
  };
}

export async function GET() {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const friendships = await prisma.friendship.findMany({
    where: { OR: [{ fromUserId: userId }, { toUserId: userId }] },
    include: {
      fromUser: { include: { character: true } },
      toUser: { include: { character: true } },
    },
    orderBy: { createdAt: 'desc' },
  });

  type PeerEntry = { friendshipId: string; name: string; level: number | null; vocation: string | null };
  const accepted: PeerEntry[] = [];
  const incoming: PeerEntry[] = [];
  const outgoing: PeerEntry[] = [];

  for (const f of friendships) {
    const isFromMe = f.fromUserId === userId;
    const peerUser = isFromMe ? f.toUser : f.fromUser;
    const entry = { friendshipId: f.id, ...toPeerSummary(peerUser.character) };

    if (f.status === 'ACCEPTED') accepted.push(entry);
    else if (isFromMe) outgoing.push(entry);
    else incoming.push(entry);
  }

  return NextResponse.json({ accepted, incoming, outgoing });
}

export async function POST(req: Request) {
  const userId = await getCurrentUserId();
  if (!userId) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }

  const body = await req.json().catch(() => null);
  const parsed = friendRequestSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? 'Dados inválidos' }, { status: 400 });
  }

  const targetEmail = parsed.data.email.toLowerCase();
  const targetUser = await prisma.user.findUnique({ where: { email: targetEmail } });
  if (!targetUser) {
    return NextResponse.json({ error: 'Nenhum usuário encontrado com esse email' }, { status: 404 });
  }
  if (targetUser.id === userId) {
    return NextResponse.json({ error: 'Você não pode adicionar a si mesmo' }, { status: 400 });
  }

  const existing = await prisma.friendship.findFirst({
    where: {
      OR: [
        { fromUserId: userId, toUserId: targetUser.id },
        { fromUserId: targetUser.id, toUserId: userId },
      ],
    },
  });
  if (existing) {
    return NextResponse.json({ error: 'Já existe um pedido ou amizade com esse usuário' }, { status: 409 });
  }

  const friendship = await prisma.friendship.create({
    data: { fromUserId: userId, toUserId: targetUser.id },
  });

  return NextResponse.json(friendship, { status: 201 });
}
EOF_src_app_api_friends_route_ts_

cat > "src/app/api/hunts/[id]/route.ts" << 'EOF_src_app_api_hunts__id__route_ts_'
import { NextResponse } from 'next/server';
import { getCurrentUserId } from '@/lib/session';
import { prisma } from '@/lib/prisma';
import { huntSessionSchema } from '@/lib/validation';
import { broadcastHuntChange } from '@/lib/supabase/broadcast';

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

  return NextResponse.json(hunt);
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

  return NextResponse.json(hunts);
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

  return NextResponse.json(hunt, { status: 201 });
}
EOF_src_app_api_hunts_route_ts_

cat > "src/app/dashboard/page.tsx" << 'EOF_src_app_dashboard_page_tsx_'
import { redirect } from 'next/navigation';
import Header from '@/components/Header';
import DashboardShell from '@/components/dashboard/DashboardShell';
import { getCurrentUserId } from '@/lib/session';

export const metadata = {
  title: 'RubinTracker — Dashboard',
  description: 'Visualize seus KPIs e evolução — XP, Profit, Bosses e demais métricas.'
};

export default async function DashboardPage() {
  const userId = await getCurrentUserId();
  if (!userId) {
    redirect('/login');
  }

  return (
    <div>
      <Header />
      <main className="max-w-7xl mx-auto py-10 px-4">
        <h1 className="text-3xl font-semibold mb-6">Dashboard</h1>
        <DashboardShell />
      </main>
    </div>
  );
}
EOF_src_app_dashboard_page_tsx_

cat > "src/app/layout.tsx" << 'EOF_src_app_layout_tsx_'
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'RubinTracker — Dashboard',
  description: 'Acompanhamento de XP diária no Tibia',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
EOF_src_app_layout_tsx_

cat > "src/components/Header.tsx" << 'EOF_src_components_Header_tsx_'
'use client';

import React, { useMemo } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import ThemeToggle from '@/components/ui/ThemeToggle';
import { useSupabaseUser } from '@/lib/supabase/useUser';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';

export default function Header() {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const { user, loading } = useSupabaseUser();

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    router.push('/');
    router.refresh();
  };

  return (
    <header className="w-full border-b border-white/6 bg-gradient-to-b from-[rgba(0,0,0,0.06)] to-transparent">
      <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/" className="logo-mark">
            <img src="/logo-tibia-inspired.svg" alt="RubinTracker" width={36} height={36} />
          </Link>
          <Link href="/" className="text-lg font-semibold tracking-tight">RubinTracker</Link>
        </div>

        <nav className="flex items-center gap-4">
          {user ? (
            <>
              <Link href="/dashboard" className="text-sm text-muted-300 hover:text-text-100">Dashboard</Link>
              <span className="text-sm text-muted-300 hidden sm:inline">
                {(user.user_metadata as { name?: string })?.name ?? user.email}
              </span>
              <button onClick={handleSignOut} className="btn-tibia text-sm">
                Sair
              </button>
            </>
          ) : loading ? null : (
            <>
              <Link href="/login" className="text-sm text-muted-300 hover:text-text-100">Entrar</Link>
              <Link href="/register" className="btn-tibia btn-tibia--primary text-sm">Cadastrar</Link>
            </>
          )}
          <ThemeToggle />
        </nav>
      </div>
    </header>
  );
}
EOF_src_components_Header_tsx_

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

cat > "src/components/dashboard/CharacterCard.tsx" << 'EOF_src_components_dashboard_CharacterCard_tsx_'
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
EOF_src_components_dashboard_CharacterCard_tsx_

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

cat > "src/components/dashboard/FriendsPanel.tsx" << 'EOF_src_components_dashboard_FriendsPanel_tsx_'
'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { UserPlus, Check, X, Trophy } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import { friendRequestSchema } from '@/lib/validation';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';
import { HUNTS_UPDATES_CHANNEL } from '@/lib/supabase/channels';

type PeerEntry = { friendshipId: string; name: string; level: number | null; vocation: string | null };
type FriendsData = { accepted: PeerEntry[]; incoming: PeerEntry[]; outgoing: PeerEntry[] };
type RankingEntry = { isMe: boolean; name: string; level: number | null; xp: number; xpPerHour: number; profit: number };

export default function FriendsPanel({ period }: { period: '24h' | '7d' | '30d' | '90d' }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [data, setData] = useState<FriendsData | null>(null);
  const [ranking, setRanking] = useState<RankingEntry[]>([]);
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    const res = await fetch('/api/friends');
    if (res.ok) setData(await res.json());
  }, []);

  const loadRanking = useCallback(async () => {
    const res = await fetch(`/api/friends/ranking?period=${period}`);
    if (res.ok) {
      const body = await res.json();
      setRanking(body.ranking);
    }
  }, [period]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    loadRanking();
  }, [loadRanking]);

  useEffect(() => {
    // Any friend (or the player) saving/editing/deleting a hunt broadcasts here, so the
    // ranking refreshes live instead of waiting for a manual page reload.
    const channel = supabase
      .channel(HUNTS_UPDATES_CHANNEL)
      .on('broadcast', { event: 'hunt-change' }, () => {
        loadRanking();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [supabase, loadRanking]);

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    const parsed = friendRequestSchema.safeParse({ email });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? 'Email inválido');
      return;
    }
    setSubmitting(true);
    const res = await fetch('/api/friends', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    });
    setSubmitting(false);
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error ?? 'Não foi possível enviar o pedido');
      return;
    }
    setEmail('');
    load();
  };

  const handleAccept = async (friendshipId: string) => {
    await fetch(`/api/friends/${friendshipId}/accept`, { method: 'POST' });
    load();
    loadRanking();
  };

  const handleRemove = async (friendshipId: string) => {
    await fetch(`/api/friends/${friendshipId}`, { method: 'DELETE' });
    load();
    loadRanking();
  };

  return (
    <div className="space-y-6">
      <GlassCard title="Adicionar amigo">
        <form onSubmit={handleAdd} className="flex items-end gap-3 flex-wrap">
          <div className="flex-1 min-w-[220px]">
            <label className="label-tibia">Email do amigo</label>
            <input
              type="email"
              className="input-tibia"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="amigo@exemplo.com"
            />
          </div>
          <button type="submit" disabled={submitting} className="btn-tibia btn-tibia--primary">
            <UserPlus className="w-4 h-4" />
            {submitting ? 'Enviando...' : 'Enviar pedido'}
          </button>
        </form>
        {error && <p className="text-sm text-red-400 mt-2">{error}</p>}
      </GlassCard>

      {data && data.incoming.length > 0 && (
        <GlassCard title="Pedidos recebidos">
          <ul className="space-y-2">
            {data.incoming.map((p) => (
              <li key={p.friendshipId} className="flex items-center justify-between text-sm">
                <span>
                  {p.name} {p.level && <span className="text-muted-300">(level {p.level})</span>}
                </span>
                <div className="flex gap-2">
                  <button onClick={() => handleAccept(p.friendshipId)} className="btn-tibia text-xs" aria-label="Aceitar">
                    <Check className="w-3.5 h-3.5" style={{ color: 'var(--series-2)' }} />
                  </button>
                  <button onClick={() => handleRemove(p.friendshipId)} className="btn-tibia text-xs" aria-label="Recusar">
                    <X className="w-3.5 h-3.5" style={{ color: 'var(--series-8)' }} />
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </GlassCard>
      )}

      {data && data.outgoing.length > 0 && (
        <GlassCard title="Pedidos enviados (aguardando)">
          <ul className="space-y-2">
            {data.outgoing.map((p) => (
              <li key={p.friendshipId} className="flex items-center justify-between text-sm">
                <span className="text-muted-300">{p.name}</span>
                <button onClick={() => handleRemove(p.friendshipId)} className="btn-tibia text-xs">
                  Cancelar
                </button>
              </li>
            ))}
          </ul>
        </GlassCard>
      )}

      <GlassCard title={`Ranking (${period})`}>
        {ranking.length <= 1 ? (
          <p className="text-sm text-muted-300">
            Adicione amigos acima para comparar XP, lucro e level no período selecionado.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-muted-300">
                  <th className="py-2 pr-4">#</th>
                  <th className="py-2 pr-4">Personagem</th>
                  <th className="py-2 pr-4">Level</th>
                  <th className="py-2 pr-4">XP</th>
                  <th className="py-2 pr-4">XP/h</th>
                  <th className="py-2 pr-4">Profit</th>
                </tr>
              </thead>
              <tbody>
                {ranking.map((r, i) => (
                  <tr key={r.name + i} className={`border-t border-white/6 ${r.isMe ? 'text-accent font-semibold' : ''}`}>
                    <td className="py-2 pr-4">
                      {i === 0 ? <Trophy className="w-4 h-4 inline" style={{ color: 'var(--series-4)' }} /> : i + 1}
                    </td>
                    <td className="py-2 pr-4">
                      {r.name} {r.isMe && <span className="text-xs text-muted-300">(você)</span>}
                    </td>
                    <td className="py-2 pr-4">{r.level ?? '—'}</td>
                    <td className="py-2 pr-4">{r.xp.toLocaleString()}</td>
                    <td className="py-2 pr-4">{r.xpPerHour.toLocaleString()}</td>
                    <td className="py-2 pr-4">{r.profit.toLocaleString()} gp</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </GlassCard>

      {data && data.accepted.length > 0 && (
        <GlassCard title="Seus amigos">
          <ul className="space-y-2">
            {data.accepted.map((p) => (
              <li key={p.friendshipId} className="flex items-center justify-between text-sm">
                <span>
                  {p.name} {p.level && <span className="text-muted-300">(level {p.level})</span>}
                </span>
                <button onClick={() => handleRemove(p.friendshipId)} className="text-red-400 text-xs">
                  Desfazer amizade
                </button>
              </li>
            ))}
          </ul>
        </GlassCard>
      )}
    </div>
  );
}
EOF_src_components_dashboard_FriendsPanel_tsx_

cat > "src/components/dashboard/Sidebar.tsx" << 'EOF_src_components_dashboard_Sidebar_tsx_'
'use client';

import React from 'react';
import { LayoutDashboard, ClipboardList, BarChart3, Trophy, Users } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

type NavItem = { key: string; label: string; icon: LucideIcon };
type NavSection = { title: string; items: NavItem[] };

const SECTIONS: NavSection[] = [
  {
    title: 'Principal',
    items: [
      { key: 'overview', label: 'Visão Geral', icon: LayoutDashboard },
      { key: 'history', label: 'Histórico de Hunts', icon: ClipboardList },
    ],
  },
  {
    title: 'Análise',
    items: [
      { key: 'stats', label: 'Estatísticas', icon: BarChart3 },
      { key: 'ranking', label: 'Ranking RubinOT', icon: Trophy },
    ],
  },
  {
    title: 'Comunidade',
    items: [{ key: 'friends', label: 'Amigos', icon: Users }],
  },
];

export default function Sidebar({ active, onChange }: { active: string; onChange: (key: string) => void }) {
  return (
    <aside className="w-56 shrink-0 border-r border-white/6 py-6 pr-4 hidden md:block">
      <nav className="space-y-6 sticky top-6">
        {SECTIONS.map((section) => (
          <div key={section.title}>
            <div className="text-xs uppercase tracking-wide text-muted-300 px-3 mb-2">{section.title}</div>
            <ul className="space-y-1">
              {section.items.map((item) => {
                const Icon = item.icon;
                const isActive = active === item.key;
                return (
                  <li key={item.key}>
                    <button
                      type="button"
                      onClick={() => onChange(item.key)}
                      aria-current={isActive ? 'page' : undefined}
                      className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-md text-sm transition-colors text-left ${
                        isActive
                          ? 'bg-accent text-black font-medium'
                          : 'text-muted-300 hover:text-[var(--text-100)] hover:bg-white/5'
                      }`}
                    >
                      <Icon className="w-4 h-4 shrink-0" />
                      {item.label}
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>
    </aside>
  );
}
EOF_src_components_dashboard_Sidebar_tsx_

cat > "src/lib/dashboard.ts" << 'EOF_src_lib_dashboard_ts_'
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

export const huntSessionSchema = z.object({
  startedAt: z.coerce.date(),
  durationMin: z.coerce.number().int().positive('Duração deve ser maior que zero'),
  xpGained: z.coerce.number().int().min(0),
  profit: z.coerce.number().int().default(0),
  waste: z.coerce.number().int().default(0),
  loot: z.coerce.number().int().default(0),
  bosses: z.coerce.number().int().min(0).default(0),
  deaths: z.coerce.number().int().min(0).default(0),
  levelAfter: z.preprocess(
    (val) => (val === '' || val === null || val === undefined ? undefined : val),
    z.coerce.number().int().positive().optional()
  ),
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

cat > "src/lib/session.ts" << 'EOF_src_lib_session_ts_'
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function getCurrentUserId(): Promise<string | null> {
  const supabase = createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  return user?.id ?? null;
}
EOF_src_lib_session_ts_

cat > "src/middleware.ts" << 'EOF_src_middleware_ts_'
import { type NextRequest } from 'next/server';
import { updateSupabaseSession } from '@/lib/supabase/middleware';

export async function middleware(request: NextRequest) {
  return updateSupabaseSession(request);
}

export const config = {
  matcher: ['/dashboard/:path*'],
};
EOF_src_middleware_ts_

cat > "src/lib/supabase/client.ts" << 'EOF_src_lib_supabase_client_ts_'
import { createBrowserClient } from '@supabase/ssr';

export function createSupabaseBrowserClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
EOF_src_lib_supabase_client_ts_

cat > "src/lib/supabase/server.ts" << 'EOF_src_lib_supabase_server_ts_'
import { cookies } from 'next/headers';
import { createServerClient } from '@supabase/ssr';

export function createSupabaseServerClient() {
  const cookieStore = cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
          } catch {
            // Called from a Server Component render — the middleware refreshes the
            // session cookie on every request, so a no-op here is safe.
          }
        },
      },
    }
  );
}
EOF_src_lib_supabase_server_ts_

cat > "src/lib/supabase/middleware.ts" << 'EOF_src_lib_supabase_middleware_ts_'
import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';

export async function updateSupabaseSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        },
      },
    }
  );

  // Revalidates the session with the Supabase Auth server (not just the local
  // cookie), so a signed-out/expired user is caught before hitting /dashboard.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isDashboardRoute = request.nextUrl.pathname.startsWith('/dashboard');

  if (isDashboardRoute && !user) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('callbackUrl', request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  return response;
}
EOF_src_lib_supabase_middleware_ts_

cat > "src/lib/supabase/useUser.ts" << 'EOF_src_lib_supabase_useUser_ts_'
'use client';

import { useEffect, useMemo, useState } from 'react';
import type { User } from '@supabase/supabase-js';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';

export function useSupabaseUser() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      setUser(data.user);
      setLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, [supabase]);

  return { user, loading };
}
EOF_src_lib_supabase_useUser_ts_

cat > "src/lib/supabase/broadcast.ts" << 'EOF_src_lib_supabase_broadcast_ts_'
import { createClient } from '@supabase/supabase-js';
import { HUNTS_UPDATES_CHANNEL } from '@/lib/supabase/channels';

const CHANNEL = HUNTS_UPDATES_CHANNEL;

/** Fire-and-forget notice so friends' ranking panels can refetch live. Best-effort: a
 *  failed broadcast never blocks the hunt CRUD response, it just delays the next
 *  auto-refresh until someone reloads the page. */
export async function broadcastHuntChange(userId: string) {
  try {
    const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
    const channel = supabase.channel(CHANNEL);

    await new Promise<void>((resolve) => {
      const timeout = setTimeout(resolve, 2000);
      channel.subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          channel
            .send({ type: 'broadcast', event: 'hunt-change', payload: { userId } })
            .finally(() => {
              clearTimeout(timeout);
              resolve();
            });
        }
      });
    });

    await supabase.removeChannel(channel);
  } catch {
    // Realtime is a nice-to-have here — never let it break a hunt save.
  }
}
EOF_src_lib_supabase_broadcast_ts_

cat > "src/lib/supabase/channels.ts" << 'EOF_src_lib_supabase_channels_ts_'
export const HUNTS_UPDATES_CHANNEL = 'hunts-updates';
EOF_src_lib_supabase_channels_ts_

npm uninstall next-auth @next-auth/prisma-adapter bcryptjs
npm install @supabase/supabase-js @supabase/ssr
npm prune

git add -A
git commit -m "Migrate auth/storage/realtime to Supabase, add sidebar navigation"
git push -u origin claude/user-auth-character-progress-00b5p6
