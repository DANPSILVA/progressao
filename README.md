# RubinTracker

Acompanhamento de progresso de personagem (XP, level, tempo de hunt e loot/profit), com cadastro/login de usuário. Cada usuário só vê e edita o próprio progresso.

## Stack

- Next.js 14 (App Router) + Tailwind
- NextAuth.js (Credentials provider, sessão JWT)
- Prisma + PostgreSQL (compatível com Neon, Vercel Postgres ou Supabase — basta apontar a `DATABASE_URL`)

## Configuração local

1. Instale as dependências:

   ```bash
   npm install
   ```

2. Copie `.env.example` para `.env` e preencha:

   ```bash
   cp .env.example .env
   ```

   - `DATABASE_URL`: string de conexão Postgres (Neon, Vercel Postgres ou Supabase).
   - `NEXTAUTH_SECRET`: gere com `openssl rand -base64 32`.
   - `NEXTAUTH_URL`: `http://localhost:3000` em desenvolvimento.

3. Rode as migrations do Prisma:

   ```bash
   npm run db:migrate
   ```

4. Suba o servidor:

   ```bash
   npm run dev
   ```

## Funcionamento

- `/register` e `/login`: cadastro e autenticação por email/senha (NextAuth Credentials + bcrypt).
- `/dashboard`: protegido por middleware — redireciona para `/login` se não autenticado.
- Cada usuário tem um `Character` (nome, vocação, level) e uma lista de `HuntSession` (data, duração, XP, profit, waste, loot, bosses, deaths), sempre filtrados pelo `userId` da sessão.
- O XP/h é sempre calculado automaticamente (XP total ÷ horas de hunt), nunca inserido manualmente.

## Scripts úteis

- `npm run db:migrate` — cria/aplica migrations em desenvolvimento.
- `npm run db:deploy` — aplica migrations em produção.
- `npm run db:studio` — abre o Prisma Studio para inspecionar o banco.
