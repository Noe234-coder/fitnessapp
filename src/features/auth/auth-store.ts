import { defaultLanguage, type Language } from '@/lib/i18n'

import {
  clearRoleHint,
  readRoleHint,
  roleFromHint,
  writeRoleHint,
  type Role,
  type RoleHint,
} from './role-hint'
import type { KeyValueStorage } from './storage'
import {
  clearStoredUser,
  LOGOUT_PENDING_KEY,
  readStoredUser,
  toAuthUser,
  writeStoredUser,
  type AuthUser,
  type SessionUser,
} from './stored-user'

export type AuthStatus = 'loading' | 'signed_out' | 'signed_in'

/**
 * `unavailable`: there is no cached role hint for this user and it could not
 * be fetched (no connection). The guard shows a "no connection" screen.
 */
export type RoleStatus = 'loading' | 'ready' | 'unavailable'

export type AuthState = {
  status: AuthStatus
  user: AuthUser | null
  hint: RoleHint | null
  roleStatus: RoleStatus
}

type SessionLike = { user: SessionUser }

/** Everything the store needs from the outside; tests pass fakes. */
export type AuthStoreDeps = {
  auth: {
    onAuthStateChange(
      callback: (event: string, session: SessionLike | null) => void,
    ): () => void
    getSession(): Promise<{ session: SessionLike | null; error: unknown }>
    /** Signs out of this device only (`scope: 'local'`). */
    signOutLocal(): Promise<unknown>
  }
  storage: KeyValueStorage
  /** Reads the role hint from the server. Rejects when it cannot. */
  fetchRoleHint(userId: string): Promise<RoleHint>
  isOnline(): boolean
  /** Calls back when the connection returns; returns the unsubscribe. */
  onOnline(callback: () => void): () => void
  /** The UI language to use; null means the default one. */
  onLanguage(language: Language | null): void
}

const SIGNED_OUT: AuthState = {
  status: 'signed_out',
  user: null,
  hint: null,
  roleStatus: 'loading',
}

/**
 * The app's auth state.
 *
 * The rule it enforces: once this device has a session, nothing here depends
 * on the network. Whether the user is signed in comes from the app's own
 * record of the last signed-in user (stored-user.ts), written on every auth
 * event that carries a session and removed only by `logout()` or by a
 * `SIGNED_OUT` event. supabase-js alone is not enough: with an expired access
 * token and no connection it retries the refresh for about 25 seconds and
 * then reports "no session", although the session is still stored and works
 * again as soon as the connection returns.
 *
 * `SIGNED_OUT` is emitted by supabase-js only when the session is really gone:
 * a logout (here or in another tab), or a refresh token the server rejected.
 * A refresh that fails because the server cannot be reached emits nothing.
 */
export function createAuthStore(deps: AuthStoreDeps) {
  const { storage } = deps
  const listeners = new Set<() => void>()
  let logoutPromise: Promise<void> | null = null
  let loadSequence = 0
  let state = initialState()

  function initialState(): AuthState {
    // A logout that was interrupted (the app was closed) is finished by
    // start(); until then the user is signed out as far as the UI goes.
    if (isLogoutPending()) return SIGNED_OUT
    const user = readStoredUser(storage)
    if (!user) {
      return {
        status: 'loading',
        user: null,
        hint: null,
        roleStatus: 'loading',
      }
    }
    const hint = readRoleHint(storage, user.id)
    return {
      status: 'signed_in',
      user,
      hint,
      roleStatus: hint ? 'ready' : 'loading',
    }
  }

  function setState(next: AuthState) {
    state = next
    for (const listener of listeners) listener()
  }

  function isLogoutPending(): boolean {
    return storage.getItem(LOGOUT_PENDING_KEY) !== null
  }

  function signedIn(user: AuthUser) {
    const previous = state.user
    writeStoredUser(storage, user)
    if (previous?.id === user.id) {
      if (
        previous.email !== user.email ||
        previous.fullName !== user.fullName
      ) {
        setState({ ...state, user })
      }
      return
    }
    // Another account on this device: its hint must not outlive its session.
    if (previous) clearRoleHint(storage, previous.id)
    const hint = readRoleHint(storage, user.id)
    setState({
      status: 'signed_in',
      user,
      hint,
      roleStatus: hint ? 'ready' : 'loading',
    })
    deps.onLanguage(hint?.locale ?? null)
    void loadRoleHint()
  }

  function signedOut() {
    const previous = state.user
    clearStoredUser(storage)
    if (previous) clearRoleHint(storage, previous.id)
    loadSequence += 1
    if (state.status !== 'signed_out') setState(SIGNED_OUT)
    deps.onLanguage(null)
  }

  function handleAuthEvent(event: string, session: SessionLike | null) {
    // While a logout is finishing, a late token refresh must not sign the
    // user back in.
    if (isLogoutPending()) return
    if (session) {
      signedIn(toAuthUser(session.user))
      return
    }
    if (event === 'SIGNED_OUT') {
      signedOut()
      return
    }
    if (event === 'INITIAL_SESSION') {
      if (!state.user) {
        signedOut()
        return
      }
      // The app has a record of a session but supabase-js could not load one.
      // Usually the refresh could not reach the server and the session is
      // still stored. Asked outside this callback: supabase-js must not be
      // called from inside it.
      setTimeout(() => void confirmStoredSession(), 0)
    }
  }

  async function confirmStoredSession() {
    let result: Awaited<ReturnType<AuthStoreDeps['auth']['getSession']>>
    try {
      result = await deps.auth.getSession()
    } catch {
      return
    }
    if (isLogoutPending()) return
    if (result.session) {
      signedIn(toAuthUser(result.session.user))
    } else if (!result.error) {
      // No error and no session: nothing is stored, the record was stale.
      signedOut()
    }
    // Any error: stay signed in. A refresh token the server rejected has
    // produced SIGNED_OUT; everything else is the network.
  }

  /**
   * Refreshes the role hint from the server. Returns the fresh hint, or null
   * when it could not be fetched; the cached hint, if any, stays in use.
   */
  async function loadRoleHint(): Promise<RoleHint | null> {
    const user = state.user
    if (!user) return null
    const sequence = ++loadSequence
    const isCurrent = () =>
      sequence === loadSequence && state.user?.id === user.id
    const failed = () => {
      if (isCurrent() && !state.hint && state.roleStatus !== 'unavailable') {
        setState({ ...state, roleStatus: 'unavailable' })
      }
      return null
    }

    if (!deps.isOnline()) return failed()
    if (!state.hint && state.roleStatus !== 'loading') {
      setState({ ...state, roleStatus: 'loading' })
    }
    let hint: RoleHint
    try {
      hint = await deps.fetchRoleHint(user.id)
    } catch {
      return failed()
    }
    if (!isCurrent()) return null
    applyHint(user.id, hint)
    return hint
  }

  function applyHint(userId: string, hint: RoleHint) {
    writeRoleHint(storage, userId, hint)
    const current = state.hint
    if (
      state.roleStatus !== 'ready' ||
      current?.isTrainer !== hint.isTrainer ||
      current.hasActiveLink !== hint.hasActiveLink ||
      current.locale !== hint.locale
    ) {
      setState({ ...state, hint, roleStatus: 'ready' })
    }
    deps.onLanguage(hint.locale)
  }

  function finishLogout(): Promise<void> {
    logoutPromise ??= deps.auth
      .signOutLocal()
      .then(
        () => storage.removeItem(LOGOUT_PENDING_KEY),
        // The stored session may still be there: keep the mark, so the next
        // start (or the next sign-in) tries again.
        () => undefined,
      )
      .then(() => {
        logoutPromise = null
      })
    return logoutPromise
  }

  return {
    getState: () => state,

    subscribe(listener: () => void): () => void {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },

    /** Starts listening to supabase-js. Returns the function that stops it. */
    start(): () => void {
      if (isLogoutPending()) void finishLogout()
      const stopAuth = deps.auth.onAuthStateChange(handleAuthEvent)
      const stopOnline = deps.onOnline(() => void loadRoleHint())
      if (state.user) {
        deps.onLanguage(state.hint?.locale ?? null)
        void loadRoleHint()
      }
      return () => {
        stopAuth()
        stopOnline()
      }
    },

    /**
     * Signs out of this device. The UI is signed out at once and it works
     * offline: removing the stored session can take a while when supabase-js
     * is busy retrying a refresh, so it finishes in the background (and on
     * the next start, if the app is closed first).
     */
    logout(): Promise<void> {
      if (!isLogoutPending()) storage.setItem(LOGOUT_PENDING_KEY, '1')
      signedOut()
      return finishLogout()
    },

    /**
     * Call before starting a new session (password sign-in, invite link):
     * waits for a logout that is still finishing, so it cannot remove the
     * session about to be created.
     */
    async beforeSignIn(): Promise<void> {
      if (isLogoutPending()) await finishLogout()
      // The new session replaces whatever is stored.
      storage.removeItem(LOGOUT_PENDING_KEY)
    },

    refreshRole: loadRoleHint,

    /**
     * Call after `accept_invitation()` succeeded: the user now has an active
     * trainer. If the fresh hint cannot be fetched, or does not show the link
     * yet, the server's answer to the call is trusted.
     */
    async linkAccepted(): Promise<void> {
      const user = state.user
      if (!user) return
      const fresh = await loadRoleHint()
      if (fresh?.hasActiveLink || state.user?.id !== user.id) return
      applyHint(user.id, {
        isTrainer: fresh?.isTrainer ?? state.hint?.isTrainer ?? false,
        hasActiveLink: true,
        locale: fresh?.locale ?? state.hint?.locale ?? defaultLanguage,
      })
    },
  }
}

export type AuthStore = ReturnType<typeof createAuthStore>

/** The role the guard routes by; null while there is no hint. */
export function roleOf(state: AuthState): Role | null {
  return state.hint ? roleFromHint(state.hint) : null
}
