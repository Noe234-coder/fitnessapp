import { useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeftIcon } from 'lucide-react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { Link } from 'react-router'
import { z } from 'zod'

import { Button } from '@/components/ui/button'
import { useAuth } from '@/features/auth/auth-context'
import { emailSchema } from '@/features/auth/email'
import { FormError, TextField } from '@/features/auth/form-fields'

import { expiryOf } from './expiry'
import {
  fetchPendingInvitations,
  inviteAthlete,
  type PendingInvitation,
} from './invite-api'
import type { InviteErrorKey } from './invite-errors'
import { useOnline } from './use-online'

/** The same limit as the invite-athlete function. */
const fullNameSchema = z.string().trim().max(200)

const pendingQueryKey = (trainerId: string) =>
  ['invitations', 'pending', trainerId] as const

/**
 * The trainer's "Invite athlete" screen: a form that returns an invite link
 * for him to pass on, and the list of invitations still pending.
 *
 * The link carries the invite token, so it is kept in this component's state
 * and nowhere else: not in the query cache, not in storage. It is shown once
 * and is gone when the trainer leaves the screen. Online only.
 */
export function InviteAthletePage() {
  const { t } = useTranslation()
  const online = useOnline()
  const [invite, setInvite] = useState<{ email: string; url: string } | null>(
    null,
  )

  return (
    <main className="flex flex-1 flex-col gap-8 py-6">
      <div className="space-y-3">
        <Button asChild variant="ghost" size="lg" className="-ml-2.5">
          <Link to="/">
            <ArrowLeftIcon aria-hidden />
            {t('invites.send.back')}
          </Link>
        </Button>
        <h1 className="text-3xl font-semibold tracking-tight">
          {t('invites.send.title')}
        </h1>
        <p className="text-muted-foreground">{t('invites.send.description')}</p>
      </div>

      {invite ? <InviteLink email={invite.email} url={invite.url} /> : null}

      {online ? (
        <>
          <InviteForm onCreated={setInvite} />
          <PendingInvitations />
        </>
      ) : (
        <div role="status" className="rounded-lg border px-4 py-3">
          <p className="font-medium">{t('invites.send.offlineTitle')}</p>
          <p className="text-sm text-muted-foreground">
            {t('invites.send.offline')}
          </p>
        </div>
      )}
    </main>
  )
}

function InviteForm({
  onCreated,
}: {
  onCreated: (invite: { email: string; url: string }) => void
}) {
  const { t } = useTranslation()
  const { user } = useAuth()
  const queryClient = useQueryClient()
  const [email, setEmail] = useState('')
  const [fullName, setFullName] = useState('')
  const [emailInvalid, setEmailInvalid] = useState(false)
  const [nameTooLong, setNameTooLong] = useState(false)
  const [errorKey, setErrorKey] = useState<InviteErrorKey | null>(null)
  const [submitting, setSubmitting] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    const parsedEmail = emailSchema.safeParse(email)
    const parsedName = fullNameSchema.safeParse(fullName)
    setEmailInvalid(!parsedEmail.success)
    setNameTooLong(!parsedName.success)
    setErrorKey(null)
    if (!parsedEmail.success || !parsedName.success) return

    setSubmitting(true)
    const result = await inviteAthlete({
      email: parsedEmail.data,
      fullName: parsedName.data || null,
    })
    setSubmitting(false)
    if ('errorKey' in result) {
      setErrorKey(result.errorKey)
      return
    }
    onCreated({ email: parsedEmail.data, url: result.url })
    setEmail('')
    setFullName('')
    if (user) {
      void queryClient.invalidateQueries({ queryKey: pendingQueryKey(user.id) })
    }
  }

  return (
    <form
      noValidate
      className="space-y-4"
      onSubmit={(event) => void submit(event)}
    >
      <TextField
        label={t('invites.send.email')}
        type="email"
        name="athlete-email"
        autoComplete="off"
        autoCapitalize="none"
        autoCorrect="off"
        spellCheck={false}
        inputMode="email"
        value={email}
        onChange={(event) => setEmail(event.target.value)}
        error={emailInvalid ? t('invites.send.emailInvalid') : null}
      />
      <TextField
        label={t('invites.send.fullName')}
        name="athlete-name"
        autoComplete="off"
        value={fullName}
        onChange={(event) => setFullName(event.target.value)}
        error={nameTooLong ? t('invites.send.fullNameTooLong') : null}
      />
      {errorKey ? <FormError>{t(errorKey)}</FormError> : null}
      <Button
        type="submit"
        size="lg"
        className="h-11 w-full text-base"
        disabled={submitting}
      >
        {t(submitting ? 'invites.send.submitting' : 'invites.send.submit')}
      </Button>
    </form>
  )
}

/** The link just created, with a copy button. */
function InviteLink({ email, url }: { email: string; url: string }) {
  const { t } = useTranslation()
  const inputRef = useRef<HTMLInputElement>(null)
  // Remembers which link was copied, so a new link starts as "not copied".
  const [copy, setCopy] = useState<{
    url: string
    outcome: 'copied' | 'selected'
  } | null>(null)
  const outcome = copy?.url === url ? copy.outcome : null

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(url)
      setCopy({ url, outcome: 'copied' })
    } catch {
      // No clipboard access (permission, old browser): leave the text
      // selected so it can be copied by hand.
      inputRef.current?.focus()
      inputRef.current?.select()
      setCopy({ url, outcome: 'selected' })
    }
  }

  return (
    <section className="space-y-3 rounded-lg border p-4">
      <TextField
        ref={inputRef}
        label={t('invites.send.linkLabel', { email })}
        readOnly
        value={url}
        onFocus={(event) => event.currentTarget.select()}
      />
      <p className="text-sm text-muted-foreground">
        {t('invites.send.linkHelp')}
      </p>
      <Button
        size="lg"
        className="h-11 w-full text-base"
        onClick={() => void copyLink()}
      >
        {t(outcome === 'copied' ? 'invites.send.copied' : 'invites.send.copy')}
      </Button>
      {outcome === 'selected' ? (
        <p role="status" className="text-sm text-muted-foreground">
          {t('invites.send.copyFallback')}
        </p>
      ) : null}
    </section>
  )
}

const CLOCK_TICK_MS = 30_000

/** The current time, refreshed often enough for "expires in …". */
function useNow(): number {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), CLOCK_TICK_MS)
    return () => clearInterval(timer)
  }, [])
  return now
}

function PendingInvitations() {
  const { t } = useTranslation()
  const { user } = useAuth()
  const trainerId = user?.id ?? ''
  const pending = useQuery({
    queryKey: pendingQueryKey(trainerId),
    queryFn: () => fetchPendingInvitations(trainerId),
    enabled: trainerId !== '',
  })

  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold">{t('invites.pending.title')}</h2>
      {pending.isPending ? (
        <p role="status" className="text-sm text-muted-foreground">
          {t('auth.loading')}
        </p>
      ) : pending.isError ? (
        <div className="space-y-3">
          <FormError>{t('invites.pending.loadError')}</FormError>
          <Button
            variant="outline"
            size="lg"
            className="h-11 w-full text-base"
            onClick={() => void pending.refetch()}
          >
            {t('invites.accept.retry')}
          </Button>
        </div>
      ) : pending.data.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          {t('invites.pending.empty')}
        </p>
      ) : (
        <PendingList invitations={pending.data} />
      )}
      <p className="text-sm text-muted-foreground">
        {t('invites.pending.hint')}
      </p>
    </section>
  )
}

function PendingList({ invitations }: { invitations: PendingInvitation[] }) {
  const { t, i18n } = useTranslation()
  const now = useNow()
  const relativeTime = new Intl.RelativeTimeFormat(i18n.language, {
    numeric: 'always',
  })

  return (
    <ul className="divide-y rounded-lg border">
      {invitations.map((invitation) => {
        const expiry = expiryOf(invitation.expires_at, now)
        return (
          <li key={invitation.id} className="space-y-0.5 px-4 py-3">
            <p className="font-medium break-all">{invitation.email}</p>
            <p
              className={
                expiry.expired
                  ? 'text-sm text-destructive'
                  : 'text-sm text-muted-foreground'
              }
            >
              {expiry.expired
                ? t('invites.pending.expired')
                : t('invites.pending.expires', {
                    when: relativeTime.format(expiry.value, expiry.unit),
                  })}
            </p>
          </li>
        )
      })}
    </ul>
  )
}
