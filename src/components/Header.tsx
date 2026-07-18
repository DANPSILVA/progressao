'use client';

import Link from 'next/link';
import { useSession, signOut } from 'next-auth/react';
import ThemeToggle from '@/components/ui/ThemeToggle';

export default function Header() {
  const { data: session, status } = useSession();

  return (
    <header className="w-full border-b border-white/6 bg-gradient-to-b from-[rgba(0,0,0,0.06)] to-transparent">
      <div className="max-w-6xl mx-auto px-4 py-4 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/" className="logo-mark">
            <img src="/logo-tibia-inspired.svg" alt="RubinTracker" width={36} height={36} />
          </Link>
          <Link href="/" className="text-lg font-semibold tracking-tight">RubinTracker</Link>
        </div>

        <nav className="flex items-center gap-4">
          <Link href="/styleguide" className="text-sm text-muted-300 hover:text-text-100">Styleguide</Link>
          <Link href="/weather" className="text-sm text-muted-300 hover:text-text-100">Weather</Link>
          {status === 'authenticated' ? (
            <>
              <Link href="/dashboard" className="text-sm text-muted-300 hover:text-text-100">Dashboard</Link>
              <span className="text-sm text-muted-300 hidden sm:inline">{session.user?.name ?? session.user?.email}</span>
              <button onClick={() => signOut({ callbackUrl: '/' })} className="btn-tibia text-sm">
                Sair
              </button>
            </>
          ) : status === 'loading' ? null : (
            <>
              <Link href="/login" className="text-sm text-muted-300 hover:text-text-100">Entrar</Link>
              <Link href="/register" className="btn-tibia btn-tibia--primary text-sm">Cadastrar</Link>
            </>
          )}
          <ThemeToggle />
        </nav>
      </div>
    </header>
  );
}
