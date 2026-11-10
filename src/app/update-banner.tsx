import { useTranslation } from 'react-i18next'
import { useRegisterSW } from 'virtual:pwa-register/react'

import { Button } from '@/components/ui/button'

const UPDATE_CHECK_INTERVAL_MS = 60 * 60 * 1000

/**
 * Asks the browser to look for a new service worker. Without this, an app
 * left open (an installed PWA can stay open for days) would only notice a
 * new version on its next full page load.
 */
function checkForUpdate(registration: ServiceWorkerRegistration) {
  if (registration.installing || !navigator.onLine) return
  // A failed check (weak signal, server down) is retried on the next tick.
  registration.update().catch(() => {})
}

/**
 * Registers the service worker and, when a new version of the app is waiting,
 * shows a banner at the bottom of the screen. The page reloads only when the
 * button is tapped: an athlete in the middle of logging a set is never
 * interrupted.
 */
export function UpdateBanner() {
  const { t } = useTranslation()
  const {
    needRefresh: [needRefresh],
    updateServiceWorker,
  } = useRegisterSW({
    onRegisteredSW(_swScriptUrl, registration) {
      if (!registration) return
      setInterval(() => checkForUpdate(registration), UPDATE_CHECK_INTERVAL_MS)
    },
  })

  if (!needRefresh) return null

  return (
    <div
      role="status"
      className="fixed inset-x-0 bottom-0 z-50 px-4 pb-[calc(env(safe-area-inset-bottom)+1rem)]"
    >
      <div className="mx-auto flex w-full max-w-md items-center justify-between gap-3 rounded-xl border bg-popover py-2 pr-2 pl-4 text-popover-foreground shadow-lg">
        <p className="text-sm font-medium">{t('update.available')}</p>
        <Button size="lg" onClick={() => void updateServiceWorker()}>
          {t('update.reload')}
        </Button>
      </div>
    </div>
  )
}
