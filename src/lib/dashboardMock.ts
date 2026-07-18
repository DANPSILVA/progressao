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
};

export function generateMockSeries(days = 30): HourlyPointFull[] {
  // generate daily points for simplicity
  const out: HourlyPointFull[] = [];
  const now = new Date();
  for (let i = days; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(now.getDate() - i);
    const xp = Math.max(1000, Math.round(Math.random() * 40000));
    const profit = Math.round(xp * (Math.random() * 0.8 + 0.2));
    const waste = Math.round(profit * (Math.random() * 0.2));
    const loot = Math.round(Math.random() * 120);
    const bosses = Math.random() > 0.8 ? Math.round(Math.random() * 3) : 0;
    const deaths = Math.random() > 0.93 ? Math.round(Math.random() * 2) : 0;
    out.push({ time: d.toISOString(), xp, profit, waste, loot, bosses, deaths });
  }
  return out;
}
