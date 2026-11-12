import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { useAuth } from '@/features/auth/auth-context'

/** Placeholder home page; replaced by the real screens in later steps. */
export function HomePage() {
  const { t } = useTranslation()
  const { user, role, logout } = useAuth()

  return (
    <main className="flex flex-1 flex-col justify-center gap-8 py-10">
      <div className="space-y-3">
        <p className="text-sm font-medium text-muted-foreground">
          {t('app.name')}
        </p>
        <h1 className="text-3xl font-semibold tracking-tight break-words">
          {t('home.greeting', { name: user?.fullName ?? user?.email ?? '' })}
        </h1>
        <p className="text-lg text-muted-foreground">
          {t(role === 'trainer' ? 'home.roleTrainer' : 'home.roleAthlete')}
        </p>
      </div>
      <Button
        variant="outline"
        size="lg"
        className="h-11 w-full text-base"
        onClick={logout}
      >
        {t('auth.logout')}
      </Button>
    </main>
  )
}
