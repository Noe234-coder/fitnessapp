import { useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { Navigate } from 'react-router'

import { Button } from '@/components/ui/button'

import { signInWithPassword } from './auth'
import { useAuth } from './auth-context'
import type { LoginErrorKey } from './auth-errors'
import { emailSchema } from './email'
import { FormError, PasswordField, TextField } from './form-fields'
import { LoadingScreen } from './screens'

/**
 * Email and password. There is no sign-up and no password reset here: the
 * app is invite-only, and a new link from the trainer is the way back in.
 */
export function LoginPage() {
  const { t } = useTranslation()
  const auth = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [emailInvalid, setEmailInvalid] = useState(false)
  const [passwordMissing, setPasswordMissing] = useState(false)
  const [formError, setFormError] = useState<LoginErrorKey | null>(null)
  const [submitting, setSubmitting] = useState(false)

  if (auth.status === 'loading') return <LoadingScreen />
  if (auth.status === 'signed_in') return <Navigate to="/" replace />

  async function submit(event: FormEvent) {
    event.preventDefault()
    const parsedEmail = emailSchema.safeParse(email)
    setEmailInvalid(!parsedEmail.success)
    setPasswordMissing(password === '')
    setFormError(null)
    if (!parsedEmail.success || password === '') return

    setSubmitting(true)
    try {
      setFormError(await signInWithPassword(parsedEmail.data, password))
    } catch {
      setFormError('errors.unknown')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <main className="flex flex-1 flex-col justify-center gap-8 py-10">
      <div className="space-y-3">
        <p className="text-sm font-medium text-muted-foreground">
          {t('app.name')}
        </p>
        <h1 className="text-3xl font-semibold tracking-tight">
          {t('auth.login.title')}
        </h1>
      </div>
      <form
        noValidate
        className="space-y-4"
        onSubmit={(event) => void submit(event)}
      >
        <TextField
          label={t('auth.login.email')}
          type="email"
          name="email"
          autoComplete="username"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          inputMode="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          error={emailInvalid ? t('auth.login.emailInvalid') : null}
        />
        <PasswordField
          label={t('auth.login.password')}
          name="password"
          autoComplete="current-password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          error={passwordMissing ? t('auth.login.passwordRequired') : null}
        />
        {formError ? <FormError>{t(formError)}</FormError> : null}
        <Button
          type="submit"
          size="lg"
          className="h-11 w-full text-base"
          disabled={submitting}
        >
          {t(submitting ? 'auth.login.submitting' : 'auth.login.submit')}
        </Button>
      </form>
      <p className="text-sm text-muted-foreground">
        {t('auth.login.forgotPassword')}
      </p>
    </main>
  )
}
