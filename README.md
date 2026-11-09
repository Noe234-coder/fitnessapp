# FitnessApp

## Local development

### Prerequisites

- Node.js >= 20
- Docker (with the compose plugin), usable without `sudo`

Install dependencies (includes the pinned Supabase CLI, run via `npx supabase`):

```sh
npm install
```

### One-time Docker network

The local stack uses default credentials, and Docker publishes container ports on
all interfaces (bypassing ufw). Create a network that binds published ports to
localhost only:

```sh
docker network create -o 'com.docker.network.bridge.host_binding_ipv4=127.0.0.1' fitnessapp-local
```

### Scripts

| Script              | What it does                                                  |
| ------------------- | ------------------------------------------------------------- |
| `npm run db:start`  | Start the local Supabase stack on the `fitnessapp-local` network |
| `npm run db:status` | Show local URLs (Studio, API, DB) and keys                    |
| `npm run db:reset`  | Recreate the local database and re-apply migrations           |
| `npm run db:stop`   | Stop the local stack                                          |

`db:start` and `db:reset` both pass `--network-id fitnessapp-local`. Without it,
`supabase db reset` recreates the database container on a generated network that
publishes Postgres on all interfaces. Always use the npm scripts instead of the
raw commands.

### Supabase CLI v3: local vs. remote

This repo pins Supabase CLI v3, which differs from the v2 syntax in most docs:

- Commands target the **local** stack by default. Add `--remote` to target the
  hosted project (replaces v2's `--linked`, `--project-ref` and `--db-url` on db
  commands).
- Commands that change the hosted project ask for confirmation (default No).
- When in doubt, check `npx supabase <command> --help`.
