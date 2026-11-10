import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import '@/index.css'
import { EnvErrorScreen } from '@/app/env-error-screen'
import { envResult } from '@/lib/env'
import '@/lib/i18n'

const root = createRoot(document.getElementById('root')!)

if (envResult.ok) {
  // The app is imported only once the environment is known to be valid:
  // modules such as the Supabase client read it when they are loaded.
  void import('@/app/providers').then(({ AppProviders }) => {
    root.render(
      <StrictMode>
        <AppProviders />
      </StrictMode>,
    )
  })
} else {
  root.render(
    <StrictMode>
      <EnvErrorScreen invalidKeys={envResult.invalidKeys} />
    </StrictMode>,
  )
}
