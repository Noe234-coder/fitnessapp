import { describe, expect, it } from 'vitest'

import { emailSchema, normalizeEmail } from './email'

describe('normalizeEmail', () => {
  it('trims and lowercases', () => {
    expect(normalizeEmail('  Ana.Ruiz@FitnessApp.Test \n')).toBe(
      'ana.ruiz@fitnessapp.test',
    )
  })

  it('leaves a normalized email alone', () => {
    expect(normalizeEmail('a1@fitnessapp.test')).toBe('a1@fitnessapp.test')
  })
})

describe('emailSchema', () => {
  it('returns the normalized email', () => {
    expect(emailSchema.parse(' A1@Fitnessapp.TEST ')).toBe('a1@fitnessapp.test')
  })

  it('rejects what is not an email', () => {
    for (const value of [
      '',
      '   ',
      'a1',
      'a1@',
      '@fitnessapp.test',
      'a b@c.d',
    ]) {
      expect(emailSchema.safeParse(value).success, value).toBe(false)
    }
  })
})
