import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'RubinTracker — Dashboard',
  description: 'Acompanhamento de XP diária no Tibia',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  );
}
