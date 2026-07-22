import { NextResponse } from 'next/server';

function htmlPage(body: string, status = 200) {
  return new NextResponse(
    `<!doctype html><html><body style="font-family: sans-serif; padding: 24px; max-width: 640px; margin: 0 auto;">${body}</body></html>`,
    { status, headers: { 'Content-Type': 'text/html; charset=utf-8' } }
  );
}

/**
 * One-off utility for the Instagram content-automation side project: receives the
 * OAuth redirect from Instagram Business Login, exchanges the code for a short-lived
 * token, then exchanges that for a 60-day long-lived token and displays it so it can
 * be copied into the automation's config. Not part of RubinTracker's own features.
 */
export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const code = searchParams.get('code');
  const error = searchParams.get('error');
  const errorDescription = searchParams.get('error_description');

  if (error) {
    return htmlPage(`<h1>Erro</h1><p>${error}: ${errorDescription}</p>`, 400);
  }

  if (!code) {
    return htmlPage('<h1>Nenhum código recebido</h1><p>Acesse esta página a partir do link de autorização do Instagram.</p>', 400);
  }

  const appId = process.env.INSTAGRAM_APP_ID;
  const appSecret = process.env.INSTAGRAM_APP_SECRET;
  const redirectUri = process.env.INSTAGRAM_REDIRECT_URI;

  if (!appId || !appSecret || !redirectUri) {
    return htmlPage(
      '<h1>Configuração ausente</h1><p>Faltam as variáveis de ambiente INSTAGRAM_APP_ID, INSTAGRAM_APP_SECRET ou INSTAGRAM_REDIRECT_URI no Vercel.</p>',
      500
    );
  }

  // Meta's own examples for this endpoint use multipart/form-data (curl -F), not
  // urlencoded — sending it urlencoded made the server unable to read client_id,
  // which is what produced the generic "Invalid platform app" error.
  const shortLivedForm = new FormData();
  shortLivedForm.set('client_id', appId);
  shortLivedForm.set('client_secret', appSecret);
  shortLivedForm.set('grant_type', 'authorization_code');
  shortLivedForm.set('redirect_uri', redirectUri);
  shortLivedForm.set('code', code.replace(/#_$/, ''));

  const shortLivedRes = await fetch('https://api.instagram.com/oauth/access_token', {
    method: 'POST',
    body: shortLivedForm,
  });
  const shortLivedData = await shortLivedRes.json();

  if (!shortLivedRes.ok || !shortLivedData.access_token) {
    const cleanedCode = code.replace(/#_$/, '');
    const debug = {
      httpStatus: shortLivedRes.status,
      appId,
      appIdLength: appId.length,
      appSecretLength: appSecret.length,
      redirectUriUsed: redirectUri,
      rawCode: code,
      rawCodeLength: code.length,
      cleanedCodeLength: cleanedCode.length,
      fullRequestUrl: req.url,
    };
    return htmlPage(
      `<h1>Erro ao trocar o código</h1><pre>${JSON.stringify(shortLivedData, null, 2)}</pre><h2>Diagnóstico</h2><pre>${JSON.stringify(debug, null, 2)}</pre>`,
      400
    );
  }

  const longLivedUrl = new URL('https://graph.instagram.com/access_token');
  longLivedUrl.searchParams.set('grant_type', 'ig_exchange_token');
  longLivedUrl.searchParams.set('client_secret', appSecret);
  longLivedUrl.searchParams.set('access_token', shortLivedData.access_token);

  const longLivedRes = await fetch(longLivedUrl.toString());
  const longLivedData = await longLivedRes.json();

  if (!longLivedRes.ok || !longLivedData.access_token) {
    return htmlPage(
      `<h1>Token de curta duração ok, mas a troca falhou</h1><pre>${JSON.stringify(longLivedData, null, 2)}</pre>`,
      400
    );
  }

  const days = Math.round(longLivedData.expires_in / 86400);

  return htmlPage(`
    <h1>Token gerado com sucesso!</h1>
    <p>Copie o valor abaixo e guarde num lugar seguro:</p>
    <textarea style="width: 100%; height: 100px;" readonly>${longLivedData.access_token}</textarea>
    <p>Válido por aproximadamente ${days} dias.</p>
  `);
}
