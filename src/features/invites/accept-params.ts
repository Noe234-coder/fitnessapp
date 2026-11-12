import { z } from 'zod'

/** How Supabase names the two kinds of token the invite function hands out. */
export const inviteLinkTypes = ['invite', 'magiclink'] as const
export type InviteLinkType = (typeof inviteLinkTypes)[number]

export type AcceptParams = {
  tokenHash: string
  type: InviteLinkType
}

const acceptParamsSchema = z.object({
  // The hashed token is opaque: only its shape as a URL value is checked.
  token_hash: z
    .string()
    .min(1)
    .max(512)
    .regex(/^[A-Za-z0-9._~-]+$/),
  type: z.enum(inviteLinkTypes),
})

/**
 * Reads `?token_hash=…&type=invite|magiclink` from an invite link. Null when
 * a parameter is missing or not what the invite function produces. Pure: the
 * page calls it on load and talks to the server only when "Accept" is tapped.
 */
export function parseAcceptParams(
  search: string | URLSearchParams,
): AcceptParams | null {
  const query =
    typeof search === 'string' ? new URLSearchParams(search) : search
  const result = acceptParamsSchema.safeParse({
    token_hash: query.get('token_hash') ?? undefined,
    type: query.get('type') ?? undefined,
  })
  if (!result.success) return null
  return { tokenHash: result.data.token_hash, type: result.data.type }
}
