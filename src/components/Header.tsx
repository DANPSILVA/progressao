import Link from 'next/link';

export default function Header() {
  return (
    <header className="w-full border-b bg-white">
      <div className="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
        <Link href="/" className="text-lg font-semibold">RubinTracker</Link>
        <nav className="space-x-4 text-sm text-slate-600">
          <Link href="/">Início</Link>
          <Link href="/dashboard">Dashboard</Link>
        </nav>
      </div>
    </header>
  );
}
