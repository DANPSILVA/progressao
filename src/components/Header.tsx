'use client';

import React, { useMemo } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import ThemeToggle from '@/components/ui/ThemeToggle';
import { useSupabaseUser } from '@/lib/supabase/useUser';
import { createSupabaseBrowserClient } from '@/lib/supabase/client';

export default function Header() {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const { user, loading } = useSupabaseUser();

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    router.push('/');
    router.refresh();
  };

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
          {user ? (
            <>
              <Link href="/dashboard" className="text-sm text-muted-300 hover:text-text-100">Dashboard</Link>
              <span className="text-sm text-muted-300 hidden sm:inline">
                {(user.user_metadata as { name?: string })?.name ?? user.email}
              </span>
              <button onClick={handleSignOut} className="btn-tibia text-sm">
                Sair
              </button>
            </>
          ) : loading ? null : (
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
