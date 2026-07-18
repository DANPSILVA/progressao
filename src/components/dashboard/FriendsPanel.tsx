'use client';

import React, { useCallback, useEffect, useState } from 'react';
import { UserPlus, Check, X, Trophy } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import { friendRequestSchema } from '@/lib/validation';

type PeerEntry = { friendshipId: string; name: string; level: number | null; vocation: string | null };
type FriendsData = { accepted: PeerEntry[]; incoming: PeerEntry[]; outgoing: PeerEntry[] };
type RankingEntry = { isMe: boolean; name: string; level: number | null; xp: number; xpPerHour: number; profit: number };

export default function FriendsPanel({ period }: { period: '24h' | '7d' | '30d' | '90d' }) {
  const [data, setData] = useState<FriendsData | null>(null);
  const [ranking, setRanking] = useState<RankingEntry[]>([]);
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    const res = await fetch('/api/friends');
    if (res.ok) setData(await res.json());
  }, []);

  const loadRanking = useCallback(async () => {
    const res = await fetch(`/api/friends/ranking?period=${period}`);
    if (res.ok) {
      const body = await res.json();
      setRanking(body.ranking);
    }
  }, [period]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    loadRanking();
  }, [loadRanking]);

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    const parsed = friendRequestSchema.safeParse({ email });
    if (!parsed.success) {
      setError(parsed.error.issues[0]?.message ?? 'Email inválido');
      return;
    }
    setSubmitting(true);
    const res = await fetch('/api/friends', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    });
    setSubmitting(false);
    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      setError(body.error ?? 'Não foi possível enviar o pedido');
      return;
    }
    setEmail('');
    load();
  };

  const handleAccept = async (friendshipId: string) => {
    await fetch(`/api/friends/${friendshipId}/accept`, { method: 'POST' });
    load();
    loadRanking();
  };

  const handleRemove = async (friendshipId: string) => {
    await fetch(`/api/friends/${friendshipId}`, { method: 'DELETE' });
    load();
    loadRanking();
  };

  return (
    <div className="space-y-6">
      <GlassCard title="Adicionar amigo">
        <form onSubmit={handleAdd} className="flex items-end gap-3 flex-wrap">
          <div className="flex-1 min-w-[220px]">
            <label className="label-tibia">Email do amigo</label>
            <input
              type="email"
              className="input-tibia"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="amigo@exemplo.com"
            />
          </div>
          <button type="submit" disabled={submitting} className="btn-tibia btn-tibia--primary">
            <UserPlus className="w-4 h-4" />
            {submitting ? 'Enviando...' : 'Enviar pedido'}
          </button>
        </form>
        {error && <p className="text-sm text-red-400 mt-2">{error}</p>}
      </GlassCard>

      {data && data.incoming.length > 0 && (
        <GlassCard title="Pedidos recebidos">
          <ul className="space-y-2">
            {data.incoming.map((p) => (
              <li key={p.friendshipId} className="flex items-center justify-between text-sm">
                <span>
                  {p.name} {p.level && <span className="text-muted-300">(level {p.level})</span>}
                </span>
                <div className="flex gap-2">
                  <button onClick={() => handleAccept(p.friendshipId)} className="btn-tibia text-xs" aria-label="Aceitar">
                    <Check className="w-3.5 h-3.5" style={{ color: 'var(--series-2)' }} />
                  </button>
                  <button onClick={() => handleRemove(p.friendshipId)} className="btn-tibia text-xs" aria-label="Recusar">
                    <X className="w-3.5 h-3.5" style={{ color: 'var(--series-8)' }} />
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </GlassCard>
      )}

      {data && data.outgoing.length > 0 && (
        <GlassCard title="Pedidos enviados (aguardando)">
          <ul className="space-y-2">
            {data.outgoing.map((p) => (
              <li key={p.friendshipId} className="flex items-center justify-between text-sm">
                <span className="text-muted-300">{p.name}</span>
                <button onClick={() => handleRemove(p.friendshipId)} className="btn-tibia text-xs">
                  Cancelar
                </button>
              </li>
            ))}
          </ul>
        </GlassCard>
      )}

      <GlassCard title={`Ranking (${period})`}>
        {ranking.length <= 1 ? (
          <p className="text-sm text-muted-300">
            Adicione amigos acima para comparar XP, lucro e level no período selecionado.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-muted-300">
                  <th className="py-2 pr-4">#</th>
                  <th className="py-2 pr-4">Personagem</th>
                  <th className="py-2 pr-4">Level</th>
                  <th className="py-2 pr-4">XP</th>
                  <th className="py-2 pr-4">XP/h</th>
                  <th className="py-2 pr-4">Profit</th>
                </tr>
              </thead>
              <tbody>
                {ranking.map((r, i) => (
                  <tr key={r.name + i} className={`border-t border-white/6 ${r.isMe ? 'text-accent font-semibold' : ''}`}>
                    <td className="py-2 pr-4">
                      {i === 0 ? <Trophy className="w-4 h-4 inline" style={{ color: 'var(--series-4)' }} /> : i + 1}
                    </td>
                    <td className="py-2 pr-4">
                      {r.name} {r.isMe && <span className="text-xs text-muted-300">(você)</span>}
                    </td>
                    <td className="py-2 pr-4">{r.level ?? '—'}</td>
                    <td className="py-2 pr-4">{r.xp.toLocaleString()}</td>
                    <td className="py-2 pr-4">{r.xpPerHour.toLocaleString()}</td>
                    <td className="py-2 pr-4">{r.profit.toLocaleString()} gp</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </GlassCard>

      {data && data.accepted.length > 0 && (
        <GlassCard title="Seus amigos">
          <ul className="space-y-2">
            {data.accepted.map((p) => (
              <li key={p.friendshipId} className="flex items-center justify-between text-sm">
                <span>
                  {p.name} {p.level && <span className="text-muted-300">(level {p.level})</span>}
                </span>
                <button onClick={() => handleRemove(p.friendshipId)} className="text-red-400 text-xs">
                  Desfazer amizade
                </button>
              </li>
            ))}
          </ul>
        </GlassCard>
      )}
    </div>
  );
}
