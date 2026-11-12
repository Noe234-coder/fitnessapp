import { Navigate, Outlet } from 'react-router'

import { useAuth } from './auth-context'
import { LoadingScreen, NoConnectionScreen } from './screens'

/**
 * Layout route for everything that needs a signed-in user with a role.
 * It decides from local state only (the stored session and the cached role
 * hint), so it works without a connection.
 */
export function RequireAuth() {
  const auth = useAuth()

  if (auth.status === 'loading') return <LoadingScreen />
  if (auth.status === 'signed_out') return <Navigate to="/login" replace />
  if (auth.role === null) {
    return auth.roleStatus === 'unavailable' ? (
      <NoConnectionScreen onRetry={auth.refreshRole} />
    ) : (
      <LoadingScreen />
    )
  }
  // Signed in, but neither a trainer nor linked to one: the only thing to do
  // is to accept (or finish accepting) an invitation.
  if (auth.role === 'unlinked') return <Navigate to="/accept-invite" replace />
  return <Outlet />
}

/** Layout route for trainer screens, inside RequireAuth. */
export function RequireTrainer() {
  const auth = useAuth()
  return auth.role === 'trainer' ? <Outlet /> : <Navigate to="/" replace />
}
