-- Group 2 (docs/schema-v1.md §7): identity tables, the sign-up trigger, the
-- RLS helper functions, policies and grants.
--
-- Order: tables (each with RLS enabled and its updated_at trigger), then the
-- helper functions (they read the tables), then policies and grants (they
-- call the helpers).
--
-- Deleting users (decided 2026-11-10): an athlete's rows cascade from his
-- profile; a trainer is protected. trainers.profile_id and every FK that
-- points at trainers use "on delete restrict", so deleting a trainer's user
-- fails instead of taking his data with it.

-- ===========================================================================
-- Tables
-- ===========================================================================

-- profiles ------------------------------------------------------------------

create table public.profiles (
  id uuid not null,
  full_name text,
  locale text not null default 'es',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_pkey primary key (id),
  constraint profiles_id_fkey foreign key (id) references auth.users (id) on delete cascade,
  constraint profiles_locale_check check (locale in ('es', 'en'))
);

comment on table public.profiles is
  'One row per auth user, created by the sign-up trigger. Users can update only full_name and locale.';
comment on column public.profiles.id is
  'Same value as auth.users.id. The profile is deleted with the auth user.';
comment on column public.profiles.full_name is
  'Display name. Null until the user or the sign-up metadata provides one.';
comment on column public.profiles.locale is
  'UI language code: es (default) or en.';
comment on column public.profiles.created_at is 'When the row was created.';
comment on column public.profiles.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

alter table public.profiles enable row level security;

create trigger set_updated_at
  before insert or update on public.profiles
  for each row execute function private.set_updated_at();

-- trainers ------------------------------------------------------------------

create table public.trainers (
  profile_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trainers_pkey primary key (profile_id),
  constraint trainers_profile_id_fkey
    foreign key (profile_id) references public.profiles (id) on delete restrict
);

comment on table public.trainers is
  'A row means this person is a trainer (D1). Created with SQL only; there is no UI or API write path.';
comment on column public.trainers.profile_id is
  'The trainer''s profile. On delete restrict: a trainer''s user cannot be deleted while this row exists.';
comment on column public.trainers.created_at is 'When the row was created.';
comment on column public.trainers.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

alter table public.trainers enable row level security;

create trigger set_updated_at
  before insert or update on public.trainers
  for each row execute function private.set_updated_at();

-- trainer_athletes ----------------------------------------------------------

create table public.trainer_athletes (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid not null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint trainer_athletes_pkey primary key (id),
  constraint trainer_athletes_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint trainer_athletes_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  -- No trainer_id <> athlete_id check: a trainer can be his own athlete (D1).
  constraint trainer_athletes_ended_after_started_check check (ended_at >= started_at)
);

comment on table public.trainer_athletes is
  'Who trains whom (D2). One active link per athlete; ended links are kept. A trainer may be linked to himself (D1). Written only by the invite Edge Function or SQL.';
comment on column public.trainer_athletes.id is 'Primary key.';
comment on column public.trainer_athletes.trainer_id is 'The trainer (trainers.profile_id).';
comment on column public.trainer_athletes.athlete_id is
  'The athlete''s profile. May equal trainer_id (self-link).';
comment on column public.trainer_athletes.started_at is 'When the link became active.';
comment on column public.trainer_athletes.ended_at is
  'When the link ended. Null means the link is active.';
comment on column public.trainer_athletes.created_at is 'When the row was created.';
comment on column public.trainer_athletes.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

-- One active link per athlete (D2).
create unique index trainer_athletes_one_active_link_per_athlete_idx
  on public.trainer_athletes (athlete_id)
  where ended_at is null;

create index trainer_athletes_trainer_id_idx on public.trainer_athletes (trainer_id);
create index trainer_athletes_athlete_id_idx on public.trainer_athletes (athlete_id);

alter table public.trainer_athletes enable row level security;

create trigger set_updated_at
  before insert or update on public.trainer_athletes
  for each row execute function private.set_updated_at();

-- invitations ---------------------------------------------------------------

create table public.invitations (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  email text not null,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint invitations_pkey primary key (id),
  constraint invitations_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint invitations_accepted_by_fkey
    foreign key (accepted_by) references public.profiles (id) on delete cascade,
  constraint invitations_email_lowercase_check check (email = lower(email)),
  constraint invitations_accepted_together_check
    check ((accepted_at is null) = (accepted_by is null))
);

comment on table public.invitations is
  'Record of invites sent by a trainer. Written only by the invite Edge Function (service role).';
comment on column public.invitations.id is 'Primary key.';
comment on column public.invitations.trainer_id is 'The trainer who sent the invite.';
comment on column public.invitations.email is 'Invited email address, stored in lowercase.';
comment on column public.invitations.expires_at is 'When the invite stops being valid.';
comment on column public.invitations.accepted_at is
  'When the invite was accepted. Null while pending. Set together with accepted_by.';
comment on column public.invitations.accepted_by is
  'Profile of the user who accepted. Null while pending. Set together with accepted_at.';
comment on column public.invitations.created_at is 'When the row was created.';
comment on column public.invitations.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index invitations_trainer_id_idx on public.invitations (trainer_id);
create index invitations_accepted_by_idx on public.invitations (accepted_by);

alter table public.invitations enable row level security;

create trigger set_updated_at
  before insert or update on public.invitations
  for each row execute function private.set_updated_at();

-- athlete_profiles ----------------------------------------------------------

create table public.athlete_profiles (
  athlete_id uuid not null,
  sex text,
  height_cm numeric(4, 1),
  long_term_goal text,
  short_term_goal text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint athlete_profiles_pkey primary key (athlete_id),
  constraint athlete_profiles_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint athlete_profiles_sex_check check (sex in ('male', 'female')),
  constraint athlete_profiles_height_cm_check check (height_cm > 0)
);

comment on table public.athlete_profiles is
  'Data the trainer keeps per athlete. Written by the athlete''s active trainer, read by both.';
comment on column public.athlete_profiles.athlete_id is 'The athlete''s profile.';
comment on column public.athlete_profiles.sex is
  'male or female. Used by the body-fat estimate (D11). Null until the trainer fills it in.';
comment on column public.athlete_profiles.height_cm is
  'Height in centimetres. Used by the body-fat estimate (D11). Null until the trainer fills it in.';
comment on column public.athlete_profiles.long_term_goal is 'Long-term goal, free text.';
comment on column public.athlete_profiles.short_term_goal is 'Short-term goal, free text.';
comment on column public.athlete_profiles.created_at is 'When the row was created.';
comment on column public.athlete_profiles.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

alter table public.athlete_profiles enable row level security;

create trigger set_updated_at
  before insert or update on public.athlete_profiles
  for each row execute function private.set_updated_at();

-- ===========================================================================
-- Sign-up trigger
-- ===========================================================================

-- Security definer: it runs when the auth service inserts a user, and that
-- role has no rights on public.profiles. It reads only full_name from the
-- user-supplied metadata; locale takes the column default ('es').
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''));
  return new;
end;
$$;

comment on function private.handle_new_user() is
  'Trigger function on auth.users: creates the profile of a new user. Reads only full_name from raw_user_meta_data.';

revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ===========================================================================
-- RLS helper functions (docs/schema-v1.md §5)
--
-- Security definer so they can read trainers and trainer_athletes whatever
-- the caller's own policies are; they only ever answer about the caller
-- (auth.uid()). Stable, empty search_path, fully qualified names.
-- ===========================================================================

create function private.is_trainer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trainers t
    where t.profile_id = (select auth.uid())
  );
$$;

comment on function private.is_trainer() is
  'True if the caller has a trainers row.';

create function private.trainer_athlete_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select ta.athlete_id
  from public.trainer_athletes ta
  where ta.trainer_id = (select auth.uid())
    and ta.ended_at is null;
$$;

comment on function private.trainer_athlete_ids() is
  'Ids of the caller''s active athletes (includes the caller if he is self-linked). Use as: athlete_id in (select private.trainer_athlete_ids()).';

create function private.is_athlete_of(trainer_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trainer_athletes ta
    where ta.trainer_id = is_athlete_of.trainer_id
      and ta.athlete_id = (select auth.uid())
      and ta.ended_at is null
  );
$$;

comment on function private.is_athlete_of(uuid) is
  'True if the caller is an active athlete of the given trainer.';

create function private.has_active_trainer()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trainer_athletes ta
    where ta.athlete_id = (select auth.uid())
      and ta.ended_at is null
  );
$$;

comment on function private.has_active_trainer() is
  'True if the caller has an active link to a trainer.';

revoke all on function private.is_trainer() from public, anon;
revoke all on function private.trainer_athlete_ids() from public, anon;
revoke all on function private.is_athlete_of(uuid) from public, anon;
revoke all on function private.has_active_trainer() from public, anon;

grant execute on function private.is_trainer() to authenticated;
grant execute on function private.trainer_athlete_ids() to authenticated;
grant execute on function private.is_athlete_of(uuid) to authenticated;
grant execute on function private.has_active_trainer() to authenticated;

-- ===========================================================================
-- Policies and grants (docs/schema-v1.md §5)
--
-- Per table: revoke everything from anon and authenticated, then grant
-- authenticated exactly what its policies allow.
-- ===========================================================================

-- profiles ------------------------------------------------------------------

revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (full_name, locale) on table public.profiles to authenticated;

create policy "users read own profile"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "athletes read their active trainer's profile"
  on public.profiles for select to authenticated
  using (private.is_athlete_of(id));

create policy "trainers read their active athletes' profiles"
  on public.profiles for select to authenticated
  using (id in (select private.trainer_athlete_ids()));

-- Which columns may change is limited by the column-level grant above.
create policy "users update own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- trainers ------------------------------------------------------------------

revoke all on table public.trainers from anon, authenticated;
grant select on table public.trainers to authenticated;

create policy "trainers read own trainer row"
  on public.trainers for select to authenticated
  using (profile_id = (select auth.uid()));

-- trainer_athletes ----------------------------------------------------------

revoke all on table public.trainer_athletes from anon, authenticated;
grant select on table public.trainer_athletes to authenticated;

create policy "trainers read their own links"
  on public.trainer_athletes for select to authenticated
  using (trainer_id = (select auth.uid()));

create policy "athletes read their own links"
  on public.trainer_athletes for select to authenticated
  using (athlete_id = (select auth.uid()));

-- invitations ---------------------------------------------------------------

revoke all on table public.invitations from anon, authenticated;
grant select on table public.invitations to authenticated;

create policy "trainers read invitations they sent"
  on public.invitations for select to authenticated
  using (trainer_id = (select auth.uid()));

create policy "users read invitations they accepted"
  on public.invitations for select to authenticated
  using (accepted_by = (select auth.uid()));

-- athlete_profiles ----------------------------------------------------------

revoke all on table public.athlete_profiles from anon, authenticated;
grant select, insert, update, delete on table public.athlete_profiles to authenticated;

create policy "athletes read own athlete profile"
  on public.athlete_profiles for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers manage their active athletes' athlete profiles"
  on public.athlete_profiles for all to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()))
  with check (athlete_id in (select private.trainer_athlete_ids()));
