import { AuthApiError, AuthRetryableFetchError } from '@supabase/supabase-js'
import { describe, expect, it } from 'vitest'

import en from '@/locales/en/common.json'
import es from '@/locales/es/common.json'

import { isNetworkError, loginErrorKey } from './auth-errors'

describe('isNetworkError', () => {
  it('recognises a request that got no answer', () => {
    expect(isNetworkError(new AuthRetryableFetchError('fetch failed', 0))).toBe(
      true,
    )
    // PostgREST, as supabase-js returns it in Chrome, Firefox and Safari.
    for (const message of [
      'TypeError: Failed to fetch',
      'TypeError: NetworkError when attempting to fetch resource.',
      'TypeError: Load failed',
    ]) {
      expect(isNetworkError({ message, code: '', details: '' }), message).toBe(
        true,
      )
    }
    expect(isNetworkError({ name: 'FunctionsFetchError', message: 'x' })).toBe(
      true,
    )
  })

  it('does not take an answer from the server for a network error', () => {
    expect(
      isNetworkError(
        new AuthApiError(
          'Invalid login credentials',
          400,
          'invalid_credentials',
        ),
      ),
    ).toBe(false)
    expect(
      isNetworkError({ code: 'P0001', message: 'invitation_not_found' }),
    ).toBe(false)
    expect(isNetworkError(null)).toBe(false)
    expect(isNetworkError('Failed to fetch')).toBe(false)
  })
})

describe('loginErrorKey', () => {
  it('maps wrong credentials, no connection and anything else', () => {
    expect(
      loginErrorKey(
        new AuthApiError(
          'Invalid login credentials',
          400,
          'invalid_credentials',
        ),
      ),
    ).toBe('errors.wrongCredentials')
    expect(loginErrorKey(new AuthRetryableFetchError('fetch failed', 0))).toBe(
      'errors.network',
    )
    expect(
      loginErrorKey(new AuthApiError('boom', 500, 'unexpected_failure')),
    ).toBe('errors.unknown')
    expect(loginErrorKey(undefined)).toBe('errors.unknown')
  })

  it('maps to keys that exist in both locales', () => {
    for (const key of ['wrongCredentials', 'network', 'unknown'] as const) {
      expect(es.errors[key]).toBeTruthy()
      expect(en.errors[key]).toBeTruthy()
    }
  })
})
