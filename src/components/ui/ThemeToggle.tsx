'use client';

import { useEffect, useState } from 'react';
import { Sun, Moon } from 'lucide-react';

export default function ThemeToggle() {
  const [isDark, setIsDark] = useState(true);

  useEffect(() => {
    setIsDark(document.documentElement.classList.contains('dark'));
  }, []);

  useEffect(() => {
    if (isDark) document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');
  }, [isDark]);

  return (
    <button
      onClick={() => setIsDark((s) => !s)}
      className="px-3 py-2 rounded-md bg-white/6 focus-ring"
      aria-label="Alternar tema"
    >
      {isDark ? <Moon className="w-4 h-4 text-accent" /> : <Sun className="w-4 h-4 text-muted-300" />}
    </button>
  );
}
