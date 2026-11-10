import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { I18nextProvider } from 'react-i18next'
import { RouterProvider } from 'react-router/dom'

import i18n from '@/lib/i18n'

import { router } from './router'

// No cache persistence yet (step 12).
const queryClient = new QueryClient()

/** Every app-wide provider, in one place: i18n, server data, router. */
export function AppProviders() {
  return (
    <I18nextProvider i18n={i18n}>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </I18nextProvider>
  )
}
