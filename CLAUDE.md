# CLAUDE.md — FitnessApp

> Source of truth for Claude Code. The claude.ai Project keeps a snapshot that Noé refreshes from this file.

## What this app is
FitnessApp is a mobile-first web app for a personal trainer and his athletes. It replaces Google Sheets (workouts, meal plans, daily tracking), Loom and WhatsApp.
- **Trainer:** maintains his own exercise and food libraries; builds mesocycle workout programs (named training days, a warm-up day, versioned week-to-week prescriptions) and meal plans (meals with macro targets, alternative options, swap rules); keeps templates and copies them to athletes; invites athletes; reviews athlete logs and weekly check-ins. He may also be his own athlete.
- **Athlete:** each calendar week does the program's training days in any order, on any day; logs reps/weight per set; ticks off meals; logs daily bodyweight/steps/sleep/stress; fills a weekly check-in and body measurements — often at the gym with weak signal.
- Scale: one trainer, ~30–40 athletes. The data model must support multiple trainers later.

## Stack
- **App:** Vite + React + TypeScript, client-only SPA (no SSR), installable PWA via vite-plugin-pwa (Workbox).
- **Routing:** React Router in data mode (`createBrowserRouter`; no framework mode).
- **UI:** Tailwind CSS + shadcn/ui (components live in the repo).
- **Forms & validation:** Zod, with plain React state for the small forms. React Hook Form is not installed yet: it is added with the first large form (step 6), as an explicit decision.
- **Server data:** supabase-js + TanStack Query; query cache persisted to IndexedDB.
- **Offline writes:** Dexie (IndexedDB) outbox, flushed on app open, window focus and the `online` event.
- **i18n:** i18next + react-i18next. Spanish (`es`) default, English (`en`) required.
- **Backend:** Supabase — Postgres, Auth, RLS. Edge Functions only where the secret key (service-role access) is needed (e.g. invites). Hosted project ref: `cfxafmgjuyigayywntjn` (eu-west-3).
- **DB tooling:** Supabase CLI **v3**, pinned as an exact dev dependency, with a local Docker stack; generated types via `supabase gen types`; RLS tests with pgTAP (`supabase test db`).
- **Quality:** Vitest, ESLint + Prettier, GitHub Actions CI.
- **Hosting:** Cloudflare Workers static assets (free plan). Deploys run from GitHub Actions on `main`.

## Commands
Database (local stack):
- `npm run db:network` — create the `fitnessapp-local` Docker network (once per machine; CI runs it too).
- `npm run db:start` — start the local Supabase stack (bound to 127.0.0.1 via the `fitnessapp-local` Docker network).
- `npm run db:stop` — stop it (data is kept).
- `npm run db:status` — local URLs and keys.
- `npm run db:reset` — rebuild the local DB from `supabase/migrations/` + `supabase/seed.sql`.
- `npm run db:test` — run the pgTAP tests in `supabase/tests/database/` against the local stack. Run `db:reset` first: the fixtures are persistent rows from `seed.sql`. Don't call `npx supabase test db` directly: without `--network-id fitnessapp-local` it can't find the local stack.
- `npx supabase migration new <name>` — create an empty migration file.
- `node scripts/test-invite-function.mjs` — check the `invite-athlete` Edge Function end to end against the local stack (after `db:reset`). Needs `supabase/functions/.env`: copy `supabase/functions/.env.example`, then restart the stack. A change to the function's code is served only after the edge runtime restarts (`docker restart supabase_edge_runtime_fitnessapp`, or `db:stop` and `db:start`); after a reboot that container may be stopped while the rest of the stack is up. Not run in CI (CI starts Postgres only).

- `npm run db:types` — regenerate `src/lib/database.types.ts` from the local database (`public` schema only). Run it after `db:reset` whenever a migration changes, and commit the result. No `--network-id` here: v3 generates types in-process and rejects the flag.

App (Node 22, see `.nvmrc`):
- `npm run dev` — Vite dev server. Needs `.env.local` (copy `.env.example`; local values from `npm run db:status`).
- `npm run build` — type-check, then build to `dist/`. `npm run preview` serves that build.
- PWA testing: `npm run build && npm run preview`. The service worker is off in `npm run dev` (`devOptions` disabled), so installability, offline boot and the update banner can only be tested on a build.
- `npx wrangler dev` — serve `dist/` locally the way Cloudflare does (SPA fallback, `public/_headers`). Build first. Use it to check status codes and cache headers.
- `npx @vite-pwa/assets-generator` — regenerate the PNG icons from `public/logo.svg` (config in `pwa-assets.config.mjs`). One-off, not a dependency; only when the logo changes.
- `npm run typecheck` — `tsc -b` only.
- `npm run lint` — ESLint (flat config in `eslint.config.js`).
- `npm run format` / `npm run format:check` — Prettier, write or check.
- `npm run test` — Vitest, node environment, files matching `src/**/*.test.{ts,tsx}`.

## Project structure
- `docs/schema-v1.md` — the approved schema: tables, conventions, design choices (D1–D12), RLS strategy, tests. **Read it before touching the database.**
- `supabase/migrations/` — versioned migrations, one per group (see schema-v1.md §7).
- `supabase/tests/database/` — pgTAP tests (`*.test.sql`): `00_meta`, `01_identity`, `02_libraries`, `03_invitations`, …
- `supabase/functions/invite-athlete/` — the invite Edge Function (`index.ts`, `cors.ts`, `secret-key.ts`). Deno, not part of the app build or `tsc`. `supabase/functions/.env` (gitignored) holds `APP_BASE_URL` and no key: the runtime, local and hosted, gives the function `SUPABASE_URL` and `SUPABASE_SECRET_KEYS` (a JSON object; the function uses the key named `default`, with no fallback to the legacy `service_role` key).
- `scripts/test-invite-function.mjs` — local end-to-end checks for that function, with the local secret and publishable keys from `supabase status`.
- `supabase/seed.sql` — local-only: the `tests` helper schema (`tests.create_user`, `tests.user_id('t1')`, `tests.authenticate_as`) and the fixtures T1, A1, A2, T2, B1, X, U (`<name>@fitnessapp.test`). Never pushed to the hosted project.

App (`src/`, imported through the `@/` alias):
- `src/main.tsx` — entry: validates the env, then loads the app, or renders the env error screen.
- `src/app/` — `providers.tsx` (i18n, TanStack Query, auth, router: every app-wide provider goes here), `router.ts` (React Router data mode; public routes first, the rest under `RequireAuth`), `root-layout.tsx`, `routes/` (placeholder home, not-found), `env-error-screen.tsx`, `update-banner.tsx` (registers the service worker; "new version" banner with reload and dismiss; hourly update check).
- `src/components/ui/` — shadcn/ui components, added with `npx shadcn@latest add <name>` (config in `components.json`).
- `src/features/` — one folder per feature. Pure logic sits in its own files with a test next to it; files that import `@/lib/supabase` cannot be unit-tested (the env is validated on import).
- `src/features/auth/` — `auth-store.ts` (the auth state, no React, no supabase import), `auth.ts` (the store wired to supabase-js; `signInWithPassword`), `auth-provider.tsx` + `auth-context.ts` (`useAuth()`), `route-guards.tsx` (`RequireAuth`, `RequireTrainer`), `login-page.tsx`, `stored-user.ts`, `role-hint.ts`, `auth-errors.ts`, `email.ts`, `storage.ts`, `form-fields.tsx`, `screens.tsx`.
- `src/features/invites/` — `accept-invite-page.tsx` (`/accept-invite`) with `accept-params.ts`, `accept-flow.ts` (resume step, pending state), `accept-api.ts`; `invite-athlete-page.tsx` (`/trainer/invites`) with `invite-api.ts`, `expiry.ts`; `invite-errors.ts` (every server code → i18n key).
- `src/lib/` — `supabase.ts` (typed client), `env.ts` (Zod-validated `VITE_*` variables), `i18n.ts`, `utils.ts` (re-exports `cn` from the `cn` package, shadcn's current default), `database.types.ts` (generated by `db:types`; never edited by hand, ignored by ESLint and Prettier).
- `src/locales/<lang>/common.json` — translations, bundled at build time. `es` is the source of truth: `en` is typed against it and `locales.test.ts` checks both have the same keys.
- `src/index.css` — Tailwind v4 entry and the shadcn theme (CSS variables).

PWA, hosting and CI:
- `vite.config.ts` — the `VitePWA` options: web manifest, and a `generateSW` service worker that precaches the app shell only.
- `public/` — icons (`logo.svg` is the source, a placeholder letter "F"; `favicon.svg` is hand-written; the PNGs, including `apple-touch-icon.png`, are generated and committed) and `_headers` (Cloudflare cache rules).
- `wrangler.jsonc` — the Cloudflare Worker: assets-only (no `main`), serves `./dist` with SPA fallback.
- `.github/workflows/ci.yml` — the CI and deploy workflow.

## CI and deploy
`.github/workflows/ci.yml` runs on every push (all branches) and on pull requests:
- **`app`** — `format:check`, `lint`, `typecheck`, `test`, then `build` with the repository variables `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` (on a push, it fails if either is empty). Uploads `dist/` as the `dist` artifact.
- **`db`** — `db:network`, `db:start` (Postgres only: every other service is excluded), `db:reset`, `db:test`, then `db:types` and `git diff --exit-code src/lib/database.types.ts`: a migration committed without regenerated types fails CI.
- **`deploy`** — only on a push to `main`, after `app` and `db` pass. Downloads the `dist` artifact (it deploys exactly what `app` built, no rebuild) and runs `npx wrangler deploy` in the `production` environment with the secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. One deploy at a time.

So **a merge to `main` deploys to production**. There are no per-branch preview deployments.

Caching: Cloudflare serves every asset with `Cache-Control: public, max-age=0, must-revalidate` by default, so `index.html`, `sw.js` and `manifest.webmanifest` always revalidate. `public/_headers` makes the hashed files under `/assets/` `immutable` for a year.

## Invites
The app is invite-only: public sign-up is off (`[auth] enable_signup = false`) and the only way in is a trainer's invitation.
1. **Trainer:** the app calls the Edge Function `invite-athlete` with `{ email, full_name? }`. It checks the caller's JWT and his `trainers` row, creates an invite token (a magic-link token if the email already has a confirmed account), refuses with `already_linked` if that user has an active trainer, inserts the `invitations` row (valid 24 h) and returns only `{ url }`: `<APP_BASE_URL>/accept-invite?token_hash=…&type=invite|magiclink`. No email is sent: the trainer passes the link on himself.
2. **Athlete:** the `/accept-invite` page (step 4b) calls `verifyOtp({ token_hash, type })` only when he taps "Accept", then `updateUser({ password })` for `invite`, then `rpc('accept_invitation')`.
3. **`public.accept_invitation()`** links the caller to the trainer of the latest pending, unexpired invitation for the email in his JWT and returns the trainer's id. Safe to retry. It raises a stable code as the message: `not_authenticated`, `invitation_not_found`, `invitation_expired`, `already_has_trainer`.

- Never return, log or store Supabase's `action_link`, the token or the invited email: the `action_link` is spent by a plain GET, so a link preview (WhatsApp) would use it up before the athlete taps it.
- `accept_invitation()` is the one deliberate exception to "identity tables are written only by an Edge Function or SQL". `invitations` rows are still inserted only by the Edge Function, and `authenticated` has no write privilege on `invitations` or `trainer_athletes`.
- `invite-athlete` has `verify_jwt = false` in `config.toml`, so it must keep verifying the JWT itself (`auth.getUser(token)`) on every non-`OPTIONS` request. It answers `OPTIONS` and sends its own CORS headers, allowing only the origin of `APP_BASE_URL`, never `*`.
- Its error codes: `unauthorized` (401), `forbidden` (403, not a trainer), `invalid_request` (400), `already_linked` (409), `invite_failed` (500), `method_not_allowed` (405), `server_misconfigured` (500, an env variable is missing).
- A second invite to someone who has not accepted yet replaces his token: the earlier link stops working.
- Tests: `supabase/tests/database/03_invitations.test.sql` (pgTAP) and `scripts/test-invite-function.mjs` (the function, local only).

## Hosted project
State on 2026-11-13, at the end of step 4b-2. Project `fitnessapp`, ref `cfxafmgjuyigayywntjn`, eu-west-3. Production origin: `https://fitnessapp.myfitnessapp.workers.dev`.

What is on it:
- **Config** (`config push`): public sign-up off, `otp_expiry` 86400 (invite links last 24 h), minimum password length 8, `site_url` = the production origin, redirect URLs = the two local dev origins. `supabase/config.toml` mirrors the hosted values: `npx supabase config diff --remote` (read-only) must report no changes. It also lists 12 properties the push does not manage and 2 masked credentials; of those, `auth.rate_limit.email_sent` has never been compared with the hosted value.
- **Database** (`db push`): the four migrations in `supabase/migrations/`. The seed and the `tests` schema are not there.
- **Edge Function:** `invite-athlete`, `verify_jwt` false, with one secret, `APP_BASE_URL` = the production origin. It is deployed by hand (`functions deploy`, from the branch that holds the code), not by CI.
- **API keys:** the app uses the publishable key `default` and the function the secret key `default`. The legacy `anon` and `service_role` keys were disabled on 2026-11-13 (step 4c) in Settings → API Keys; Supabase's migration guide says they can be re-activated there. Nothing in the repo uses them. The JWT signing keys were not changed: moving to asymmetric keys is a separate migration, and the legacy JWT secret can only be revoked while the legacy keys are disabled.
- **Users:** one, the first trainer, with his `trainers` row and an active self-link in `trainer_athletes`. There is no UI to create a trainer: the auth user is created in the dashboard (Authentication → Users → Add user, auto-confirm), then one SQL transaction inserts the `trainers` row and the self-link. His email and id are not in the repo.

Working with it:
- Hosted writes are run by Noé, in his own terminal (the CLI's confirmation is interactive) or in the dashboard SQL editor, one at a time, after the exact command and its effect have been shown. Each one is verified read-only afterwards.
- `secrets`, `functions` and `projects api-keys` act on the linked project without `--remote`. `secrets list` shows the SHA-256 digest of each value, not the value. `projects api-keys` prints key values: filter its output, never show them.
- Reads: `npx supabase db query --remote --read-only "<select>"` needs no confirmation. It accepts only `SELECT`, `WITH`, `VALUES`, `TABLE`, `SHOW` and `EXPLAIN`; pass longer SQL with `--file` (SQL that starts with a `--` comment is taken for a flag). It runs as a role that cannot `set role`, so "what does this user see through RLS" cannot be checked from the CLI: that query is run in the dashboard SQL editor.
- Logs, read-only: `npx supabase logs --remote --service <functions|function-edge|edge|auth> --since <UTC timestamp> --output-format json`. `function-edge` has one line per function request (method and status), `functions` the function's own console output. They lag by up to a minute. Print the method, path and status only: the records can hold more.
- Never select a real user's email into the output of a check: compare it or count it instead.

Verified on 2026-11-13:
- **CORS:** the hosted gateway passes the function's `Access-Control-Allow-Origin` through unchanged on every response, the preflight included. Only the local gateway replaces it with `*`.
- **The invite flow, end to end** (run by Noé on an Android phone with Chrome, against production, with a synthetic `.test` address, which the hosted project accepts): invite created, the WhatsApp preview does not spend the token, accept, password, log out and in, the spent link reports "expired", an athlete who opens `/trainer/invites` is sent back to `/`, and an offline reload stays signed in. The test user was deleted afterwards.
- **RLS as each user:** the rows a linked athlete and his trainer see in `profiles`, `trainers`, `invitations` and `trainer_athletes` match `docs/schema-v1.md` §5.
- **The secret key (step 4c):** with the function reading `SUPABASE_SECRET_KEYS`, one invite created from the production app succeeded (the test user and its pending invitation were deleted afterwards: a pending invitation is not removed by the user's cascade). With the legacy keys disabled, the API answers 401 "Legacy API keys are disabled" to the legacy `anon` key, the publishable key works, and the function still answers 401 without a user JWT and 405 on other methods.

Open:
- Advisors after the `db push`. Security: no ERROR, two expected WARN (`authenticated_security_definer_function_executable` on `accept_invitation()` and `auth_otp_long_expiry`, both deliberate). Performance: WARN `multiple_permissive_policies` on 8 tables for `authenticated` SELECT, INFO `unindexed_foreign_keys` for `food_swaps_from_food_id_trainer_id_fkey`. Nothing was changed: a fix is a new migration, and Noé decides.

## Rules for working in this repo

### Supabase CLI (v3)
- Always run the CLI through `npx supabase …` or the npm scripts, so the pinned version is used. Don't install it globally.
- v3 targets the **local** stack by default. `--remote` targets the hosted project. `--linked`, `--project-ref` (for db commands) and `--db-url` are deprecated: don't use them, even if docs or examples do. When unsure of a flag, check `npx supabase <command> --help` instead of guessing from v2 docs.
- Never run a command that changes the hosted project (`db push`, `config push`, `functions deploy`, `secrets set`, `db reset --remote`, anything with `--remote` that writes) unless Noé explicitly asked for it in this session. Never pass `--yes` to skip the confirmation.
- Never write the hosted DB password, access tokens or secret keys into files in the repo or into the chat.

### Database
- `docs/schema-v1.md` is the source of truth for the data model. If a task seems to need something it doesn't cover, or contradicts it, stop and ask instead of improvising.
- Every schema change is a new SQL migration file in `supabase/migrations/`. Never edit the database through the dashboard, and never edit a migration that has already been applied (pushed, or committed and shared) — write a new one.
- Conventions (full list in schema-v1.md §2): plural snake_case tables, singular columns, `<singular>_id` FKs, `_at` timestamptz / `_on` date, units in column names, `text` + named check constraints instead of enums, fixed-vocabulary values stored as English codes (labels live in i18n), `created_at`/`updated_at` + the shared `private.set_updated_at()` trigger (before insert **and** update) on every table.
- Every table has RLS enabled in the same migration that creates it, with explicit policies, and explicit grants: revoke everything from `anon`; grant `authenticated` only the operations its policies allow. Don't rely on default privileges.
- **Functions:** the PUBLIC execute right on new functions is revoked for `postgres` in every schema. Every new function that `authenticated` calls (RLS helpers, RPCs) needs an explicit `grant execute … to authenticated`; never grant to `anon`. Trigger functions need no grant.
- Ownership columns are copied down every tree and children use composite FKs that include them (schema-v1.md D3/D4). Don't replace a composite FK with a plain one, even if it looks redundant — it's what stops a row from pointing at another user's data, because FK checks ignore RLS.
- **Deletes:** an athlete's data (profile, links, plans, logs) cascades from his auth user; anything pointing at `trainers` or at library rows is `on delete restrict`. Library rows are archived (`archived_at`), not deleted, once used.
- RLS helpers live in the `private` schema (security definer, `stable`, `set search_path = ''`, fully qualified names). Policies use `(select auth.uid())` and `in (select private.trainer_athlete_ids())` so they run once per query.
- Add `comment on table` / `comment on column` for every new table and column.
- When adding or changing policies, add or update the corresponding pgTAP tests. The meta tests must keep passing (RLS on, comments, timestamps, trigger on every `public` table; no anon privileges).
- After a migration, regenerate TypeScript types and commit them (from step 3 on).
- Derived values (kcal = 4P + 4C + 9F, meal option macros, weekly averages, body fat, day status) are computed, never stored as hand-typed numbers.
- Library tables (exercises, foods) are trainer-scoped and carry `source` / `source_ref`. Don't import external datasets without checking their license first.

### Deploys
- Deploys happen only through CI on `main`. Never run `wrangler deploy`, or any Wrangler command that changes the Cloudflare account, by hand unless Noé explicitly asked for it in this session. `npx wrangler dev` is local and fine.
- Wrangler is pinned as an exact dev dependency, like the Supabase CLI: run it through `npx wrangler`.

### PWA
- The service worker precaches the app shell only. Never add `runtimeCaching` for Supabase or any other origin: it must not cache API or auth responses (offline data is TanStack Query + Dexie).
- Updates are prompt-based (`registerType: 'prompt'`): a new version waits until the user taps "Recargar" in the update banner. Never switch to `autoUpdate` or reload the page automatically; it could interrupt an athlete mid-session.
- Translations are bundled, never fetched, so the UI works offline. New user-facing strings (the banner's included) go through i18n.

### Security
- Never use or expose a secret key (`sb_secret_…`, or the legacy `service_role` key) in client code. The client uses the publishable key only. Anything needing service-role access runs in an Edge Function.
- Athletes may only read/write their own data; trainers only their own athletes' data. Enforce this in RLS, not only in the UI.

### Auth & session (app)
- **Offline-safe guard:** route decisions use local state only: the app's own record of the signed-in user (`fitnessapp.auth.user`) and the cached role hint. Never make a route wait on, or depend on, a network call. Don't decide "signed out" from `getSession()` or `INITIAL_SESSION` alone: with an expired token and no connection supabase-js retries for about 25 s and then reports no session, although it is still stored.
- **Network errors never sign out.** Only the logout button and a `SIGNED_OUT` event from supabase-js do (it emits one only when the session is really gone).
- **Logout uses the local scope** (`signOut({ scope: 'local' })`, through `authStore.logout()`), so it works offline.
- **The role hint is routing only.** `{ isTrainer, hasActiveLink, locale }` is cached in localStorage per user id; what a user may read or write is decided by RLS. With no cache and no connection, show the "no connection" screen, never the login page.
- **The invite token is never logged, stored or cached:** component state only; no `console.*`, localStorage, sessionStorage or TanStack Query cache. The same goes for the invite URL on the trainer's screen. `/accept-invite` sends nothing until "Accept" is tapped.
- **No `signUp` call anywhere** in the app: accounts are created only by the `invite-athlete` function.

### Public repository
- This repo is public: every committed file, in every commit, is visible to anyone, forever.
- Never commit the trainer's data or any real person's data: exercises, foods, swaps, plans, notes or numbers taken from his sheets; athlete logs; real names, emails or phone numbers. Seed data extracted from his sheets (step 5) lives in a gitignored folder.
- Test fixtures are synthetic only: `@fitnessapp.test` users, invented foods and numbers.
- Commits use the GitHub noreply email, never a personal or school address.
- No env files except `.env.example`, which holds placeholders or local-stack values only.

### Offline
- The athlete's week view and all athlete logging (sets, meals, daily metrics, check-ins, measurements) must keep working without a connection and sync on reconnect. Don't introduce features on those screens that require being online.
- Athlete writes go through the outbox as upserts on each table's **natural key** (schema-v1.md D12), so retries and second devices update the same row, never a duplicate. Send only the fields that changed.
- Row ids are generated on the client: random v4 for most logs; **UUID v5 of (training_day_id, program_week)** for training sessions, so two devices produce the same session id.
- Never trust the client clock for `updated_at` (the server trigger sets it).
- Writes rejected by RLS (e.g. the athlete's link ended) are shown as an error, not retried forever.
- Don't rely on the Background Sync API (not available on iOS). Sync runs while the app is open.
- Trainer screens may assume they are online.

### Language
- Code, identifiers, comments and commit messages in English.
- All user-facing text goes through i18n. Spanish is the default locale; English must also be provided. No hard-coded UI strings.

### Scope discipline
- Only touch the files, tables and migrations the current task names. If something outside scope looks broken, report it instead of fixing it.
- Not in MVP: trainer progress dashboard/charts, weekly volume-per-muscle analytics, progress arrows and load suggestions, Open Food Facts lookup, photo/video uploads, chat, supplement tracking. Don't build them.
- Don't add new dependencies or services beyond the stack above without it being decided first.

### Done means
- The task's acceptance checklist passes.
- Lint/build/tests pass (app: `npm run lint`, `npm run format:check`, `npm run typecheck`, `npm run test`, `npm run build`; database: `npm run db:reset` then `npm run db:test`).
- New migrations apply cleanly on a fresh local database (`npm run db:reset`).
