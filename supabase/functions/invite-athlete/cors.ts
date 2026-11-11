// CORS for a function called from the browser. The local gateway adds no CORS
// headers on /functions/v1 (Supabase CLI 3.1.0), so the function answers the
// preflight and sends the headers on every response itself.

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
