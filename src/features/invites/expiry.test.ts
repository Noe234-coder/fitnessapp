import { describe, expect, it } from 'vitest'

import { expiryOf } from './expiry'

const NOW = Date.parse('2026-11-12T10:00:00Z')
const at = (iso: string) => expiryOf(iso, NOW)

describe('expiryOf', () => {
  it('counts whole hours, rounded down', () => {
    expect(at('2026-11-13T10:00:00Z')).toEqual({
      expired: false,
      value: 24,
      unit: 'hour',
    })
    expect(at('2026-11-13T09:59:00Z')).toEqual({
      expired: false,
      value: 23,
      unit: 'hour',
    })
    expect(at('2026-11-12T11:30:00Z')).toEqual({
      expired: false,
      value: 1,
      unit: 'hour',
    })
  })

  it('counts minutes under an hour, at least one', () => {
    expect(at('2026-11-12T10:59:59Z')).toEqual({
      expired: false,
      value: 59,
      unit: 'minute',
    })
    expect(at('2026-11-12T10:00:20Z')).toEqual({
      expired: false,
      value: 1,
      unit: 'minute',
    })
  })

  it('is expired at or after the deadline, or with an unreadable date', () => {
    expect(at('2026-11-12T10:00:00Z')).toEqual({ expired: true })
    expect(at('2026-11-11T10:00:00Z')).toEqual({ expired: true })
    expect(at('not a date')).toEqual({ expired: true })
  })
})
