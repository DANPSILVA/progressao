import { NextResponse } from 'next/server';
import crypto from 'crypto';

/**
 * Meta's required data-deletion callback: must respond with a status page URL
 * and a confirmation code. Required to be a filled-in URL for the app's
 * Instagram Login config to be considered complete, even though this bot
 * doesn't store any per-user data to delete.
 */
export async function POST(req: Request) {
  const confirmationCode = crypto.randomBytes(8).toString('hex');
  const url = new URL(req.url);
  const statusUrl = `${url.origin}/api/instagram-data-deletion?id=${confirmationCode}`;
  return NextResponse.json({ url: statusUrl, confirmation_code: confirmationCode });
}

export async function GET() {
  return new NextResponse(
    '<!doctype html><html><body style="font-family: sans-serif; padding: 24px;"><h1>Nenhum dado armazenado</h1><p>Este app não guarda dados pessoais associados à sua conta do Instagram.</p></body></html>',
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } }
  );
}
