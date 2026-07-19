/** Normalizes NEXT_PUBLIC_SUPABASE_URL down to its origin — Supabase's dashboard shows this
 *  value with different trailing paths in different tabs (e.g. `/rest/v1/`), and pasting
 *  one of those in by mistake breaks every API call with an "Invalid path" error. */
export function getSupabaseUrl(): string {
  return new URL(process.env.NEXT_PUBLIC_SUPABASE_URL!).origin;
}
