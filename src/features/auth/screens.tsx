import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'

/** Shown while the stored session or the role hint is being read. */
export function LoadingScreen() {
  const { t } = useTranslation()
  return (
    <main
      role="status"
      className="flex flex-1 flex-col items-center justify-center py-10 text-muted-foreground"
    >
      {t('auth.loading')}
    </main>
  )
}

/**
 * Shown to a signed-in user when what the app needs to route him is neither
 * cached nor reachable. Never a redirect to the login page: he is signed in.
 */
export function NoConnectionScreen({
  onRetry,
}: {
  onRetry: () => Promise<unknown>
}) {
  const { t } = useTranslation()
  const [retrying, setRetrying] = useState(false)

  async function retry() {
    setRetrying(true)
    try {
      await onRetry()
    } finally {
      setRetrying(false)
    }
  }

  return (
    <main className="flex flex-1 flex-col justify-center gap-8 py-10">
      <div className="space-y-3">
        <h1 className="text-3xl font-semibold tracking-tight">
          {t('auth.noConnection.title')}
        </h1>
        <p className="text-muted-foreground">
          {t('auth.noConnection.description')}
        </p>
      </div>
      <Button
        size="lg"
        className="h-11 w-full text-base"
        disabled={retrying}
        onClick={() => void retry()}
      >
        {t('auth.noConnection.retry')}
      </Button>
    </main>
  )
}
