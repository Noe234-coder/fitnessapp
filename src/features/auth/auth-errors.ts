import { isAuthRetryableFetchError } from '@supabase/supabase-js'

/** The `code` of a Supabase error (auth, PostgREST), if it has one. */
export function errorCode(error: unknown): string | null {
  if (typeof error !== 'object' || error === null || !('code' in error)) {
    return null
  }
  return typeof error.code === 'string' && error.code !== '' ? error.code : null
}

/**
 * True when the request never got an answer: no signal, server unreachable or
 * a gateway error. Auth reports these as a retryable fetch error; PostgREST
 * as an error with no code whose message is the fetch failure.
 */
export function isNetworkError(error: unknown): boolean {
  if (isAuthRetryableFetchError(error)) return true
  if (typeof error !== 'object' || error === null) return false
  if ('name' in error && error.name === 'FunctionsFetchError') return true
  const message =
    'message' in error && typeof error.message === 'string' ? error.message : ''
  return (
    errorCode(error) === null &&
    /failed to fetch|fetch failed|networkerror|load failed|network request failed|aborted|timed? ?out/i.test(
      message,
    )
  )
}

/**
 * A response that comes from a gateway in front of the server, not from the
 * server itself (502, 503, 504): to the user it is the same as no connection,
 * and trying again later is the right thing to do.
 */
export function isGatewayStatus(status: number): boolean {
  return status >= 502 && status <= 504
}

export type LoginErrorKey =
  'errors.wrongCredentials' | 'errors.network' | 'errors.unknown'

/** The i18n key to show for a failed `signInWithPassword`. */
export function loginErrorKey(error: unknown): LoginErrorKey {
  if (isNetworkError(error)) return 'errors.network'
  if (errorCode(error) === 'invalid_credentials') {
    return 'errors.wrongCredentials'
  }
  return 'errors.unknown'
}
