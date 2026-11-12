import { createContext, useContext } from 'react'

import type { AuthStatus, RoleStatus } from './auth-store'
import type { Role, RoleHint } from './role-hint'
import type { AuthUser } from './stored-user'

export type AuthContextValue = {
  status: AuthStatus
  user: AuthUser | null
  /** Null while the role hint is not known yet. Routing only: see RLS. */
  role: Role | null
  roleStatus: RoleStatus
  /** Re-reads the role hint from the server; null if it could not. */
  refreshRole: () => Promise<RoleHint | null>
  /** To call once `accept_invitation()` has succeeded. */
  linkAccepted: () => Promise<void>
  /** Signs out of this device; works offline. */
  logout: () => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth must be used inside <AuthProvider>')
  return value
}
