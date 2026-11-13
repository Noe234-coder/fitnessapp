# Backups and restore

The hosted Supabase project is on the free plan: it has no backups of its own
and it pauses after a week without activity. The workflow
`.github/workflows/backup.yml` covers both. This document says what it stores,
where the keys are and how to get the data back.

This repository is public, and so are its workflow logs and artifacts. A
backup is therefore only ever uploaded encrypted, and it is never committed,
in clear or encrypted (`.gitignore` covers `*.age`, `*.sql.gz`, `*.dump`,
`/backups/` and `.sql` files at the repository root).

## What runs, and when

- **Schedule:** Wednesday and Sunday at 03:23 UTC, and by hand
  (`gh workflow run backup.yml`, or "Run workflow" on the Actions page). It
  never runs on a push or a pull request.
- **Backup:** `scripts/backup-db.sh` pipes `pg_dump` (version 17, like the
  server) into `gzip` and `age`. The clear dump is never written to the
  runner's disk. The encrypted file is uploaded as the artifact
  `db-backup-<date>-<run id>`, kept for 90 days, so about 26 backups exist at
  any time.
- **Keep-alive:** the dump is a real database connection. The job also sends
  one request to the API (`/rest/v1/` with the publishable key); any answer
  below HTTP 500 counts.
- **Logs:** the job prints the size of the encrypted file and the HTTP status,
  nothing else: no connection string, no row.

## Where the settings live

| What                   | Where                                         | Notes                                                                  |
| ---------------------- | --------------------------------------------- | ---------------------------------------------------------------------- |
| `BACKUP_DB_URL`        | secret of the GitHub environment `backup`     | Session pooler connection string of the hosted database (see below).   |
| `BACKUP_AGE_RECIPIENT` | variable of the GitHub environment `backup`   | An age **public** key (`age1…`). Public keys only encrypt.             |
| The age private key    | Noé's password manager, plus one offline copy | Never on GitHub, in the repo or in a chat. It is the only way to read a backup. |
| `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` | repository variables (already used by CI) | Used by the keep-alive request.          |

The environment `backup` is restricted to the `main` branch, so the workflow
cannot run from another branch.

`BACKUP_DB_URL` has this shape:

```
postgresql://postgres.cfxafmgjuyigayywntjn:<password>@aws-1-eu-west-3.pooler.supabase.com:5432/postgres
```

It is the **session pooler** (port 5432, user `postgres.<project ref>`):
GitHub's runners have no IPv6, and the free plan's direct connection is
IPv6-only. A password with characters such as `@`, `:`, `/`, `#` or `%` must be
percent-encoded in the URL. If the database password is reset (dashboard,
Settings → Database), this secret must be updated, and the CLI will ask for
the new password on the next `db push`.

## What a backup holds

Data only, read in one snapshot:

- every table of the `public` schema;
- `auth.users` and `auth.identities`: the accounts, with their password
  hashes, so people keep their passwords.

What it does **not** hold:

- **The schema.** Tables, policies, functions and triggers come from
  `supabase/migrations/`.
- **Sessions and one-time tokens** (the other `auth` tables). After a restore
  everybody signs in again, and invite links that were still pending stop
  working: the trainer invites those people again.
- **Project settings, the Edge Function and its secret.** They come from the
  repo (`config push`, `functions deploy`) and from `secrets set APP_BASE_URL`.
- **Storage.** The app does not use it.

## Triggers and the restore

Two kinds of trigger would spoil a naive restore:

- Every `public` table has a `set_updated_at` trigger (before insert or
  update) that sets `updated_at = now()`. Loading the rows with it active
  would replace every `updated_at` with the time of the restore, silently.
- `auth.users` has `on_auth_user_created`, which inserts the user's profile.
  Loading `auth.users` with it active creates the profiles, and the load of
  `public.profiles` then fails on a duplicate key.

So the dump begins with `SET session_replication_role = replica;`: while it
loads, no trigger fires (foreign keys are not re-checked either; the rows come
from one consistent snapshot). `updated_at` is restored exactly as it was.

The `postgres` role is not a superuser, but Supabase lets it change this
setting. If a role that may not change it loads the dump, the first statement
fails and nothing is loaded, as long as `psql` runs with
`-v ON_ERROR_STOP=1 --single-transaction` as shown below.

Checked on the local stack (2026-11-13): a dump of 11 tables restored into a
database with the migrations only gave the same row counts and the same
checksum of every row, `updated_at` included; the restored user could sign in
with his password. The same dump without the first statement failed on
`profiles_pkey` and loaded nothing. Loading into a new **hosted** project has
not been tried.

## Getting a backup

You need `age`, `gzip`, `psql` 17 or newer, and the private key file.

```
gh run list --workflow backup.yml --limit 5
gh run download <run id> --dir <a folder outside the repo>
```

The folder then holds `db-backup-<date>-<run id>/db-backup-<date>-<run id>.sql.gz.age`.
To check a file without decrypting it: its first line is
`age-encryption.org/v1`.

Decrypt straight into `psql`, so the clear dump never touches the disk:

```
age --decrypt -i <private key file> <backup>.sql.gz.age \
  | gunzip \
  | psql --single-transaction -v ON_ERROR_STOP=1 '<connection string of the target>'
```

If a load fails, `psql` may print the row it stopped at: don't paste that
output anywhere.

## Restore drill (local, no risk)

Loads a backup into the local stack, to prove the backup and the key work.

1. `npm run db:start`, then
   `npx supabase db reset --no-seed --network-id fitnessapp-local`: the local
   database now has the migrations and no rows, like a new project.
2. Run the decrypt command above with the local connection string from
   `npm run db:status`.
3. Compare the row counts with the hosted project (counts only):
   `npx supabase db query --remote --read-only "select (select count(*) from auth.users) as auth_users, (select count(*) from public.profiles) as profiles"`,
   and the same query without `--remote`.
4. `npm run db:reset` puts the local fixtures back. The restored rows are real
   data: don't leave them in the local database.

## Restore into a new Supabase project

1. Create the project (same region, Postgres 17). Don't create any user in it.
2. Point the repo at it (`npx supabase link`), then, each run by Noé:
   `npx supabase config push --remote` and `npx supabase db push --remote`.
   The database now has the schema and no rows. The seed is not pushed.
3. Check the target is empty: `auth.users` and every `public` table must have
   0 rows. The dump does not delete anything, so a row that already exists
   stops the load with a duplicate key.
4. Load the newest backup with the decrypt command above, using the new
   project's session pooler connection string.
5. Compare row counts per table with what you expect.
6. Put back what the backup does not hold:
   `npx supabase secrets set APP_BASE_URL=<the app's origin>`, then
   `npx supabase functions deploy invite-athlete`.
7. Point the app at the new project: update the repository variables
   `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`, and redeploy (a
   push to `main`). Update `BACKUP_DB_URL` in the `backup` environment and the
   project ref in `CLAUDE.md`.
8. Tell people to sign in again, and invite again whoever had a pending
   invitation.

## Things that break the backups

- **Sixty days without repository activity.** GitHub disables the scheduled
  workflows of a public repository after 60 days with no activity in it (a
  commit counts as activity; the backup runs themselves do not). The workflow
  is re-enabled on the Actions page. A disabled workflow also means no
  keep-alive: the project pauses a week later.
- **Losing the private key.** Every backup becomes unreadable, and nothing can
  recover it. Keep the two copies.
- **Replacing the key pair.** New backups use the new public key
  (`BACKUP_AGE_RECIPIENT`); the older ones still need the old private key
  until they expire, 90 days later.
- **A new database password** without updating `BACKUP_DB_URL`: the job
  fails. Whether that reaches Noé depends on his GitHub notification settings
  for failed workflow runs: check they are on.
- **A Postgres major upgrade** of the project: `pg_dump` must match. Change
  the client version in the workflow and `BACKUP_PG_MAJOR` in the script.
- **Ninety days.** Older backups are gone. There is no long-term archive.
