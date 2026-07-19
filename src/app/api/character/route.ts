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
