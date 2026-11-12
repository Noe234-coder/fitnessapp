import {
  useEffect,
  useEffectEvent,
  useState,
  type FormEvent,
  type ReactNode,
} from 'react'
import { useTranslation } from 'react-i18next'
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router'

import { Button } from '@/components/ui/button'
import { useAuth } from '@/features/auth/auth-context'
import { FormError, PasswordField } from '@/features/auth/form-fields'
import { LoadingScreen, NoConnectionScreen } from '@/features/auth/screens'
import { safeLocalStorage } from '@/features/auth/storage'

import { acceptInvitation, setPassword, verifyInvite } from './accept-api'
import {
  clearPendingAccept,
  MIN_PASSWORD_LENGTH,
  readPendingAccept,
  resumeStep,
  writePendingAccept,
  type PendingAccept,
} from './accept-flow'
import { parseAcceptParams, type AcceptParams } from './accept-params'
import type {
  AcceptErrorKey,
  PasswordErrorKey,
  VerifyErrorKey,
} from './invite-errors'

/**
 * `/accept-invite?token_hash=…&type=invite|magiclink`: where an invited
 * athlete lands, and where a signed-in user without a trainer is sent.
 *
 * Opening the link sends nothing to the server: the token is spent only when
 * "Accept" is tapped, so a link preview cannot use it up. After that the
 * page works through what is left (a password for a new account, then
 * `accept_invitation()`), and picks up at the right step after a reload.
 *
 * The token lives in this component's state and nowhere else: it is never
 * logged, stored or cached, and the query string is dropped once it is spent.
 */
export function AcceptInvitePage() {
  const { t } = useTranslation()
  const auth = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [params, setParams] = useState<AcceptParams | null>(() =>
    parseAcceptParams(searchParams),
  )
  const [pending, setPending] = useState<PendingAccept | null>(() =>
    readPendingAccept(safeLocalStorage),
  )
  const [linkExpired, setLinkExpired] = useState(false)

  const step = resumeStep({
    params,
    pending,
    userId: auth.user?.id ?? null,
    role: auth.role,
  })

  function savePending(next: PendingAccept) {
    writePendingAccept(safeLocalStorage, next)
    setPending(next)
  }

  /** The token is spent (or refused): forget it and clean the address bar. */
  function forgetToken() {
    setParams(null)
    void navigate('/accept-invite', { replace: true })
  }

  async function finish() {
    // The role first: while the setup is still pending this page keeps
    // showing the last step, and then leaves for the home page.
    await auth.linkAccepted()
    clearPendingAccept(safeLocalStorage)
    setPending(null)
  }

  if (linkExpired) {
    return (
      <Screen
        title={t('invites.accept.expiredTitle')}
        description={t('errors.linkExpired')}
      >
        <LoginLink />
      </Screen>
    )
  }

  switch (step) {
    case 'confirm':
      // `params` is set whenever the step is `confirm`.
      return params ? (
        <ConfirmStep
          params={params}
          onVerified={(userId) => {
            savePending({ userId, type: params.type, passwordSet: false })
            forgetToken()
          }}
          onExpired={() => {
            setLinkExpired(true)
            forgetToken()
          }}
        />
      ) : null
    case 'password':
      return (
        <PasswordStep
          onDone={() => {
            if (pending) savePending({ ...pending, passwordSet: true })
          }}
        />
      )
    case 'link':
      return <LinkStep automatic onDone={finish} />
    case 'unlinked':
      return <LinkStep automatic={false} onDone={finish} />
    case 'home':
      return <Navigate to="/" replace />
    case 'checking':
      return auth.roleStatus === 'unavailable' ? (
        <NoConnectionScreen onRetry={auth.refreshRole} />
      ) : (
        <LoadingScreen />
      )
    case 'invalid':
      // Signed out with no link in the URL. Wait for the stored session to
      // be read before saying so.
      return auth.status === 'loading' ? <LoadingScreen /> : <InvalidLink />
  }
}

function Screen({
  title,
  description,
  children,
}: {
  title: string
  description?: string
  children?: ReactNode
}) {
  const { t } = useTranslation()
  return (
    <main className="flex flex-1 flex-col justify-center gap-8 py-10">
      <div className="space-y-3">
        <p className="text-sm font-medium text-muted-foreground">
          {t('app.name')}
        </p>
        <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
        {description ? (
          <p className="text-muted-foreground">{description}</p>
        ) : null}
      </div>
      {children}
    </main>
  )
}

/** The way out of a dead end: the login page, or home when signed in. */
function LoginLink() {
  const { t } = useTranslation()
  const { status } = useAuth()
  return (
    <Button
      asChild
      variant="outline"
      size="lg"
      className="h-11 w-full text-base"
    >
      {status === 'signed_in' ? (
        <Link to="/">{t('notFound.backHome')}</Link>
      ) : (
        <Link to="/login">{t('invites.accept.goToLogin')}</Link>
      )}
    </Button>
  )
}

function InvalidLink() {
  const { t } = useTranslation()
  return (
    <Screen
      title={t('invites.accept.invalidTitle')}
      description={t('invites.accept.invalidDescription')}
    >
      <LoginLink />
    </Screen>
  )
}

/** Step 1: nothing is sent until the button is tapped. */
function ConfirmStep({
  params,
  onVerified,
  onExpired,
}: {
  params: AcceptParams
  onVerified: (userId: string) => void
  /** The token was refused: it will not work on a second try either. */
  onExpired: () => void
}) {
  const { t } = useTranslation()
  const auth = useAuth()
  const [busy, setBusy] = useState(false)
  const [errorKey, setErrorKey] = useState<VerifyErrorKey | null>(null)
  // Whoever was signed in when the link was opened; verifying replaces him.
  const [otherUser] = useState(() => auth.user)

  async function accept() {
    setBusy(true)
    setErrorKey(null)
    const result = await verifyInvite(params)
    if ('userId' in result) {
      onVerified(result.userId)
      return
    }
    if (result.errorKey === 'errors.linkExpired') {
      onExpired()
      return
    }
    setBusy(false)
    setErrorKey(result.errorKey)
  }

  return (
    <Screen
      title={t('invites.accept.title')}
      description={t('invites.accept.description')}
    >
      <div className="space-y-4">
        {otherUser ? (
          <p className="rounded-lg border px-3 py-2 text-sm">
            {t('invites.accept.otherSession', {
              who: otherUser.email ?? otherUser.fullName ?? '',
            })}
          </p>
        ) : null}
        {errorKey ? <FormError>{t(errorKey)}</FormError> : null}
        <Button
          size="lg"
          className="h-11 w-full text-base"
          disabled={busy}
          onClick={() => void accept()}
        >
          {t(
            busy
              ? 'invites.accept.submitting'
              : errorKey
                ? 'invites.accept.retry'
                : 'invites.accept.submit',
          )}
        </Button>
      </div>
    </Screen>
  )
}

/** Step 2, new accounts only: the password the athlete will log in with. */
function PasswordStep({ onDone }: { onDone: () => void }) {
  const { t } = useTranslation()
  const [password, setPasswordValue] = useState('')
  const [tooShort, setTooShort] = useState(false)
  const [busy, setBusy] = useState(false)
  const [errorKey, setErrorKey] = useState<PasswordErrorKey | null>(null)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setErrorKey(null)
    if (password.length < MIN_PASSWORD_LENGTH) {
      setTooShort(true)
      return
    }
    setTooShort(false)
    setBusy(true)
    const error = await setPassword(password)
    if (error === null) {
      onDone()
      return
    }
    setBusy(false)
    setErrorKey(error)
  }

  return (
    <Screen
      title={t('invites.accept.passwordTitle')}
      description={t('invites.accept.passwordDescription')}
    >
      <form
        noValidate
        className="space-y-4"
        onSubmit={(event) => void submit(event)}
      >
        <PasswordField
          label={t('invites.accept.passwordLabel')}
          name="new-password"
          autoComplete="new-password"
          value={password}
          onChange={(event) => setPasswordValue(event.target.value)}
          error={
            tooShort
              ? t('invites.accept.passwordTooShort', {
                  min: MIN_PASSWORD_LENGTH,
                })
              : null
          }
        />
        {tooShort ? null : (
          <p className="text-sm text-muted-foreground">
            {t('invites.accept.passwordHint', { min: MIN_PASSWORD_LENGTH })}
          </p>
        )}
        {errorKey ? <FormError>{t(errorKey)}</FormError> : null}
        <Button
          type="submit"
          size="lg"
          className="h-11 w-full text-base"
          disabled={busy}
        >
          {t(
            busy
              ? 'invites.accept.passwordSubmitting'
              : errorKey
                ? 'invites.accept.retry'
                : 'invites.accept.passwordSubmit',
          )}
        </Button>
      </form>
    </Screen>
  )
}

/**
 * Last step: `accept_invitation()`. `automatic` runs it on arrival, for a
 * setup in progress; otherwise (a signed-in user who simply has no trainer)
 * it waits for the button. The call is idempotent, so running it again after
 * a lost answer, or twice at once, is harmless.
 */
function LinkStep({
  automatic,
  onDone,
}: {
  automatic: boolean
  onDone: () => Promise<void>
}) {
  const { t } = useTranslation()
  const { user, logout } = useAuth()
  // Each attempt is one call; the outcome is kept with the attempt's number,
  // so "running" is simply an attempt with no outcome yet.
  const [attempt, setAttempt] = useState(automatic ? 1 : 0)
  const [failure, setFailure] = useState<{
    attempt: number
    errorKey: AcceptErrorKey
  } | null>(null)

  const done = useEffectEvent(onDone)

  useEffect(() => {
    if (attempt === 0) return
    let cancelled = false
    void acceptInvitation().then(async (errorKey) => {
      if (cancelled) return
      if (errorKey) setFailure({ attempt, errorKey })
      else await done()
    })
    return () => {
      cancelled = true
    }
  }, [attempt])

  const running = attempt > 0 && failure?.attempt !== attempt
  const errorKey = failure?.attempt === attempt ? failure.errorKey : null

  return (
    <Screen
      title={t(
        automatic
          ? 'invites.accept.linkingTitle'
          : 'invites.accept.unlinkedTitle',
      )}
      description={
        automatic
          ? t('invites.accept.linkingDescription')
          : t('invites.accept.unlinkedDescription', {
              who: user?.email ?? user?.fullName ?? '',
            })
      }
    >
      <div className="space-y-4">
        {errorKey ? <FormError>{t(errorKey)}</FormError> : null}
        {running ? (
          <p role="status" className="text-sm text-muted-foreground">
            {t('invites.accept.linking')}
          </p>
        ) : (
          <Button
            size="lg"
            className="h-11 w-full text-base"
            onClick={() => setAttempt((value) => value + 1)}
          >
            {t(errorKey ? 'invites.accept.retry' : 'invites.accept.submit')}
          </Button>
        )}
        {running ? null : (
          <Button
            variant="outline"
            size="lg"
            className="h-11 w-full text-base"
            onClick={logout}
          >
            {t('auth.logout')}
          </Button>
        )}
      </div>
    </Screen>
  )
}
