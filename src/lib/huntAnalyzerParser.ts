/** Parses the text RubinOT's in-game "Hunt Analyzer" window produces via its
 *  "Copy to Clipboard" button. Only extracts the fields our HuntSession model
 *  tracks — everything else (Charm/Imbuement/Item Upgrade data, killed monsters,
 *  looted items) is ignored rather than treated as an error, since the format
 *  has more sections than we need and may vary between sessions. */

export type ParsedHuntAnalyzer = {
  startedAt: string; // yyyy-MM-ddTHH:mm, ready for a <input type="datetime-local">
  durationMin: number;
  xpGained: number;
  profit: number;
  waste: number;
  loot: number;
  deaths: number;
};

function parseAmount(raw: string): number {
  // RubinOT uses "." as the thousands separator on the solo Hunt Analyzer but "," on
  // the Party Hunt one — stripping every non-digit character handles both.
  const cleaned = raw.replace(/[^\d-]/g, '');
  const value = parseInt(cleaned, 10);
  return Number.isNaN(value) ? 0 : value;
}

function toDateTimeLocal(dateStr: string): string | null {
  // "2026-07-19, 11:44:12" -> "2026-07-19T11:44"
  const match = dateStr.trim().match(/^(\d{4}-\d{2}-\d{2}),\s*(\d{2}:\d{2})/);
  if (!match) return null;
  return `${match[1]}T${match[2]}`;
}

export function parseHuntAnalyzer(text: string): ParsedHuntAnalyzer | null {
  const sessionMatch = text.match(/^Session data:\s*From\s+([\d-]+,\s*[\d:]+)\s+to\s+([\d-]+,\s*[\d:]+)/m);
  const durationMatch = text.match(/^Session:\s*(\d+):(\d+)h/m);
  const xpGainMatch = text.match(/^XP Gain:\s*([\d.,]+)/m);
  const lootMatch = text.match(/^Loot:\s*([\d.,]+)/m);
  const suppliesMatch = text.match(/^Supplies:\s*([\d.,]+)/m);
  const balanceMatch = text.match(/^Balance:\s*(-?[\d.,]+)/m);
  const deathsMatch = text.match(/^Deaths:\s*(\d+)/m);

  // Require at minimum a recognizable session window and an XP figure — anything
  // less means this probably isn't a Hunt Analyzer paste at all.
  if (!durationMatch || !xpGainMatch) return null;

  const startedAt = sessionMatch ? toDateTimeLocal(sessionMatch[1]) : null;

  return {
    startedAt: startedAt ?? '',
    durationMin: parseInt(durationMatch[1], 10) * 60 + parseInt(durationMatch[2], 10),
    xpGained: parseAmount(xpGainMatch[1]),
    profit: balanceMatch ? parseAmount(balanceMatch[1]) : 0,
    loot: lootMatch ? parseAmount(lootMatch[1]) : 0,
    waste: suppliesMatch ? parseAmount(suppliesMatch[1]) : 0,
    deaths: deathsMatch ? parseInt(deathsMatch[1], 10) : 0,
  };
}

export type ParsedPartyHuntMember = {
  name: string;
  loot: number;
  waste: number;
  profit: number;
};

export type ParsedPartyHunt = {
  startedAt: string;
  durationMin: number;
  members: ParsedPartyHuntMember[];
};

function isPartyHuntTopLevelLine(trimmed: string): boolean {
  return /^(Session data:|Session:|Loot Type:|Loot:|Supplies:|Balance:)/.test(trimmed);
}

/** Party Hunt analyzer text has no XP figure at all — instead it breaks Loot/
 *  Supplies/Balance (plus Damage/Healing, which we don't track) down per member.
 *  Since there's no way to know which member is "you", the caller shows a picker
 *  and re-derives loot/waste/profit from whichever member gets selected. */
export function parsePartyHunt(text: string): ParsedPartyHunt | null {
  const sessionMatch = text.match(/Session data:\s*From\s+([\d-]+,\s*[\d:]+)\s+to\s+([\d-]+,\s*[\d:]+)/);
  const durationMatch = text.match(/Session:\s*(\d+):(\d+)h/);
  if (!durationMatch) return null;

  const startedAt = sessionMatch ? toDateTimeLocal(sessionMatch[1]) : null;
  const durationMin = parseInt(durationMatch[1], 10) * 60 + parseInt(durationMatch[2], 10);

  const members: ParsedPartyHuntMember[] = [];
  let current: Partial<ParsedPartyHuntMember> | null = null;

  const flush = () => {
    if (current?.name) {
      members.push({
        name: current.name,
        loot: current.loot ?? 0,
        waste: current.waste ?? 0,
        profit: current.profit ?? 0,
      });
    }
    current = null;
  };

  for (const rawLine of text.split('\n')) {
    const line = rawLine.replace(/\s+$/, '');
    const trimmed = line.trim();
    if (!trimmed) continue;

    if (!/^[\t ]/.test(line)) {
      if (isPartyHuntTopLevelLine(trimmed)) continue;
      flush();
      current = { name: trimmed.replace(/\s*\(Leader\)\s*$/, '') };
      continue;
    }

    if (!current) continue;

    const loot = trimmed.match(/^Loot:\s*(-?[\d.,]+)/);
    const supplies = trimmed.match(/^Supplies:\s*(-?[\d.,]+)/);
    const balance = trimmed.match(/^Balance:\s*(-?[\d.,]+)/);

    if (loot) current.loot = parseAmount(loot[1]);
    else if (supplies) current.waste = parseAmount(supplies[1]);
    else if (balance) current.profit = parseAmount(balance[1]);
  }
  flush();

  if (members.length === 0) return null;

  return { startedAt: startedAt ?? '', durationMin, members };
}

export type ParsedInputAnalyzer = {
  damageReceived: number;
  maxDps: number;
  damageTypes: { type: string; amount: number; percentage: number }[];
  damageSources: { name: string; amount: number; percentage: number }[];
};

/** Input Analyzer text has no session/XP/loot data at all — it's purely a damage-taken
 *  breakdown ("Total"/"Max-DPS" plus per-element and per-monster lists), so it never
 *  contributes startedAt/durationMin the way the other two formats do. */
export function parseInputAnalyzer(text: string): ParsedInputAnalyzer | null {
  const totalMatch = text.match(/^Total:\s*([\d.,]+)/m);
  const maxDpsMatch = text.match(/^Max-DPS:\s*([\d.,]+)/m);
  if (!totalMatch || !maxDpsMatch) return null;

  const damageTypes: { type: string; amount: number; percentage: number }[] = [];
  const damageSources: { name: string; amount: number; percentage: number }[] = [];
  let section: 'types' | 'sources' | null = null;
  const entryPattern = /^(.+?)\s+([\d.,]+)\s+\(([\d.]+)%\)$/;

  for (const rawLine of text.split('\n')) {
    const trimmed = rawLine.trim();
    if (!trimmed) continue;
    if (trimmed === 'Damage Types') {
      section = 'types';
      continue;
    }
    if (trimmed === 'Damage Sources') {
      section = 'sources';
      continue;
    }
    if (/^(Received Damage|Total:|Max-DPS:)/.test(trimmed)) continue;

    const match = trimmed.match(entryPattern);
    if (!match) continue;
    const [, name, amountRaw, pctRaw] = match;
    const amount = parseAmount(amountRaw);
    const percentage = parseFloat(pctRaw);

    if (section === 'types') damageTypes.push({ type: name, amount, percentage });
    else if (section === 'sources') damageSources.push({ name, amount, percentage });
  }

  return {
    damageReceived: parseAmount(totalMatch[1]),
    maxDps: parseAmount(maxDpsMatch[1]),
    damageTypes,
    damageSources,
  };
}
