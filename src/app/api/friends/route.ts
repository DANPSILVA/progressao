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
