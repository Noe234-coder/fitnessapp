// The project's secret API key, from SUPABASE_SECRET_KEYS: a variable Supabase
// sets for every Edge Function (hosted and local), holding a JSON object of
// the project's secret keys by name. This function uses the one named
// `default`. It replaces the legacy service-role key variable; there is no
// fallback to it.
//
// No Deno or npm imports here: scripts/test-invite-function.mjs imports this
// file in Node to check it.

/** The `default` secret key, or null if the value is missing or malformed. */
export function defaultSecretKey(raw: string | undefined): string | null {
  if (!raw) return null
  let keys: unknown
  try {
    keys = JSON.parse(raw)
  } catch {
    return null
  }
  if (typeof keys !== 'object' || keys === null || Array.isArray(keys)) {
    return null
  }
  const key = (keys as Record<string, unknown>).default
  return typeof key === 'string' && key.trim() !== '' ? key : null
}
