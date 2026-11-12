import i18n, { defaultLanguage } from '@/lib/i18n'
import { supabase } from '@/lib/supabase'

import { loginErrorKey, type LoginErrorKey } from './auth-errors'
import { createAuthStore } from './auth-store'
import { normalizeEmail } from './email'
import { parseLocale, type RoleHint } from './role-hint'
import { safeLocalStorage } from './storage'

/**
 * How long the guard waits for the role hint when there is no cached one.
 * It covers the whole request, including a token refresh that supabase-js
 * retries before sending it.
 */
const ROLE_HINT_TIMEOUT_MS = 12_000

/**
 * The caller's own rows: is he a trainer, does he have an active trainer,
 * and his language. RLS limits each query to rows he may read.
 */
async function fetchRoleHint(userId: string): Promise<RoleHint> {
  const signal = AbortSignal.timeout(ROLE_HINT_TIMEOUT_MS)
  const queries = Promise.all([
    supabase
      .from('trainers')
      .select('profile_id')
      .eq('profile_id', userId)
      .abortSignal(signal)
      .maybeSingle(),
    supabase
      .from('trainer_athletes')
      .select('id')
      .eq('athlete_id', userId)
      .is('ended_at', null)
      .limit(1)
      .abortSignal(signal),
    supabase
      .from('profiles')
      .select('locale')
      .eq('id', userId)
      .abortSignal(signal)
      .maybeSingle(),
  ])
  const timeout = new Promise<never>((_resolve, reject) => {
    signal.addEventListener('abort', () => reject(new Error('timeout')), {
      once: true,
    })
  })
  const [trainer, link, profile] = await Promise.race([queries, timeout])
  // An error on any of them (no connection, or a request sent without a
  // valid session) must not be read as "not a trainer, no link".
  if (trainer.error || link.error || profile.error) {
    throw new Error('role hint unavailable')
  }
  return {
    isTrainer: trainer.data !== null,
    hasActiveLink: link.data.length > 0,
    locale: parseLocale(profile.data?.locale),
  }
}

export const authStore = createAuthStore({
  auth: {
    onAuthStateChange(callback) {
      const { data } = supabase.auth.onAuthStateChange(callback)
      return () => data.subscription.unsubscribe()
    },
    async getSession() {
      const { data, error } = await supabase.auth.getSession()
      return { session: data.session, error }
    },
    signOutLocal: () => supabase.auth.signOut({ scope: 'local' }),
  },
  storage: safeLocalStorage,
  fetchRoleHint,
  isOnline: () => navigator.onLine,
  onOnline(callback) {
    window.addEventListener('online', callback)
    return () => window.removeEventListener('online', callback)
  },
  onLanguage(language) {
    const next = language ?? defaultLanguage
    if (i18n.language !== next) void i18n.changeLanguage(next)
  },
})

// Started when the module loads, before React renders, so no auth event of
// the client's own start-up is missed.
authStore.start()

/**
 * Signs in with email and password. Returns the i18n key of the error, or
 * null on success (the store then moves to `signed_in` by itself).
 */
export async function signInWithPassword(
  email: string,
  password: string,
): Promise<LoginErrorKey | null> {
  if (!navigator.onLine) return 'errors.network'
  await authStore.beforeSignIn()
  const { error } = await supabase.auth.signInWithPassword({
    email: normalizeEmail(email),
    password,
  })
  return error ? loginErrorKey(error) : null
}
