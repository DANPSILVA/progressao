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
