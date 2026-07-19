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
