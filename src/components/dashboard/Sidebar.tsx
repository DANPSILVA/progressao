'use client';

import React from 'react';
import { LayoutDashboard, ClipboardList, BarChart3, Trophy, Users } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';

type NavItem = { key: string; label: string; icon: LucideIcon };
type NavSection = { title: string; items: NavItem[] };

const SECTIONS: NavSection[] = [
  {
    title: 'Principal',
    items: [
      { key: 'overview', label: 'Visão Geral', icon: LayoutDashboard },
      { key: 'history', label: 'Histórico de Hunts', icon: ClipboardList },
    ],
  },
  {
    title: 'Análise',
    items: [
      { key: 'stats', label: 'Estatísticas', icon: BarChart3 },
      { key: 'ranking', label: 'Ranking RubinOT', icon: Trophy },
    ],
  },
  {
    title: 'Comunidade',
    items: [{ key: 'friends', label: 'Amigos', icon: Users }],
  },
];

export default function Sidebar({ active, onChange }: { active: string; onChange: (key: string) => void }) {
  return (
    <aside className="w-56 shrink-0 border-r border-white/6 py-6 pr-4 hidden md:block">
      <nav className="space-y-6 sticky top-6">
        {SECTIONS.map((section) => (
          <div key={section.title}>
            <div className="text-xs uppercase tracking-wide text-muted-300 px-3 mb-2">{section.title}</div>
            <ul className="space-y-1">
              {section.items.map((item) => {
                const Icon = item.icon;
                const isActive = active === item.key;
                return (
                  <li key={item.key}>
                    <button
                      type="button"
                      onClick={() => onChange(item.key)}
                      aria-current={isActive ? 'page' : undefined}
                      className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-md text-sm transition-colors text-left ${
                        isActive
                          ? 'bg-accent text-black font-medium'
                          : 'text-muted-300 hover:text-[var(--text-100)] hover:bg-white/5'
                      }`}
                    >
                      <Icon className="w-4 h-4 shrink-0" />
                      {item.label}
                    </button>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>
    </aside>
  );
}
