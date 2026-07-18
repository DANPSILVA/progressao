import type { Metadata } from 'next';
import './globals.css';
import SessionProviderWrapper from '@/components/providers/SessionProviderWrapper';

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
      <body>
        <SessionProviderWrapper>{children}</SessionProviderWrapper>
      </body>
    </html>
  );
}
