#!/bin/bash
set -e
mkdir -p "src/app/api/friends/[id]/accept"
mkdir -p src/app/api/friends/ranking
mkdir -p prisma/migrations/20260718200559_add_friendships

cat > "prisma/migrations/20260718200559_add_friendships/migration.sql" << 'EOF_prisma_migrations_20260718200559_add_friendships_migration_sql_'
-- CreateEnum
CREATE TYPE "FriendshipStatus" AS ENUM ('PENDING', 'ACCEPTED');

-- CreateTable
CREATE TABLE "Friendship" (
    "id" TEXT NOT NULL,
    "fromUserId" TEXT NOT NULL,
    "toUserId" TEXT NOT NULL,
    "status" "FriendshipStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Friendship_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Friendship_fromUserId_toUserId_key" ON "Friendship"("fromUserId", "toUserId");

-- AddForeignKey
ALTER TABLE "Friendship" ADD CONSTRAINT "Friendship_fromUserId_fkey" FOREIGN KEY ("fromUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Friendship" ADD CONSTRAINT "Friendship_toUserId_fkey" FOREIGN KEY ("toUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EOF_prisma_migrations_20260718200559_add_friendships_migration_sql_

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

cat > "src/app/api/friends/[id]/accept/route.ts" << 'EOF_src_app_api_friends__id__accept_route_ts_'
import { NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';

export async function POST(_req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

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
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';

export async function DELETE(_req: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

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
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
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
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    return NextResponse.json({ error: 'Não autenticado' }, { status: 401 });
  }
  const userId = (session.user as { id: string }).id;

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
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/prisma';
import { friendRequestSchema } from '@/lib/validation';

async function currentUserId() {
  const session = await getServerSession(authOptions);
  if (!session?.user) return null;
  return (session.user as { id: string }).id;
}

function toPeerSummary(character: { name: string; level: number; vocation: string | null } | null) {
  return {
    name: character?.name ?? 'Sem personagem',
    level: character?.level ?? null,
    vocation: character?.vocation ?? null,
  };
}

export async function GET() {
  const userId = await currentUserId();
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
  const userId = await currentUserId();
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

cat > "src/components/dashboard/DashboardShell.tsx" << 'EOF_src_components_dashboard_DashboardShell_tsx_'
'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { RefreshCw } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import Tabs from '@/components/ui/Tabs';
import StatsGrid from './StatsGrid';
import Filters from './Filters';
import PeriodFilter from './PeriodFilter';
import InteractiveChart from './InteractiveChart';
import EconomyDonut from './EconomyDonut';
import BossesDeaths from './BossesDeaths';
import ProgressTarget from './ProgressTarget';
import HuntForm from './HuntForm';
import HuntHistory from './HuntHistory';
import CharacterCard from './CharacterCard';
import XpEvolutionChart from './XpEvolutionChart';
import ProfitPerDayChart from './ProfitPerDayChart';
import XpPerHourSessionChart from './XpPerHourSessionChart';
import FriendsPanel from './FriendsPanel';
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
        <button onClick={() => setShowAddForm((v) => !v)} className="btn-tibia btn-tibia--primary text-sm">
          {showAddForm ? 'Fechar' : '+ Nova hunt'}
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
          <EconomyDonut summary={summary} />
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

  return (
    <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }} className="space-y-6">
      {character && <CharacterCard character={character} onChanged={loadData} />}

      <Tabs
        tabs={[
          { key: 'overview', label: 'Visão Geral', content: <GlassCard>{overviewTab}</GlassCard> },
          { key: 'history', label: 'Histórico de Hunts', content: historyTab },
          { key: 'stats', label: 'Estatísticas', content: statsTab },
          { key: 'friends', label: 'Amigos', content: friendsTab },
        ]}
      />
    </motion.div>
  );
}
EOF_src_components_dashboard_DashboardShell_tsx_

cat > "src/components/dashboard/Filters.tsx" << 'EOF_src_components_dashboard_Filters_tsx_'
'use client';

import React from 'react';
import PeriodFilter from './PeriodFilter';

export default function Filters({ period, onChange, showCumulative, setShowCumulative }: { period: '24h' | '7d' | '30d' | '90d'; onChange: (p: '24h' | '7d' | '30d' | '90d') => void; showCumulative: boolean; setShowCumulative: (v: boolean) => void }) {
  return (
    <div className="flex items-center gap-3">
      <PeriodFilter period={period} onChange={onChange} />

      <label className="inline-flex items-center gap-2 text-sm text-muted-300">
        <input type="checkbox" checked={showCumulative} onChange={(e) => setShowCumulative(e.target.checked)} className="rounded" />
        Cumulativo
      </label>
    </div>
  );
}
EOF_src_components_dashboard_Filters_tsx_

cat > "src/components/dashboard/FriendsPanel.tsx" << 'EOF_src_components_dashboard_FriendsPanel_tsx_'
'use client';

import React, { useCallback, useEffect, useState } from 'react';
import { UserPlus, Check, X, Trophy } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import { friendRequestSchema } from '@/lib/validation';

type PeerEntry = { friendshipId: string; name: string; level: number | null; vocation: string | null };
type FriendsData = { accepted: PeerEntry[]; incoming: PeerEntry[]; outgoing: PeerEntry[] };
type RankingEntry = { isMe: boolean; name: string; level: number | null; xp: number; xpPerHour: number; profit: number };

export default function FriendsPanel({ period }: { period: '24h' | '7d' | '30d' | '90d' }) {
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

cat > "src/components/dashboard/PeriodFilter.tsx" << 'EOF_src_components_dashboard_PeriodFilter_tsx_'
'use client';

import React from 'react';

export default function PeriodFilter({
  period,
  onChange,
}: {
  period: '24h' | '7d' | '30d' | '90d';
  onChange: (p: '24h' | '7d' | '30d' | '90d') => void;
}) {
  return (
    <div className="flex gap-2 rounded-md bg-[rgba(255,255,255,0.02)] p-1">
      {(['24h', '7d', '30d', '90d'] as const).map((p) => (
        <button key={p} onClick={() => onChange(p)} className={`px-3 py-1 rounded-md text-sm ${period === p ? 'bg-accent text-black' : 'text-muted-300'}`}>
          {p}
        </button>
      ))}
    </div>
  );
}
EOF_src_components_dashboard_PeriodFilter_tsx_

cat > "src/components/dashboard/ProfitPerDayChart.tsx" << 'EOF_src_components_dashboard_ProfitPerDayChart_tsx_'
'use client';

import React, { useMemo } from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import GlassCard from '@/components/ui/GlassCard';
import { HourlyPointFull } from '@/lib/dashboard';

export default function ProfitPerDayChart({ data }: { data: HourlyPointFull[] }) {
  const mapped = useMemo(
    () =>
      [...data]
        .sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime())
        .map((d) => ({ label: new Date(d.time).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }), profit: d.profit })),
    [data]
  );

  return (
    <GlassCard title="Lucro por dia">
      {mapped.length === 0 ? (
        <p className="text-sm text-muted-300">Sem dados no período selecionado.</p>
      ) : (
        <div style={{ width: '100%', height: 280 }}>
          <ResponsiveContainer>
            <BarChart data={mapped} margin={{ top: 10, right: 20, left: 8, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="label" tick={{ fill: 'var(--muted-300)' }} />
              <YAxis
                tick={{ fill: 'var(--muted-300)' }}
                width={56}
                tickFormatter={(v: number) => Intl.NumberFormat('pt-BR', { notation: 'compact' }).format(v)}
              />
              <Tooltip
                formatter={(value: number) => [value.toLocaleString() + ' gp', 'Profit']}
                contentStyle={{ background: 'var(--bg-800)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8 }}
                cursor={{ fill: 'rgba(255,255,255,0.03)' }}
              />
              <Bar dataKey="profit" fill="var(--series-3)" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </GlassCard>
  );
}
EOF_src_components_dashboard_ProfitPerDayChart_tsx_

cat > "src/components/dashboard/XpEvolutionChart.tsx" << 'EOF_src_components_dashboard_XpEvolutionChart_tsx_'
'use client';

import React, { useMemo } from 'react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import GlassCard from '@/components/ui/GlassCard';
import { HourlyPointFull } from '@/lib/dashboard';

export default function XpEvolutionChart({ data }: { data: HourlyPointFull[] }) {
  const cumulative = useMemo(() => {
    const sorted = [...data].sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime());
    let running = 0;
    return sorted.map((d) => {
      running += d.xp;
      return { label: new Date(d.time).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }), xp: running };
    });
  }, [data]);

  return (
    <GlassCard title="Evolução de XP acumulado">
      {cumulative.length === 0 ? (
        <p className="text-sm text-muted-300">Sem dados no período selecionado.</p>
      ) : (
        <div style={{ width: '100%', height: 280 }}>
          <ResponsiveContainer>
            <AreaChart data={cumulative} margin={{ top: 10, right: 20, left: 8, bottom: 0 }}>
              <defs>
                <linearGradient id="xpEvoGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="var(--series-1)" stopOpacity={0.3} />
                  <stop offset="100%" stopColor="var(--series-1)" stopOpacity={0.02} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="label" tick={{ fill: 'var(--muted-300)' }} />
              <YAxis
                tick={{ fill: 'var(--muted-300)' }}
                width={56}
                tickFormatter={(v: number) => Intl.NumberFormat('pt-BR', { notation: 'compact' }).format(v)}
              />
              <Tooltip
                formatter={(value: number) => [value.toLocaleString(), 'XP acumulado']}
                contentStyle={{ background: 'var(--bg-800)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8 }}
              />
              <Area type="monotone" dataKey="xp" stroke="var(--series-1)" fill="url(#xpEvoGrad)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}
    </GlassCard>
  );
}
EOF_src_components_dashboard_XpEvolutionChart_tsx_

cat > "src/components/dashboard/XpPerHourSessionChart.tsx" << 'EOF_src_components_dashboard_XpPerHourSessionChart_tsx_'
'use client';

import React from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import GlassCard from '@/components/ui/GlassCard';
import { SessionPoint } from '@/lib/dashboard';

export default function XpPerHourSessionChart({ data }: { data: SessionPoint[] }) {
  return (
    <GlassCard title="XP/h por sessão de hunt">
      {data.length === 0 ? (
        <p className="text-sm text-muted-300">Sem hunts registradas no período selecionado.</p>
      ) : (
        <div style={{ width: '100%', height: 280 }}>
          <ResponsiveContainer>
            <BarChart data={data} margin={{ top: 10, right: 20, left: 8, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="label" tick={{ fill: 'var(--muted-300)' }} />
              <YAxis
                tick={{ fill: 'var(--muted-300)' }}
                width={56}
                tickFormatter={(v: number) => Intl.NumberFormat('pt-BR', { notation: 'compact' }).format(v)}
              />
              <Tooltip
                formatter={(value: number) => [value.toLocaleString(), 'XP/h']}
                contentStyle={{ background: 'var(--bg-800)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8 }}
                cursor={{ fill: 'rgba(255,255,255,0.03)' }}
              />
              <Bar dataKey="xpPerHour" fill="var(--series-2)" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}
    </GlassCard>
  );
}
EOF_src_components_dashboard_XpPerHourSessionChart_tsx_

cat > "src/components/ui/Tabs.tsx" << 'EOF_src_components_ui_Tabs_tsx_'
'use client';

import React, { useState } from 'react';

export type TabItem = {
  key: string;
  label: string;
  content: React.ReactNode;
};

export default function Tabs({ tabs, defaultTab }: { tabs: TabItem[]; defaultTab?: string }) {
  const [active, setActive] = useState(defaultTab ?? tabs[0]?.key);

  return (
    <div>
      <div role="tablist" className="flex gap-1 rounded-md bg-[rgba(255,255,255,0.02)] p-1 mb-6 w-fit">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            role="tab"
            aria-selected={active === tab.key}
            onClick={() => setActive(tab.key)}
            className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors ${
              active === tab.key ? 'bg-accent text-black' : 'text-muted-300 hover:text-[var(--text-100)]'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {tabs.map((tab) => (
        <div key={tab.key} role="tabpanel" hidden={active !== tab.key}>
          {active === tab.key && tab.content}
        </div>
      ))}
    </div>
  );
}
EOF_src_components_ui_Tabs_tsx_

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
});

export const friendRequestSchema = z.object({
  email: z.string().email('Email inválido'),
});
EOF_src_lib_validation_ts_

git add -A
git commit -m "Add dashboard tabs, more charts, and friend-based ranking"
git push -u origin claude/user-auth-character-progress-00b5p6
