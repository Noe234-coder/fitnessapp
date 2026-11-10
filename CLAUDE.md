# CLAUDE.md — FitnessApp (draft)

> Draft maintained in the claude.ai Project. The repo root has a copy (since step 2b-1); keep both in sync.
> Sections marked TBD get filled in during repo setup (step 3).

## What this app is
FitnessApp is a mobile-first web app for a personal trainer and his athletes. It replaces Google Sheets (workouts, meal plans, daily tracking), Loom and WhatsApp.
- **Trainer:** maintains his own exercise and food libraries; builds mesocycle workout programs (named training days, a warm-up day, versioned week-to-week prescriptions) and meal plans (meals with macro targets, alternative options, swap rules); keeps templates and copies them to athletes; invites athletes; reviews athlete logs and weekly check-ins. He may also be his own athlete.
- **Athlete:** each calendar week does the program's training days in any order, on any day; logs reps/weight per set; ticks off meals; logs daily bodyweight/steps/sleep/stress; fills a weekly check-in and body measurements — often at the gym with weak signal.
- Scale: one trainer, ~30–40 athletes. The data model must support multiple trainers later.

## Stack
- **App:** Vite + React + TypeScript, client-only SPA (no SSR), installable PWA via vite-plugin-pwa (Workbox).
- **Routing:** React Router (SPA mode).
- **UI:** Tailwind CSS + shadcn/ui (components live in the repo).
- **Forms & validation:** React Hook Form + Zod.
- **Server data:** supabase-js + TanStack Query; query cache persisted to IndexedDB.
- **Offline writes:** Dexie (IndexedDB) outbox, flushed on app open, window focus and the `online` event.
- **i18n:** i18next + react-i18next. Spanish (`es`) default, English (`en`) required.
- **Backend:** Supabase — Postgres, Auth, RLS. Edge Functions only where the service-role key is needed (e.g. invites). Hosted project ref: `cfxafmgjuyigayywntjn` (eu-west-3).
- **DB tooling:** Supabase CLI **v3**, pinned as an exact dev dependency, with a local Docker stack; generated types via `supabase gen types`; RLS tests with pgTAP (`supabase test db`).
- **Quality:** Vitest, ESLint + Prettier, GitHub Actions CI.
- **Hosting:** Cloudflare Workers static assets (free plan).

## Commands
Database (local stack):
- `npm run db:start` — start the local Supabase stack (bound to 127.0.0.1 via the `fitnessapp-local` Docker network).
- `npm run db:stop` — stop it (data is kept).
- `npm run db:status` — local URLs and keys.
- `npm run db:reset` — rebuild the local DB from `supabase/migrations/` + `supabase/seed.sql`.
- `npm run db:test` — run the pgTAP tests in `supabase/tests/database/` against the local stack. Run `db:reset` first: the fixtures are persistent rows from `seed.sql`. Don't call `npx supabase test db` directly: without `--network-id fitnessapp-local` it can't find the local stack.
- `npx supabase migration new <name>` — create an empty migration file.

TBD — dev server, build, lint, app tests, type generation.

## Project structure
- `docs/schema-v1.md` — the approved schema: tables, conventions, design choices (D1–D12), RLS strategy, tests. **Read it before touching the database.**
- `supabase/migrations/` — versioned migrations, one per group (see schema-v1.md §7).
- `supabase/tests/database/` — pgTAP tests (`*.test.sql`): `00_meta`, `01_identity`, `02_libraries`, …
- `supabase/seed.sql` — local-only: the `tests` helper schema (`tests.create_user`, `tests.user_id('t1')`) and the fixtures T1, A1, A2, T2, B1, X, U (`<name>@fitnessapp.test`). Never pushed to the hosted project.

TBD — app folders (step 3).

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

### Security
- Never use or expose the service-role key in client code. Client uses the anon/publishable key only. Anything needing the service role runs in an Edge Function.
- Athletes may only read/write their own data; trainers only their own athletes' data. Enforce this in RLS, not only in the UI.

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
- Lint/build/tests pass (app commands TBD; database: `npm run db:reset` then `npm run db:test`).
- New migrations apply cleanly on a fresh local database (`npm run db:reset`).
