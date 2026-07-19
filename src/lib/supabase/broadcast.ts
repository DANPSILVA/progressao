import { createClient } from '@supabase/supabase-js';
import { HUNTS_UPDATES_CHANNEL } from '@/lib/supabase/channels';

const CHANNEL = HUNTS_UPDATES_CHANNEL;

/** Fire-and-forget notice so friends' ranking panels can refetch live. Best-effort: a
 *  failed broadcast never blocks the hunt CRUD response, it just delays the next
 *  auto-refresh until someone reloads the page. */
export async function broadcastHuntChange(userId: string) {
  try {
    const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
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
