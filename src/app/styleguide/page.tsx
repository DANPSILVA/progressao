import '../../styles/tibia.css';
import GlassCard from '@/components/ui/GlassCard';
import Button from '@/components/ui/Button';
import ThemeToggle from '@/components/ui/ThemeToggle';

export const metadata = {
  title: 'Styleguide — RubinTracker',
  description: 'Design system preview (Tibia-inspired)'
};

export default function StyleGuide() {
  return (
    <div className="min-h-screen bg-[var(--bg-900)] text-[var(--text-100)] py-12 px-6">
      <div className="max-w-5xl mx-auto space-y-6">
        <header className="flex items-center justify-between">
          <div className="logo-mark">
            <img src="/logo-tibia-inspired.svg" alt="RubinTracker" width={48} height={48} />
            <div>
              <div className="text-2xl font-semibold">RubinTracker</div>
              <div className="text-sm text-muted-300">Tibia-inspired visual preview</div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <ThemeToggle />
            <Button variant="primary">Ação</Button>
          </div>
        </header>

        <div className="grid grid-cols-3 gap-6">
          <GlassCard title="Player Progress">
            <div className="text-xl font-bold">+12%</div>
            <div className="text-sm text-muted-300">Última semana</div>
          </GlassCard>

          <GlassCard title="Activity">
            <div className="text-sm text-muted-300">Eventos recentes</div>
          </GlassCard>

          <GlassCard title="Summary">
            <div className="text-sm text-muted-300">Visão rápida</div>
          </GlassCard>
        </div>

        <div>
          <h3 className="text-lg font-semibold mb-3">Components</h3>
          <div className="flex gap-3">
            <Button>Default</Button>
            <Button variant="primary">Primary</Button>
            <button className="btn-tibia">HTML Button</button>
          </div>
        </div>
      </div>
    </div>
  );
}
