import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'

import { Button } from '@/components/ui/button'

export function NotFoundPage() {
  const { t } = useTranslation()

  return (
    <main className="flex flex-1 flex-col justify-center gap-8 py-10">
      <div className="space-y-3">
        <h1 className="text-3xl font-semibold tracking-tight">
          {t('notFound.title')}
        </h1>
        <p className="text-muted-foreground">{t('notFound.description')}</p>
      </div>
      <Button asChild size="lg" className="h-11 w-full text-base">
        <Link to="/">{t('notFound.backHome')}</Link>
      </Button>
    </main>
  )
}
