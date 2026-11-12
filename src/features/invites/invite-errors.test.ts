import { AuthApiError, AuthRetryableFetchError } from '@supabase/supabase-js'
import { describe, expect, it } from 'vitest'

import en from '@/locales/en/common.json'
import es from '@/locales/es/common.json'

import {
  ACCEPT_ERROR_KEYS,
  acceptErrorKey,
  isSamePasswordError,
  passwordErrorKey,
  verifyErrorKey,
} from './invite-errors'

type Tree = { [key: string]: string | Tree }

/** The translation at a dotted key, or undefined. */
function lookup(tree: Tree, key: string): string | undefined {
  const value = key
    .split('.')
    .reduce<string | Tree | undefined>(
      (node, part) => (typeof node === 'object' ? node[part] : undefined),
      tree,
    )
  return typeof value === 'string' ? value : undefined
}

function expectInBothLocales(key: string) {
  expect(lookup(es, key), `es: ${key}`).toBeTruthy()
  expect(lookup(en, key), `en: ${key}`).toBeTruthy()
}

const NETWORK = new AuthRetryableFetchError('Failed to fetch', 0)

describe('acceptErrorKey', () => {
  // As PostgREST returns what accept_invitation() raises.
  const raised = (message: string) => ({
    code: 'P0001',
    details: null,
    hint: null,
    message,
  })

  it('maps every code accept_invitation() raises (CLAUDE.md "Invites")', () => {
    expect(acceptErrorKey(raised('not_authenticated'))).toBe(
      'errors.accept.notAuthenticated',
    )
    expect(acceptErrorKey(raised('invitation_not_found'))).toBe(
      'errors.accept.invitationNotFound',
    )
    expect(acceptErrorKey(raised('invitation_expired'))).toBe(
      'errors.accept.invitationExpired',
    )
    expect(acceptErrorKey(raised('already_has_trainer'))).toBe(
      'errors.accept.alreadyHasTrainer',
    )
  })

  it('maps each code to a key present in both locales', () => {
    expect(Object.keys(ACCEPT_ERROR_KEYS).sort()).toEqual([
      'already_has_trainer',
      'invitation_expired',
      'invitation_not_found',
      'not_authenticated',
    ])
    for (const key of Object.values(ACCEPT_ERROR_KEYS)) expectInBothLocales(key)
    expectInBothLocales('errors.network')
    expectInBothLocales('errors.unknown')
  })

  it('treats a call without a valid session as not authenticated', () => {
    expect(
      acceptErrorKey({
        code: '42501',
        message: 'permission denied for function accept_invitation',
      }),
    ).toBe('errors.accept.notAuthenticated')
    expect(acceptErrorKey({ code: 'PGRST301', message: 'JWT expired' })).toBe(
      'errors.accept.notAuthenticated',
    )
  })

  it('maps a network failure and anything unexpected', () => {
    expect(
      acceptErrorKey({ message: 'TypeError: Failed to fetch', code: '' }),
    ).toBe('errors.network')
    expect(acceptErrorKey(raised('something_new'))).toBe('errors.unknown')
    expect(acceptErrorKey(raised('toString'))).toBe('errors.unknown')
    expect(acceptErrorKey(null)).toBe('errors.unknown')
  })
})

describe('verifyErrorKey', () => {
  it('maps a spent or expired token, the network and the rest', () => {
    expect(
      verifyErrorKey(
        new AuthApiError(
          'Email link is invalid or has expired',
          403,
          'otp_expired',
        ),
      ),
    ).toBe('errors.linkExpired')
    expect(verifyErrorKey(NETWORK)).toBe('errors.network')
    expect(
      verifyErrorKey(new AuthApiError('boom', 500, 'unexpected_failure')),
    ).toBe('errors.unknown')
    expectInBothLocales('errors.linkExpired')
  })
})

describe('passwordErrorKey', () => {
  it('maps a weak password, the network, a lost session and the rest', () => {
    expect(
      passwordErrorKey(new AuthApiError('too short', 422, 'weak_password')),
    ).toBe('errors.weakPassword')
    expect(passwordErrorKey(NETWORK)).toBe('errors.network')
    expect(passwordErrorKey({ name: 'AuthSessionMissingError' })).toBe(
      'errors.accept.notAuthenticated',
    )
    expect(passwordErrorKey(new Error('boom'))).toBe('errors.unknown')
    expectInBothLocales('errors.weakPassword')
  })

  it('recognises a repeated password change as already done', () => {
    expect(
      isSamePasswordError(new AuthApiError('same', 422, 'same_password')),
    ).toBe(true)
    expect(isSamePasswordError(NETWORK)).toBe(false)
  })
})
