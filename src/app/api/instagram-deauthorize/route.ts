import { NextResponse } from 'next/server';

/**
 * Meta calls this when a user removes the Instagram app connection. Required
 * to be a filled-in URL for the app's Instagram Login config to be considered
 * complete, even though this bot doesn't store any per-user data to clean up.
 */
export async function POST() {
  return NextResponse.json({ ok: true });
}
