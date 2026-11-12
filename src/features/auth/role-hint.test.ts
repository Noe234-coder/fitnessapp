import { describe, expect, it } from 'vitest'

import {
  parseLocale,
  parseRoleHint,
  roleFromHint,
  roleHintKey,
} from './role-hint'

describe('parseRoleHint', () => {
  it('reads a complete hint', () => {
    const hint = { isTrainer: false, hasActiveLink: true, locale: 'en' }
    expect(parseRoleHint(JSON.stringify(hint))).toEqual(hint)
  })

  it('returns null when nothing is stored', () => {
    expect(parseRoleHint(null)).toBeNull()
  })

  it('returns null for corrupt JSON', () => {
    expect(parseRoleHint('{"isTrainer": tru')).toBeNull()
    expect(parseRoleHint('')).toBeNull()
  })

  it('returns null for JSON that is not a complete hint', () => {
    expect(parseRoleHint('null')).toBeNull()
    expect(parseRoleHint('"trainer"')).toBeNull()
    expect(parseRoleHint('{"isTrainer":true}')).toBeNull()
    expect(
      parseRoleHint('{"isTrainer":"yes","hasActiveLink":true,"locale":"es"}'),
    ).toBeNull()
    expect(
      parseRoleHint('{"isTrainer":true,"hasActiveLink":true,"locale":"fr"}'),
    ).toBeNull()
  })
})

describe('roleFromHint', () => {
  it('routes a trainer as a trainer, also when he trains himself', () => {
    expect(
      roleFromHint({ isTrainer: true, hasActiveLink: false, locale: 'es' }),
    ).toBe('trainer')
    expect(
      roleFromHint({ isTrainer: true, hasActiveLink: true, locale: 'es' }),
    ).toBe('trainer')
  })

  it('routes a linked user as an athlete', () => {
    expect(
      roleFromHint({ isTrainer: false, hasActiveLink: true, locale: 'es' }),
    ).toBe('athlete')
  })

  it('a user with neither is unlinked', () => {
    expect(
      roleFromHint({ isTrainer: false, hasActiveLink: false, locale: 'es' }),
    ).toBe('unlinked')
  })
})

describe('roleHintKey', () => {
  it('includes the user id', () => {
    expect(roleHintKey('abc')).toContain('abc')
    expect(roleHintKey('abc')).not.toBe(roleHintKey('abd'))
  })
})

describe('parseLocale', () => {
  it('keeps a supported language and falls back to Spanish', () => {
    expect(parseLocale('en')).toBe('en')
    expect(parseLocale('es')).toBe('es')
    expect(parseLocale('fr')).toBe('es')
    expect(parseLocale(undefined)).toBe('es')
  })
})
