-- Group 5 (docs/schema-v1.md §7, step 2b-2a): the nutrition plan tables —
-- meal_plans → meals → meal_options → meal_option_items, and macro_targets —
-- with RLS, policies and grants, the two unit triggers, the foods "used in
-- own plans" policy, and an index on food_swaps.
--
-- Meal plans are individual (D4): every row has an athlete, there are no
-- templates. Every table has:
--   * trainer_id (→ trainers, on delete restrict);
--   * athlete_id (→ profiles, on delete cascade), never null.
--
-- Every child has one composite FK to its parent, on delete cascade:
-- (parent_id, athlete_id, trainer_id). FK checks ignore RLS: the athlete
-- column stops a row from pointing at another athlete's plan, and the trainer
-- column stops a new trainer from attaching rows to a plan the athlete's
-- previous trainer wrote (D3).
--
-- Policies are the same on all five tables:
--   * an athlete reads his own rows, also after his link ended;
--   * a trainer manages (select, insert, update, delete: one policy each) the
--     rows that carry his trainer_id and belong to one of his active athletes.

-- ===========================================================================
-- meal_plans
-- ===========================================================================

create table public.meal_plans (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid not null,
  name text not null,
  status text not null default 'draft',
  guidelines text,
  copied_from_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_plans_pkey primary key (id),
  -- Targets of composite FKs: copied_from_id, and the FK of meals.
  constraint meal_plans_id_trainer_id_key unique (id, trainer_id),
  constraint meal_plans_id_athlete_id_trainer_id_key unique (id, athlete_id, trainer_id),
  constraint meal_plans_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint meal_plans_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  -- Composite: the lineage never points at another trainer's plan. When the
  -- source is deleted only copied_from_id is set to null; trainer_id stays.
  constraint meal_plans_copied_from_id_trainer_id_fkey
    foreign key (copied_from_id, trainer_id)
    references public.meal_plans (id, trainer_id) on delete set null (copied_from_id),
  constraint meal_plans_status_check check (status in ('draft', 'active', 'archived'))
);

comment on table public.meal_plans is
  'One athlete''s meal plan (D4): individual, never a template. Reuse means duplicating a plan.';
comment on column public.meal_plans.id is 'Primary key.';
comment on column public.meal_plans.trainer_id is 'The trainer who wrote this plan.';
comment on column public.meal_plans.athlete_id is 'The athlete this plan is for.';
comment on column public.meal_plans.name is 'Name of the plan, e.g. "Volumen".';
comment on column public.meal_plans.status is
  'draft, active or archived. One active meal plan per athlete.';
comment on column public.meal_plans.guidelines is
  'Free-text guidelines: hydration, weigh food raw…, and the supplement list with amounts and timing.';
comment on column public.meal_plans.copied_from_id is
  'The meal plan of the same trainer this one was duplicated from (lineage). Set to null if the source is deleted.';
comment on column public.meal_plans.created_at is 'When the row was created.';
comment on column public.meal_plans.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

-- One active meal plan per athlete.
create unique index meal_plans_one_active_per_athlete_idx
  on public.meal_plans (athlete_id)
  where status = 'active';

create index meal_plans_trainer_id_idx on public.meal_plans (trainer_id);
create index meal_plans_athlete_id_idx on public.meal_plans (athlete_id);
create index meal_plans_copied_from_id_trainer_id_idx
  on public.meal_plans (copied_from_id, trainer_id);

alter table public.meal_plans enable row level security;

create trigger set_updated_at
  before insert or update on public.meal_plans
  for each row execute function private.set_updated_at();

revoke all on table public.meal_plans from anon, authenticated;
grant select, insert, update, delete on table public.meal_plans to authenticated;

create policy "athletes read own meal plans"
  on public.meal_plans for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read their active athletes' meal plans"
  on public.meal_plans for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers create their active athletes' meal plans"
  on public.meal_plans for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers update their active athletes' meal plans"
  on public.meal_plans for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  )
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers delete their active athletes' meal plans"
  on public.meal_plans for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

-- ===========================================================================
-- meals
-- ===========================================================================

create table public.meals (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid not null,
  meal_plan_id uuid not null,
  name text not null,
  position smallint not null default 0,
  day_type text not null default 'all',
  target_protein_g numeric(5, 2) not null,
  target_carbs_g numeric(5, 2) not null,
  target_fat_g numeric(5, 2) not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meals_pkey primary key (id),
  constraint meals_id_athlete_id_trainer_id_key unique (id, athlete_id, trainer_id),
  constraint meals_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint meals_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint meals_meal_plan_id_athlete_id_trainer_id_fkey
    foreign key (meal_plan_id, athlete_id, trainer_id)
    references public.meal_plans (id, athlete_id, trainer_id) on delete cascade,
  constraint meals_day_type_check check (day_type in ('all', 'training', 'rest')),
  constraint meals_target_protein_g_check check (target_protein_g >= 0),
  constraint meals_target_carbs_g_check check (target_carbs_g >= 0),
  constraint meals_target_fat_g_check check (target_fat_g >= 0)
);

comment on table public.meals is
  'A meal of a meal plan, with its own macro targets (D9). kcal is never stored (4P + 4C + 9F).';
comment on column public.meals.id is 'Primary key.';
comment on column public.meals.trainer_id is
  'The trainer who wrote the plan. Copied from the parent; part of the composite FK.';
comment on column public.meals.athlete_id is
  'The athlete of the plan. Copied from the parent; part of the composite FK.';
comment on column public.meals.meal_plan_id is 'The meal plan this meal belongs to.';
comment on column public.meals.name is 'Name of the meal, e.g. "Desayuno".';
comment on column public.meals.position is 'Display order within the plan.';
comment on column public.meals.day_type is
  'Days the meal applies to: all, training or rest. The intra-workout meal is training.';
comment on column public.meals.target_protein_g is 'Protein target of the meal, in grams.';
comment on column public.meals.target_carbs_g is 'Carbohydrate target of the meal, in grams.';
comment on column public.meals.target_fat_g is 'Fat target of the meal, in grams.';
comment on column public.meals.notes is 'Free-text notes: portions, "verdura libre"…';
comment on column public.meals.created_at is 'When the row was created.';
comment on column public.meals.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index meals_trainer_id_idx on public.meals (trainer_id);
create index meals_athlete_id_idx on public.meals (athlete_id);
create index meals_meal_plan_id_athlete_id_trainer_id_idx
  on public.meals (meal_plan_id, athlete_id, trainer_id);

alter table public.meals enable row level security;

create trigger set_updated_at
  before insert or update on public.meals
  for each row execute function private.set_updated_at();

revoke all on table public.meals from anon, authenticated;
grant select, insert, update, delete on table public.meals to authenticated;

create policy "athletes read own meals"
  on public.meals for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read their active athletes' meals"
  on public.meals for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers create their active athletes' meals"
  on public.meals for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers update their active athletes' meals"
  on public.meals for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  )
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers delete their active athletes' meals"
  on public.meals for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

-- ===========================================================================
-- meal_options
-- ===========================================================================

create table public.meal_options (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid not null,
  meal_id uuid not null,
  position smallint not null default 0,
  label text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_options_pkey primary key (id),
  constraint meal_options_id_athlete_id_trainer_id_key unique (id, athlete_id, trainer_id),
  constraint meal_options_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint meal_options_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint meal_options_meal_id_athlete_id_trainer_id_fkey
    foreign key (meal_id, athlete_id, trainer_id)
    references public.meals (id, athlete_id, trainer_id) on delete cascade
);

comment on table public.meal_options is
  'One of the alternative ways to eat a meal. Its macros are computed from its items, never stored.';
comment on column public.meal_options.id is 'Primary key.';
comment on column public.meal_options.trainer_id is
  'The trainer who wrote the plan. Copied from the parent; part of the composite FK.';
comment on column public.meal_options.athlete_id is
  'The athlete of the plan. Copied from the parent; part of the composite FK.';
comment on column public.meal_options.meal_id is 'The meal this option belongs to.';
comment on column public.meal_options.position is 'Display order within the meal.';
comment on column public.meal_options.label is
  'Optional name of the option. Null means the UI numbers it by position.';
comment on column public.meal_options.notes is 'Free-text notes, e.g. a recipe idea.';
comment on column public.meal_options.created_at is 'When the row was created.';
comment on column public.meal_options.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index meal_options_trainer_id_idx on public.meal_options (trainer_id);
create index meal_options_athlete_id_idx on public.meal_options (athlete_id);
create index meal_options_meal_id_athlete_id_trainer_id_idx
  on public.meal_options (meal_id, athlete_id, trainer_id);

alter table public.meal_options enable row level security;

create trigger set_updated_at
  before insert or update on public.meal_options
  for each row execute function private.set_updated_at();

revoke all on table public.meal_options from anon, authenticated;
grant select, insert, update, delete on table public.meal_options to authenticated;

create policy "athletes read own meal options"
  on public.meal_options for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read their active athletes' meal options"
  on public.meal_options for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers create their active athletes' meal options"
  on public.meal_options for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers update their active athletes' meal options"
  on public.meal_options for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  )
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers delete their active athletes' meal options"
  on public.meal_options for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

-- ===========================================================================
-- meal_option_items
-- ===========================================================================

create table public.meal_option_items (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid not null,
  meal_option_id uuid not null,
  food_id uuid not null,
  position smallint not null default 0,
  amount numeric(7, 2) not null,
  amount_unit text not null default 'g',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_option_items_pkey primary key (id),
  constraint meal_option_items_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint meal_option_items_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint meal_option_items_meal_option_id_athlete_id_trainer_id_fkey
    foreign key (meal_option_id, athlete_id, trainer_id)
    references public.meal_options (id, athlete_id, trainer_id) on delete cascade,
  -- Composite: a plan can only use its own trainer's foods. On delete
  -- restrict: a used food is archived, not deleted.
  constraint meal_option_items_food_id_trainer_id_fkey
    foreign key (food_id, trainer_id)
    references public.foods (id, trainer_id) on delete restrict,
  constraint meal_option_items_amount_check check (amount > 0),
  constraint meal_option_items_amount_unit_check check (amount_unit in ('g', 'unit'))
);

comment on table public.meal_option_items is
  'A food and its amount within a meal option. Amounts are in grams or in the food''s own unit (D8).';
comment on column public.meal_option_items.id is 'Primary key.';
comment on column public.meal_option_items.trainer_id is
  'The trainer who wrote the plan. Copied from the parent; part of the composite FKs.';
comment on column public.meal_option_items.athlete_id is
  'The athlete of the plan. Copied from the parent; part of the composite FK.';
comment on column public.meal_option_items.meal_option_id is 'The meal option this item belongs to.';
comment on column public.meal_option_items.food_id is
  'The food, from the same trainer''s library.';
comment on column public.meal_option_items.position is 'Display order within the option.';
comment on column public.meal_option_items.amount is
  'How much of the food, in amount_unit. Greater than 0.';
comment on column public.meal_option_items.amount_unit is
  'g (grams; ml is treated as g) or unit (the food''s unit_grams). unit is allowed only for foods that have a unit; a trigger checks it.';
comment on column public.meal_option_items.created_at is 'When the row was created.';
comment on column public.meal_option_items.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index meal_option_items_trainer_id_idx on public.meal_option_items (trainer_id);
create index meal_option_items_athlete_id_idx on public.meal_option_items (athlete_id);
create index meal_option_items_meal_option_id_athlete_id_trainer_id_idx
  on public.meal_option_items (meal_option_id, athlete_id, trainer_id);
create index meal_option_items_food_id_trainer_id_idx
  on public.meal_option_items (food_id, trainer_id);

alter table public.meal_option_items enable row level security;

create trigger set_updated_at
  before insert or update on public.meal_option_items
  for each row execute function private.set_updated_at();

revoke all on table public.meal_option_items from anon, authenticated;
grant select, insert, update, delete on table public.meal_option_items to authenticated;

create policy "athletes read own meal option items"
  on public.meal_option_items for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read their active athletes' meal option items"
  on public.meal_option_items for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers create their active athletes' meal option items"
  on public.meal_option_items for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers update their active athletes' meal option items"
  on public.meal_option_items for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  )
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers delete their active athletes' meal option items"
  on public.meal_option_items for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

-- ===========================================================================
-- macro_targets
-- ===========================================================================

create table public.macro_targets (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  athlete_id uuid not null,
  effective_on date not null,
  day_type text not null,
  protein_g numeric(6, 2) not null,
  carbs_g numeric(6, 2) not null,
  fat_g numeric(6, 2) not null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint macro_targets_pkey primary key (id),
  constraint macro_targets_athlete_id_effective_on_day_type_key
    unique (athlete_id, effective_on, day_type),
  constraint macro_targets_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint macro_targets_athlete_id_fkey
    foreign key (athlete_id) references public.profiles (id) on delete cascade,
  constraint macro_targets_day_type_check check (day_type in ('training', 'rest')),
  constraint macro_targets_protein_g_check check (protein_g >= 0),
  constraint macro_targets_carbs_g_check check (carbs_g >= 0),
  constraint macro_targets_fat_g_check check (fat_g >= 0)
);

comment on table public.macro_targets is
  'An athlete''s daily macro targets, with history (D9): one row per effective date and day type. The current target of a day type is the latest row with effective_on ≤ today. kcal is never stored (4P + 4C + 9F).';
comment on column public.macro_targets.id is 'Primary key.';
comment on column public.macro_targets.trainer_id is 'The trainer who set this target.';
comment on column public.macro_targets.athlete_id is 'The athlete the target is for.';
comment on column public.macro_targets.effective_on is 'First day the target applies.';
comment on column public.macro_targets.day_type is 'training or rest.';
comment on column public.macro_targets.protein_g is 'Daily protein target, in grams.';
comment on column public.macro_targets.carbs_g is 'Daily carbohydrate target, in grams.';
comment on column public.macro_targets.fat_g is 'Daily fat target, in grams.';
comment on column public.macro_targets.note is
  'Free-text note on the change, e.g. "superávit → déficit".';
comment on column public.macro_targets.created_at is 'When the row was created.';
comment on column public.macro_targets.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

-- The athlete_id FK is served by the unique (athlete_id, effective_on,
-- day_type) index, which leads with athlete_id.
create index macro_targets_trainer_id_idx on public.macro_targets (trainer_id);

alter table public.macro_targets enable row level security;

create trigger set_updated_at
  before insert or update on public.macro_targets
  for each row execute function private.set_updated_at();

revoke all on table public.macro_targets from anon, authenticated;
grant select, insert, update, delete on table public.macro_targets to authenticated;

create policy "athletes read own macro targets"
  on public.macro_targets for select to authenticated
  using (athlete_id = (select auth.uid()));

create policy "trainers read their active athletes' macro targets"
  on public.macro_targets for select to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers create their active athletes' macro targets"
  on public.macro_targets for insert to authenticated
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers update their active athletes' macro targets"
  on public.macro_targets for update to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  )
  with check (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

create policy "trainers delete their active athletes' macro targets"
  on public.macro_targets for delete to authenticated
  using (
    trainer_id = (select auth.uid())
    and athlete_id in (select private.trainer_athlete_ids())
  );

-- ===========================================================================
-- Unit triggers (D8): amount_unit 'unit' only for foods that have a unit
--
-- A check constraint can't read another table, so two triggers keep the rule
-- from both sides. Both raise check_violation (23514) with a stable code as
-- the message, like public.accept_invitation():
--   food_has_no_unit   an item in 'unit' for a food without unit_grams;
--   food_unit_in_use   removing unit_grams from a food an item uses in 'unit'.
--
-- Security definer: the rule must hold whoever writes. The trainer who edits
-- a food cannot read the items of a former athlete's plan through RLS, and
-- they still count.
-- ===========================================================================

create function private.check_meal_option_item_unit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  food_unit_grams numeric;
begin
  if new.amount_unit = 'unit' then
    -- "for share" makes a concurrent update of the food wait for this
    -- transaction, so the two triggers cannot miss each other. A food that
    -- does not exist is left to the foreign key.
    select f.unit_grams
    into food_unit_grams
    from public.foods f
    where f.id = new.food_id
    for share;

    if found and food_unit_grams is null then
      raise exception 'food_has_no_unit' using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

comment on function private.check_meal_option_item_unit() is
  'Trigger function on meal_option_items: rejects amount_unit ''unit'' for a food without unit_grams (message food_has_no_unit).';

revoke all on function private.check_meal_option_item_unit() from public, anon, authenticated;

create trigger check_unit
  before insert or update of food_id, amount_unit on public.meal_option_items
  for each row execute function private.check_meal_option_item_unit();

create function private.check_food_unit_in_use()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.meal_option_items i
    where i.food_id = new.id
      and i.amount_unit = 'unit'
  ) then
    raise exception 'food_unit_in_use' using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function private.check_food_unit_in_use() is
  'Trigger function on foods: rejects removing unit_grams while a meal option item uses the food in ''unit'' (message food_unit_in_use).';

revoke all on function private.check_food_unit_in_use() from public, anon, authenticated;

create trigger check_unit_in_use
  before update on public.foods
  for each row
  when (old.unit_grams is not null and new.unit_grams is null)
  execute function private.check_food_unit_in_use();

-- ===========================================================================
-- Libraries: foods used in the athlete's own plans (docs/schema-v1.md §5, D2)
--
-- Same pattern as the exercises policy of the training plans migration: a
-- former athlete still reads the names and macros of the foods of his old
-- plans. The subquery runs as the caller, once per query.
-- ===========================================================================

create policy "athletes read foods used in their own plans"
  on public.foods for select to authenticated
  using (
    id in (
      select i.food_id
      from public.meal_option_items i
      where i.athlete_id = (select auth.uid())
    )
  );

-- ===========================================================================
-- food_swaps: an index with exactly the columns of its from_food FK
--
-- The unique (from_food_id, to_food_id) index already serves these lookups,
-- but the Supabase advisor (unindexed_foreign_keys, reported after the hosted
-- push) only accepts an index that starts with all the FK's columns.
-- ===========================================================================

create index food_swaps_from_food_id_trainer_id_idx
  on public.food_swaps (from_food_id, trainer_id);
