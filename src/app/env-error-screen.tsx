import { useTranslation } from 'react-i18next'

type EnvErrorScreenProps = {
  invalidKeys: string[]
}

/** Shown instead of the app when the environment variables are not valid. */
export function EnvErrorScreen({ invalidKeys }: EnvErrorScreenProps) {
  const { t } = useTranslation()

  return (
    <main
      role="alert"
      className="mx-auto flex min-h-dvh w-full max-w-md flex-col justify-center gap-4 px-4 py-10"
    >
      <h1 className="text-2xl font-semibold tracking-tight text-destructive">
        {t('envError.title')}
      </h1>
      <p>{t('envError.description')}</p>
      <ul className="list-inside list-disc font-mono text-sm">
        {invalidKeys.map((key) => (
          <li key={key}>{key}</li>
        ))}
      </ul>
      <p className="text-sm text-muted-foreground">{t('envError.hint')}</p>
    </main>
  )
}
