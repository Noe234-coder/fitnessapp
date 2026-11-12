import { z } from 'zod'

import { defaultLanguage, supportedLanguages } from '@/lib/i18n'

import { parseJson, type KeyValueStorage } from './storage'

/**
 * What the route guard needs to know about the signed-in user, cached per
 * user so the app can route without a connection. It is a routing hint only:
 * what a user may read or write is decided by RLS.
 */
export const roleHintSchema = z.object({
  isTrainer: z.boolean(),
  hasActiveLink: z.boolean(),
  locale: z.enum(supportedLanguages),
})

export type RoleHint = z.infer<typeof roleHintSchema>

/** `unlinked`: neither a trainer nor an athlete with an active trainer. */
export type Role = 'trainer' | 'athlete' | 'unlinked'

export function roleHintKey(userId: string): string {
  return `fitnessapp.role-hint.${userId}`
}

/** Null for anything that is not a complete hint (missing, corrupt, old). */
export function parseRoleHint(raw: string | null): RoleHint | null {
  const result = roleHintSchema.safeParse(parseJson(raw))
  return result.success ? result.data : null
}

/** A trainer who is also his own athlete is routed as a trainer. */
export function roleFromHint(hint: RoleHint): Role {
  if (hint.isTrainer) return 'trainer'
  return hint.hasActiveLink ? 'athlete' : 'unlinked'
}

/** `profiles.locale` as a supported language; Spanish for anything else. */
export function parseLocale(value: unknown): RoleHint['locale'] {
  const result = roleHintSchema.shape.locale.safeParse(value)
  return result.success ? result.data : defaultLanguage
}

export function readRoleHint(
  storage: KeyValueStorage,
  userId: string,
): RoleHint | null {
  return parseRoleHint(storage.getItem(roleHintKey(userId)))
}

export function writeRoleHint(
  storage: KeyValueStorage,
  userId: string,
  hint: RoleHint,
) {
  storage.setItem(roleHintKey(userId), JSON.stringify(hint))
}

export function clearRoleHint(storage: KeyValueStorage, userId: string) {
  storage.removeItem(roleHintKey(userId))
}
