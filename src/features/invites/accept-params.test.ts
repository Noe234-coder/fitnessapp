import { describe, expect, it } from 'vitest'

import { parseAcceptParams } from './accept-params'

const HASH = '87367a1745cbfade15a1d70535f924d0ca3672c504ad6d0fa589b516'

describe('parseAcceptParams', () => {
  it('reads an invite link', () => {
    expect(parseAcceptParams(`?token_hash=${HASH}&type=invite`)).toEqual({
      tokenHash: HASH,
      type: 'invite',
    })
  })

  it('reads a magic-link invite', () => {
    expect(parseAcceptParams(`token_hash=${HASH}&type=magiclink`)).toEqual({
      tokenHash: HASH,
      type: 'magiclink',
    })
  })

  it('accepts URLSearchParams and ignores other parameters', () => {
    const search = new URLSearchParams({
      type: 'invite',
      utm_source: 'whatsapp',
      token_hash: HASH,
    })
    expect(parseAcceptParams(search)?.tokenHash).toBe(HASH)
  })

  it('returns null when a parameter is missing', () => {
    expect(parseAcceptParams('')).toBeNull()
    expect(parseAcceptParams('?type=invite')).toBeNull()
    expect(parseAcceptParams(`?token_hash=${HASH}`)).toBeNull()
    expect(parseAcceptParams('?token_hash=&type=invite')).toBeNull()
  })

  it('returns null for a type the invite function never produces', () => {
    for (const type of ['recovery', 'signup', 'email', 'INVITE', '']) {
      expect(
        parseAcceptParams(`?token_hash=${HASH}&type=${type}`),
        type,
      ).toBeNull()
    }
  })

  it('returns null for a token that is not a plain URL value', () => {
    expect(parseAcceptParams('?token_hash=a%20b&type=invite')).toBeNull()
    expect(parseAcceptParams('?token_hash=<script>&type=invite')).toBeNull()
    expect(
      parseAcceptParams(`?token_hash=${'a'.repeat(513)}&type=invite`),
    ).toBeNull()
  })
})
