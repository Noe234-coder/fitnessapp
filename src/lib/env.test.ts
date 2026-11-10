import { describe, expect, it } from 'vitest'

import { parseEnv } from './env'

const valid = {
  VITE_SUPABASE_URL: 'http://127.0.0.1:54321',
  VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_example',
}

describe('parseEnv', () => {
  it('accepts a valid environment and ignores other variables', () => {
    expect(parseEnv({ ...valid, MODE: 'test' })).toEqual({
      ok: true,
      env: valid,
    })
  })

  it('reports a missing variable by name', () => {
    expect(
      parseEnv({ VITE_SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_example' }),
    ).toEqual({ ok: false, invalidKeys: ['VITE_SUPABASE_URL'] })
  })

  it('reports every invalid variable', () => {
    expect(
      parseEnv({
        VITE_SUPABASE_URL: 'not a url',
        VITE_SUPABASE_PUBLISHABLE_KEY: '',
      }),
    ).toEqual({
      ok: false,
      invalidKeys: ['VITE_SUPABASE_URL', 'VITE_SUPABASE_PUBLISHABLE_KEY'],
    })
  })

  it('rejects a key that is not a publishable key', () => {
    expect(
      parseEnv({ ...valid, VITE_SUPABASE_PUBLISHABLE_KEY: 'some-other-key' }),
    ).toEqual({ ok: false, invalidKeys: ['VITE_SUPABASE_PUBLISHABLE_KEY'] })
  })
})
