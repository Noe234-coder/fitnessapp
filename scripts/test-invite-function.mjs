// Checks the invite-athlete Edge Function against the LOCAL stack, end to end.
//
//   npm run db:start && npm run db:reset
//   node scripts/test-invite-function.mjs
//
// It needs supabase/functions/.env (copy .env.example) and the fixtures from
// supabase/seed.sql (t1, a1, u). Every user it creates is
// <something>@fitnessapp.test and is deleted at the end, together with the
// invitations it caused, so it can be run again without a reset.
//
// Local only: the URL and keys come from `supabase status`, which never
// reports the hosted project. It uses the local secret and publishable keys,
// never the legacy service_role and anon ones.
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { createClient } from '@supabase/supabase-js'

// Plain TypeScript with no imports: Node 22 loads it as is.
import { defaultSecretKey } from '../supabase/functions/invite-athlete/secret-key.ts'

const FUNCTION_NAME = 'invite-athlete'
const EDGE_RUNTIME_PORT = 8081

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

const status = JSON.parse(
  execFileSync('npx', ['supabase', 'status', '-o', 'json'], {
    stdio: ['ignore', 'pipe', 'ignore'],
  }).toString(),
)
if (!/^http:\/\/(127\.0\.0\.1|localhost):/.test(status.API_URL ?? '')) {
  throw new Error('This script only runs against the local stack.')
}
if (!status.SECRET_KEY || !status.PUBLISHABLE_KEY) {
  throw new Error(
    '`supabase status` reports no secret or publishable key: is the stack running?',
  )
}

const appBaseUrl = readAppBaseUrl()
const appOrigin = new URL(appBaseUrl).origin
const functionUrl = `${status.FUNCTIONS_URL}/${FUNCTION_NAME}`

const clientOptions = {
  auth: { persistSession: false, autoRefreshToken: false },
}
const admin = createClient(status.API_URL, status.SECRET_KEY, clientOptions)
const newAnonClient = () =>
  createClient(status.API_URL, status.PUBLISHABLE_KEY, clientOptions)

const run = Math.random().toString(36).slice(2, 8)
const newEmail = `invite-test-new-${run}@fitnessapp.test`
const existingEmail = `invite-test-existing-${run}@fitnessapp.test`

let failures = 0
let checks = 0

function check(description, passed, detail) {
  checks += 1
  if (!passed) failures += 1
  console.log(`${passed ? 'ok  ' : 'FAIL'} ${description}`)
  if (!passed && detail !== undefined)
    console.log(`       ${JSON.stringify(detail)}`)
}

function readAppBaseUrl() {
  const envFile = fileURLToPath(
    new URL('../supabase/functions/.env', import.meta.url),
  )
  let content
  try {
    content = readFileSync(envFile, 'utf8')
  } catch {
    throw new Error(
      'supabase/functions/.env is missing: copy supabase/functions/.env.example.',
    )
  }
  const match = /^APP_BASE_URL=(.+)$/m.exec(content)
  if (!match)
    throw new Error('APP_BASE_URL is not set in supabase/functions/.env.')
  return match[1].trim().replace(/\/+$/, '')
}

/** Signs an existing user in, through the same mechanism the app uses. */
async function signIn(email) {
  const { data: link, error: linkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email,
  })
  if (linkError)
    throw new Error(`generateLink for ${email}: ${linkError.message}`)
  const { data, error } = await newAnonClient().auth.verifyOtp({
    token_hash: link.properties.hashed_token,
    type: 'magiclink',
  })
  if (error) throw new Error(`verifyOtp for ${email}: ${error.message}`)
  return { userId: data.session.user.id, token: data.session.access_token }
}

/** Calls the function the way supabase-js does from the browser. */
async function invite({
  token,
  body,
  method = 'POST',
  baseUrl = functionUrl,
} = {}) {
  const headers = { Origin: appOrigin, apikey: status.PUBLISHABLE_KEY }
  if (token) headers.Authorization = `Bearer ${token}`
  if (body !== undefined) headers['Content-Type'] = 'application/json'
  const response = await fetch(baseUrl, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const text = await response.text()
  let json = null
  try {
    json = JSON.parse(text)
  } catch {
    // Not JSON: the checks below report it.
  }
  return { status: response.status, headers: response.headers, text, json }
}

async function pendingInvitations(email) {
  const { data, error } = await admin
    .from('invitations')
    .select('trainer_id, email, expires_at, accepted_at')
    .eq('email', email)
    .is('accepted_at', null)
  if (error) throw new Error(`reading invitations: ${error.message}`)
  return data
}

/** The function's own address, bypassing the gateway. Null if unreachable. */
function directFunctionUrl() {
  try {
    const ip = execFileSync(
      'docker',
      [
        'inspect',
        '-f',
        '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}',
        'supabase_edge_runtime_fitnessapp',
      ],
      { stdio: ['ignore', 'pipe', 'ignore'] },
    )
      .toString()
      .trim()
    return ip ? `http://${ip}:${EDGE_RUNTIME_PORT}/${FUNCTION_NAME}` : null
  } catch {
    return null
  }
}

function parseInviteUrl(url) {
  const parsed = new URL(url)
  return {
    base: `${parsed.origin}${parsed.pathname}`,
    params: [...parsed.searchParams.keys()].sort().join(','),
    tokenHash: parsed.searchParams.get('token_hash'),
    type: parsed.searchParams.get('type'),
  }
}

const hasNoSupabaseLink = (text) =>
  !text.includes('action_link') &&
  !text.includes('email_otp') &&
  !text.includes('/auth/v1/')

// ---------------------------------------------------------------------------
// Checks
// ---------------------------------------------------------------------------

/**
 * The function reads its key from SUPABASE_SECRET_KEYS. The local runtime
 * always sets that variable, so a missing or malformed value cannot be
 * produced end to end: the parsing is checked here, and the function answers
 * `server_misconfigured` (500) whenever it returns null.
 */
function checkSecretKeyParsing() {
  check(
    'SUPABASE_SECRET_KEYS: the `default` key of the JSON object is used',
    defaultSecretKey('{"default":"sb_secret_example","other":"x"}') ===
      'sb_secret_example',
  )
  const malformed = {
    missing: undefined,
    empty: '',
    'not JSON': 'sb_secret_example',
    'no default': '{"other":"sb_secret_example"}',
    'empty default': '{"default":" "}',
    'default not a string': '{"default":{"key":"sb_secret_example"}}',
    'an array': '["sb_secret_example"]',
    'JSON null': 'null',
  }
  const accepted = Object.entries(malformed)
    .filter(([, raw]) => defaultSecretKey(raw) !== null)
    .map(([name]) => name)
  check(
    'SUPABASE_SECRET_KEYS: missing or malformed values give no key (-> server_misconfigured)',
    accepted.length === 0,
    accepted,
  )
}

async function main() {
  checkSecretKeyParsing()

  const { userId: trainerId, token: trainerToken } =
    await signIn('t1@fitnessapp.test')
  const { token: nonTrainerToken } = await signIn('u@fitnessapp.test')

  // CORS preflight ------------------------------------------------------------
  // Locally the gateway answers the preflight itself (allowing any origin).
  const preflightHeaders = {
    Origin: appOrigin,
    'Access-Control-Request-Method': 'POST',
    'Access-Control-Request-Headers':
      'authorization, apikey, content-type, x-client-info',
  }
  {
    const response = await fetch(functionUrl, {
      method: 'OPTIONS',
      headers: preflightHeaders,
    })
    const allowOrigin = response.headers.get('access-control-allow-origin')
    const allowHeaders = (
      response.headers.get('access-control-allow-headers') ?? ''
    ).toLowerCase()
    const allowMethods =
      response.headers.get('access-control-allow-methods') ?? ''
    check(
      'OPTIONS preflight through the gateway succeeds without a JWT',
      response.ok,
      response.status,
    )
    check(
      'the preflight allows the app origin',
      allowOrigin === appOrigin || allowOrigin === '*',
      allowOrigin,
    )
    check(
      'the preflight allows the headers supabase-js sends and POST',
      ['authorization', 'apikey', 'content-type', 'x-client-info'].every(
        (header) => allowHeaders.includes(header),
      ) && allowMethods.includes('POST'),
      { allowHeaders, allowMethods },
    )
  }

  // The function's own CORS headers, which is what a deployed function sends.
  const directUrl = directFunctionUrl()
  let directReachable = false
  if (directUrl) {
    try {
      const response = await fetch(directUrl, {
        method: 'OPTIONS',
        headers: preflightHeaders,
        signal: AbortSignal.timeout(5000),
      })
      directReachable = true
      check(
        'the function answers OPTIONS itself: 204, only the app origin allowed (not *)',
        response.status === 204 &&
          response.headers.get('access-control-allow-origin') === appOrigin &&
          (response.headers.get('access-control-allow-methods') ?? '').includes(
            'POST',
          ),
        {
          status: response.status,
          allowOrigin: response.headers.get('access-control-allow-origin'),
        },
      )
    } catch {
      directReachable = false
    }
  }
  if (!directReachable) {
    console.log(
      'skip the function is not reachable without the gateway (container IP not routable)',
    )
  }

  // Not allowed ---------------------------------------------------------------
  {
    const response = await invite({ body: { email: newEmail } })
    check(
      'no JWT -> 401 unauthorized',
      response.status === 401 && response.json?.error === 'unauthorized',
      { status: response.status, body: response.text },
    )
    check(
      'error responses carry the CORS headers too',
      response.headers.has('access-control-allow-origin'),
    )
  }
  {
    const response = await invite({
      token: status.PUBLISHABLE_KEY,
      body: { email: newEmail },
    })
    check(
      'the publishable key as bearer (a signed-out client) -> 401 unauthorized',
      response.status === 401 && response.json?.error === 'unauthorized',
      { status: response.status, body: response.text },
    )
  }
  {
    const response = await invite({
      token: 'not-a-jwt',
      body: { email: newEmail },
    })
    check(
      'a malformed token -> 401 unauthorized',
      response.status === 401 && response.json?.error === 'unauthorized',
      { status: response.status, body: response.text },
    )
  }
  {
    const response = await invite({
      token: nonTrainerToken,
      body: { email: newEmail },
    })
    check(
      'a logged-in user who is not a trainer -> 403 forbidden',
      response.status === 403 && response.json?.error === 'forbidden',
      { status: response.status, body: response.text },
    )
  }
  check(
    'none of the refused calls created an invitation',
    (await pendingInvitations(newEmail)).length === 0,
  )
  {
    const response = await invite({ token: trainerToken, method: 'GET' })
    check('GET -> 405', response.status === 405, response.status)
  }
  for (const body of [
    {},
    { email: 'not-an-email' },
    { email: newEmail, full_name: 42 },
  ]) {
    const response = await invite({ token: trainerToken, body })
    check(
      `invalid body ${JSON.stringify(body).replace(newEmail, '<email>')} -> 400 invalid_request`,
      response.status === 400 && response.json?.error === 'invalid_request',
      { status: response.status, body: response.text },
    )
  }

  // Trainer + new email -------------------------------------------------------
  // Sent in mixed case with spaces: the function trims and lowercases it.
  const first = await invite({
    token: trainerToken,
    body: { email: `  ${newEmail.toUpperCase()} `, full_name: 'Invite Test' },
  })
  check('trainer + new email -> 200', first.status === 200, {
    status: first.status,
    body: first.json?.error,
  })
  check(
    'the response body is exactly { url }',
    first.json !== null && Object.keys(first.json).join(',') === 'url',
    Object.keys(first.json ?? {}),
  )
  check(
    'the response never contains action_link, the OTP or a Supabase auth URL',
    hasNoSupabaseLink(first.text),
  )
  const firstUrl = first.json?.url ? parseInviteUrl(first.json.url) : null
  check(
    'the URL is <APP_BASE_URL>/accept-invite?token_hash=…&type=invite',
    firstUrl !== null &&
      firstUrl.base === `${appBaseUrl}/accept-invite` &&
      firstUrl.params === 'token_hash,type' &&
      firstUrl.type === 'invite' &&
      Boolean(firstUrl.tokenHash),
    firstUrl && {
      base: firstUrl.base,
      params: firstUrl.params,
      type: firstUrl.type,
    },
  )
  if (directReachable) {
    // Asked again without the gateway, to read the function's own header.
    const response = await invite({
      baseUrl: directUrl,
      body: { email: newEmail },
    })
    check(
      'the function sends Access-Control-Allow-Origin: <app origin> on its responses',
      response.headers.get('access-control-allow-origin') === appOrigin,
      response.headers.get('access-control-allow-origin'),
    )
  }
  {
    const rows = await pendingInvitations(newEmail)
    const expiresInHours = rows[0]
      ? (new Date(rows[0].expires_at) - Date.now()) / 3_600_000
      : null
    check(
      'one pending invitation: lowercase email, this trainer, expires in 24 h',
      rows.length === 1 &&
        rows[0].trainer_id === trainerId &&
        expiresInHours > 23.9 &&
        expiresInHours <= 24,
      { count: rows.length, expiresInHours },
    )
  }

  // Same email again ----------------------------------------------------------
  const second = await invite({
    token: trainerToken,
    body: { email: newEmail },
  })
  const secondUrl = second.json?.url ? parseInviteUrl(second.json.url) : null
  check(
    'same email again -> 200 with a new URL',
    second.status === 200 &&
      secondUrl !== null &&
      Boolean(secondUrl.tokenHash) &&
      secondUrl.tokenHash !== firstUrl?.tokenHash,
    { status: second.status, body: second.json?.error },
  )
  check(
    'and a second pending invitation',
    (await pendingInvitations(newEmail)).length === 2,
  )
  check(
    'still type=invite: the user has not accepted yet',
    secondUrl?.type === 'invite',
    secondUrl?.type,
  )

  // An email that already has a confirmed user ----------------------------------
  {
    const { error } = await admin.auth.admin.createUser({
      email: existingEmail,
      email_confirm: true,
    })
    if (error) throw new Error(`createUser: ${error.message}`)
  }
  const existing = await invite({
    token: trainerToken,
    body: { email: existingEmail },
  })
  const existingUrl = existing.json?.url
    ? parseInviteUrl(existing.json.url)
    : null
  check(
    'an email that already has an account -> 200 with type=magiclink',
    existing.status === 200 &&
      existingUrl?.type === 'magiclink' &&
      Boolean(existingUrl?.tokenHash),
    { status: existing.status, type: existingUrl?.type },
  )
  check(
    'that response has no Supabase link either',
    hasNoSupabaseLink(existing.text),
  )

  // Already linked ------------------------------------------------------------
  {
    const response = await invite({
      token: trainerToken,
      body: { email: 'a1@fitnessapp.test' },
    })
    check(
      'an athlete with an active link -> 409 already_linked',
      response.status === 409 && response.json?.error === 'already_linked',
      { status: response.status, body: response.text },
    )
    check(
      'and no invitation is recorded for him',
      (await pendingInvitations('a1@fitnessapp.test')).length === 0,
    )
  }
  {
    const response = await invite({
      token: trainerToken,
      body: { email: 't1@fitnessapp.test' },
    })
    check(
      'a self-linked trainer inviting himself -> 409 already_linked',
      response.status === 409 && response.json?.error === 'already_linked',
      { status: response.status, body: response.text },
    )
  }

  // The athlete's side, with the URLs returned above -----------------------------
  if (secondUrl?.tokenHash) {
    const athlete = newAnonClient()
    const stale = await newAnonClient().auth.verifyOtp({
      token_hash: firstUrl.tokenHash,
      type: 'invite',
    })
    check(
      'the first URL stopped working when the second was created',
      Boolean(stale.error),
    )

    const { data, error } = await athlete.auth.verifyOtp({
      token_hash: secondUrl.tokenHash,
      type: 'invite',
    })
    check(
      'verifyOtp({ token_hash, type: invite }) gives the athlete a session',
      !error && Boolean(data.session),
      error?.code,
    )
    if (data.session) {
      const password = await athlete.auth.updateUser({
        password: `Pw-${run}-${Date.now()}`,
      })
      check(
        'the invited athlete can set a password',
        !password.error,
        password.error?.code,
      )

      const accepted = await athlete.rpc('accept_invitation')
      check(
        "rpc('accept_invitation') returns the trainer's id",
        !accepted.error && accepted.data === trainerId,
        accepted.error?.message,
      )
      const retried = await athlete.rpc('accept_invitation')
      check(
        'calling it again returns the same trainer',
        !retried.error && retried.data === trainerId,
        retried.error?.message,
      )
      const { data: links } = await admin
        .from('trainer_athletes')
        .select('trainer_id, ended_at')
        .eq('athlete_id', data.session.user.id)
      check(
        'the athlete has exactly one active link, to that trainer',
        links?.length === 1 &&
          links[0].trainer_id === trainerId &&
          links[0].ended_at === null,
        links,
      )
      const { data: profile } = await athlete
        .from('profiles')
        .select('full_name')
        .eq('id', data.session.user.id)
        .maybeSingle()
      check(
        'his profile has the full_name the trainer typed',
        profile?.full_name === 'Invite Test',
        profile,
      )

      const again = await invite({
        token: trainerToken,
        body: { email: newEmail },
      })
      check(
        'inviting him again now -> 409 already_linked',
        again.status === 409 && again.json?.error === 'already_linked',
        { status: again.status, body: again.text },
      )
    }
  }
  if (existingUrl?.tokenHash) {
    const athlete = newAnonClient()
    const { data, error } = await athlete.auth.verifyOtp({
      token_hash: existingUrl.tokenHash,
      type: 'magiclink',
    })
    check(
      'verifyOtp({ token_hash, type: magiclink }) gives the existing user a session',
      !error && Boolean(data.session),
      error?.code,
    )
    if (data.session) {
      const accepted = await athlete.rpc('accept_invitation')
      check(
        "and rpc('accept_invitation') links him to the trainer",
        !accepted.error && accepted.data === trainerId,
        accepted.error?.message,
      )
    }
  }
  {
    const stranger = createClient(status.API_URL, status.PUBLISHABLE_KEY, {
      ...clientOptions,
      global: { headers: { Authorization: `Bearer ${nonTrainerToken}` } },
    })
    const { error } = await stranger.rpc('accept_invitation')
    check(
      'a user who was not invited gets invitation_not_found from the rpc',
      error?.message === 'invitation_not_found',
      error?.message,
    )
  }
}

async function cleanUp() {
  // Deleting the users cascades to their profiles, links and accepted invitations.
  const testEmails = [newEmail, existingEmail]
  const { data } = await admin.auth.admin.listUsers({ perPage: 1000 })
  for (const user of data?.users ?? []) {
    if (testEmails.includes(user.email))
      await admin.auth.admin.deleteUser(user.id)
  }
  await admin.from('invitations').delete().in('email', testEmails)
}

let stopped = false
try {
  await main()
} catch (error) {
  stopped = true
  console.error(`FAIL the script stopped early: ${error.message}`)
} finally {
  await cleanUp()
}

console.log(`\n${checks - failures}/${checks} checks passed`)
process.exit(failures === 0 && !stopped ? 0 : 1)
