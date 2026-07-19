#!/bin/bash
set -e

cat > "src/lib/supabase/url.ts" << 'EOF_src_lib_supabase_url_ts_'
/** Normalizes NEXT_PUBLIC_SUPABASE_URL down to its origin — Supabase's dashboard shows this
 *  value with different trailing paths in different tabs (e.g. `/rest/v1/`), and pasting
 *  one of those in by mistake breaks every API call with an "Invalid path" error. */
export function getSupabaseUrl(): string {
  return new URL(process.env.NEXT_PUBLIC_SUPABASE_URL!).origin;
}
EOF_src_lib_supabase_url_ts_

cat > "src/lib/supabase/client.ts" << 'EOF_src_lib_supabase_client_ts_'
import { createBrowserClient } from '@supabase/ssr';
import { getSupabaseUrl } from './url';

export function createSupabaseBrowserClient() {
  return createBrowserClient(
    getSupabaseUrl(),
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
EOF_src_lib_supabase_client_ts_

cat > "src/lib/supabase/server.ts" << 'EOF_src_lib_supabase_server_ts_'
import { cookies } from 'next/headers';
import { createServerClient } from '@supabase/ssr';
import { getSupabaseUrl } from './url';

export function createSupabaseServerClient() {
  const cookieStore = cookies();

  return createServerClient(
    getSupabaseUrl(),
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
          } catch {
            // Called from a Server Component render — the middleware refreshes the
            // session cookie on every request, so a no-op here is safe.
          }
        },
      },
    }
  );
}
EOF_src_lib_supabase_server_ts_

cat > "src/lib/supabase/middleware.ts" << 'EOF_src_lib_supabase_middleware_ts_'
import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';
import { getSupabaseUrl } from './url';

export async function updateSupabaseSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    getSupabaseUrl(),
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
        },
      },
    }
  );

  // Revalidates the session with the Supabase Auth server (not just the local
  // cookie), so a signed-out/expired user is caught before hitting /dashboard.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isDashboardRoute = request.nextUrl.pathname.startsWith('/dashboard');

  if (isDashboardRoute && !user) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('callbackUrl', request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  return response;
}
EOF_src_lib_supabase_middleware_ts_

cat > "src/lib/supabase/broadcast.ts" << 'EOF_src_lib_supabase_broadcast_ts_'
import { createClient } from '@supabase/supabase-js';
import { HUNTS_UPDATES_CHANNEL } from '@/lib/supabase/channels';
import { getSupabaseUrl } from './url';

const CHANNEL = HUNTS_UPDATES_CHANNEL;

/** Fire-and-forget notice so friends' ranking panels can refetch live. Best-effort: a
 *  failed broadcast never blocks the hunt CRUD response, it just delays the next
 *  auto-refresh until someone reloads the page. */
export async function broadcastHuntChange(userId: string) {
  try {
    const supabase = createClient(getSupabaseUrl(), process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
    const channel = supabase.channel(CHANNEL);

    await new Promise<void>((resolve) => {
      const timeout = setTimeout(resolve, 2000);
      channel.subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          channel
            .send({ type: 'broadcast', event: 'hunt-change', payload: { userId } })
            .finally(() => {
              clearTimeout(timeout);
              resolve();
            });
        }
      });
    });

    await supabase.removeChannel(channel);
  } catch {
    // Realtime is a nice-to-have here — never let it break a hunt save.
  }
}
EOF_src_lib_supabase_broadcast_ts_

git add -A
git commit -m "Normalize NEXT_PUBLIC_SUPABASE_URL to its origin"
git push -u origin claude/user-auth-character-progress-00b5p6
