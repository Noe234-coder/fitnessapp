// CORS for a function called from the browser: the function answers the
// preflight and sends the headers on every response itself, so it never
// depends on a gateway adding them.
//
// Observed on the local stack (Supabase CLI 3.1.0): the gateway answers the
// preflight itself and replaces Access-Control-Allow-Origin with `*` on the
// responses it proxies. The single-origin rule below is therefore only visible
// when the function is called directly, which is how
// scripts/test-invite-function.mjs checks it.

// Every header supabase-js may send (the list in `@supabase/supabase-js/cors`).
const ALLOWED_HEADERS = [
  'authorization',
  'x-client-info',
  'apikey',
  'content-type',
  'x-retry-count',
  'traceparent',
  'tracestate',
  'baggage',
].join(', ')

/** CORS headers that allow exactly one origin: the app's. Never `*`. */
export function corsHeaders(appOrigin: string): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': appOrigin,
    'Access-Control-Allow-Headers': ALLOWED_HEADERS,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  }
}
