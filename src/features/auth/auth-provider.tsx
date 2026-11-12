import { useMemo, useSyncExternalStore, type ReactNode } from 'react'

import { authStore } from './auth'
import { AuthContext, type AuthContextValue } from './auth-context'
import { roleOf } from './auth-store'

/** Makes the auth state (auth-store.ts) available through `useAuth()`. */
export function AuthProvider({ children }: { children: ReactNode }) {
  const state = useSyncExternalStore(authStore.subscribe, authStore.getState)

  const value = useMemo<AuthContextValue>(
    () => ({
      status: state.status,
      user: state.user,
      role: roleOf(state),
      roleStatus: state.roleStatus,
      refreshRole: authStore.refreshRole,
      linkAccepted: authStore.linkAccepted,
      logout: () => void authStore.logout(),
    }),
    [state],
  )

  return <AuthContext value={value}>{children}</AuthContext>
}
