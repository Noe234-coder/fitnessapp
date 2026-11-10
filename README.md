# FitnessApp

A mobile-first web app (installable PWA) for a personal trainer and his athletes:
workout programs, meal plans, daily tracking and weekly check-ins, usable at the
gym with a weak connection.

Built with Vite, React and TypeScript on top of Supabase (Postgres, Auth, RLS).
The project is in early development.

## Local development

### Prerequisites

- Node.js 22 (the version in `.nvmrc`; with nvm, run `nvm use`)
- Docker (with the compose plugin), usable without `sudo`

### Setup

1. Install dependencies. This includes the pinned Supabase CLI, which is always
   run through `npx supabase` or the npm scripts:

   ```sh
   npm ci
   ```

2. Create the Docker network for the local stack (once per machine). The local
   stack uses default credentials, and Docker publishes container ports on all
   interfaces, so this network binds them to localhost only:

   ```sh
   docker network create -o 'com.docker.network.bridge.host_binding_ipv4=127.0.0.1' fitnessapp-local
   ```

3. Start the local Supabase stack:

   ```sh
   npm run db:start
   ```

4. Create your env file:

   ```sh
   cp .env.example .env.local
   ```

   Then set `VITE_SUPABASE_PUBLISHABLE_KEY` in `.env.local` to the publishable
   key printed by `npm run db:status`. `.env.local` is gitignored; never commit
   it.

5. Start the app:

   ```sh
   npm run dev
   ```

### Commands and conventions

[CLAUDE.md](CLAUDE.md) lists every command (app, database, tests) and the rules
for working in this repo. The data model is described in
[docs/schema-v1.md](docs/schema-v1.md).

Always use the `db:*` npm scripts instead of the raw Supabase commands: they pass
`--network-id fitnessapp-local`, which keeps the local database off public
interfaces. The repo pins Supabase CLI v3, whose flags differ from the v2 syntax
in most docs; when in doubt, check `npx supabase <command> --help`.
