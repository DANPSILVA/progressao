'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import WeatherChart from './WeatherChart';
import GlassCard from '@/components/ui/GlassCard';
import Button from '@/components/ui/Button';

type FormValues = { city: string };
const schema = z.object({ city: z.string().min(1, 'Informe uma cidade') });

type HourlyPoint = { time: string; temp: number };

export default function WeatherDashboard() {
  const { register, handleSubmit, formState } = useForm<FormValues>({ resolver: zodResolver(schema) });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [place, setPlace] = useState<string | null>(null);
  const [points, setPoints] = useState<HourlyPoint[] | null>(null);
  const [current, setCurrent] = useState<number | null>(null);

  async function onSubmit(data: FormValues) {
    setError(null);
    setPoints(null);
    setCurrent(null);
    setPlace(null);
    setLoading(true);

    try {
      const geoRes = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(data.city)}&limit=1`,
        { headers: { 'User-Agent': 'RubinTracker/1.0 (you@domain.com)' } }
      );
      const geoJson = await geoRes.json();
      if (!geoJson || geoJson.length === 0) throw new Error('Local não encontrado');
      const { lat, lon, display_name } = geoJson[0];
      setPlace(display_name);

      const weatherRes = await fetch(
        `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m&timezone=auto`
      );
      const weatherJson = await weatherRes.json();

      const times: string[] = weatherJson.hourly?.time || [];
      const temps: number[] = weatherJson.hourly?.temperature_2m || [];

      if (!times.length || !temps.length) throw new Error('Dados meteorológicos indisponíveis');

      const pts: HourlyPoint[] = times.map((t, i) => ({ time: t, temp: temps[i] }));
      const slice = pts.slice(0, 24);

      setPoints(slice);
      setCurrent(slice[0].temp);
    } catch (err: any) {
      setError(err?.message || 'Erro ao buscar dados');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <form onSubmit={handleSubmit(onSubmit)} className="flex gap-3">
        <input
          {...register('city')}
          placeholder="Ex: São Paulo"
          className="flex-1 rounded-md border border-white/6 bg-[rgba(255,255,255,0.01)] px-3 py-2 text-[var(--text-100)]"
        />
        <Button>{loading ? 'Buscando...' : 'Buscar'}</Button>
      </form>

      {error && <div className="text-danger">{error}</div>}

      {place && (
        <GlassCard>
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm text-muted-300">Local</div>
              <div className="font-semibold">{place}</div>
            </div>
            <div className="text-right">
              <div className="text-sm text-muted-300">Agora</div>
              <div className="text-2xl font-bold">{current != null ? `${current.toFixed(1)} °C` : '—'}</div>
            </div>
          </div>

          <div className="mt-4">{points ? <WeatherChart data={points} /> : <div className="text-muted-300">Nenhum dado de gráfico</div>}</div>
        </GlassCard>
      )}
    </div>
  );
}
