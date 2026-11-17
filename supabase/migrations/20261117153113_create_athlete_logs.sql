-- Group 6 (docs/schema-v1.md §7, step 2b-2b): the athlete log tables —
-- training_sessions → set_logs, meal_logs, daily_metrics, body_measurements,
-- weekly_checkins — with RLS, policies and grants, the warm-up session
-- trigger (D7) and the ownership trigger (§4 "Log integrity rules").
--
-- Every log row carries athlete_id (→ profiles, on delete cascade) and a
-- natural unique key (D12), which is what the offline outbox upserts on.
--
-- Logs point into plans with composite FKs that include athlete_id, so a log
-- can only reference its own athlete's plan rows, never a template (D3/D4).
-- Those FKs are "on delete no action" (§4 "Log integrity rules"): a trainer
-- cannot delete a training day, day exercise or meal that has logs, while
-- deleting an athlete still works, because no action is checked at the end of
-- the statement, after the cascade from his profile has removed his plans and
-- his logs. Restrict is checked at once and would break that cascade.
-- Exception: meal_logs.meal_option_id is set to null when the option goes.
--
-- Policies (§5):
--   * an athlete reads his own rows always, and creates, updates and deletes
--     them while he has an active trainer;
--   * a trainer reads his active athletes' rows, and corrects (update only)
--     their set_logs, daily_metrics and body_measurements.

-- ===========================================================================
-- Targets of the new composite FKs on the plan tables
--
-- These tables were created by earlier migrations (already pushed), so the
-- unique constraints are added here. training_days already has
-- (id, athlete_id) and day_exercises (id, athlete_id).
-- ===========================================================================

alter table public.day_exercises
  add constraint day_exercises_id_training_day_id_key unique (id, training_day_id);

alter table public.meals
  add constraint meals_id_athlete_id_key unique (id, athlete_id);

alter table public.meal_options
  add constraint meal_options_id_meal_id_key unique (id, meal_id);

-- ===========================================================================
-- Trigger functions
-- ===========================================================================

-- Ownership columns of a log never change (§4 "Log integrity rules"). The
-- triggers below call this only when one of them changed (WHEN clause), so it
-- just raises. Without it a trainer could move a daily_metrics row from one
-- of his athletes to another: the policy accepts both, and daily_metrics has
-- no parent FK that would notice.
create function private.reject_log_ownership_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'log_ownership_immutable' using errcode = 'check_violation';
end;
$$;

comment on function private.reject_log_ownership_change() is
  'Trigger function on the log tables: rejects an update that changes an ownership column (message log_ownership_immutable). The trigger''s WHEN clause decides which columns.';

revoke all on function private.reject_log_ownership_change() from public, anon, authenticated;

-- A warm-up day is never logged (D7). A foreign key cannot check a column's
-- value, so this trigger does. Security definer: the rule must hold whoever
-- writes, whatever he can read of training_days.
create function private.reject_warmup_session()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.training_days d
    where d.id = new.training_day_id
      and d.kind = 'warmup'
  ) then
    raise exception 'warmup_day_not_loggable' using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function private.reject_warmup_session() is
  'Trigger function on training_sessions: rejects a session on a warmup training day (message warmup_day_not_loggable, D7).';

revoke all on function private.reject_warmup_session() from public, anon, authenticated;

-- ===========================================================================
-- training_sessions
-- ===========================================================================

create table public.training_sessions (
  id uuid not null default gen_random_uuid(),
  athlete_id uuid not null,
  training_day_id uuid not null,
  program_week smallint not null,
  performed_on date not null,
  completed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint training_sessions_pkey primary key (id),
  -- Natural key (D12): one session per training day per program week (D6).
  constraint training_sessions_training_day_id_program_week_key
    unique (training_day_id, program_week),
  -- Targets of the two composite FKs of set_logs.
  constraint training_sessions_id_athlete_id_key unique (id, athlete_id),
  constraint training_sessions_id_training_day_id_key unique (id, training_day_id),
  constraint training_sessions_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  -- Composite: only a day of the athlete's own mesocycle, never a template.
  constraint training_sessions_training_day_id_athlete_id_fkey
    foreign key (training_day_id, athlete_id)
    references public.training_days (id, athlete_id) on delete no action,
  constraint training_sessions_program_week_check check (program_week >= 1)
);

comment on table public.training_sessions is
  'One athlete''s workout of a training day in a program week (D6). Its id is a UUID v5 of (training_day_id, program_week), made on the client, so two devices create the same session (D12). Day status is derived from these rows, never stored.';
comment on column public.training_sessions.id is
  'Primary key: UUID v5 of (training_day_id, program_week), generated on the client.';
comment on column public.training_sessions.athlete_id is
  'The athlete who trained. Part of the composite FK to the training day.';
comment on column public.training_sessions.training_day_id is
  'The training day of the athlete''s own mesocycle. Never a warmup day (trigger).';
comment on column public.training_sessions.program_week is
  'Program week (1 or more) the session belongs to, set by the phone when the session is created. One session per day and week.';
comment on column public.training_sessions.performed_on is 'Calendar date of the workout.';
comment on column public.training_sessions.completed_at is
  'When the athlete finished the session. Null while it is in progress (status incomplete if it has sets).';
comment on column public.training_sessions.notes is 'The athlete''s free-text note on the session.';
comment on column public.training_sessions.created_at is 'When the row was created.';
comment on column public.training_sessions.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index training_sessions_athlete_id_idx on public.training_sessions (athlete_id);
create index training_sessions_training_day_id_athlete_id_idx
  on public.training_sessions (training_day_id, athlete_id);

alter table public.training_sessions enable row level security;

create trigger set_updated_at
  before insert or update on public.training_sessions
  for each row execute function private.set_updated_at();

create trigger reject_warmup_session
  before insert or update of training_day_id on public.training_sessions
  for each row execute function private.reject_warmup_session();

create trigger reject_ownership_change
  before update on public.training_sessions
  for each row
  when (old.athlete_id is distinct from new.athlete_id)
  execute function private.reject_log_ownership_change();

revoke all on table public.training_sessions from anon, authenticated;
grant select, insert, update, delete on table public.training_sessions to authenticated;

create policy "athletes read own training sessions"
  on public.training_sessions for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "athletes create own training sessions while linked"
  on public.training_sessions for insert to authenticated
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes update own training sessions while linked"
  on public.training_sessions for update to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()))
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes delete own training sessions while linked"
  on public.training_sessions for delete to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "trainers read their active athletes' training sessions"
  on public.training_sessions for select to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()));

-- ===========================================================================
-- set_logs
-- ===========================================================================

create table public.set_logs (
  id uuid not null default gen_random_uuid(),
  athlete_id uuid not null,
  training_session_id uuid not null,
  training_day_id uuid not null,
  day_exercise_id uuid not null,
  set_number smallint not null,
  reps smallint,
  weight_kg numeric(6, 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint set_logs_pkey primary key (id),
  -- Natural key (D12).
  constraint set_logs_training_session_id_day_exercise_id_set_number_key
    unique (training_session_id, day_exercise_id, set_number),
  constraint set_logs_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  -- The session: the athlete's own (D3). Deleting a session deletes its sets.
  constraint set_logs_training_session_id_athlete_id_fkey
    foreign key (training_session_id, athlete_id)
    references public.training_sessions (id, athlete_id) on delete cascade,
  -- training_day_id is the session's day...
  constraint set_logs_training_session_id_training_day_id_fkey
    foreign key (training_session_id, training_day_id)
    references public.training_sessions (id, training_day_id) on delete cascade,
  -- ...and the exercise's day, so a set can't log an exercise of another day.
  constraint set_logs_day_exercise_id_training_day_id_fkey
    foreign key (day_exercise_id, training_day_id)
    references public.day_exercises (id, training_day_id) on delete no action,
  constraint set_logs_day_exercise_id_athlete_id_fkey
    foreign key (day_exercise_id, athlete_id)
    references public.day_exercises (id, athlete_id) on delete no action,
  constraint set_logs_set_number_check check (set_number >= 1),
  constraint set_logs_reps_check check (reps >= 0),
  constraint set_logs_weight_kg_check check (weight_kg >= 0)
);

comment on table public.set_logs is
  'One logged set of a day exercise in a training session: reps and weight. One row per set, for the later volume and progress features.';
comment on column public.set_logs.id is 'Primary key. Random v4 UUID, generated on the client.';
comment on column public.set_logs.athlete_id is
  'The athlete who trained. Part of the composite FKs; cannot change (trigger).';
comment on column public.set_logs.training_session_id is
  'The session this set belongs to. Cannot change (trigger).';
comment on column public.set_logs.training_day_id is
  'The training day of the session, copied down (D3). Part of the two FKs that make the session''s day and the exercise''s day the same. Cannot change (trigger).';
comment on column public.set_logs.day_exercise_id is
  'The day exercise performed, from the session''s training day. Cannot change (trigger).';
comment on column public.set_logs.set_number is
  'Order of the set within the exercise in this session, from 1.';
comment on column public.set_logs.reps is
  'Repetitions done (0 or more). Null until entered: the phone saves each field as it is typed.';
comment on column public.set_logs.weight_kg is
  'Load in kilograms (0 or more). Null until entered, or for an exercise without external load.';
comment on column public.set_logs.created_at is 'When the row was created.';
comment on column public.set_logs.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index set_logs_athlete_id_idx on public.set_logs (athlete_id);
create index set_logs_training_session_id_athlete_id_idx
  on public.set_logs (training_session_id, athlete_id);
create index set_logs_training_session_id_training_day_id_idx
  on public.set_logs (training_session_id, training_day_id);
create index set_logs_day_exercise_id_training_day_id_idx
  on public.set_logs (day_exercise_id, training_day_id);
create index set_logs_day_exercise_id_athlete_id_idx
  on public.set_logs (day_exercise_id, athlete_id);

alter table public.set_logs enable row level security;

create trigger set_updated_at
  before insert or update on public.set_logs
  for each row execute function private.set_updated_at();

create trigger reject_ownership_change
  before update on public.set_logs
  for each row
  when (
    old.athlete_id is distinct from new.athlete_id
    or old.training_session_id is distinct from new.training_session_id
    or old.training_day_id is distinct from new.training_day_id
    or old.day_exercise_id is distinct from new.day_exercise_id
  )
  execute function private.reject_log_ownership_change();

revoke all on table public.set_logs from anon, authenticated;
grant select, insert, update, delete on table public.set_logs to authenticated;

create policy "athletes read own set logs"
  on public.set_logs for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "athletes create own set logs while linked"
  on public.set_logs for insert to authenticated
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes update own set logs while linked"
  on public.set_logs for update to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()))
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes delete own set logs while linked"
  on public.set_logs for delete to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "trainers read their active athletes' set logs"
  on public.set_logs for select to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()));

create policy "trainers correct their active athletes' set logs"
  on public.set_logs for update to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()))
  with check (athlete_id in (select private.trainer_athlete_ids()));

-- ===========================================================================
-- meal_logs
-- ===========================================================================

create table public.meal_logs (
  id uuid not null default gen_random_uuid(),
  athlete_id uuid not null,
  meal_id uuid not null,
  logged_on date not null,
  meal_option_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_logs_pkey primary key (id),
  -- Natural key (D12). It also serves the athlete_id FK (leading column).
  constraint meal_logs_athlete_id_meal_id_logged_on_key unique (athlete_id, meal_id, logged_on),
  constraint meal_logs_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  -- Composite: only a meal of the athlete's own plan.
  constraint meal_logs_meal_id_athlete_id_fkey
    foreign key (meal_id, athlete_id)
    references public.meals (id, athlete_id) on delete no action,
  -- Composite: only an option of that meal. Deleting the option keeps the
  -- log and sets only meal_option_id to null.
  constraint meal_logs_meal_option_id_meal_id_fkey
    foreign key (meal_option_id, meal_id)
    references public.meal_options (id, meal_id) on delete set null (meal_option_id)
);

comment on table public.meal_logs is
  'A ticked meal: the athlete ate this meal on this day. Unticking deletes the row.';
comment on column public.meal_logs.id is 'Primary key. Random v4 UUID, generated on the client.';
comment on column public.meal_logs.athlete_id is
  'The athlete who ate the meal. Part of the composite FK; cannot change (trigger).';
comment on column public.meal_logs.meal_id is 'The meal of the athlete''s own plan.';
comment on column public.meal_logs.logged_on is 'Calendar date the meal was eaten.';
comment on column public.meal_logs.meal_option_id is
  'The option eaten, one of that meal''s options. Null when not specified, or when the option was deleted.';
comment on column public.meal_logs.created_at is 'When the row was created.';
comment on column public.meal_logs.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index meal_logs_meal_id_athlete_id_idx on public.meal_logs (meal_id, athlete_id);
create index meal_logs_meal_option_id_meal_id_idx on public.meal_logs (meal_option_id, meal_id);

alter table public.meal_logs enable row level security;

create trigger set_updated_at
  before insert or update on public.meal_logs
  for each row execute function private.set_updated_at();

create trigger reject_ownership_change
  before update on public.meal_logs
  for each row
  when (old.athlete_id is distinct from new.athlete_id)
  execute function private.reject_log_ownership_change();

revoke all on table public.meal_logs from anon, authenticated;
grant select, insert, update, delete on table public.meal_logs to authenticated;

create policy "athletes read own meal logs"
  on public.meal_logs for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "athletes create own meal logs while linked"
  on public.meal_logs for insert to authenticated
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes update own meal logs while linked"
  on public.meal_logs for update to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()))
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes delete own meal logs while linked"
  on public.meal_logs for delete to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "trainers read their active athletes' meal logs"
  on public.meal_logs for select to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()));

-- ===========================================================================
-- daily_metrics
-- ===========================================================================

create table public.daily_metrics (
  id uuid not null default gen_random_uuid(),
  athlete_id uuid not null,
  recorded_on date not null,
  fasted_weight_kg numeric(5, 2),
  steps integer,
  sleep_minutes smallint,
  stress smallint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_metrics_pkey primary key (id),
  -- Natural key (D12). It also serves the athlete_id FK (leading column).
  constraint daily_metrics_athlete_id_recorded_on_key unique (athlete_id, recorded_on),
  constraint daily_metrics_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint daily_metrics_fasted_weight_kg_check check (fasted_weight_kg > 0),
  constraint daily_metrics_steps_check check (steps >= 0),
  constraint daily_metrics_sleep_minutes_check check (sleep_minutes between 0 and 1440),
  constraint daily_metrics_stress_check check (stress between 0 and 10)
);

comment on table public.daily_metrics is
  'One day of an athlete''s tracking: fasted weight, steps, sleep and stress. Every value is nullable, because they are filled in through the day.';
comment on column public.daily_metrics.id is 'Primary key. Random v4 UUID, generated on the client.';
comment on column public.daily_metrics.athlete_id is 'The athlete. Cannot change (trigger).';
comment on column public.daily_metrics.recorded_on is 'The calendar day the values are for.';
comment on column public.daily_metrics.fasted_weight_kg is
  'Bodyweight in kilograms, fasted, in the morning. Greater than 0.';
comment on column public.daily_metrics.steps is 'Steps walked that day (0 or more).';
comment on column public.daily_metrics.sleep_minutes is 'Sleep of the night before, in minutes (0–1440).';
comment on column public.daily_metrics.stress is 'Stress level, 0 (none) to 10.';
comment on column public.daily_metrics.created_at is 'When the row was created.';
comment on column public.daily_metrics.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

alter table public.daily_metrics enable row level security;

create trigger set_updated_at
  before insert or update on public.daily_metrics
  for each row execute function private.set_updated_at();

create trigger reject_ownership_change
  before update on public.daily_metrics
  for each row
  when (old.athlete_id is distinct from new.athlete_id)
  execute function private.reject_log_ownership_change();

revoke all on table public.daily_metrics from anon, authenticated;
grant select, insert, update, delete on table public.daily_metrics to authenticated;

create policy "athletes read own daily metrics"
  on public.daily_metrics for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "athletes create own daily metrics while linked"
  on public.daily_metrics for insert to authenticated
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes update own daily metrics while linked"
  on public.daily_metrics for update to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()))
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes delete own daily metrics while linked"
  on public.daily_metrics for delete to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "trainers read their active athletes' daily metrics"
  on public.daily_metrics for select to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()));

create policy "trainers correct their active athletes' daily metrics"
  on public.daily_metrics for update to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()))
  with check (athlete_id in (select private.trainer_athlete_ids()));

-- ===========================================================================
-- body_measurements
-- ===========================================================================

create table public.body_measurements (
  id uuid not null default gen_random_uuid(),
  athlete_id uuid not null,
  measured_on date not null,
  chest_cm numeric(5, 1),
  biceps_left_cm numeric(5, 1),
  biceps_right_cm numeric(5, 1),
  upper_abdomen_cm numeric(5, 1),
  navel_cm numeric(5, 1),
  hip_cm numeric(5, 1),
  glute_cm numeric(5, 1),
  quad_left_cm numeric(5, 1),
  quad_right_cm numeric(5, 1),
  calf_left_cm numeric(5, 1),
  calf_right_cm numeric(5, 1),
  neck_cm numeric(5, 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint body_measurements_pkey primary key (id),
  -- Natural key (D12). It also serves the athlete_id FK (leading column).
  constraint body_measurements_athlete_id_measured_on_key unique (athlete_id, measured_on),
  constraint body_measurements_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint body_measurements_chest_cm_check check (chest_cm > 0),
  constraint body_measurements_biceps_left_cm_check check (biceps_left_cm > 0),
  constraint body_measurements_biceps_right_cm_check check (biceps_right_cm > 0),
  constraint body_measurements_upper_abdomen_cm_check check (upper_abdomen_cm > 0),
  constraint body_measurements_navel_cm_check check (navel_cm > 0),
  constraint body_measurements_hip_cm_check check (hip_cm > 0),
  constraint body_measurements_glute_cm_check check (glute_cm > 0),
  constraint body_measurements_quad_left_cm_check check (quad_left_cm > 0),
  constraint body_measurements_quad_right_cm_check check (quad_right_cm > 0),
  constraint body_measurements_calf_left_cm_check check (calf_left_cm > 0),
  constraint body_measurements_calf_right_cm_check check (calf_right_cm > 0),
  constraint body_measurements_neck_cm_check check (neck_cm > 0)
);

comment on table public.body_measurements is
  'One day of body circumferences (his MEDIDAS sites plus the neck, D11). Every site is measured contracted, except the glute. Every value is nullable, and greater than 0 when set.';
comment on column public.body_measurements.id is 'Primary key. Random v4 UUID, generated on the client.';
comment on column public.body_measurements.athlete_id is 'The athlete. Cannot change (trigger).';
comment on column public.body_measurements.measured_on is 'The calendar day of the measurement.';
comment on column public.body_measurements.chest_cm is 'Chest, in centimetres. Contracted.';
comment on column public.body_measurements.biceps_left_cm is 'Left biceps, in centimetres. Contracted.';
comment on column public.body_measurements.biceps_right_cm is 'Right biceps, in centimetres. Contracted.';
comment on column public.body_measurements.upper_abdomen_cm is
  'Upper abdomen, 2 cm above the navel, in centimetres. Contracted.';
comment on column public.body_measurements.navel_cm is
  'Waist at the navel, in centimetres. Contracted. The waist of the body-fat estimate (D11).';
comment on column public.body_measurements.hip_cm is
  'Hip ("cadera"), 2 cm below the navel, in centimetres. Contracted. The hip of the women''s body-fat estimate (D11): not the Navy''s widest point of the glutes.';
comment on column public.body_measurements.glute_cm is
  'Glutes, in centimetres. The one site measured relaxed, not contracted.';
comment on column public.body_measurements.quad_left_cm is 'Left quadriceps, in centimetres. Contracted.';
comment on column public.body_measurements.quad_right_cm is 'Right quadriceps, in centimetres. Contracted.';
comment on column public.body_measurements.calf_left_cm is 'Left calf, in centimetres. Contracted.';
comment on column public.body_measurements.calf_right_cm is 'Right calf, in centimetres. Contracted.';
comment on column public.body_measurements.neck_cm is
  'Neck, in centimetres. Used by the body-fat estimate (D11).';
comment on column public.body_measurements.created_at is 'When the row was created.';
comment on column public.body_measurements.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

alter table public.body_measurements enable row level security;

create trigger set_updated_at
  before insert or update on public.body_measurements
  for each row execute function private.set_updated_at();

create trigger reject_ownership_change
  before update on public.body_measurements
  for each row
  when (old.athlete_id is distinct from new.athlete_id)
  execute function private.reject_log_ownership_change();

revoke all on table public.body_measurements from anon, authenticated;
grant select, insert, update, delete on table public.body_measurements to authenticated;

create policy "athletes read own body measurements"
  on public.body_measurements for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "athletes create own body measurements while linked"
  on public.body_measurements for insert to authenticated
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes update own body measurements while linked"
  on public.body_measurements for update to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()))
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes delete own body measurements while linked"
  on public.body_measurements for delete to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "trainers read their active athletes' body measurements"
  on public.body_measurements for select to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()));

create policy "trainers correct their active athletes' body measurements"
  on public.body_measurements for update to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()))
  with check (athlete_id in (select private.trainer_athlete_ids()));

-- ===========================================================================
-- weekly_checkins
-- ===========================================================================

create table public.weekly_checkins (
  id uuid not null default gen_random_uuid(),
  athlete_id uuid not null,
  week_starts_on date not null,
  training_adherence text,
  recovery text,
  can_progress text,
  energy text,
  motivation text,
  training_notes text,
  diet_adherence text,
  satiety smallint,
  diet_satisfaction text,
  diet_notes text,
  diet_missed_reason text,
  sleep_quality text,
  message_to_trainer text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint weekly_checkins_pkey primary key (id),
  -- Natural key (D12). It also serves the athlete_id FK (leading column).
  constraint weekly_checkins_athlete_id_week_starts_on_key unique (athlete_id, week_starts_on),
  constraint weekly_checkins_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint weekly_checkins_week_starts_on_monday_check
    check (extract(isodow from week_starts_on) = 1),
  -- Answer codes (§4), ordered best → worst. Every answer is nullable.
  constraint weekly_checkins_training_adherence_check
    check (training_adherence in ('100', 'gt_80', 'gt_50', 'lt_50')),
  constraint weekly_checkins_recovery_check
    check (recovery in ('very_good', 'good', 'slight_soreness', 'heavy_soreness')),
  constraint weekly_checkins_can_progress_check
    check (can_progress in ('yes_most', 'yes_some', 'few', 'none')),
  constraint weekly_checkins_energy_check
    check (energy in ('very_high', 'high', 'medium', 'low')),
  constraint weekly_checkins_motivation_check
    check (motivation in ('very_high', 'high', 'medium', 'low')),
  constraint weekly_checkins_diet_adherence_check
    check (diet_adherence in ('100', 'gt_80', 'gt_50', 'lt_50')),
  constraint weekly_checkins_satiety_check check (satiety between 1 and 5),
  constraint weekly_checkins_diet_satisfaction_check
    check (diet_satisfaction in ('very_high', 'high', 'medium', 'low')),
  constraint weekly_checkins_sleep_quality_check
    check (sleep_quality in ('excellent', 'good', 'fair', 'poor'))
);

comment on table public.weekly_checkins is
  'The athlete''s weekly check-in (his FORMULARIO, D11). Fixed answers are English codes, ordered best → worst; the labels live in i18n. Every answer is nullable.';
comment on column public.weekly_checkins.id is 'Primary key. Random v4 UUID, generated on the client.';
comment on column public.weekly_checkins.athlete_id is 'The athlete. Cannot change (trigger).';
comment on column public.weekly_checkins.week_starts_on is
  'Monday of the week the check-in is about (not the day it was sent).';
comment on column public.weekly_checkins.training_adherence is
  'Share of the planned training done: 100, gt_80, gt_50 or lt_50 (buckets, not numbers).';
comment on column public.weekly_checkins.recovery is
  'Recovery: very_good, good, slight_soreness or heavy_soreness.';
comment on column public.weekly_checkins.can_progress is
  'Could he progress in his exercises: yes_most, yes_some, few or none.';
comment on column public.weekly_checkins.energy is 'Energy: very_high, high, medium or low.';
comment on column public.weekly_checkins.motivation is 'Motivation: very_high, high, medium or low.';
comment on column public.weekly_checkins.training_notes is 'Free-text notes on the training week.';
comment on column public.weekly_checkins.diet_adherence is
  'Share of the meal plan followed: 100, gt_80, gt_50 or lt_50 (buckets, not numbers).';
comment on column public.weekly_checkins.satiety is
  'Satiety from 1 (very hungry) to 5 (the food is too much); 3–4 is right. Not a "higher is better" scale: 1 and 5 are both warnings.';
comment on column public.weekly_checkins.diet_satisfaction is
  'Satisfaction with the diet: very_high, high, medium or low.';
comment on column public.weekly_checkins.diet_notes is 'Free-text notes on the nutrition week.';
comment on column public.weekly_checkins.diet_missed_reason is
  'Free text: why meals of the plan were missed, if any.';
comment on column public.weekly_checkins.sleep_quality is
  'Sleep quality: excellent, good, fair or poor.';
comment on column public.weekly_checkins.message_to_trainer is 'Free-text message to the trainer.';
comment on column public.weekly_checkins.created_at is 'When the row was created.';
comment on column public.weekly_checkins.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

alter table public.weekly_checkins enable row level security;

create trigger set_updated_at
  before insert or update on public.weekly_checkins
  for each row execute function private.set_updated_at();

create trigger reject_ownership_change
  before update on public.weekly_checkins
  for each row
  when (old.athlete_id is distinct from new.athlete_id)
  execute function private.reject_log_ownership_change();

revoke all on table public.weekly_checkins from anon, authenticated;
grant select, insert, update, delete on table public.weekly_checkins to authenticated;

create policy "athletes read own weekly checkins"
  on public.weekly_checkins for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "athletes create own weekly checkins while linked"
  on public.weekly_checkins for insert to authenticated
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes update own weekly checkins while linked"
  on public.weekly_checkins for update to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()))
  with check (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "athletes delete own weekly checkins while linked"
  on public.weekly_checkins for delete to authenticated
  using (athlete_id = (select auth.uid()) and (select private.has_active_trainer()));

create policy "trainers read their active athletes' weekly checkins"
  on public.weekly_checkins for select to authenticated
  using (athlete_id in (select private.trainer_athlete_ids()));
