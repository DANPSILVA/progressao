'use client';

import React from 'react';
import { ExternalLink, Trophy } from 'lucide-react';
import GlassCard from '@/components/ui/GlassCard';

const HIGHSCORES_URL = 'https://rubinot.com.br/highscores';

export default function RubinOtRanking() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div className="text-xl font-semibold">Ranking RubinOT</div>
      </div>

      <GlassCard>
        <div className="flex flex-col items-center text-center gap-4 py-8">
          <div className="w-14 h-14 rounded-full bg-accent/10 flex items-center justify-center">
            <Trophy className="w-7 h-7 text-accent" />
          </div>
          <div className="space-y-1 max-w-md">
            <p className="text-[var(--text-100)] font-medium">Highscores oficiais do RubinOT</p>
            <p className="text-sm text-muted-300">
              O site do RubinOT protege o highscores contra acesso automatizado e carrega os dados apenas depois
              que a página abre no seu navegador, então não é possível trazer o ranking ao vivo para dentro do
              RubinTracker. Use o link abaixo para conferir o ranking atualizado direto na fonte oficial.
            </p>
          </div>
          <a
            href={HIGHSCORES_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="btn-tibia btn-tibia--primary text-sm inline-flex items-center gap-2"
          >
            Abrir highscores no site do RubinOT <ExternalLink className="w-3.5 h-3.5" />
          </a>
        </div>
      </GlassCard>
    </div>
  );
}
