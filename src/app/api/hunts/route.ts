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
