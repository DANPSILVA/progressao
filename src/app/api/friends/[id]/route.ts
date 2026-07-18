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
