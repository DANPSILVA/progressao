import Header from '@/components/Header';
import dynamic from 'next/dynamic';

const WeatherDashboard = dynamic(() => import('@/components/weather/WeatherDashboard'), { ssr: false });

export const metadata = {
  title: 'RubinTracker — Weather',
  description: 'Weather dashboard demo (geocoding + forecast)'
};

export default function WeatherPage() {
  return (
    <div>
      <Header />
      <main className="max-w-4xl mx-auto py-10 px-4">
        <h1 className="text-3xl font-semibold mb-4">Weather Dashboard</h1>
        <p className="text-muted-300 mb-6">Busque por uma cidade para ver a previsão (Nominatim + Open-Meteo).</p>
        <WeatherDashboard />
      </main>
    </div>
  );
}
