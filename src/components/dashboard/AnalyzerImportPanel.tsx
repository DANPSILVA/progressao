'use client';

import React, { useState } from 'react';
import {
  parseHuntAnalyzer,
  parsePartyHunt,
  parseInputAnalyzer,
  parseMiscAnalyzer,
  ParsedPartyHuntMember,
} from '@/lib/huntAnalyzerParser';

type AnalyzerTab = 'hunt' | 'party' | 'input' | 'misc';
type Status = 'idle' | 'ok' | 'error';

const TABS: { key: AnalyzerTab; label: string }[] = [
  { key: 'hunt', label: 'Hunt Analyzer' },
  { key: 'party', label: 'Party Hunt' },
  { key: 'input', label: 'Input Analyzer' },
  { key: 'misc', label: 'Miscellaneous' },
];

/** Each tab pastes into its own box and runs its own dedicated parser (rather than one
 *  box trying every parser on whatever text shows up) — matching each tab to a fixed
 *  format keeps "why didn't this detect" easy to reason about, and lets the Party Hunt
 *  member-picker live only where it's relevant. Every tab still feeds the same hunt
 *  form via onApply, so pasting across multiple tabs freely combines data. */
export default function AnalyzerImportPanel({ onApply }: { onApply: (patch: Record<string, unknown>) => void }) {
  const [activeTab, setActiveTab] = useState<AnalyzerTab>('hunt');

  const [huntText, setHuntText] = useState('');
  const [partyText, setPartyText] = useState('');
  const [inputText, setInputText] = useState('');
  const [miscText, setMiscText] = useState('');

  const [huntStatus, setHuntStatus] = useState<Status>('idle');
  const [partyStatus, setPartyStatus] = useState<Status>('idle');
  const [inputStatus, setInputStatus] = useState<Status>('idle');
  const [miscStatus, setMiscStatus] = useState<Status>('idle');

  const [partyMembers, setPartyMembers] = useState<ParsedPartyHuntMember[] | null>(null);
  const [inputSummary, setInputSummary] = useState<{ damageReceived: number; maxDps: number } | null>(null);
  const [miscSummary, setMiscSummary] = useState<number | null>(null);

  const statusFor: Record<AnalyzerTab, Status> = {
    hunt: huntStatus,
    party: partyStatus,
    input: inputStatus,
    misc: miscStatus,
  };

  const handleDetectHunt = () => {
    const parsed = parseHuntAnalyzer(huntText);
    if (!parsed) {
      setHuntStatus('error');
      return;
    }
    onApply({
      ...(parsed.startedAt ? { startedAt: parsed.startedAt } : {}),
      durationMin: parsed.durationMin,
      xpGained: parsed.xpGained,
      profit: parsed.profit,
      waste: parsed.waste,
      loot: parsed.loot,
      deaths: parsed.deaths,
    });
    setHuntStatus('ok');
  };

  const handleDetectParty = () => {
    const parsed = parsePartyHunt(partyText);
    if (!parsed) {
      setPartyStatus('error');
      setPartyMembers(null);
      return;
    }
    onApply({
      ...(parsed.startedAt ? { startedAt: parsed.startedAt } : {}),
      durationMin: parsed.durationMin,
    });
    setPartyMembers(parsed.members);
    setPartyStatus('ok');
  };

  const handlePickPartyMember = (name: string) => {
    const member = partyMembers?.find((m) => m.name === name);
    if (!member) return;
    onApply({ profit: member.profit, waste: member.waste, loot: member.loot });
  };

  const handleDetectInput = () => {
    const parsed = parseInputAnalyzer(inputText);
    if (!parsed) {
      setInputStatus('error');
      setInputSummary(null);
      return;
    }
    onApply({
      damageReceived: parsed.damageReceived,
      maxDps: parsed.maxDps,
      damageTypes: parsed.damageTypes,
      damageSources: parsed.damageSources,
    });
    setInputSummary({ damageReceived: parsed.damageReceived, maxDps: parsed.maxDps });
    setInputStatus('ok');
  };

  const handleDetectMisc = () => {
    const parsed = parseMiscAnalyzer(miscText);
    if (!parsed) {
      setMiscStatus('error');
      setMiscSummary(null);
      return;
    }
    onApply({ miscData: parsed });
    setMiscSummary(parsed.charmData.length + parsed.imbuementData.length + parsed.itemUpgrade.length);
    setMiscStatus('ok');
  };

  return (
    <div className="mb-5 pb-5 border-b border-white/6">
      <div className="flex gap-1 rounded-md bg-[rgba(255,255,255,0.02)] p-1 mb-3 w-fit flex-wrap">
        {TABS.map((tab) => {
          const isActive = activeTab === tab.key;
          return (
            <button
              key={tab.key}
              type="button"
              onClick={() => setActiveTab(tab.key)}
              className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors flex items-center gap-1.5 ${
                isActive ? 'bg-accent text-black' : 'text-muted-300 hover:text-[var(--text-100)]'
              }`}
            >
              {tab.label}
              {statusFor[tab.key] === 'ok' && <span className="w-1.5 h-1.5 rounded-full bg-[var(--series-2)]" />}
            </button>
          );
        })}
      </div>

      {activeTab === 'hunt' && (
        <div>
          <textarea
            className="input-tibia w-full h-28 font-mono text-xs"
            placeholder="Cole aqui o texto copiado do Hunt Analyzer do jogo..."
            value={huntText}
            onChange={(e) => {
              setHuntText(e.target.value);
              setHuntStatus('idle');
            }}
          />
          <div className="flex items-center gap-3 mt-2">
            <button type="button" onClick={handleDetectHunt} className="btn-tibia text-sm" disabled={!huntText.trim()}>
              Detectar dados
            </button>
            {huntStatus === 'ok' && <span className="text-sm text-accent">Dados detectados! Confira os campos abaixo.</span>}
            {huntStatus === 'error' && (
              <span className="text-sm text-red-400">Não reconheci esse texto — confira se é do Hunt Analyzer.</span>
            )}
          </div>
        </div>
      )}

      {activeTab === 'party' && (
        <div>
          <textarea
            className="input-tibia w-full h-28 font-mono text-xs"
            placeholder="Cole aqui o texto copiado do Party Hunt Analyzer do jogo..."
            value={partyText}
            onChange={(e) => {
              setPartyText(e.target.value);
              setPartyStatus('idle');
            }}
          />
          <div className="flex items-center gap-3 mt-2">
            <button type="button" onClick={handleDetectParty} className="btn-tibia text-sm" disabled={!partyText.trim()}>
              Detectar dados
            </button>
            {partyStatus === 'ok' && <span className="text-sm text-accent">Dados detectados! Escolha seu personagem abaixo.</span>}
            {partyStatus === 'error' && (
              <span className="text-sm text-red-400">Não reconheci esse texto — confira se é do Party Hunt.</span>
            )}
          </div>

          {partyMembers && (
            <div className="mt-3">
              <label className="label-tibia">Qual desses é o seu personagem?</label>
              <select className="input-tibia" defaultValue="" onChange={(e) => handlePickPartyMember(e.target.value)}>
                <option value="" disabled>
                  Selecione...
                </option>
                {partyMembers.map((m) => (
                  <option key={m.name} value={m.name}>
                    {m.name}
                  </option>
                ))}
              </select>
              <p className="text-xs text-muted-300 mt-1">
                Esse formato não traz XP ganho por membro — preencha esse campo manualmente abaixo.
              </p>
            </div>
          )}
        </div>
      )}

      {activeTab === 'input' && (
        <div>
          <textarea
            className="input-tibia w-full h-28 font-mono text-xs"
            placeholder="Cole aqui o texto copiado do Input Analyzer do jogo..."
            value={inputText}
            onChange={(e) => {
              setInputText(e.target.value);
              setInputStatus('idle');
            }}
          />
          <div className="flex items-center gap-3 mt-2">
            <button type="button" onClick={handleDetectInput} className="btn-tibia text-sm" disabled={!inputText.trim()}>
              Detectar dados
            </button>
            {inputStatus === 'ok' && <span className="text-sm text-accent">Dados detectados!</span>}
            {inputStatus === 'error' && (
              <span className="text-sm text-red-400">Não reconheci esse texto — confira se é do Input Analyzer.</span>
            )}
          </div>
          {inputSummary && (
            <p className="text-xs text-muted-300 mt-2">
              Dano recebido detectado: {inputSummary.damageReceived.toLocaleString()} (pico de DPS:{' '}
              {inputSummary.maxDps.toLocaleString()})
            </p>
          )}
        </div>
      )}

      {activeTab === 'misc' && (
        <div>
          <textarea
            className="input-tibia w-full h-28 font-mono text-xs"
            placeholder="Cole aqui o texto copiado do Miscellaneous do jogo..."
            value={miscText}
            onChange={(e) => {
              setMiscText(e.target.value);
              setMiscStatus('idle');
            }}
          />
          <div className="flex items-center gap-3 mt-2">
            <button type="button" onClick={handleDetectMisc} className="btn-tibia text-sm" disabled={!miscText.trim()}>
              Detectar dados
            </button>
            {miscStatus === 'ok' && <span className="text-sm text-accent">Dados detectados!</span>}
            {miscStatus === 'error' && (
              <span className="text-sm text-red-400">Não reconheci esse texto — confira se é do Miscellaneous.</span>
            )}
          </div>
          {miscSummary !== null && (
            <p className="text-xs text-muted-300 mt-2">
              Dados de charms/imbuements/upgrades detectados — {miscSummary} item(ns).
            </p>
          )}
        </div>
      )}
    </div>
  );
}
