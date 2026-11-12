import { z } from 'zod'

import { parseJson, type KeyValueStorage } from './storage'

/** What the app needs to know about the signed-in user to render offline. */
export type AuthUser = {
  id: string
  email: string | null
  fullName: string | null
}

const authUserSchema = z.object({
  id: z.string().min(1),
  email: z.string().nullable(),
  fullName: z.string().nullable(),
})

/**
 * The last user this device signed in as. It is the app's own record that a
 * session exists: supabase-js reports "no session" when the stored access
 * token has expired and the refresh cannot reach the server, which is the
 * normal state of an athlete opening the app at the gym.
 */
export const STORED_USER_KEY = 'fitnessapp.auth.user'

/** Set while a logout has not finished removing the stored session. */
export const LOGOUT_PENDING_KEY = 'fitnessapp.auth.logout-pending'

export function parseStoredUser(raw: string | null): AuthUser | null {
  const result = authUserSchema.safeParse(parseJson(raw))
  return result.success ? result.data : null
}

export function readStoredUser(storage: KeyValueStorage): AuthUser | null {
  return parseStoredUser(storage.getItem(STORED_USER_KEY))
}

export function writeStoredUser(storage: KeyValueStorage, user: AuthUser) {
  storage.setItem(STORED_USER_KEY, JSON.stringify(user))
}

export function clearStoredUser(storage: KeyValueStorage) {
  storage.removeItem(STORED_USER_KEY)
}

/** The user of a Supabase session, reduced to what the app keeps. */
export type SessionUser = {
  id: string
  email?: string
  user_metadata?: Record<string, unknown>
}

export function toAuthUser(user: SessionUser): AuthUser {
  const fullName = user.user_metadata?.full_name
  return {
    id: user.id,
    email: user.email ?? null,
    fullName:
      typeof fullName === 'string' && fullName.trim() !== ''
        ? fullName.trim()
        : null,
  }
}
