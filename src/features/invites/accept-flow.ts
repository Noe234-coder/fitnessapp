import { z } from 'zod'

import type { Role } from '@/features/auth/role-hint'
import { parseJson, type KeyValueStorage } from '@/features/auth/storage'

import {
  inviteLinkTypes,
  type AcceptParams,
  type InviteLinkType,
} from './accept-params'

/** The app's own minimum; the server may allow shorter passwords. */
export const MIN_PASSWORD_LENGTH = 8

/**
 * What is left to do after the invite token has been exchanged for a session,
 * kept until `accept_invitation()` succeeds so the flow survives a reload or
 * a lost connection. It never holds the token: by then it has been spent.
 */
export type PendingAccept = {
  /** Whose setup this is; ignored when someone else is signed in. */
  userId: string
  type: InviteLinkType
  passwordSet: boolean
}

const pendingAcceptSchema = z.object({
  userId: z.string().min(1),
  type: z.enum(inviteLinkTypes),
  passwordSet: z.boolean(),
})

export const PENDING_ACCEPT_KEY = 'fitnessapp.accept-invite.pending'

export function parsePendingAccept(raw: string | null): PendingAccept | null {
  const result = pendingAcceptSchema.safeParse(parseJson(raw))
  return result.success ? result.data : null
}

export function readPendingAccept(
  storage: KeyValueStorage,
): PendingAccept | null {
  return parsePendingAccept(storage.getItem(PENDING_ACCEPT_KEY))
}

export function writePendingAccept(
  storage: KeyValueStorage,
  pending: PendingAccept,
) {
  storage.setItem(PENDING_ACCEPT_KEY, JSON.stringify(pending))
}

export function clearPendingAccept(storage: KeyValueStorage) {
  storage.removeItem(PENDING_ACCEPT_KEY)
}

/**
 * - `confirm`: a link was opened; nothing has been sent yet.
 * - `password`: signed in through an invite link, no password yet.
 * - `link`: signed in, `accept_invitation()` still has to succeed.
 * - `unlinked`: signed in with no trainer and no setup in progress.
 * - `home`: nothing to do here.
 * - `checking`: signed in, but the role is not known yet.
 * - `invalid`: no usable link and nobody signed in.
 */
export type AcceptStep =
  'confirm' | 'password' | 'link' | 'unlinked' | 'home' | 'checking' | 'invalid'

/**
 * Where the accept page stands, from local state only. A setup in progress
 * for the signed-in user wins over a link in the URL: its token is spent or
 * about to be, and the remaining steps need only the session.
 */
export function resumeStep(input: {
  params: AcceptParams | null
  pending: PendingAccept | null
  userId: string | null
  role: Role | null
}): AcceptStep {
  const { params, pending, userId, role } = input
  if (pending && userId !== null && pending.userId === userId) {
    return pending.type === 'invite' && !pending.passwordSet
      ? 'password'
      : 'link'
  }
  if (params) return 'confirm'
  if (userId === null) return 'invalid'
  if (role === null) return 'checking'
  return role === 'unlinked' ? 'unlinked' : 'home'
}
