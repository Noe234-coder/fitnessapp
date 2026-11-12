import { describe, expect, it } from 'vitest'

import { parseStoredUser, toAuthUser } from './stored-user'

describe('parseStoredUser', () => {
  it('reads a stored user', () => {
    const user = { id: 'u1', email: 'a1@fitnessapp.test', fullName: null }
    expect(parseStoredUser(JSON.stringify(user))).toEqual(user)
  })

  it('returns null for missing, corrupt or incomplete values', () => {
    expect(parseStoredUser(null)).toBeNull()
    expect(parseStoredUser('{')).toBeNull()
    expect(parseStoredUser('{"email":"a1@fitnessapp.test"}')).toBeNull()
    expect(parseStoredUser('{"id":"","email":null,"fullName":null}')).toBeNull()
  })
})

describe('toAuthUser', () => {
  it('takes the name from the user metadata', () => {
    expect(
      toAuthUser({
        id: 'u1',
        email: 'a1@fitnessapp.test',
        user_metadata: { full_name: '  Ana Ruiz ' },
      }),
    ).toEqual({ id: 'u1', email: 'a1@fitnessapp.test', fullName: 'Ana Ruiz' })
  })

  it('has no name when the metadata has none', () => {
    expect(toAuthUser({ id: 'u1' })).toEqual({
      id: 'u1',
      email: null,
      fullName: null,
    })
    expect(
      toAuthUser({ id: 'u1', user_metadata: { full_name: '  ' } }).fullName,
    ).toBeNull()
    expect(
      toAuthUser({ id: 'u1', user_metadata: { full_name: 42 } }).fullName,
    ).toBeNull()
  })
})
