#!/bin/bash
set -e

cat > ".env.example" << 'EOF__env_example_'
# Postgres connection strings from your Supabase project (Connect → ORMs → Prisma)
# DATABASE_URL: pooled connection, used by the app at runtime (port 6543)
DATABASE_URL="postgresql://postgres.xxxxxxxx:password@aws-0-xx-xxxx-1.pooler.supabase.com:6543/postgres?pgbouncer=true"
# DIRECT_URL: direct connection, used only for running migrations (port 5432)
DIRECT_URL="postgresql://postgres.xxxxxxxx:password@aws-0-xx-xxxx-1.pooler.supabase.com:5432/postgres"

# Supabase project settings
# Settings → API
NEXT_PUBLIC_SUPABASE_URL="https://xxxxxxxx.supabase.co"
NEXT_PUBLIC_SUPABASE_ANON_KEY="replace-with-your-anon-public-key"
EOF__env_example_

cat > "prisma/schema.prisma" << 'EOF_prisma_schema_prisma_'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")
  directUrl = env("DIRECT_URL")
}

// id has no default: it must equal the corresponding auth.users.id in Supabase.
// The row itself is created by the handle_new_user() trigger (see migration.sql).
model User {
  id           String   @id
  name         String?
  email        String   @unique
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  character    Character?
  huntSessions HuntSession[]

  friendRequestsSent     Friendship[] @relation("FriendRequestsSent")
  friendRequestsReceived Friendship[] @relation("FriendRequestsReceived")
}

model Character {
  id        String   @id @default(cuid())
  userId    String   @unique
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  name      String
  vocation  String?
  level     Int      @default(8)
  avatarUrl String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model HuntSession {
  id          String   @id @default(cuid())
  userId      String
  user        User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  startedAt   DateTime
  durationMin Int
  xpGained    Int
  profit      Int      @default(0)
  waste       Int      @default(0)
  loot        Int      @default(0)
  bosses      Int      @default(0)
  deaths      Int      @default(0)
  levelAfter  Int?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([userId, startedAt])
}

enum FriendshipStatus {
  PENDING
  ACCEPTED
}

model Friendship {
  id          String           @id @default(cuid())
  fromUserId  String
  fromUser    User             @relation("FriendRequestsSent", fields: [fromUserId], references: [id], onDelete: Cascade)
  toUserId    String
  toUser      User             @relation("FriendRequestsReceived", fields: [toUserId], references: [id], onDelete: Cascade)
  status      FriendshipStatus @default(PENDING)
  createdAt   DateTime         @default(now())
  updatedAt   DateTime         @updatedAt

  @@unique([fromUserId, toUserId])
}
EOF_prisma_schema_prisma_

git add -A
git commit -m "Split DATABASE_URL/DIRECT_URL for Prisma against Supabase's pooler"
git push -u origin claude/user-auth-character-progress-00b5p6
