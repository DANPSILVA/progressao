export type HuntSession = {
  id: string;
  startedAt: string;
  durationMin: number;
  xpGained: number;
  profit: number;
  waste: number;
  loot: number;
  bosses: number;
  deaths: number;
  levelAfter: number | null;
};

export type Character = {
  id: string;
  name: string;
  vocation: string | null;
  level: number;
  avatarUrl: string | null;
};

export type HourlyPointFull = {
  time: string;
  xp: number;
  profit: number;
  waste: number;
  loot: number;
  bosses: number;
  deaths: number;
};

export type SummaryMetrics = {
  xp: number;
  xpPerHour: number;
  profit: number;
  waste: number;
  loot: number;
  bosses: number;
  deaths: number;
  hours: number;
};

export function filterByPeriod(hunts: HuntSession[], period: '24h' | '7d' | '30d' | '90d'): HuntSession[] {
  const now = new Date();
  const start = new Date(now);
  if (period === '24h') start.setDate(now.getDate() - 1);
  if (period === '7d') start.setDate(now.getDate() - 7);
  if (period === '30d') start.setDate(now.getDate() - 30);
  if (period === '90d') start.setDate(now.getDate() - 90);
  return hunts.filter((h) => new Date(h.startedAt) >= start);
}

export function aggregateByDay(hunts: HuntSession[]): HourlyPointFull[] {
  const byDay = new Map<string, HourlyPointFull>();

  const sorted = [...hunts].sort((a, b) => new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime());

  for (const h of sorted) {
    const dayKey = new Date(h.startedAt).toISOString().slice(0, 10);
    const existing = byDay.get(dayKey) ?? { time: dayKey, xp: 0, profit: 0, waste: 0, loot: 0, bosses: 0, deaths: 0 };
    existing.xp += h.xpGained;
    existing.profit += h.profit;
    existing.waste += h.waste;
    existing.loot += h.loot;
    existing.bosses += h.bosses;
    existing.deaths += h.deaths;
    byDay.set(dayKey, existing);
  }

  return Array.from(byDay.values());
}

export type SessionPoint = {
  label: string;
  xpPerHour: number;
  xp: number;
  profit: number;
};

/** One point per individual hunt (not day-aggregated) — for spotting variance across sessions. */
export function perSessionSeries(hunts: HuntSession[]): SessionPoint[] {
  return [...hunts]
    .sort((a, b) => new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime())
    .map((h) => ({
      label: new Date(h.startedAt).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }),
      xpPerHour: h.durationMin > 0 ? Math.round(h.xpGained / (h.durationMin / 60)) : 0,
      xp: h.xpGained,
      profit: h.profit,
    }));
}

/** XP/h is derived automatically from total XP gained divided by total hunting time — never entered manually. */
export function computeSummary(hunts: HuntSession[]): SummaryMetrics {
  const xp = hunts.reduce((s, h) => s + h.xpGained, 0);
  const durationMin = hunts.reduce((s, h) => s + h.durationMin, 0);
  const hours = durationMin / 60;
  const xpPerHour = hours > 0 ? xp / hours : 0;
  const profit = hunts.reduce((s, h) => s + h.profit, 0);
  const waste = hunts.reduce((s, h) => s + h.waste, 0);
  const loot = hunts.reduce((s, h) => s + h.loot, 0);
  const bosses = hunts.reduce((s, h) => s + h.bosses, 0);
  const deaths = hunts.reduce((s, h) => s + h.deaths, 0);

  return { xp, xpPerHour, profit, waste, loot, bosses, deaths, hours };
}
