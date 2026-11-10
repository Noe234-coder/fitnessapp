import { z } from 'zod'

// Only public values belong here: everything prefixed with VITE_ is bundled
// into the client. The publishable key is the only Supabase key the app uses.
const envSchema = z.object({
  VITE_SUPABASE_URL: z.url(),
  VITE_SUPABASE_PUBLISHABLE_KEY: z.string().startsWith('sb_publishable_'),
})

export type Env = z.infer<typeof envSchema>

export type EnvResult =
  { ok: true; env: Env } | { ok: false; invalidKeys: string[] }

export function parseEnv(source: Record<string, unknown>): EnvResult {
  const result = envSchema.safeParse(source)
  if (result.success) {
    return { ok: true, env: result.data }
  }
  const invalidKeys = [
    ...new Set(result.error.issues.map((issue) => String(issue.path[0]))),
  ]
  return { ok: false, invalidKeys }
}

/** Checked once at startup; main.tsx shows an error screen when it is not ok. */
export const envResult = parseEnv(import.meta.env)

/** The validated environment. Throws if it is invalid (main.tsx checks first). */
export function getEnv(): Env {
  if (!envResult.ok) {
    throw new Error(
      `Invalid environment variables: ${envResult.invalidKeys.join(', ')}`,
    )
  }
  return envResult.env
}
