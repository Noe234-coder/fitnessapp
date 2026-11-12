import { authStore } from '@/features/auth/auth'
import { isGatewayStatus } from '@/features/auth/auth-errors'
import { supabase } from '@/lib/supabase'

import type { AcceptParams } from './accept-params'
import {
  acceptErrorKey,
  isSamePasswordError,
  passwordErrorKey,
  verifyErrorKey,
  type AcceptErrorKey,
  type PasswordErrorKey,
  type VerifyErrorKey,
} from './invite-errors'

// The three server calls of the accept flow. Each returns the i18n key of
// its error instead of throwing, and none of them logs anything: the token
// and the session must never reach the console.

/**
 * Exchanges the invite token for a session. The token is used once: after
 * this call, whatever the answer, the caller forgets it.
 */
export async function verifyInvite(
  params: AcceptParams,
): Promise<{ userId: string } | { errorKey: VerifyErrorKey }> {
  if (!navigator.onLine) return { errorKey: 'errors.network' }
  try {
    await authStore.beforeSignIn()
    const { data, error } = await supabase.auth.verifyOtp({
      token_hash: params.tokenHash,
      type: params.type,
    })
    if (error) return { errorKey: verifyErrorKey(error) }
    if (!data.user || !data.session) return { errorKey: 'errors.unknown' }
    return { userId: data.user.id }
  } catch (error) {
    return { errorKey: verifyErrorKey(error) }
  }
}

/** Sets the password of the signed-in user. Safe to repeat. */
export async function setPassword(
  password: string,
): Promise<PasswordErrorKey | null> {
  if (!navigator.onLine) return 'errors.network'
  try {
    const { error } = await supabase.auth.updateUser({ password })
    if (!error || isSamePasswordError(error)) return null
    return passwordErrorKey(error)
  } catch (error) {
    return passwordErrorKey(error)
  }
}

/** Links the signed-in user to the trainer who invited him. Safe to repeat. */
export async function acceptInvitation(): Promise<AcceptErrorKey | null> {
  if (!navigator.onLine) return 'errors.network'
  try {
    const { error, status } = await supabase.rpc('accept_invitation')
    if (!error) return null
    return status === 0 || isGatewayStatus(status)
      ? 'errors.network'
      : acceptErrorKey(error)
  } catch (error) {
    return acceptErrorKey(error)
  }
}
