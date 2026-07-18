#!/bin/bash
set -e
mkdir -p prisma/migrations/20260718152837_init
mkdir -p "src/app/api/auth/[...nextauth]"
mkdir -p src/app/api/character
mkdir -p "src/app/api/hunts/[id]"
mkdir -p src/app/api/register
mkdir -p src/app/login src/app/register
mkdir -p src/components/auth src/components/dashboard src/components/providers src/lib
rm -f src/lib/dashboardMock.ts

cat > ".env.example" << 'EOF__env_example_'
# Postgres connection string (Vercel Postgres, Neon or Supabase all work — just copy their connection string here)
DATABASE_URL="postgresql://user:password@host:5432/dbname?sslmode=require"

# NextAuth
# Generate with: openssl rand -base64 32
NEXTAUTH_SECRET="replace-with-a-random-secret"
NEXTAUTH_URL="http://localhost:3000"
EOF__env_example_

cat > ".gitignore" << 'EOF__gitignore_'
# dependencies
/node_modules

# next.js
/.next/
/out/

# production
/build

# env files
.env
.env*.local

# misc
.DS_Store
*.pem
npm-debug.log*

# typescript
*.tsbuildinfo
next-env.d.ts
EOF__gitignore_

cat > "README.md" << 'EOF_README_md_'
# RubinTracker

Acompanhamento de progresso de personagem (XP, level, tempo de hunt e loot/profit), com cadastro/login de usuário. Cada usuário só vê e edita o próprio progresso.

## Stack

- Next.js 14 (App Router) + Tailwind
- NextAuth.js (Credentials provider, sessão JWT)
- Prisma + PostgreSQL (compatível com Neon, Vercel Postgres ou Supabase — basta apontar a `DATABASE_URL`)

## Configuração local

1. Instale as dependências:

   ```bash
   npm install
   ```

2. Copie `.env.example` para `.env` e preencha:

   ```bash
   cp .env.example .env
   ```

   - `DATABASE_URL`: string de conexão Postgres (Neon, Vercel Postgres ou Supabase).
   - `NEXTAUTH_SECRET`: gere com `openssl rand -base64 32`.
   - `NEXTAUTH_URL`: `http://localhost:3000` em desenvolvimento.

3. Rode as migrations do Prisma:

   ```bash
   npm run db:migrate
   ```

4. Suba o servidor:

   ```bash
   npm run dev
   ```

## Funcionamento

- `/register` e `/login`: cadastro e autenticação por email/senha (NextAuth Credentials + bcrypt).
- `/dashboard`: protegido por middleware — redireciona para `/login` se não autenticado.
- Cada usuário tem um `Character` (nome, vocação, level) e uma lista de `HuntSession` (data, duração, XP, profit, waste, loot, bosses, deaths), sempre filtrados pelo `userId` da sessão.
- O XP/h é sempre calculado automaticamente (XP total ÷ horas de hunt), nunca inserido manualmente.

## Scripts úteis

- `npm run db:migrate` — cria/aplica migrations em desenvolvimento.
- `npm run db:deploy` — aplica migrations em produção.
- `npm run db:studio` — abre o Prisma Studio para inspecionar o banco.
EOF_README_md_

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
    "@next-auth/prisma-adapter": "^1.0.7",
    "@prisma/client": "^5.22.0",
    "bcryptjs": "^3.0.3",
    "framer-motion": "^11.3.19",
    "lucide-react": "^0.400.0",
    "next": "14.2.15",
    "next-auth": "^4.24.14",
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

cat > "prisma/migrations/20260718152837_init/migration.sql" << 'EOF_prisma_migrations_20260718152837_init_migration_sql_'
-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "name" TEXT,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Character" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "vocation" TEXT,
    "level" INTEGER NOT NULL DEFAULT 8,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Character_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "HuntSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL,
    "durationMin" INTEGER NOT NULL,
    "xpGained" INTEGER NOT NULL,
    "profit" INTEGER NOT NULL DEFAULT 0,
    "waste" INTEGER NOT NULL DEFAULT 0,
    "loot" INTEGER NOT NULL DEFAULT 0,
    "bosses" INTEGER NOT NULL DEFAULT 0,
    "deaths" INTEGER NOT NULL DEFAULT 0,
    "levelAfter" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "HuntSession_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Character_userId_key" ON "Character"("userId");

-- CreateIndex
CREATE INDEX "HuntSession_userId_startedAt_idx" ON "HuntSession"("userId", "startedAt");

-- AddForeignKey
ALTER TABLE "Character" ADD CONSTRAINT "Character_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "HuntSession" ADD CONSTRAINT "HuntSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EOF_prisma_migrations_20260718152837_init_migration_sql_

cat > "prisma/migrations/migration_lock.toml" << 'EOF_prisma_migrations_migration_lock_toml_'
# Please do not edit this file manually
# It should be added in your version-control system (i.e. Git)
provider = "postgresql"
EOF_prisma_migrations_migration_lock_toml_

cat > "prisma/schema.prisma" << 'EOF_prisma_schema_prisma_'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String   @id @default(cuid())
  name         String?
  email        String   @unique
  passwordHash String
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  character    Character?
  huntSessions HuntSession[]
}

model Character {
  id        String   @id @default(cuid())
  userId    String   @unique
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  name      String
  vocation  String?
  level     Int      @default(8)
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
EOF_prisma_schema_prisma_

cat > "src/app/api/auth/[...nextauth]/route.ts" << 'EOF_src_app_api_auth_____nextauth__route_ts_'
import NextAuth from 'next-auth';
import { authOptions } from '@/lib/auth';

const handler = NextAuth(authOptions);

export { handler as GET, handler as POST };
EOF_src_app_api_auth_____nextauth__route_ts_

cat > "src/app/api/character/route.ts" << 'EOF_src_app_api_character_route_ts_'
import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';
import { characterSchema } from '@/lib/validation';

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

  const character = await prisma.character.findUnique({ where: { userId } });
  return NextResponse.json(character);
}

export async function PUT(req: Request) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

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

cat > "src/app/api/hunts/[id]/route.ts" << 'EOF_src_app_api_hunts__id__route_ts_'
import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';
import { huntSessionSchema } from '@/lib/validation';

async function requireOwnedHunt(id: string, userId: string) {
  const hunt = await prisma.huntSession.findUnique({ where: { id } });
  if (!hunt || hunt.userId !== userId) return null;
  return hunt;
}

export async function PUT(req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

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

  return NextResponse.json(hunt);
}

export async function DELETE(_req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

  const existing = await requireOwnedHunt(params.id, userId);
  if (!existing) {
    return NextResponse.json({ error: 'Registro não encontrado' }, { status: 404 });
  }

  await prisma.huntSession.delete({ where: { id: params.id } });

  return NextResponse.json({ ok: true });
}
EOF_src_app_api_hunts__id__route_ts_

cat > "src/app/api/hunts/route.ts" << 'EOF_src_app_api_hunts_route_ts_'
import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';
import { huntSessionSchema } from '@/lib/validation';

export async function GET(req: Request) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

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
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

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

  return NextResponse.json(hunt, { status: 201 });
}
EOF_src_app_api_hunts_route_ts_

cat > "src/app/api/register/route.ts" << 'EOF_src_app_api_register_route_ts_'
import { NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { prisma } from '@/lib/prisma';
import { registerSchema } from '@/lib/validation';

export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  const parsed = registerSchema.safeParse(body);

  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.issues[0]?.message ?? 'Dados inválidos' }, { status: 400 });
  }

  const { name, characterName, email, password } = parsed.data;
  const normalizedEmail = email.toLowerCase();

  const existing = await prisma.user.findUnique({ where: { email: normalizedEmail } });
  if (existing) {
    return NextResponse.json({ error: 'Este email já está cadastrado' }, { status: 409 });
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const user = await prisma.user.create({
    data: {
      name,
      email: normalizedEmail,
      passwordHash,
      character: {
        create: {
          name: characterName,
          level: 8,
        },
      },
    },
  });

  return NextResponse.json({ id: user.id, email: user.email }, { status: 201 });
}
EOF_src_app_api_register_route_ts_

cat > "src/app/dashboard/page.tsx" << 'EOF_src_app_dashboard_page_tsx_'
import { getServerSession } from 'next-auth';
import { redirect } from 'next/navigation';
import Header from '@/components/Header';
import DashboardShell from '@/components/dashboard/DashboardShell';
import { authOptions } from '@/lib/auth';

export const metadata = {
  title: 'RubinTracker — Dashboard',
  description: 'Visualize seus KPIs e evolução — XP, Profits, Loot, Bosses e demais métricas.'
};

export default async function DashboardPage() {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    redirect('/login');
  }

  return (
    <div>
      <Header />
      <main className="max-w-6xl mx-auto py-10 px-4">
        <h1 className="text-3xl font-semibold mb-6">Dashboard</h1>
        <DashboardShell />
      </main>
    </div>
  );
}
EOF_src_app_dashboard_page_tsx_

cat > "src/app/globals.css" << 'EOF_src_app_globals_css_'
@tailwind base;
@tailwind components;
@tailwind utilities;

@import "../styles/tibia.css";

html, body, #__next {
  height: 100%;
}

body {
  background: var(--bg-900);
  color: var(--text-100);
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

main {
  min-height: 100vh;
}
EOF_src_app_globals_css_

cat > "src/app/layout.tsx" << 'EOF_src_app_layout_tsx_'
import type { Metadata } from 'next';
import './globals.css';
import SessionProviderWrapper from '@/components/providers/SessionProviderWrapper';

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
      <body>
        <SessionProviderWrapper>{children}</SessionProviderWrapper>
      </body>
    </html>
  );
}
EOF_src_app_layout_tsx_

cat > "src/app/login/page.tsx" << 'EOF_src_app_login_page_tsx_'
import Header from '@/components/Header';
import LoginForm from '@/components/auth/LoginForm';

export const metadata = {
  title: 'Entrar — RubinTracker',
};

export default function LoginPage() {
  return (
    <div>
      <Header />
      <main className="max-w-md mx-auto py-16 px-4">
        <LoginForm />
      </main>
    </div>
  );
}
EOF_src_app_login_page_tsx_

cat > "src/app/register/page.tsx" << 'EOF_src_app_register_page_tsx_'
import Header from '@/components/Header';
import RegisterForm from '@/components/auth/RegisterForm';

export const metadata = {
  title: 'Criar conta — RubinTracker',
};

export default function RegisterPage() {
  return (
    <div>
      <Header />
      <main className="max-w-md mx-auto py-16 px-4">
        <RegisterForm />
      </main>
    </div>
  );
}
EOF_src_app_register_page_tsx_

cat > "src/components/Header.tsx" << 'EOF_src_components_Header_tsx_'
'use client';

import Link from 'next/link';
import { useSession, signOut } from 'next-auth/react';
import ThemeToggle from '@/components/ui/ThemeToggle';

export default function Header() {
  const { data: session, status } = useSession();

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
          <Link href="/styleguide" className="text-sm text-muted-300 hover:text-text-100">Styleguide</Link>
          <Link href="/weather" className="text-sm text-muted-300 hover:text-text-100">Weather</Link>
          {status === 'authenticated' ? (
            <>
              <Link href="/dashboard" className="text-sm text-muted-300 hover:text-text-100">Dashboard</Link>
              <span className="text-sm text-muted-300 hidden sm:inline">{session.user?.name ?? session.user?.email}</span>
              <button onClick={() => signOut({ callbackUrl: '/' })} className="btn-tibia text-sm">
                Sair
              </button>
            </>
          ) : status === 'loading' ? null : (
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
EOF_src_components_auth_LoginForm_tsx_

cat > "src/components/auth/RegisterForm.tsx" << 'EOF_src_components_auth_RegisterForm_tsx_'
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
EOF_src_components_auth_RegisterForm_tsx_

cat > "src/components/dashboard/BossesDeaths.tsx" << 'EOF_src_components_dashboard_BossesDeaths_tsx_'
'use client';

import React from 'react';
import GlassCard from '@/components/ui/GlassCard';
import { SummaryMetrics } from '@/lib/dashboard';

export default function BossesDeaths({ summary }: { summary: SummaryMetrics }) {
  return (
    <GlassCard title="Bosses & Deaths">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-sm text-muted-300">Bosses</div>
          <div className="text-lg font-semibold">{summary.bosses}</div>
        </div>
        <div className="text-right">
          <div className="text-sm text-muted-300">Deaths</div>
          <div className="text-lg font-semibold text-danger">{summary.deaths}</div>
        </div>
      </div>
    </GlassCard>
  );
}
EOF_src_components_dashboard_BossesDeaths_tsx_

cat > "src/components/dashboard/CharacterCard.tsx" << 'EOF_src_components_dashboard_CharacterCard_tsx_'
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
EOF_src_components_dashboard_CharacterCard_tsx_

cat > "src/components/dashboard/DashboardShell.tsx" << 'EOF_src_components_dashboard_DashboardShell_tsx_'
'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import GlassCard from '@/components/ui/GlassCard';
import StatsGrid from './StatsGrid';
import Filters from './Filters';
import InteractiveChart from './InteractiveChart';
import LootProfit from './LootProfit';
import BossesDeaths from './BossesDeaths';
import ProgressTarget from './ProgressTarget';
import HuntForm from './HuntForm';
import HuntHistory from './HuntHistory';
import CharacterCard from './CharacterCard';
import { aggregateByDay, computeSummary, filterByPeriod, Character, HuntSession } from '@/lib/dashboard';

export default function DashboardShell() {
  const [period, setPeriod] = useState<'24h' | '7d' | '30d' | '90d'>('7d');
  const [showCumulative, setShowCumulative] = useState(false);
  const [hunts, setHunts] = useState<HuntSession[]>([]);
  const [character, setCharacter] = useState<Character | null>(null);
  const [loading, setLoading] = useState(true);
  const [showAddForm, setShowAddForm] = useState(false);

  const loadData = useCallback(async () => {
    const [huntsRes, characterRes] = await Promise.all([fetch('/api/hunts'), fetch('/api/character')]);
    if (huntsRes.ok) setHunts(await huntsRes.json());
    if (characterRes.ok) setCharacter(await characterRes.json());
    setLoading(false);
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const windowedHunts = useMemo(() => filterByPeriod(hunts, period), [hunts, period]);
  const windowed = useMemo(() => aggregateByDay(windowedHunts), [windowedHunts]);
  const allSeries = useMemo(() => aggregateByDay(hunts), [hunts]);
  const summary = useMemo(() => computeSummary(windowedHunts), [windowedHunts]);

  if (loading) {
    return (
      <GlassCard>
        <p className="text-muted-300">Carregando seu progresso...</p>
      </GlassCard>
    );
  }

  return (
    <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }} className="space-y-6">
      {character && <CharacterCard character={character} onChanged={loadData} />}

      <GlassCard>
        <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
          <div>
            <div className="text-sm text-muted-300">Visão geral</div>
            <div className="text-xl font-semibold">Seu progresso — visão rápida</div>
          </div>
          <div className="flex items-center gap-3">
            <Filters period={period} onChange={setPeriod} showCumulative={showCumulative} setShowCumulative={setShowCumulative} />
            <button onClick={() => setShowAddForm((v) => !v)} className="btn-tibia btn-tibia--primary text-sm">
              {showAddForm ? 'Fechar' : '+ Nova hunt'}
            </button>
          </div>
        </div>

        <StatsGrid summary={summary} />

        <div className="mt-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <GlassCard>
              <InteractiveChart data={windowed} showCumulative={showCumulative} />
            </GlassCard>
          </div>

          <div className="space-y-6">
            <LootProfit summary={summary} />
            <BossesDeaths summary={summary} />
            <ProgressTarget data={allSeries} summary={summary} />
          </div>
        </div>
      </GlassCard>

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
    </motion.div>
  );
}
EOF_src_components_dashboard_DashboardShell_tsx_

cat > "src/components/dashboard/HuntForm.tsx" << 'EOF_src_components_dashboard_HuntForm_tsx_'
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
          waste: hunt.waste,
          loot: hunt.loot,
          bosses: hunt.bosses,
          deaths: hunt.deaths,
          levelAfter: hunt.levelAfter ?? undefined,
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
            <label className="label-tibia">Waste (gp)</label>
            <input type="number" className="input-tibia" {...register('waste')} />
          </div>

          <div>
            <label className="label-tibia">Loot (itens)</label>
            <input type="number" className="input-tibia" {...register('loot')} />
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
EOF_src_components_dashboard_HuntForm_tsx_

cat > "src/components/dashboard/HuntHistory.tsx" << 'EOF_src_components_dashboard_HuntHistory_tsx_'
'use client';

import React, { useState } from 'react';
import GlassCard from '@/components/ui/GlassCard';
import { HuntSession } from '@/lib/dashboard';
import HuntForm from './HuntForm';

export default function HuntHistory({ hunts, onChanged }: { hunts: HuntSession[]; onChanged: () => void }) {
  const [editing, setEditing] = useState<HuntSession | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const sorted = [...hunts].sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());

  const handleDelete = async (id: string) => {
    setDeletingId(id);
    await fetch(`/api/hunts/${id}`, { method: 'DELETE' });
    setDeletingId(null);
    onChanged();
  };

  if (editing) {
    return (
      <HuntForm
        hunt={editing}
        onSaved={() => {
          setEditing(null);
          onChanged();
        }}
        onCancel={() => setEditing(null)}
      />
    );
  }

  return (
    <GlassCard title="Histórico de hunts">
      {sorted.length === 0 ? (
        <p className="text-sm text-muted-300">Nenhuma hunt registrada ainda.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-muted-300">
                <th className="py-2 pr-4">Data</th>
                <th className="py-2 pr-4">Duração</th>
                <th className="py-2 pr-4">XP</th>
                <th className="py-2 pr-4">XP/h</th>
                <th className="py-2 pr-4">Profit</th>
                <th className="py-2 pr-4">Loot</th>
                <th className="py-2 pr-4"></th>
              </tr>
            </thead>
            <tbody>
              {sorted.map((h) => {
                const xpPerHour = h.durationMin > 0 ? Math.round(h.xpGained / (h.durationMin / 60)) : 0;
                return (
                  <tr key={h.id} className="border-t border-white/6">
                    <td className="py-2 pr-4">{new Date(h.startedAt).toLocaleString()}</td>
                    <td className="py-2 pr-4">{h.durationMin} min</td>
                    <td className="py-2 pr-4">{h.xpGained.toLocaleString()}</td>
                    <td className="py-2 pr-4 text-accent">{xpPerHour.toLocaleString()}</td>
                    <td className="py-2 pr-4">{h.profit.toLocaleString()} gp</td>
                    <td className="py-2 pr-4">{h.loot.toLocaleString()}</td>
                    <td className="py-2 pr-4 text-right whitespace-nowrap">
                      <button onClick={() => setEditing(h)} className="text-accent mr-3">
                        Editar
                      </button>
                      <button
                        onClick={() => handleDelete(h.id)}
                        disabled={deletingId === h.id}
                        className="text-red-400"
                      >
                        {deletingId === h.id ? 'Excluindo...' : 'Excluir'}
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </GlassCard>
  );
}
EOF_src_components_dashboard_HuntHistory_tsx_

cat > "src/components/dashboard/InteractiveChart.tsx" << 'EOF_src_components_dashboard_InteractiveChart_tsx_'
'use client';

import React from 'react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, AreaChart, Area, CartesianGrid, Bar, BarChart } from 'recharts';
import { HourlyPointFull } from '@/lib/dashboard';

export default function InteractiveChart({ data, showCumulative }: { data: HourlyPointFull[]; showCumulative: boolean }) {
  // map to chart-friendly
  const mapped = data.map((d) => ({ timeLabel: new Date(d.time).toLocaleDateString(), xp: d.xp, profit: d.profit }));

  const cumulative = mapped.reduce<{ timeLabel: string; xp: number; profit: number }[]>((acc, cur, i) => {
    const prev = acc[i - 1];
    acc.push({ timeLabel: cur.timeLabel, xp: cur.xp + (prev ? prev.xp : 0), profit: cur.profit + (prev ? prev.profit : 0) });
    return acc;
  }, []);

  const source = showCumulative ? cumulative : mapped;

  return (
    <div style={{ width: '100%', height: 360 }}>
      <ResponsiveContainer>
        <AreaChart data={source} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="g1" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="var(--accent)" stopOpacity={0.18} />
              <stop offset="100%" stopColor="var(--accent)" stopOpacity={0.02} />
            </linearGradient>
          </defs>
          <XAxis dataKey="timeLabel" tick={{ fill: 'var(--muted-300)' }} />
          <YAxis yAxisId="left" tick={{ fill: 'var(--muted-300)' }} />
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.02)" />
          <Tooltip formatter={(value: any) => value.toLocaleString?.() ?? value} />
          <Area yAxisId="left" type="monotone" dataKey="xp" stroke="var(--accent)" fill="url(#g1)" strokeWidth={2} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
EOF_src_components_dashboard_InteractiveChart_tsx_

cat > "src/components/dashboard/LootProfit.tsx" << 'EOF_src_components_dashboard_LootProfit_tsx_'
'use client';

import React from 'react';
import { SummaryMetrics } from '@/lib/dashboard';
import GlassCard from '@/components/ui/GlassCard';

export default function LootProfit({ summary }: { summary: SummaryMetrics }) {
  return (
    <GlassCard title="Loot & Profit">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-sm text-muted-300">Loot total</div>
          <div className="text-lg font-semibold">{summary.loot.toLocaleString()}</div>
        </div>
        <div className="text-right">
          <div className="text-sm text-muted-300">Profit</div>
          <div className="text-lg font-semibold">{summary.profit.toLocaleString()} gp</div>
        </div>
      </div>
    </GlassCard>
  );
}
EOF_src_components_dashboard_LootProfit_tsx_

cat > "src/components/dashboard/ProgressTarget.tsx" << 'EOF_src_components_dashboard_ProgressTarget_tsx_'
'use client';

import React, { useMemo } from 'react';
import GlassCard from '@/components/ui/GlassCard';
import { HourlyPointFull, SummaryMetrics } from '@/lib/dashboard';

export default function ProgressTarget({ data, summary }: { data: HourlyPointFull[]; summary: SummaryMetrics }) {
  // simplistic: assume next level requires fixed XP (e.g., 200k), compute remaining
  const nextLevelXP = 200000;
  const remaining = Math.max(0, nextLevelXP - summary.xp);
  const hoursNeeded = Math.ceil(remaining / Math.max(1, Math.round(summary.xpPerHour)));

  return (
    <GlassCard title="Meta de Level">
      <div className="space-y-3">
        <div>
          <div className="text-sm text-muted-300">Próximo level</div>
          <div className="text-xl font-semibold">{nextLevelXP.toLocaleString()} XP</div>
        </div>

        <div className="flex items-center justify-between">
          <div className="text-sm text-muted-300">Faltam</div>
          <div className="text-lg font-semibold">{remaining.toLocaleString()} XP</div>
        </div>

        <div className="flex items-center justify-between">
          <div className="text-sm text-muted-300">Estimativa</div>
          <div className="text-lg font-semibold">{hoursNeeded} horas</div>
        </div>
      </div>
    </GlassCard>
  );
}
EOF_src_components_dashboard_ProgressTarget_tsx_

cat > "src/components/dashboard/StatsGrid.tsx" << 'EOF_src_components_dashboard_StatsGrid_tsx_'
'use client';

import React from 'react';
import StatCard from './StatCard';
import { SummaryMetrics } from '@/lib/dashboard';

export default function StatsGrid({ summary }: { summary: SummaryMetrics }) {
  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-4">
      <StatCard title="XP" value={summary.xp} subtitle="Total" accent />
      <StatCard title="XP/H" value={Math.round(summary.xpPerHour)} subtitle="Média" />
      <StatCard title="Profit" value={summary.profit} subtitle="Gold" />
      <StatCard title="Waste" value={summary.waste} subtitle="Despesas" />
      <StatCard title="Loot" value={summary.loot} subtitle="Itens" />
      <StatCard title="Bosses" value={summary.bosses} subtitle="Derrotados" />
    </div>
  );
}
EOF_src_components_dashboard_StatsGrid_tsx_

cat > "src/components/providers/SessionProviderWrapper.tsx" << 'EOF_src_components_providers_SessionProviderWrapper_tsx_'
'use client';

import { SessionProvider } from 'next-auth/react';
import React from 'react';

export default function SessionProviderWrapper({ children }: { children: React.ReactNode }) {
  return <SessionProvider>{children}</SessionProvider>;
}
EOF_src_components_providers_SessionProviderWrapper_tsx_

cat > "src/lib/auth.ts" << 'EOF_src_lib_auth_ts_'
import { PrismaAdapter } from '@next-auth/prisma-adapter';
import { type NextAuthOptions } from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';
import bcrypt from 'bcryptjs';
import { prisma } from '@/lib/prisma';

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  session: { strategy: 'jwt' },
  pages: {
    signIn: '/login',
  },
  providers: [
    CredentialsProvider({
      name: 'Credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Senha', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null;

        const user = await prisma.user.findUnique({
          where: { email: credentials.email.toLowerCase() },
        });
        if (!user) return null;

        const valid = await bcrypt.compare(credentials.password, user.passwordHash);
        if (!valid) return null;

        return { id: user.id, name: user.name, email: user.email };
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) token.id = user.id;
      return token;
    },
    async session({ session, token }) {
      if (session.user) (session.user as { id?: string }).id = token.id as string;
      return session;
    },
  },
  secret: process.env.NEXTAUTH_SECRET,
};
EOF_src_lib_auth_ts_

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

cat > "src/lib/prisma.ts" << 'EOF_src_lib_prisma_ts_'
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
EOF_src_lib_prisma_ts_

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
});
EOF_src_lib_validation_ts_

cat > "src/middleware.ts" << 'EOF_src_middleware_ts_'
import { withAuth } from 'next-auth/middleware';

export default withAuth({
  pages: {
    signIn: '/login',
  },
});

export const config = {
  matcher: ['/dashboard/:path*'],
};
EOF_src_middleware_ts_

cat > "src/styles/tibia.css" << 'EOF_src_styles_tibia_css_'
/* Tibia-inspired theme utilities and tokens */
:root{
  --bg-900:#081014;
  --bg-800:#0b1a1a;
  --glass: rgba(255,255,255,0.03);
  --accent: #9bd66b;
  --accent-2: #ffcf6b;
  --neon: #00E0FF;
  --muted-300: #9aa6a6;
  --text-100:#E6F3FF;
  --radius-md: 12px;
  --card-shadow: 0 10px 30px rgba(2,6,23,0.55);
}

/* Glassmorphism base */
.theme-glass {
  background: linear-gradient(180deg, rgba(255,255,255,0.02), rgba(0,0,0,0.02));
  border: 1px solid rgba(255,255,255,0.04);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  box-shadow: var(--card-shadow);
  border-radius: var(--radius-md);
}

/* Tibia-like panel trim (wood-ish) */
.panel-trim {
  background-image: linear-gradient(180deg, rgba(0,0,0,0.12), rgba(255,255,255,0.02));
  border: 1px solid rgba(0,0,0,0.6);
}

/* Soft glow accent */
.glow-accent {
  box-shadow: 0 6px 20px rgba(155,214,107,0.06), inset 0 -2px 10px rgba(0,0,0,0.25);
}

/* Buttons */
.btn-tibia{
  display:inline-flex;align-items:center;gap:8px;padding:8px 12px;border-radius:10px;border:1px solid rgba(255,255,255,0.04);background:linear-gradient(180deg, rgba(255,255,255,0.02), rgba(0,0,0,0.02));color:var(--text-100);font-weight:600;box-shadow:0 6px 18px rgba(2,6,23,0.6);
}
.btn-tibia--primary{background:linear-gradient(180deg,var(--accent), #7bb14f);color:#09210a;border:1px solid rgba(0,0,0,0.4)}
.btn-tibia:disabled{opacity:0.5;cursor:not-allowed}

/* Form inputs */
.input-tibia{
  width:100%;padding:8px 12px;border-radius:10px;border:1px solid rgba(255,255,255,0.08);
  background:rgba(0,0,0,0.2);color:var(--text-100);outline:none;
}
.input-tibia:focus{border-color:var(--accent)}
.label-tibia{display:block;font-size:0.8rem;color:var(--muted-300);margin-bottom:4px}

/* Logo wrapper */
.logo-mark{display:inline-flex;align-items:center;gap:10px}
.logo-mark svg{filter: drop-shadow(0 6px 20px rgba(0,0,0,0.5))}

/* reduced motion */
@media (prefers-reduced-motion: reduce){
  * { animation-duration: 0.001ms !important; transition-duration: 0.001ms !important; }
}
EOF_src_styles_tibia_css_

git add -A
git commit -m "Add user auth and persist character progress to Postgres"
git push -u origin claude/user-auth-character-progress-00b5p6
