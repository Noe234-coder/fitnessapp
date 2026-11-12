# Handoff: step 4b-2 (auth + invites, hosted)

Written on 2026-11-12, at the end of the first session of step 4b-2. Branch:
`chore/step-4b2-hosted` (local only, not pushed). Hosted project: `fitnessapp`,
ref `cfxafmgjuyigayywntjn`, eu-west-3, Postgres 17.11.

Delete this file when step 4b-2 is closed out; what must last goes into
CLAUDE.md ("Hosted project" note, step 7).

## Where we are

Two of the four hosted writes are done and verified. Nothing is deployed to the
function runtime yet, and the hosted project still has no users.

| #   | Hosted write                       | State                    |
| --- | ---------------------------------- | ------------------------ |
| 1   | `config push --remote`             | Done, verified           |
| 2   | `db push --remote`                 | Done, verified           |
| 3   | `secrets set APP_BASE_URL`         | Not done, needs a yes    |
| 4   | `functions deploy invite-athlete`  | Not done, needs a yes    |
| 5   | First trainer (dashboard + SQL)    | Not done, needs a yes    |

## Step 0 (done)

- Login hint "Forgot your password? …" removed, with both locale keys:
  commit `09dfcec`. CLAUDE.md's forms line now says Zod with plain React state;
  React Hook Form comes with the first large form (step 6).
- 4b-1 merged into `main` as a fast-forward (`de09b93..09dfcec`); CI run
  43297062670: `app`, `db` and `deploy` all green. The UI is live.
- Production origin, confirmed by Noé:
  `https://fitnessapp.myfitnessapp.workers.dev` (https, no trailing slash).
- The orphaned CI run 43095104173 cannot be cancelled or deleted
  (`gh run delete` answers HTTP 403). Left as is.

## Hosted baseline, before any write

Read on 2026-11-12: no migrations applied, no tables in `public`, no `private`
schema, no Edge Functions, 0 rows in `auth.users`, sign-up enabled
(`disable_signup: false`).

## Local commits on this branch

- `d1ccae9` — `config.toml`: `site_url` = the production origin,
  `additional_redirect_urls` = the two local dev origins,
  `minimum_password_length = 8`.
- `9e408ec` — `config.toml` mirrors the hosted values for twelve keys that
  were local defaults (email and SMS confirmations on, email `max_frequency`
  `1m0s`, OTP length 8, TOTP MFA on, pooler 15 / 200, vector buckets off with
  their limits unset). After the restart: `db:test` 204,
  `scripts/test-invite-function.mjs` 39/39, no test changed.
- This file.

## Hosted write 1: `npx supabase config push --remote` (done)

Run by Noé in his own terminal (the CLI's confirmation cannot be answered from
a Claude session). According to Noé the CLI showed six keys, the same as the
read-only diff beforehand:

| Key                             | Before                  | After                                         |
| ------------------------------- | ----------------------- | --------------------------------------------- |
| `auth.enable_signup`            | `true`                  | `false`                                       |
| `auth.email.otp_expiry`         | 3600                    | 86400                                         |
| `auth.minimum_password_length`  | 6                       | 8                                             |
| `auth.site_url`                 | `http://localhost:3000` | `https://fitnessapp.myfitnessapp.workers.dev` |
| `auth.additional_redirect_urls` | `[]`                    | `http://localhost:5173`, `http://127.0.0.1:5173` |
| `auth.password_requirements`    | not set                 | `""`                                          |

Verified afterwards (read-only, by Claude):

- `config diff --remote`: "No config differences found".
- Public auth settings: `disable_signup: true`, anonymous users off.
- `POST /auth/v1/signup` with a throwaway `@fitnessapp.test` address: HTTP 422
  `signup_disabled`.
- `POST /auth/v1/signup` with an empty body: HTTP 422
  `anonymous_provider_disabled`.
- `auth.users`: 0 rows.

Properties `config.toml` declares that the push does not manage: Noé's push
output says 10, so they were not sent. The read-only diff had listed 12 as
"not compared" (Apple client id and email-optional, the OAuth server path and
dynamic registration, `auth.rate_limit.email_sent`, the Twilio account and
message-service ids, both `db.network_restrictions` CIDR lists, and the three
storage analytics limits) plus 2 masked credentials. The two numbers were not
reconciled. Of these, only the network restrictions were read back: hosted
allows `0.0.0.0/0` and `::/0`, the same as the file.
`auth.rate_limit.email_sent` (2 in the file) was never compared with the
hosted value; it is under Authentication → Rate Limits in the dashboard.

## Hosted write 2: `npx supabase db push --remote` (done)

Run by Noé in his own terminal. According to Noé the dry run was shown first
and matched, and the four migrations applied with no errors.

Verification (read-only, all run by Claude on 2026-11-12, nothing pending):

- **Migrations** (`list_migrations`): exactly `20261110155046`
  create_private_helpers, `20261110155047` create_identity, `20261110155048`
  create_libraries, `20261111200844` create_invitation_functions.
- **RLS** (`list_tables` and the catalog): 9 tables in `public` (`profiles`,
  `trainers`, `trainer_athletes`, `invitations`, `athlete_profiles`,
  `movement_categories`, `exercises`, `foods`, `food_swaps`), every one with
  RLS enabled. `anon` has no table grant.
- **Schemas**: `private` exists; `anon` has no usage on it, `authenticated`
  does. The `tests` schema does not exist (the seed was not pushed). The API
  refuses `private`: PGRST106, "Only the following schemas are exposed:
  public, graphql_public".
- **Functions**: all seven (six in `private`, `public.accept_invitation()`)
  have `search_path=""`. `accept_invitation()` is security definer;
  `anon` and PUBLIC cannot execute it, `authenticated` can. Its ACL is
  `postgres`, `authenticated` and `service_role`: the `service_role` entry is
  not in the migration (the function still needs a JWT with an email, so such
  a call raises `not_authenticated`). Called through the API without a
  session: HTTP 401, code 42501.
- **Row counts**: `auth.users` 0, and 0 in each of the 9 public tables.
- **Security advisors**: no ERROR. Two WARN, both expected:
  - `authenticated_security_definer_function_executable` on
    `public.accept_invitation()`: the deliberate design of the invite flow.
  - `auth_otp_long_expiry`: the 24-hour `otp_expiry`, chosen so invite links
    last a day.
- **Performance advisors** (required by step 3b): WARN
  `multiple_permissive_policies` on 8 tables for `authenticated` SELECT
  (`athlete_profiles`, `exercises`, `food_swaps`, `foods`, `invitations`,
  `movement_categories`, `profiles`, `trainer_athletes`); INFO
  `unindexed_foreign_keys` for `food_swaps_from_food_id_trainer_id_fkey`;
  INFO `unused_index` for 10 indexes (the tables are empty). Nothing was
  changed: a fix is a new migration, and Noé decides.

## Open point before writes 3 and 4: the service-role env name

Checked on 2026-11-12 in the Supabase docs
(<https://supabase.com/docs/guides/functions/secrets>): hosted Edge Functions
get `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` by default, which are the
two names `invite-athlete` reads. But the docs list
`SUPABASE_SERVICE_ROLE_KEY` under "Legacy keys", next to the newer
`SUPABASE_SECRET_KEYS` (a JSON object, the key under `default`), and the
key-migration guide says the legacy keys keep working until the end of 2026.

Not checked yet: whether this project (created 2026-11-07) has the legacy
keys enabled at all. If it does not, the deployed function would answer
`server_misconfigured` or fail to authenticate. To decide tomorrow, before
deploying: deploy as is and test, or first change the function to read
`SUPABASE_SECRET_KEYS` (a code change in `supabase/functions/`, with the local
checks re-run).

## Remaining, in order (each hosted write needs Noé's separate yes)

1. `npx supabase secrets set APP_BASE_URL=https://fitnessapp.myfitnessapp.workers.dev`
   (a public value; exact origin, no trailing slash).
2. `npx supabase functions deploy invite-athlete`, then confirm
   `verify_jwt = false` is in effect (`get_edge_function`).
3. Hosted checks, read-only or harmless:
   - the function without a JWT → 401 `unauthorized`; a wrong method → report
     the code returned;
   - CORS: an `OPTIONS` request with `Origin` = the production origin and one
     with `Origin: https://evil.example`; record the
     `Access-Control-Allow-Origin` of each exactly;
   - a REST select on `profiles` with the publishable key returns no rows or
     a permission error.
4. First trainer: Noé creates the auth user in the dashboard (Authentication →
   Users → Add user, auto-confirm) and chooses the email; Claude never asks
   for the password. Read-only check that the profile row exists, then one SQL
   write, shown first: the `trainers` row and the self-link in
   `trainer_athletes`. The email never goes into the repo.
5. Phone end-to-end by Noé: invite `athlete-test@fitnessapp.test` ("Test
   Athlete") from the live app, send the link in a real WhatsApp message and
   look at the preview without tapping, open it on the phone (it must still
   offer "Accept"), accept, set a password, log out and in, open the link
   again (expired), airplane mode and reload (still signed in).
6. Read-only check of the invitation, the link and the profile locale; then
   Noé deletes the test user in the dashboard and Claude verifies that only
   the trainer remains.
7. Close out: push this branch, CI green, fast-forward into `main`; add the
   "Hosted project" note to CLAUDE.md; update the invites text there if the
   hosted CORS result changes any statement; delete this file.

## Rules for this step

- A hosted write happens only after Noé's explicit yes in chat, one at a
  time, after the exact command and its effect have been shown.
- Noé runs `config push` and `db push` in his own terminal: their confirmation
  is interactive.
- Never `--yes` on a hosted change.
- Schema fixes go through migrations in the repo, never the dashboard or MCP.
- No secret, password or real email in the repo, a commit message or the
  chat. The only test address is `athlete-test@fitnessapp.test`.
- If anything differs from the plan, stop and report.
