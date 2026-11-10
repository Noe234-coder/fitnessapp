import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import type { Language } from '@/lib/i18n'

/** Placeholder home page; replaced by the real screens in later steps. */
export function HomePage() {
  const { t, i18n } = useTranslation()
  const nextLanguage: Language = i18n.resolvedLanguage === 'es' ? 'en' : 'es'

  return (
    <main className="flex flex-1 flex-col justify-center gap-8 py-10">
      <div className="space-y-3">
        <h1 className="text-4xl font-semibold tracking-tight">
          {t('app.name')}
        </h1>
        <p className="text-lg text-muted-foreground">{t('home.tagline')}</p>
      </div>
      <Button
        size="lg"
        className="h-11 w-full text-base"
        lang={nextLanguage}
        onClick={() => void i18n.changeLanguage(nextLanguage)}
      >
        {t('home.switchLanguage')}
      </Button>
    </main>
  )
}
