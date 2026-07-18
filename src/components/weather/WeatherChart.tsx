'use client';

import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';

type DataPoint = { time: string; temp: number };

export default function WeatherChart({ data }: { data: DataPoint[] }) {
  const mapped = data.map((d) => ({ ...d, timeLabel: new Date(d.time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }));

  return (
    <div style={{ width: '100%', height: 300 }} className="mt-2">
      <ResponsiveContainer>
        <LineChart data={mapped} margin={{ top: 10, right: 20, bottom: 0, left: 0 }}>
          <XAxis dataKey="timeLabel" tick={{ fontSize: 12, fill: 'var(--muted-300)' }} />
          <YAxis domain={["auto", "auto"]} tick={{ fontSize: 12, fill: 'var(--muted-300)' }} />
          <Tooltip formatter={(value: any) => `${value} °C`} />
          <Line type="monotone" dataKey="temp" stroke="var(--neon)" strokeWidth={2} dot={{ r: 2 }} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
