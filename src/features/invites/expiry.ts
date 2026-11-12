export type Expiry =
  { expired: true } | { expired: false; value: number; unit: 'hour' | 'minute' }

const MINUTE_MS = 60_000

/**
 * How long an invitation still has, rounded down so the screen never
 * promises more time than is left. An unreadable date counts as expired.
 */
export function expiryOf(expiresAt: string, now: number): Expiry {
  const remainingMs = Date.parse(expiresAt) - now
  if (!(remainingMs > 0)) return { expired: true }
  const minutes = Math.max(1, Math.floor(remainingMs / MINUTE_MS))
  return minutes < 60
    ? { expired: false, value: minutes, unit: 'minute' }
    : { expired: false, value: Math.floor(minutes / 60), unit: 'hour' }
}
