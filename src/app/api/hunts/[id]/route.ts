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
