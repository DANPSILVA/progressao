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
