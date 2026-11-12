import { FunctionsFetchError, FunctionsHttpError } from '@supabase/supabase-js'
import { z } from 'zod'

import { isGatewayStatus } from '@/features/auth/auth-errors'
import { supabase } from '@/lib/supabase'

import { inviteErrorKey, type InviteErrorKey } from './invite-errors'

const inviteResponseSchema = z.object({ url: z.url() })

/**
 * Asks the invite-athlete function for an invite link. The link carries the
 * invite token: it is returned to the caller and nothing else is done with
 * it here (no log, no cache).
 */
export async function inviteAthlete(input: {
  email: string
  fullName: string | null
}): Promise<{ url: string } | { errorKey: InviteErrorKey }> {
  if (!navigator.onLine) return { errorKey: 'errors.network' }
  try {
    const { data, error } = await supabase.functions.invoke<unknown>(
      'invite-athlete',
      {
        body: {
          email: input.email,
          ...(input.fullName ? { full_name: input.fullName } : {}),
        },
      },
    )
    if (error instanceof FunctionsFetchError) {
      return { errorKey: 'errors.network' }
    }
    if (error instanceof FunctionsHttpError) {
      // The function answers every refusal with { error: <code> }.
      const response = error.context as Response
      if (isGatewayStatus(response.status)) {
        return { errorKey: 'errors.network' }
      }
      const body: unknown = await response.json().catch(() => null)
      const code =
        typeof body === 'object' && body !== null && 'error' in body
          ? body.error
          : null
      return { errorKey: inviteErrorKey(code) }
    }
    if (error) return { errorKey: 'errors.unknown' }
    const parsed = inviteResponseSchema.safeParse(data)
    return parsed.success
      ? { url: parsed.data.url }
      : { errorKey: 'errors.unknown' }
  } catch {
    return { errorKey: 'errors.unknown' }
  }
}

export type PendingInvitation = {
  id: string
  email: string
  expires_at: string
}

/** The trainer's invitations nobody has accepted yet, newest first. */
export async function fetchPendingInvitations(
  trainerId: string,
): Promise<PendingInvitation[]> {
  const { data, error } = await supabase
    .from('invitations')
    .select('id, email, expires_at')
    .eq('trainer_id', trainerId)
    .is('accepted_at', null)
    .order('created_at', { ascending: false })
    .limit(100)
  if (error) throw new Error('pending invitations unavailable')
  return data
}
