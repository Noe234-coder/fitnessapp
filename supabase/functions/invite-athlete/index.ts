// invite-athlete: a trainer invites an athlete by email (CLAUDE.md "Invites").
//
// POST { email, full_name? } with the trainer's access token.
// 200 { url }: a link to the app's /accept-invite page, for the trainer to
// send to the athlete himself (WhatsApp). No email is sent.
//
// The link carries the hashed token, not Supabase's `action_link`: that one is
// consumed by a plain GET, so a link preview would spend it before the athlete
// taps it. The app calls verifyOtp({ token_hash, type }) when he taps "Accept".
//
// config.toml sets verify_jwt = false (the CORS preflight has no Authorization
// header), so this function verifies the caller's JWT itself.
//
// Never log or store the token, the link or the invited email.
import { createClient } from 'npm:@supabase/supabase-js@2.119.0'

import { corsHeaders } from './cors.ts'

const INVITATION_TTL_MS = 24 * 60 * 60 * 1000
const MAX_EMAIL_LENGTH = 254
const MAX_FULL_NAME_LENGTH = 200

type ErrorCode =
  | 'server_misconfigured'
  | 'method_not_allowed'
  | 'unauthorized'
  | 'forbidden'
  | 'invalid_request'
  | 'already_linked'
  | 'invite_failed'

type LinkType = 'invite' | 'magiclink'

interface Config {
  supabaseUrl: string
  serviceRoleKey: string
  /** Where the app is served, without a trailing slash. */
  appBaseUrl: string
  /** The only origin allowed to call this function from a browser. */
  appOrigin: string
}

function readConfig(): Config | null {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const appBaseUrl = Deno.env.get('APP_BASE_URL')
  if (!supabaseUrl || !serviceRoleKey || !appBaseUrl) return null
  try {
    return {
      supabaseUrl,
      serviceRoleKey,
      appBaseUrl: appBaseUrl.replace(/\/+$/, ''),
      appOrigin: new URL(appBaseUrl).origin,
    }
  } catch {
    return null
  }
}

const config = readConfig()

function json(
  status: number,
  body: { url: string } | { error: ErrorCode },
  headers: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...headers,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  })
}

function bearerToken(req: Request): string | null {
  const match = /^Bearer\s+(\S+)$/i.exec(req.headers.get('Authorization') ?? '')
  return match ? match[1] : null
}

/** The validated request body, or null if it is not what we expect. */
async function readBody(
  req: Request,
): Promise<{ email: string; fullName: string | null } | null> {
  let body: unknown
  try {
    body = await req.json()
  } catch {
    return null
  }
  if (typeof body !== 'object' || body === null) return null
  const { email, full_name: fullName } = body as Record<string, unknown>

  if (typeof email !== 'string') return null
  const normalizedEmail = email.trim().toLowerCase()
  if (
    normalizedEmail.length > MAX_EMAIL_LENGTH ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)
  ) {
    return null
  }

  if (fullName === undefined || fullName === null) {
    return { email: normalizedEmail, fullName: null }
  }
  if (typeof fullName !== 'string') return null
  const trimmedName = fullName.trim()
  if (trimmedName.length > MAX_FULL_NAME_LENGTH) return null
  return { email: normalizedEmail, fullName: trimmedName || null }
}

Deno.serve(async (req) => {
  if (!config) {
    console.error(
      'invite-athlete: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY or APP_BASE_URL is missing or invalid',
    )
    return json(500, { error: 'server_misconfigured' }, {})
  }
  const cors = corsHeaders(config.appOrigin)

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors })
  }
  if (req.method !== 'POST') {
    return json(
      405,
      { error: 'method_not_allowed' },
      { ...cors, Allow: 'POST, OPTIONS' },
    )
  }

  // Service-role client: used to verify the caller, and for everything RLS
  // does not let a trainer do himself.
  const admin = createClient(config.supabaseUrl, config.serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  })

  // 1. Who is calling? A missing, malformed, expired or non-user token (the
  //    anon key included) all get the same answer.
  const token = bearerToken(req)
  if (!token) return json(401, { error: 'unauthorized' }, cors)
  const { data: caller, error: callerError } = await admin.auth.getUser(token)
  if (callerError || !caller.user)
    return json(401, { error: 'unauthorized' }, cors)
  const trainerId = caller.user.id

  // 2. Only trainers invite.
  const { data: trainer, error: trainerError } = await admin
    .from('trainers')
    .select('profile_id')
    .eq('profile_id', trainerId)
    .maybeSingle()
  if (trainerError) {
    console.error('invite-athlete: reading trainers failed', trainerError.code)
    return json(500, { error: 'invite_failed' }, cors)
  }
  if (!trainer) return json(403, { error: 'forbidden' }, cors)

  const body = await readBody(req)
  if (!body) return json(400, { error: 'invalid_request' }, cors)

  // 3. A new email gets an invite token (this creates the auth user). An
  //    email that already has a confirmed user gets a magic-link token.
  let type: LinkType = 'invite'
  let link = await admin.auth.admin.generateLink({
    type: 'invite',
    email: body.email,
    options: body.fullName ? { data: { full_name: body.fullName } } : undefined,
  })
  if (link.error?.code === 'email_exists') {
    type = 'magiclink'
    link = await admin.auth.admin.generateLink({
      type: 'magiclink',
      email: body.email,
    })
  }
  if (
    link.error?.code === 'validation_failed' ||
    link.error?.code === 'email_address_invalid'
  ) {
    return json(400, { error: 'invalid_request' }, cors)
  }
  const invitedUserId = link.data?.user?.id
  const hashedToken = link.data?.properties?.hashed_token
  if (link.error || !invitedUserId || !hashedToken) {
    console.error(
      'invite-athlete: generateLink failed',
      type,
      link.error?.status,
      link.error?.code,
    )
    return json(500, { error: 'invite_failed' }, cors)
  }

  // 4. Somebody who already trains with a trainer cannot be invited. This
  //    also stops a self-linked trainer from inviting himself. The token
  //    generated above is simply never handed out.
  const { data: activeLink, error: activeLinkError } = await admin
    .from('trainer_athletes')
    .select('id')
    .eq('athlete_id', invitedUserId)
    .is('ended_at', null)
    .maybeSingle()
  if (activeLinkError) {
    console.error(
      'invite-athlete: reading trainer_athletes failed',
      activeLinkError.code,
    )
    return json(500, { error: 'invite_failed' }, cors)
  }
  if (activeLink) return json(409, { error: 'already_linked' }, cors)

  // 5. Record the invitation. accept_invitation() looks it up by email.
  const { error: insertError } = await admin.from('invitations').insert({
    trainer_id: trainerId,
    email: body.email,
    expires_at: new Date(Date.now() + INVITATION_TTL_MS).toISOString(),
  })
  if (insertError) {
    console.error(
      'invite-athlete: inserting the invitation failed',
      insertError.code,
    )
    return json(500, { error: 'invite_failed' }, cors)
  }

  const url = new URL(`${config.appBaseUrl}/accept-invite`)
  url.searchParams.set('token_hash', hashedToken)
  url.searchParams.set('type', type)
  return json(200, { url: url.toString() }, cors)
})
