import { getServerSession } from 'next-auth';
import { redirect } from 'next/navigation';
import Header from '@/components/Header';
import DashboardShell from '@/components/dashboard/DashboardShell';
import { authOptions } from '@/lib/auth';

export const metadata = {
  title: 'RubinTracker — Dashboard',
  description: 'Visualize seus KPIs e evolução — XP, Profits, Loot, Bosses e demais métricas.'
};

export default async function DashboardPage() {
  const session = await getServerSession(authOptions);
  if (!session?.user) {
    redirect('/login');
  }

  return (
    <div>
      <Header />
      <main className="max-w-6xl mx-auto py-10 px-4">
        <h1 className="text-3xl font-semibold mb-6">Dashboard</h1>
        <DashboardShell />
      </main>
    </div>
  );
}
