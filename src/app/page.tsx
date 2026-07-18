import './globals.css';
import GlassCard from '@/components/ui/GlassCard';
import Button from '@/components/ui/Button';

export const metadata = {
  title: 'RubinTracker',
  description: 'Acompanhamento de evolução para jogadores do RubinOT'
};

export default function Home() {
  return (
    <div className="min-h-screen py-24 px-6">
      <div className="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-6">
          <GlassCard title="Bem-vindo ao RubinTracker">
            <h1 className="text-3xl font-bold mb-2 text-[var(--text-100)]">Acompanhe sua evolução</h1>
            <p className="text-muted-300">Plataforma para jogadores do RubinOT com análises, gráficos e histórico de progresso.</p>
            <div className="mt-6">
              <Button variant="primary">Começar</Button>
            </div>
          </GlassCard>

          <GlassCard title="Notícias">
            <p className="text-muted-300">Novidades e dicas para melhorar sua performance no jogo.</p>
          </GlassCard>
        </div>

        <aside className="space-y-6">
          <GlassCard title="Atalhos">
            <ul className="space-y-2 text-sm text-muted-300">
              <li>Dashboard</li>
              <li>Player profiles</li>
              <li>Histórico</li>
            </ul>
          </GlassCard>

          <GlassCard title="Status">
            <div className="text-xl font-semibold text-accent">Online</div>
            <div className="text-sm text-muted-300">Todos os serviços funcionando</div>
          </GlassCard>
        </aside>
      </div>
    </div>
  );
}
