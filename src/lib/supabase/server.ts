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
