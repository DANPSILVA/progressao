import { createClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

if (!url || !anonKey) {
  // do not throw in modules — allow runtime check in server/client usage
  console.warn('Supabase URL or ANON KEY not set');
}

export const supabase = createClient(url, anonKey);
