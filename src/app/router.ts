import { createBrowserRouter } from 'react-router'

import { RootLayout } from './root-layout'
import { HomePage } from './routes/home'
import { NotFoundPage } from './routes/not-found'

// React Router in data mode. Feature routes are added as children of the
// root layout; the catch-all stays last.
export const router = createBrowserRouter([
  {
    path: '/',
    Component: RootLayout,
    children: [
      { index: true, Component: HomePage },
      { path: '*', Component: NotFoundPage },
    ],
  },
])
