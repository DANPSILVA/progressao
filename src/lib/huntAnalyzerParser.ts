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
  // RubinOT formats amounts with "." as the thousands separator (e.g. "220.076").
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
