-- Group 1 (docs/schema-v1.md §7): the private schema, the shared updated_at
-- trigger function, and default privileges that keep anon out.

-- ---------------------------------------------------------------------------
-- private schema: RLS helper functions and trigger functions. Not exposed
-- through the API (only public is). Policies call its functions as the
-- caller, so authenticated needs usage; nobody else does.
-- ---------------------------------------------------------------------------

create schema private;

comment on schema private is
  'RLS helper functions and trigger functions. Not exposed through the API.';

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- ---------------------------------------------------------------------------
-- Default privileges
--
-- Migrations run as postgres, so these are set for role postgres. (Supabase
-- also keeps defaults for supabase_admin in public; postgres cannot change
-- them and nothing in this project creates objects as supabase_admin.)
--
-- Every table still gets explicit revokes and grants in its own migration;
-- these defaults are the safety net for whatever is created later.
-- ---------------------------------------------------------------------------

-- Postgres lets PUBLIC execute every new function. That built-in default is
-- global: a per-schema "alter default privileges" can only add to it, never
-- remove it, so it has to be revoked without "in schema". After this, a new
-- function created by postgres in any schema is executable only by roles
-- that are granted it.
alter default privileges for role postgres
  revoke execute on functions from public;

-- Supabase's defaults give anon everything on new objects in public.
alter default privileges for role postgres in schema public
  revoke all on tables from anon;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon;
alter default privileges for role postgres in schema public
  revoke all on functions from anon;

-- ---------------------------------------------------------------------------
-- Shared updated_at trigger function. Every public table has a
-- "before insert or update" row trigger that calls it, so updated_at is
-- always the server clock, whatever the client sends.
-- ---------------------------------------------------------------------------

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function private.set_updated_at() is
  'Trigger function: sets updated_at to now(). Attached to every public table (before insert or update).';

revoke all on function private.set_updated_at() from public, anon;
