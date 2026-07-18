import './globals.css';
import { ReactNode } from 'react';

export const metadata = {
  title: 'RubinTracker',
  description: 'Acompanhamento de evolução para jogadores do RubinOT'
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>
        <main className="min-h-screen bg-slate-50 text-slate-900">{children}</main>
      </body>
    </html>
  );
}
