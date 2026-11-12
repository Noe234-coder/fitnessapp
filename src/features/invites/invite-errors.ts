import { errorCode, isNetworkError } from '@/features/auth/auth-errors'

type CommonErrorKey = 'errors.network' | 'errors.unknown'

function messageOf(error: unknown): string {
  return typeof error === 'object' &&
    error !== null &&
    'message' in error &&
    typeof error.message === 'string'
    ? error.message
    : ''
}

// --- verifyOtp --------------------------------------------------------------

export type VerifyErrorKey = 'errors.linkExpired' | CommonErrorKey

/**
 * A spent, expired or unknown token all come back as `otp_expired`. So does
 * a token whose answer was lost on the way back: it is spent by then.
 */
export function verifyErrorKey(error: unknown): VerifyErrorKey {
  if (isNetworkError(error)) return 'errors.network'
  return errorCode(error) === 'otp_expired'
    ? 'errors.linkExpired'
    : 'errors.unknown'
}

// --- updateUser({ password }) -------------------------------------------------

export type PasswordErrorKey =
  'errors.weakPassword' | 'errors.accept.notAuthenticated' | CommonErrorKey

/**
 * The server refuses a password equal to the current one. In this flow that
 * only happens when an earlier attempt did get through and its answer was
 * lost, so it counts as done.
 */
export function isSamePasswordError(error: unknown): boolean {
  return errorCode(error) === 'same_password'
}

export function passwordErrorKey(error: unknown): PasswordErrorKey {
  if (isNetworkError(error)) return 'errors.network'
  if (errorCode(error) === 'weak_password') return 'errors.weakPassword'
  if (
    typeof error === 'object' &&
    error !== null &&
    'name' in error &&
    error.name === 'AuthSessionMissingError'
  ) {
    return 'errors.accept.notAuthenticated'
  }
  return 'errors.unknown'
}

// --- rpc('accept_invitation') -------------------------------------------------

/** The stable codes `public.accept_invitation()` raises as its message. */
export const ACCEPT_ERROR_KEYS = {
  not_authenticated: 'errors.accept.notAuthenticated',
  invitation_not_found: 'errors.accept.invitationNotFound',
  invitation_expired: 'errors.accept.invitationExpired',
  already_has_trainer: 'errors.accept.alreadyHasTrainer',
} as const

export type AcceptErrorKey =
  (typeof ACCEPT_ERROR_KEYS)[keyof typeof ACCEPT_ERROR_KEYS] | CommonErrorKey

export function acceptErrorKey(error: unknown): AcceptErrorKey {
  if (isNetworkError(error)) return 'errors.network'
  const message = messageOf(error)
  if (Object.hasOwn(ACCEPT_ERROR_KEYS, message)) {
    return ACCEPT_ERROR_KEYS[message as keyof typeof ACCEPT_ERROR_KEYS]
  }
  // Called without a valid session: the request goes out with the
  // publishable key and the database refuses it (42501), or PostgREST
  // rejects the token (PGRST301, PGRST302).
  const code = errorCode(error)
  if (code === '42501' || code === 'PGRST301' || code === 'PGRST302') {
    return 'errors.accept.notAuthenticated'
  }
  return 'errors.unknown'
}

// --- Edge Function invite-athlete --------------------------------------------

/** The `{ error }` codes of the invite-athlete function (CLAUDE.md "Invites"). */
export const INVITE_ERROR_KEYS = {
  unauthorized: 'errors.invite.unauthorized',
  forbidden: 'errors.invite.forbidden',
  invalid_request: 'errors.invite.invalidRequest',
  already_linked: 'errors.invite.alreadyLinked',
  invite_failed: 'errors.invite.inviteFailed',
  server_misconfigured: 'errors.invite.serverMisconfigured',
  method_not_allowed: 'errors.invite.methodNotAllowed',
} as const

export type InviteErrorKey =
  (typeof INVITE_ERROR_KEYS)[keyof typeof INVITE_ERROR_KEYS] | CommonErrorKey

/** The i18n key for the `error` code in the function's response body. */
export function inviteErrorKey(code: unknown): InviteErrorKey {
  return typeof code === 'string' && Object.hasOwn(INVITE_ERROR_KEYS, code)
    ? INVITE_ERROR_KEYS[code as keyof typeof INVITE_ERROR_KEYS]
    : 'errors.unknown'
}
