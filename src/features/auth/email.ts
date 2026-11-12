import { z } from 'zod'

/** Emails are stored and compared in lowercase, without surrounding spaces. */
export function normalizeEmail(value: string): string {
  return value.trim().toLowerCase()
}

/** A normalized, valid email address. */
export const emailSchema = z
  .string()
  .transform(normalizeEmail)
  .pipe(z.email().max(254))
