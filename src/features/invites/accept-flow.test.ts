import { describe, expect, it } from 'vitest'

import {
  parsePendingAccept,
  resumeStep,
  type PendingAccept,
} from './accept-flow'
import type { AcceptParams } from './accept-params'

const LINK: AcceptParams = { tokenHash: 'abc123', type: 'invite' }
const ME = 'user-1'

function pending(overrides: Partial<PendingAccept> = {}): PendingAccept {
  return { userId: ME, type: 'invite', passwordSet: false, ...overrides }
}

describe('resumeStep', () => {
  it('asks to confirm when a link is opened, signed in or not', () => {
    expect(
      resumeStep({ params: LINK, pending: null, userId: null, role: null }),
    ).toBe('confirm')
    expect(
      resumeStep({ params: LINK, pending: null, userId: ME, role: 'athlete' }),
    ).toBe('confirm')
  })

  it('resumes at the password step for a new account without a password', () => {
    expect(
      resumeStep({
        params: null,
        pending: pending(),
        userId: ME,
        role: 'unlinked',
      }),
    ).toBe('password')
  })

  it('resumes at the link step once the password is set', () => {
    expect(
      resumeStep({
        params: null,
        pending: pending({ passwordSet: true }),
        userId: ME,
        role: 'unlinked',
      }),
    ).toBe('link')
  })

  it('has no password step for a magic-link invite', () => {
    expect(
      resumeStep({
        params: null,
        pending: pending({ type: 'magiclink' }),
        userId: ME,
        role: 'unlinked',
      }),
    ).toBe('link')
  })

  it('resumes without knowing the role (no connection, no cache)', () => {
    expect(
      resumeStep({ params: null, pending: pending(), userId: ME, role: null }),
    ).toBe('password')
  })

  it('lets a setup in progress win over a link in the URL', () => {
    expect(
      resumeStep({
        params: LINK,
        pending: pending({ passwordSet: true }),
        userId: ME,
        role: 'unlinked',
      }),
    ).toBe('link')
  })

  it("ignores another user's unfinished setup", () => {
    const other = pending({ userId: 'user-2' })
    expect(
      resumeStep({ params: null, pending: other, userId: ME, role: 'athlete' }),
    ).toBe('home')
    expect(
      resumeStep({ params: LINK, pending: other, userId: ME, role: 'athlete' }),
    ).toBe('confirm')
    expect(
      resumeStep({ params: null, pending: other, userId: null, role: null }),
    ).toBe('invalid')
  })

  it('is an invalid link with no parameters and nobody signed in', () => {
    expect(
      resumeStep({ params: null, pending: null, userId: null, role: null }),
    ).toBe('invalid')
  })

  it('offers to accept to a signed-in user with no trainer', () => {
    expect(
      resumeStep({ params: null, pending: null, userId: ME, role: 'unlinked' }),
    ).toBe('unlinked')
  })

  it('sends trainers and linked athletes home', () => {
    for (const role of ['trainer', 'athlete'] as const) {
      expect(
        resumeStep({ params: null, pending: null, userId: ME, role }),
      ).toBe('home')
    }
  })

  it('waits for the role of a signed-in user before deciding', () => {
    expect(
      resumeStep({ params: null, pending: null, userId: ME, role: null }),
    ).toBe('checking')
  })
})

describe('parsePendingAccept', () => {
  it('reads what the flow stores', () => {
    const value = pending({ passwordSet: true })
    expect(parsePendingAccept(JSON.stringify(value))).toEqual(value)
  })

  it('keeps nothing but the three fields: no token can ride along', () => {
    const stored = JSON.stringify({ ...pending(), token_hash: 'abc123' })
    expect(parsePendingAccept(stored)).toEqual(pending())
  })

  it('returns null for missing, corrupt or incomplete values', () => {
    expect(parsePendingAccept(null)).toBeNull()
    expect(parsePendingAccept('{"type":"invite"')).toBeNull()
    expect(
      parsePendingAccept('{"type":"invite","passwordSet":false}'),
    ).toBeNull()
    expect(
      parsePendingAccept(
        '{"userId":"u","type":"recovery","passwordSet":false}',
      ),
    ).toBeNull()
  })
})
