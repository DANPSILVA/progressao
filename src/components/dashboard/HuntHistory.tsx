'use client';

import React, { useState } from 'react';
import { ChevronDown, ChevronRight } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';
import { HuntSession } from '@/lib/dashboard';
import HuntForm from './HuntForm';

export default function HuntHistory({ hunts, onChanged }: { hunts: HuntSession[]; onChanged: () => void }) {
  const [editing, setEditing] = useState<HuntSession | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

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
                <th className="py-2 pr-4"></th>
                <th className="py-2 pr-4">Data</th>
                <th className="py-2 pr-4">Duração</th>
                <th className="py-2 pr-4">XP</th>
                <th className="py-2 pr-4">XP/h</th>
                <th className="py-2 pr-4">Profit</th>
                <th className="py-2 pr-4">Dano recebido</th>
                <th className="py-2 pr-4"></th>
              </tr>
            </thead>
            <tbody>
              {sorted.map((h) => {
                const xpPerHour = h.durationMin > 0 ? Math.round(h.xpGained / (h.durationMin / 60)) : 0;
                const hasDamageDetail = h.damageReceived !== null;
                const isExpanded = expandedId === h.id;
                return (
                  <React.Fragment key={h.id}>
                    <tr className="border-t border-white/6">
                      <td className="py-2 pr-2">
                        {hasDamageDetail && (
                          <button
                            onClick={() => setExpandedId(isExpanded ? null : h.id)}
                            aria-label={isExpanded ? 'Recolher detalhes de dano' : 'Ver detalhes de dano'}
                            className="text-muted-300 hover:text-accent"
                          >
                            {isExpanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                          </button>
                        )}
                      </td>
                      <td className="py-2 pr-4">{new Date(h.startedAt).toLocaleString()}</td>
                      <td className="py-2 pr-4">{h.durationMin} min</td>
                      <td className="py-2 pr-4">{h.xpGained.toLocaleString()}</td>
                      <td className="py-2 pr-4 text-accent">{xpPerHour.toLocaleString()}</td>
                      <td className="py-2 pr-4">{h.profit.toLocaleString()} gp</td>
                      <td className="py-2 pr-4">{hasDamageDetail ? h.damageReceived!.toLocaleString() : '—'}</td>
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
                    {isExpanded && hasDamageDetail && (
                      <tr className="border-t border-white/6 bg-white/[0.02]">
                        <td></td>
                        <td colSpan={7} className="py-3 pr-4">
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <div>
                              <div className="text-xs text-muted-300 mb-1">
                                Pico de DPS: {h.maxDps?.toLocaleString() ?? '—'}
                              </div>
                              {h.damageTypes && h.damageTypes.length > 0 && (
                                <>
                                  <div className="text-xs text-muted-300 mb-1 mt-2">Tipos de dano</div>
                                  <ul className="space-y-0.5">
                                    {h.damageTypes.map((d) => (
                                      <li key={d.type} className="flex justify-between text-xs">
                                        <span>{d.type}</span>
                                        <span className="text-muted-300">
                                          {d.amount.toLocaleString()} ({d.percentage}%)
                                        </span>
                                      </li>
                                    ))}
                                  </ul>
                                </>
                              )}
                            </div>
                            {h.damageSources && h.damageSources.length > 0 && (
                              <div>
                                <div className="text-xs text-muted-300 mb-1">Fontes de dano</div>
                                <ul className="space-y-0.5">
                                  {h.damageSources.map((s) => (
                                    <li key={s.name} className="flex justify-between text-xs">
                                      <span>{s.name}</span>
                                      <span className="text-muted-300">
                                        {s.amount.toLocaleString()} ({s.percentage}%)
                                      </span>
                                    </li>
                                  ))}
                                </ul>
                              </div>
                            )}
                          </div>
                        </td>
                      </tr>
                    )}
                  </React.Fragment>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </GlassCard>
  );
}
