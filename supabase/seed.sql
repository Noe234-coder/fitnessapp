-- Local-only seed. Runs after the migrations on `npm run db:reset`.
-- Never pushed to the hosted project.
--
-- 1. The `tests` schema: helpers used by the pgTAP tests in supabase/tests/database/.
-- 2. Identity fixtures (docs/schema-v1.md §6).

-- ---------------------------------------------------------------------------
-- 1. Test helpers
-- ---------------------------------------------------------------------------

create schema tests;

comment on schema tests is
  'Local-only helpers for the pgTAP tests. Created by supabase/seed.sql; never exists on the hosted project.';

-- Tests switch to the anon / authenticated roles and must still reach the helpers.
grant usage on schema tests to anon, authenticated;

-- Creates an auth user the way a sign-up does, so the sign-up trigger runs.
create function tests.create_user(
  email text,
  raw_user_meta_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  new_user_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  )
  values (
    '00000000-0000-0000-0000-000000000000', new_user_id, 'authenticated', 'authenticated',
    create_user.email, '', now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, create_user.raw_user_meta_data,
    now(), now()
  );
  return new_user_id;
end;
$$;

comment on function tests.create_user(text, jsonb) is
  'Inserts a confirmed auth.users row (the sign-up trigger creates its profile) and returns its id. The user has no password and cannot sign in.';

-- Makes the rest of the transaction run as that user, the way PostgREST would.
create function tests.authenticate_as(user_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', user_id, 'role', 'authenticated')::text,
    true
  );
  perform set_config('role', 'authenticated', true);
end;
$$;

comment on function tests.authenticate_as(uuid) is
  'Switches to the authenticated role with request.jwt.claims.sub = user_id, local to the current transaction.';

-- Back to the session role (postgres), with no JWT claims.
create function tests.clear_authentication()
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('role', 'none', true);
end;
$$;

comment on function tests.clear_authentication() is
  'Resets the role to the session role and clears request.jwt.claims, local to the current transaction.';

-- Id of a fixture user by short name ('t1', 'a1', …). Security definer because
-- tests call it while authenticated, and authenticated cannot read auth.users.
create function tests.user_id(fixture_name text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id from auth.users u where u.email = fixture_name || '@fitnessapp.test';
$$;

comment on function tests.user_id(text) is
  'Returns the id of the fixture user <fixture_name>@fitnessapp.test, or null.';

-- Migration 1 removes the default execute privilege, so grant it explicitly.
grant execute on function tests.authenticate_as(uuid) to anon, authenticated;
grant execute on function tests.clear_authentication() to anon, authenticated;
grant execute on function tests.user_id(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Identity fixtures (docs/schema-v1.md §6)
--
--   t1  trainer, also his own athlete (self-link), with athletes a1 and a2
--   t2  trainer with athlete b1
--   x   former athlete of t1 (link ended)
--   u   user with no links
--
-- Emails are <name>@fitnessapp.test; tests look them up with tests.user_id().
-- trainers and trainer_athletes rows are created with SQL, as in production
-- (docs/schema-v1.md D1).
-- ---------------------------------------------------------------------------

do $$
declare
  t1 uuid := tests.create_user('t1@fitnessapp.test', '{"full_name": "Trainer One"}');
  a1 uuid := tests.create_user('a1@fitnessapp.test', '{"full_name": "Athlete A1"}');
  a2 uuid := tests.create_user('a2@fitnessapp.test', '{"full_name": "Athlete A2"}');
  t2 uuid := tests.create_user('t2@fitnessapp.test', '{"full_name": "Trainer Two"}');
  b1 uuid := tests.create_user('b1@fitnessapp.test', '{"full_name": "Athlete B1"}');
  x  uuid := tests.create_user('x@fitnessapp.test',  '{"full_name": "Former Athlete X"}');
  u  uuid := tests.create_user('u@fitnessapp.test',  '{"full_name": "Unlinked User U"}');
begin
  insert into public.trainers (profile_id) values (t1), (t2);

  insert into public.trainer_athletes (trainer_id, athlete_id)
  values (t1, t1), (t1, a1), (t1, a2), (t2, b1);

  insert into public.trainer_athletes (trainer_id, athlete_id, started_at, ended_at)
  values (t1, x, now() - interval '60 days', now() - interval '30 days');
end;
$$;
