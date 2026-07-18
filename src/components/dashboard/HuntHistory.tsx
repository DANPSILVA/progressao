'use client';

import React, { useState } from 'react';
import GlassCard from '@/components/ui/GlassCard';
import { HuntSession } from '@/lib/dashboard';
import HuntForm from './HuntForm';

export default function HuntHistory({ hunts, onChanged }: { hunts: HuntSession[]; onChanged: () => void }) {
  const [editing, setEditing] = useState<HuntSession | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const sorted = [...hunts].sort((a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());

  const handleDelete = async (id: string) => {
    setDeletingId(id);
    await fetch(`/api/hunts/${id}`, { method: 'DELETE' });
    setDeletingId(null);
    onChanged();
  };

  if (editing) {
    return (
      <HuntForm
        hunt={editing}
        onSaved={() => {
          setEditing(null);
          onChanged();
        }}
        onCancel={() => setEditing(null)}
      />
    );
  }

  return (
    <GlassCard title="Histórico de hunts">
      {sorted.length === 0 ? (
        <p className="text-sm text-muted-300">Nenhuma hunt registrada ainda.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-muted-300">
                <th className="py-2 pr-4">Data</th>
                <th className="py-2 pr-4">Duração</th>
                <th className="py-2 pr-4">XP</th>
                <th className="py-2 pr-4">XP/h</th>
                <th className="py-2 pr-4">Profit</th>
                <th className="py-2 pr-4">Loot</th>
                <th className="py-2 pr-4"></th>
              </tr>
            </thead>
            <tbody>
              {sorted.map((h) => {
                const xpPerHour = h.durationMin > 0 ? Math.round(h.xpGained / (h.durationMin / 60)) : 0;
                return (
                  <tr key={h.id} className="border-t border-white/6">
                    <td className="py-2 pr-4">{new Date(h.startedAt).toLocaleString()}</td>
                    <td className="py-2 pr-4">{h.durationMin} min</td>
                    <td className="py-2 pr-4">{h.xpGained.toLocaleString()}</td>
                    <td className="py-2 pr-4 text-accent">{xpPerHour.toLocaleString()}</td>
                    <td className="py-2 pr-4">{h.profit.toLocaleString()} gp</td>
                    <td className="py-2 pr-4">{h.loot.toLocaleString()}</td>
                    <td className="py-2 pr-4 text-right whitespace-nowrap">
                      <button onClick={() => setEditing(h)} className="text-accent mr-3">
                        Editar
                      </button>
                      <button
                        onClick={() => handleDelete(h.id)}
                        disabled={deletingId === h.id}
                        className="text-red-400"
                      >
                        {deletingId === h.id ? 'Excluindo...' : 'Excluir'}
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </GlassCard>
  );
}
