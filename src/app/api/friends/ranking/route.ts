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
