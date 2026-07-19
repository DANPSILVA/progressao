import { redirect } from 'next/navigation';
import Header from '@/components/Header';
import DashboardShell from '@/components/dashboard/DashboardShell';
import { getCurrentUserId } from '@/lib/session';

export const metadata = {
  title: 'RubinTracker — Dashboard',
  description: 'Visualize seus KPIs e evolução — XP, Profit, Bosses e demais métricas.'
};

export default async function DashboardPage() {
  const userId = await getCurrentUserId();
  if (!userId) {
    redirect('/login');
  }

  return (
    <div>
      <Header />
      <main className="max-w-7xl mx-auto py-10 px-4">
        <h1 className="text-3xl font-semibold mb-6">Dashboard</h1>
        <DashboardShell />
      </main>
    </div>
  );
}
