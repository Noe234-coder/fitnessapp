import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { createAuthStore, roleOf, type AuthStoreDeps } from './auth-store'
import { roleHintKey, type RoleHint } from './role-hint'
import { LOGOUT_PENDING_KEY, STORED_USER_KEY } from './stored-user'

const A1 = { id: 'a1-id', email: 'a1@fitnessapp.test' }
const A2 = { id: 'a2-id', email: 'a2@fitnessapp.test' }
const ATHLETE: RoleHint = {
  isTrainer: false,
  hasActiveLink: true,
  locale: 'en',
}
const NETWORK_ERROR = new Error('fetch failed')

function memoryStorage(initial: Record<string, string> = {}) {
  const items = new Map(Object.entries(initial))
  return {
    items,
    getItem: (key: string) => items.get(key) ?? null,
    setItem: (key: string, value: string) => void items.set(key, value),
    removeItem: (key: string) => void items.delete(key),
  }
}

/** A stand-in for supabase-js and the browser, driven by the test. */
function harness(options: { stored?: Record<string, string> } = {}) {
  const storage = memoryStorage(options.stored)
  let emit: (event: string, session: { user: typeof A1 } | null) => void = () =>
    undefined
  let online = true
  let comeOnline: () => void = () => undefined
  const languages: (string | null)[] = []

  const getSession = vi.fn<AuthStoreDeps['auth']['getSession']>(() =>
    Promise.resolve({ session: null, error: null }),
  )
  const signOutLocal = vi.fn(() => Promise.resolve())
  const fetchRoleHint = vi.fn<AuthStoreDeps['fetchRoleHint']>(() =>
    Promise.resolve(ATHLETE),
  )

  const store = createAuthStore({
    auth: {
      onAuthStateChange(callback) {
        emit = callback
        return () => undefined
      },
      getSession,
      signOutLocal,
    },
    storage,
    fetchRoleHint,
    isOnline: () => online,
    onOnline(callback) {
      comeOnline = callback
      return () => undefined
    },
    onLanguage: (language) => void languages.push(language),
  })

  return {
    store,
    storage,
    languages,
    getSession,
    signOutLocal,
    fetchRoleHint,
    emit: (event: string, session: { user: typeof A1 } | null) =>
      emit(event, session),
    setOnline(value: boolean) {
      online = value
      if (value) comeOnline()
    },
  }
}

function storedSession(user = A1, hint: RoleHint | null = ATHLETE) {
  return {
    [STORED_USER_KEY]: JSON.stringify({ ...user, fullName: null }),
    ...(hint ? { [roleHintKey(user.id)]: JSON.stringify(hint) } : {}),
  }
}

/** Lets pending promise callbacks and zero-delay timers run. */
async function settle() {
  await vi.runAllTimersAsync()
}

beforeEach(() => {
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
})

describe('start-up', () => {
  it('is loading, then signed out, when nothing is stored', () => {
    const h = harness()
    expect(h.store.getState().status).toBe('loading')
    h.store.start()
    h.emit('INITIAL_SESSION', null)
    expect(h.store.getState().status).toBe('signed_out')
    expect(h.getSession).not.toHaveBeenCalled()
  })

  it('is signed in at once from the stored user and the cached hint', () => {
    const h = harness({ stored: storedSession() })
    const state = h.store.getState()
    expect(state.status).toBe('signed_in')
    expect(state.user?.id).toBe(A1.id)
    expect(roleOf(state)).toBe('athlete')
    expect(state.roleStatus).toBe('ready')
  })

  it('uses the language of the cached hint', () => {
    const h = harness({ stored: storedSession() })
    h.store.start()
    expect(h.languages[0]).toBe('en')
  })

  it('stays signed in when the token refresh cannot reach the server', async () => {
    const h = harness({ stored: storedSession() })
    h.setOnline(false)
    h.getSession.mockResolvedValue({ session: null, error: NETWORK_ERROR })
    h.store.start()
    // What supabase-js emits with an expired access token and no network.
    h.emit('INITIAL_SESSION', null)
    await settle()
    expect(h.getSession).toHaveBeenCalledOnce()
    expect(h.store.getState().status).toBe('signed_in')
    expect(roleOf(h.store.getState())).toBe('athlete')
    expect(h.storage.getItem(STORED_USER_KEY)).not.toBeNull()
  })

  it('stays signed in when asking for the session throws', async () => {
    const h = harness({ stored: storedSession() })
    h.getSession.mockRejectedValue(NETWORK_ERROR)
    h.store.start()
    h.emit('INITIAL_SESSION', null)
    await settle()
    expect(h.store.getState().status).toBe('signed_in')
  })

  it('signs out when the stored user has no session behind it', async () => {
    const h = harness({ stored: storedSession() })
    h.store.start()
    h.emit('INITIAL_SESSION', null)
    await settle()
    expect(h.store.getState().status).toBe('signed_out')
    expect(h.storage.getItem(STORED_USER_KEY)).toBeNull()
    expect(h.storage.getItem(roleHintKey(A1.id))).toBeNull()
  })

  it('signs out on SIGNED_OUT (a session the server ended)', () => {
    const h = harness({ stored: storedSession() })
    h.store.start()
    h.emit('SIGNED_OUT', null)
    expect(h.store.getState().status).toBe('signed_out')
    expect(h.storage.getItem(STORED_USER_KEY)).toBeNull()
    expect(h.languages.at(-1)).toBeNull()
  })
})

describe('role hint', () => {
  it('is fetched and cached after signing in', async () => {
    const h = harness()
    h.store.start()
    h.emit('INITIAL_SESSION', null)
    h.emit('SIGNED_IN', { user: A1 })
    expect(h.store.getState().status).toBe('signed_in')
    expect(roleOf(h.store.getState())).toBeNull()
    expect(h.store.getState().roleStatus).toBe('loading')
    await settle()
    expect(h.fetchRoleHint).toHaveBeenCalledWith(A1.id)
    expect(roleOf(h.store.getState())).toBe('athlete')
    expect(h.storage.getItem(roleHintKey(A1.id))).toBe(JSON.stringify(ATHLETE))
    expect(h.languages.at(-1)).toBe('en')
  })

  it('is unavailable, not signed out, with no cache and no connection', async () => {
    const h = harness({ stored: storedSession(A1, null) })
    h.setOnline(false)
    h.store.start()
    await settle()
    expect(h.store.getState().status).toBe('signed_in')
    expect(h.store.getState().roleStatus).toBe('unavailable')
    expect(h.fetchRoleHint).not.toHaveBeenCalled()
  })

  it('is unavailable when the fetch fails and nothing is cached', async () => {
    const h = harness({ stored: storedSession(A1, null) })
    h.fetchRoleHint.mockRejectedValue(NETWORK_ERROR)
    h.store.start()
    await settle()
    expect(h.store.getState().roleStatus).toBe('unavailable')
    expect(h.store.getState().status).toBe('signed_in')
  })

  it('keeps the cached hint when the refresh fails', async () => {
    const h = harness({ stored: storedSession() })
    h.fetchRoleHint.mockRejectedValue(NETWORK_ERROR)
    h.store.start()
    await settle()
    expect(roleOf(h.store.getState())).toBe('athlete')
    expect(h.store.getState().roleStatus).toBe('ready')
  })

  it('is fetched when the connection returns', async () => {
    const h = harness({ stored: storedSession(A1, null) })
    h.setOnline(false)
    h.store.start()
    await settle()
    h.setOnline(true)
    await settle()
    expect(roleOf(h.store.getState())).toBe('athlete')
  })

  it('replaces the cache when the server says something else', async () => {
    const h = harness({ stored: storedSession() })
    h.fetchRoleHint.mockResolvedValue({ ...ATHLETE, hasActiveLink: false })
    h.store.start()
    await settle()
    expect(roleOf(h.store.getState())).toBe('unlinked')
  })

  it('is not refetched on a token refresh for the same user', async () => {
    const h = harness({ stored: storedSession() })
    h.store.start()
    await settle()
    h.emit('TOKEN_REFRESHED', { user: A1 })
    await settle()
    expect(h.fetchRoleHint).toHaveBeenCalledOnce()
  })

  it('does not survive a change of user on the device', async () => {
    const h = harness({ stored: storedSession() })
    h.fetchRoleHint.mockResolvedValue({
      isTrainer: false,
      hasActiveLink: false,
      locale: 'es',
    })
    h.store.start()
    h.emit('SIGNED_IN', { user: A2 })
    expect(h.store.getState().user?.id).toBe(A2.id)
    expect(roleOf(h.store.getState())).toBeNull()
    expect(h.storage.getItem(roleHintKey(A1.id))).toBeNull()
    await settle()
    expect(roleOf(h.store.getState())).toBe('unlinked')
  })

  it('linkAccepted trusts the accepted invitation when it cannot refetch', async () => {
    const h = harness({
      stored: storedSession(A1, {
        isTrainer: false,
        hasActiveLink: false,
        locale: 'en',
      }),
    })
    h.fetchRoleHint.mockRejectedValue(NETWORK_ERROR)
    h.store.start()
    await settle()
    expect(roleOf(h.store.getState())).toBe('unlinked')
    await h.store.linkAccepted()
    expect(roleOf(h.store.getState())).toBe('athlete')
    expect(h.store.getState().hint?.locale).toBe('en')
  })
})

describe('logout', () => {
  it('signs out at once, before the stored session is removed', async () => {
    const h = harness({ stored: storedSession() })
    let finishSignOut: () => void = () => undefined
    h.signOutLocal.mockReturnValue(
      new Promise<void>((resolve) => {
        finishSignOut = resolve
      }),
    )
    h.store.start()
    void h.store.logout()
    expect(h.store.getState().status).toBe('signed_out')
    expect(h.storage.getItem(STORED_USER_KEY)).toBeNull()
    expect(h.storage.getItem(roleHintKey(A1.id))).toBeNull()
    expect(h.storage.getItem(LOGOUT_PENDING_KEY)).not.toBeNull()

    // A refresh that lands while the logout is finishing changes nothing.
    h.emit('TOKEN_REFRESHED', { user: A1 })
    expect(h.store.getState().status).toBe('signed_out')

    finishSignOut()
    await settle()
    expect(h.storage.getItem(LOGOUT_PENDING_KEY)).toBeNull()
    expect(h.signOutLocal).toHaveBeenCalledOnce()
  })

  it('is finished on the next start if the app was closed first', async () => {
    const h = harness({ stored: { [LOGOUT_PENDING_KEY]: '1' } })
    expect(h.store.getState().status).toBe('signed_out')
    h.store.start()
    h.emit('INITIAL_SESSION', { user: A1 })
    expect(h.store.getState().status).toBe('signed_out')
    await settle()
    expect(h.signOutLocal).toHaveBeenCalledOnce()
    expect(h.storage.getItem(LOGOUT_PENDING_KEY)).toBeNull()
  })

  it('lets the next sign-in through', async () => {
    const h = harness({ stored: storedSession() })
    h.store.start()
    await h.store.logout()
    await h.store.beforeSignIn()
    h.emit('SIGNED_IN', { user: A2 })
    expect(h.store.getState().status).toBe('signed_in')
    expect(h.store.getState().user?.id).toBe(A2.id)
  })

  it('beforeSignIn waits for a logout that is still finishing', async () => {
    const h = harness({ stored: storedSession() })
    let finishSignOut: () => void = () => undefined
    h.signOutLocal.mockReturnValue(
      new Promise<void>((resolve) => {
        finishSignOut = resolve
      }),
    )
    h.store.start()
    void h.store.logout()
    let ready = false
    void h.store.beforeSignIn().then(() => {
      ready = true
    })
    await settle()
    expect(ready).toBe(false)
    finishSignOut()
    await settle()
    expect(ready).toBe(true)
  })
})
