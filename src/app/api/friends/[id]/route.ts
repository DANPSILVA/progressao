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
