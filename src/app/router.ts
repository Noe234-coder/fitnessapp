import { createBrowserRouter } from 'react-router'

import { LoginPage } from '@/features/auth/login-page'
import { RequireAuth } from '@/features/auth/route-guards'
import { AcceptInvitePage } from '@/features/invites/accept-invite-page'

import { RootLayout } from './root-layout'
import { HomePage } from './routes/home'
import { NotFoundPage } from './routes/not-found'

// React Router in data mode. Feature routes are added as children of the
// root layout; the catch-all stays last.
//
// Public routes come first. Everything under RequireAuth needs a signed-in
// user with a role (a trainer, or an athlete with an active trainer).
export const router = createBrowserRouter([
  {
    path: '/',
    Component: RootLayout,
    children: [
      { path: 'login', Component: LoginPage },
      { path: 'accept-invite', Component: AcceptInvitePage },
      {
        Component: RequireAuth,
        children: [{ index: true, Component: HomePage }],
      },
      { path: '*', Component: NotFoundPage },
    ],
  },
])
