-- Group 4 (docs/schema-v1.md §7, step 2b-2a): the training plan tables —
-- mesocycles → training_days → day_exercises → exercise_prescriptions →
-- prescribed_sets — with RLS, policies and grants, plus the library
-- "used in own plans" policies for exercises and movement categories.
--
-- Templates and athletes' plans share these tables (D4). Every table has:
--   * trainer_id (→ trainers, on delete restrict);
--   * athlete_id (→ profiles, on delete cascade). Null means a template row;
--   * is_template, generated from athlete_id, so nobody can send a wrong value.
--
-- Every child has two composite FKs to its parent, both on delete cascade:
--   1. (parent_id, trainer_id, is_template), always checked: same trainer,
--      and template rows and athlete rows can never be mixed;
--   2. (parent_id, athlete_id), checked for athlete rows: same athlete. With
--      the default MATCH SIMPLE it is skipped when athlete_id is null, which
--      is why the first one exists.
-- FK checks ignore RLS: these two are what stops a row from pointing at
-- another trainer's or another athlete's plan (D3).
--
-- Constraint and index names for the first FK end in "_template" instead of
-- "_trainer_id_is_template": the full name passes Postgres's 63-byte limit on
-- the two deepest tables.
--
-- Policies are the same on all five tables:
--   * an athlete reads his own rows (never templates), also after his link
--     ended;
--   * a trainer manages (select, insert, update, delete: one policy each) the
--     rows that carry his trainer_id and are templates or belong to one of
--     his active athletes.

-- ===========================================================================
-- mesocycles
-- ===========================================================================

create table public.mesocycles (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid,
  is_template boolean not null generated always as (athlete_id is null) stored,
  name text not null,
  starts_on date,
  status text not null default 'draft',
  copied_from_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint mesocycles_pkey primary key (id),
  -- Targets of composite FKs: copied_from_id, and the two FKs of training_days.
  constraint mesocycles_id_trainer_id_key unique (id, trainer_id),
  constraint mesocycles_id_trainer_id_is_template_key unique (id, trainer_id, is_template),
  constraint mesocycles_id_athlete_id_key unique (id, athlete_id),
  constraint mesocycles_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint mesocycles_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  -- Composite: the lineage never points at another trainer's mesocycle. When
  -- the source is deleted only copied_from_id is set to null; trainer_id stays.
  constraint mesocycles_copied_from_id_trainer_id_fkey
    foreign key (copied_from_id, trainer_id)
    references public.mesocycles (id, trainer_id) on delete set null (copied_from_id),
  constraint mesocycles_status_check check (status in ('draft', 'active', 'archived')),
  constraint mesocycles_template_no_starts_on_check
    check (athlete_id is not null or starts_on is null),
  constraint mesocycles_active_needs_starts_on_check
    check (athlete_id is null or status <> 'active' or starts_on is not null),
  constraint mesocycles_starts_on_monday_check check (extract(isodow from starts_on) = 1)
);

comment on table public.mesocycles is
  'A training block: a trainer''s template (athlete_id null) or one athlete''s mesocycle (D4). Templates are deep-copied per athlete; the trees never share rows.';
comment on column public.mesocycles.id is 'Primary key.';
comment on column public.mesocycles.trainer_id is 'The trainer who owns this mesocycle.';
comment on column public.mesocycles.athlete_id is
  'The athlete this mesocycle is for. Null means it is a template.';
comment on column public.mesocycles.is_template is
  'Generated: true when athlete_id is null. Part of the composite FKs of the child tables.';
comment on column public.mesocycles.name is 'Name of the block or template.';
comment on column public.mesocycles.starts_on is
  'Monday of program week 1 (D6). Null for templates; required once an athlete''s mesocycle is active.';
comment on column public.mesocycles.status is
  'draft, active or archived. One active mesocycle per athlete.';
comment on column public.mesocycles.copied_from_id is
  'The mesocycle of the same trainer this one was copied from (lineage). Set to null if the source is deleted.';
comment on column public.mesocycles.created_at is 'When the row was created.';
comment on column public.mesocycles.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

-- One active mesocycle per athlete; templates are not limited.
create unique index mesocycles_one_active_per_athlete_idx
  on public.mesocycles (athlete_id)
  where status = 'active' and athlete_id is not null;

create index mesocycles_trainer_id_idx on public.mesocycles (trainer_id);
create index mesocycles_athlete_id_idx on public.mesocycles (athlete_id);
create index mesocycles_copied_from_id_trainer_id_idx
  on public.mesocycles (copied_from_id, trainer_id);

alter table public.mesocycles enable row level security;

create trigger set_updated_at
  before insert or update on public.mesocycles
  for each row execute function private.set_updated_at();

revoke all on table public.mesocycles from anon, authenticated;
grant select, insert, update, delete on table public.mesocycles to authenticated;

create policy "athletes read own mesocycles"
  on public.mesocycles for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read mesocycles they manage"
  on public.mesocycles for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers create mesocycles they manage"
  on public.mesocycles for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers update mesocycles they manage"
  on public.mesocycles for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  )
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers delete mesocycles they manage"
  on public.mesocycles for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

-- ===========================================================================
-- training_days
-- ===========================================================================

create table public.training_days (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid,
  is_template boolean not null generated always as (athlete_id is null) stored,
  mesocycle_id uuid not null,
  name text not null,
  position smallint not null default 0,
  kind text not null default 'training',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint training_days_pkey primary key (id),
  constraint training_days_id_trainer_id_is_template_key unique (id, trainer_id, is_template),
  constraint training_days_id_athlete_id_key unique (id, athlete_id),
  constraint training_days_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint training_days_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint training_days_mesocycle_id_template_fkey
    foreign key (mesocycle_id, trainer_id, is_template)
    references public.mesocycles (id, trainer_id, is_template) on delete cascade,
  constraint training_days_mesocycle_id_athlete_id_fkey
    foreign key (mesocycle_id, athlete_id)
    references public.mesocycles (id, athlete_id) on delete cascade,
  constraint training_days_kind_check check (kind in ('training', 'warmup'))
);

comment on table public.training_days is
  'A named day of a mesocycle. The athlete does the training days of a week in any order. A warmup day is the block''s warm-up/mobility routine: shown before every session, never logged (D7).';
comment on column public.training_days.id is 'Primary key.';
comment on column public.training_days.trainer_id is
  'The trainer who owns the mesocycle. Copied from the parent; part of the composite FK.';
comment on column public.training_days.athlete_id is
  'The athlete of the mesocycle. Null for a template row. Copied from the parent; part of the composite FK.';
comment on column public.training_days.is_template is
  'Generated: true when athlete_id is null. Part of the composite FK, so template and athlete rows are never mixed.';
comment on column public.training_days.mesocycle_id is 'The mesocycle this day belongs to.';
comment on column public.training_days.name is 'Name of the day, e.g. "Torso".';
comment on column public.training_days.position is 'Display order within the mesocycle.';
comment on column public.training_days.kind is
  'training or warmup. At most one warmup day per mesocycle.';
comment on column public.training_days.created_at is 'When the row was created.';
comment on column public.training_days.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

-- At most one warm-up day per mesocycle (D7).
create unique index training_days_one_warmup_per_mesocycle_idx
  on public.training_days (mesocycle_id)
  where kind = 'warmup';

create index training_days_trainer_id_idx on public.training_days (trainer_id);
create index training_days_athlete_id_idx on public.training_days (athlete_id);
create index training_days_mesocycle_id_template_idx
  on public.training_days (mesocycle_id, trainer_id, is_template);
create index training_days_mesocycle_id_athlete_id_idx
  on public.training_days (mesocycle_id, athlete_id);

alter table public.training_days enable row level security;

create trigger set_updated_at
  before insert or update on public.training_days
  for each row execute function private.set_updated_at();

revoke all on table public.training_days from anon, authenticated;
grant select, insert, update, delete on table public.training_days to authenticated;

create policy "athletes read own training days"
  on public.training_days for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read training days they manage"
  on public.training_days for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers create training days they manage"
  on public.training_days for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers update training days they manage"
  on public.training_days for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  )
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers delete training days they manage"
  on public.training_days for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

-- ===========================================================================
-- day_exercises
-- ===========================================================================

create table public.day_exercises (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid,
  is_template boolean not null generated always as (athlete_id is null) stored,
  training_day_id uuid not null,
  exercise_id uuid not null,
  position smallint not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint day_exercises_pkey primary key (id),
  constraint day_exercises_id_trainer_id_is_template_key unique (id, trainer_id, is_template),
  constraint day_exercises_id_athlete_id_key unique (id, athlete_id),
  constraint day_exercises_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint day_exercises_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint day_exercises_training_day_id_template_fkey
    foreign key (training_day_id, trainer_id, is_template)
    references public.training_days (id, trainer_id, is_template) on delete cascade,
  constraint day_exercises_training_day_id_athlete_id_fkey
    foreign key (training_day_id, athlete_id)
    references public.training_days (id, athlete_id) on delete cascade,
  -- Composite: a plan can only use its own trainer's exercises. On delete
  -- restrict: a used exercise is archived, not deleted.
  constraint day_exercises_exercise_id_trainer_id_fkey
    foreign key (exercise_id, trainer_id)
    references public.exercises (id, trainer_id) on delete restrict
);

comment on table public.day_exercises is
  'The fixed exercise list of a training day. The sets live in exercise_prescriptions and prescribed_sets.';
comment on column public.day_exercises.id is 'Primary key.';
comment on column public.day_exercises.trainer_id is
  'The trainer who owns the mesocycle. Copied from the parent; part of the composite FKs.';
comment on column public.day_exercises.athlete_id is
  'The athlete of the mesocycle. Null for a template row. Copied from the parent; part of the composite FK.';
comment on column public.day_exercises.is_template is
  'Generated: true when athlete_id is null. Part of the composite FK, so template and athlete rows are never mixed.';
comment on column public.day_exercises.training_day_id is 'The training day this exercise belongs to.';
comment on column public.day_exercises.exercise_id is
  'The exercise, from the same trainer''s library. The same exercise may appear more than once in a day.';
comment on column public.day_exercises.position is 'Display order within the day.';
comment on column public.day_exercises.notes is
  'Coach notes for this program, shown in addition to the exercise''s technique notes.';
comment on column public.day_exercises.created_at is 'When the row was created.';
comment on column public.day_exercises.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index day_exercises_trainer_id_idx on public.day_exercises (trainer_id);
create index day_exercises_athlete_id_idx on public.day_exercises (athlete_id);
create index day_exercises_training_day_id_template_idx
  on public.day_exercises (training_day_id, trainer_id, is_template);
create index day_exercises_training_day_id_athlete_id_idx
  on public.day_exercises (training_day_id, athlete_id);
create index day_exercises_exercise_id_trainer_id_idx
  on public.day_exercises (exercise_id, trainer_id);

alter table public.day_exercises enable row level security;

create trigger set_updated_at
  before insert or update on public.day_exercises
  for each row execute function private.set_updated_at();

revoke all on table public.day_exercises from anon, authenticated;
grant select, insert, update, delete on table public.day_exercises to authenticated;

create policy "athletes read own day exercises"
  on public.day_exercises for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read day exercises they manage"
  on public.day_exercises for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers create day exercises they manage"
  on public.day_exercises for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers update day exercises they manage"
  on public.day_exercises for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  )
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers delete day exercises they manage"
  on public.day_exercises for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

-- ===========================================================================
-- exercise_prescriptions
-- ===========================================================================

create table public.exercise_prescriptions (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid,
  is_template boolean not null generated always as (athlete_id is null) stored,
  day_exercise_id uuid not null,
  from_week smallint not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_prescriptions_pkey primary key (id),
  constraint exercise_prescriptions_id_trainer_id_is_template_key
    unique (id, trainer_id, is_template),
  constraint exercise_prescriptions_id_athlete_id_key unique (id, athlete_id),
  constraint exercise_prescriptions_day_exercise_id_from_week_key
    unique (day_exercise_id, from_week),
  constraint exercise_prescriptions_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint exercise_prescriptions_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint exercise_prescriptions_day_exercise_id_template_fkey
    foreign key (day_exercise_id, trainer_id, is_template)
    references public.day_exercises (id, trainer_id, is_template) on delete cascade,
  constraint exercise_prescriptions_day_exercise_id_athlete_id_fkey
    foreign key (day_exercise_id, athlete_id)
    references public.day_exercises (id, athlete_id) on delete cascade,
  constraint exercise_prescriptions_from_week_check check (from_week >= 1)
);

comment on table public.exercise_prescriptions is
  'A version of the sets of a day exercise, valid from a program week until a later version exists (D5). Week W uses the version with the largest from_week ≤ W.';
comment on column public.exercise_prescriptions.id is 'Primary key.';
comment on column public.exercise_prescriptions.trainer_id is
  'The trainer who owns the mesocycle. Copied from the parent; part of the composite FK.';
comment on column public.exercise_prescriptions.athlete_id is
  'The athlete of the mesocycle. Null for a template row. Copied from the parent; part of the composite FK.';
comment on column public.exercise_prescriptions.is_template is
  'Generated: true when athlete_id is null. Part of the composite FK, so template and athlete rows are never mixed.';
comment on column public.exercise_prescriptions.day_exercise_id is
  'The day exercise this version belongs to.';
comment on column public.exercise_prescriptions.from_week is
  'First program week (1 or more) this version applies to. Unique per day exercise.';
comment on column public.exercise_prescriptions.created_at is 'When the row was created.';
comment on column public.exercise_prescriptions.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index exercise_prescriptions_trainer_id_idx on public.exercise_prescriptions (trainer_id);
create index exercise_prescriptions_athlete_id_idx on public.exercise_prescriptions (athlete_id);
create index exercise_prescriptions_day_exercise_id_template_idx
  on public.exercise_prescriptions (day_exercise_id, trainer_id, is_template);
create index exercise_prescriptions_day_exercise_id_athlete_id_idx
  on public.exercise_prescriptions (day_exercise_id, athlete_id);

alter table public.exercise_prescriptions enable row level security;

create trigger set_updated_at
  before insert or update on public.exercise_prescriptions
  for each row execute function private.set_updated_at();

revoke all on table public.exercise_prescriptions from anon, authenticated;
grant select, insert, update, delete on table public.exercise_prescriptions to authenticated;

create policy "athletes read own exercise prescriptions"
  on public.exercise_prescriptions for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read exercise prescriptions they manage"
  on public.exercise_prescriptions for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers create exercise prescriptions they manage"
  on public.exercise_prescriptions for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers update exercise prescriptions they manage"
  on public.exercise_prescriptions for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  )
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers delete exercise prescriptions they manage"
  on public.exercise_prescriptions for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

-- ===========================================================================
-- prescribed_sets
-- ===========================================================================

create table public.prescribed_sets (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid,
  is_template boolean not null generated always as (athlete_id is null) stored,
  exercise_prescription_id uuid not null,
  set_number smallint not null,
  target_reps_min smallint not null,
  target_reps_max smallint not null,
  is_per_side boolean not null default false,
  target_effort text,
  target_rir_min smallint,
  target_rir_max smallint,
  technique text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint prescribed_sets_pkey primary key (id),
  constraint prescribed_sets_exercise_prescription_id_set_number_key
    unique (exercise_prescription_id, set_number),
  constraint prescribed_sets_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint prescribed_sets_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint prescribed_sets_exercise_prescription_id_template_fkey
    foreign key (exercise_prescription_id, trainer_id, is_template)
    references public.exercise_prescriptions (id, trainer_id, is_template) on delete cascade,
  constraint prescribed_sets_exercise_prescription_id_athlete_id_fkey
    foreign key (exercise_prescription_id, athlete_id)
    references public.exercise_prescriptions (id, athlete_id) on delete cascade,
  constraint prescribed_sets_set_number_check check (set_number >= 1),
  constraint prescribed_sets_target_reps_check
    check (target_reps_min >= 1 and target_reps_min <= target_reps_max),
  constraint prescribed_sets_target_effort_check check (target_effort in ('rir', 'failure')),
  -- The RIR columns are set if and only if the effort is 'rir'. "is not
  -- distinct from" keeps the comparison true/false when target_effort is null.
  constraint prescribed_sets_target_rir_effort_check check (
    (target_effort is not distinct from 'rir') = (target_rir_min is not null)
    and (target_effort is not distinct from 'rir') = (target_rir_max is not null)
  ),
  constraint prescribed_sets_target_rir_range_check
    check (target_rir_min >= 0 and target_rir_min <= target_rir_max),
  constraint prescribed_sets_technique_check
    check (technique in ('myo_reps', 'rest_pause', 'drop_set', 'partials')),
  constraint prescribed_sets_technique_needs_effort_check
    check (technique is null or target_effort is not null)
);

comment on table public.prescribed_sets is
  'One prescribed set of an exercise prescription: a rep range, the target effort and an optional technique. Warm-up sets have no effort and no technique.';
comment on column public.prescribed_sets.id is 'Primary key.';
comment on column public.prescribed_sets.trainer_id is
  'The trainer who owns the mesocycle. Copied from the parent; part of the composite FK.';
comment on column public.prescribed_sets.athlete_id is
  'The athlete of the mesocycle. Null for a template row. Copied from the parent; part of the composite FK.';
comment on column public.prescribed_sets.is_template is
  'Generated: true when athlete_id is null. Part of the composite FK, so template and athlete rows are never mixed.';
comment on column public.prescribed_sets.exercise_prescription_id is
  'The prescription version this set belongs to.';
comment on column public.prescribed_sets.set_number is
  'Order of the set within the prescription, from 1. Unique per prescription.';
comment on column public.prescribed_sets.target_reps_min is
  'Lower end of the rep range (1 or more). Equal to target_reps_max for a fixed number.';
comment on column public.prescribed_sets.target_reps_max is 'Upper end of the rep range.';
comment on column public.prescribed_sets.is_per_side is 'True when the reps are per side.';
comment on column public.prescribed_sets.target_effort is
  'rir (reps in reserve, see the RIR columns) or failure. Null for a warm-up set.';
comment on column public.prescribed_sets.target_rir_min is
  'Lower end of the RIR range (0 or more). Set if and only if target_effort is rir.';
comment on column public.prescribed_sets.target_rir_max is
  'Upper end of the RIR range. Set if and only if target_effort is rir.';
comment on column public.prescribed_sets.technique is
  'Intensity technique: myo_reps, rest_pause, drop_set or partials. One per set. Null for none, and always null when target_effort is null.';
comment on column public.prescribed_sets.notes is 'Free-text note for this set.';
comment on column public.prescribed_sets.created_at is 'When the row was created.';
comment on column public.prescribed_sets.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index prescribed_sets_trainer_id_idx on public.prescribed_sets (trainer_id);
create index prescribed_sets_athlete_id_idx on public.prescribed_sets (athlete_id);
create index prescribed_sets_exercise_prescription_id_template_idx
  on public.prescribed_sets (exercise_prescription_id, trainer_id, is_template);
create index prescribed_sets_exercise_prescription_id_athlete_id_idx
  on public.prescribed_sets (exercise_prescription_id, athlete_id);

alter table public.prescribed_sets enable row level security;

create trigger set_updated_at
  before insert or update on public.prescribed_sets
  for each row execute function private.set_updated_at();

revoke all on table public.prescribed_sets from anon, authenticated;
grant select, insert, update, delete on table public.prescribed_sets to authenticated;

create policy "athletes read own prescribed sets"
  on public.prescribed_sets for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read prescribed sets they manage"
  on public.prescribed_sets for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers create prescribed sets they manage"
  on public.prescribed_sets for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers update prescribed sets they manage"
  on public.prescribed_sets for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  )
  with check (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

create policy "trainers delete prescribed sets they manage"
  on public.prescribed_sets for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and (athlete_id is null or athlete_id in (select private.trainer_athlete_ids()))
  );

-- ===========================================================================
-- Libraries: rows used in the athlete's own plans (docs/schema-v1.md §5, D2)
--
-- An athlete reads his active trainer's whole library through the policies of
-- the libraries migration. These two add the rows his own plans use, whatever
-- his link: a former athlete still reads the names of the exercises and
-- categories of his old plans.
--
-- The subqueries run as the caller, under his own policies on day_exercises
-- and exercises, and they do not depend on the outer row, so each runs once
-- per query.
-- ===========================================================================

create policy "athletes read exercises used in their own plans"
  on public.exercises for select to authenticated
  using (
    id in (
      select de.exercise_id
      from public.day_exercises de
      where de.athlete_id = (select auth.uid())
    )
  );

create policy "athletes read categories of exercises in their own plans"
  on public.movement_categories for select to authenticated
  using (
    id in (
      select e.movement_category_id
      from public.exercises e
      join public.day_exercises de on de.exercise_id = e.id
      where de.athlete_id = (select auth.uid())
    )
  );
