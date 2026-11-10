import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { I18nextProvider } from 'react-i18next'
import { RouterProvider } from 'react-router/dom'

import i18n from '@/lib/i18n'

import { router } from './router'
import { UpdateBanner } from './update-banner'

// No cache persistence yet (step 12).
const queryClient = new QueryClient()

/**
 * Every app-wide provider, in one place: i18n, server data, router. The update
 * banner sits outside the router so it shows on every screen.
 */
export function AppProviders() {
  return (
    <I18nextProvider i18n={i18n}>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
        <UpdateBanner />
      </QueryClientProvider>
    </I18nextProvider>
  )
}
