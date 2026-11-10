-- Group 3 (docs/schema-v1.md §7): the trainer libraries — movement_categories,
-- exercises, foods, food_swaps — with RLS, policies and grants.
--
-- Every library table:
--   * belongs to a trainer (trainer_id → trainers, on delete restrict: a
--     trainer's library can't disappear with his user);
--   * has archived_at (rows are archived, not hard-deleted, once used);
--   * has unique (id, trainer_id), the target of composite FKs, so a row can
--     only be referenced together with its own trainer (D3). FK checks ignore
--     RLS; the composite FK is what stops a row from pointing at another
--     trainer's data.
--
-- Policies are the same on all four tables:
--   * the trainer has all operations on his own rows;
--   * an athlete reads the library of his active trainer.
-- The "rows used in his own plans" policies (former athletes) come with the
-- plan tables in step 2b-2.

-- ===========================================================================
-- movement_categories
-- ===========================================================================

create table public.movement_categories (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  name text not null,
  position smallint not null default 0,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint movement_categories_pkey primary key (id),
  constraint movement_categories_id_trainer_id_key unique (id, trainer_id),
  constraint movement_categories_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict
);

comment on table public.movement_categories is
  'A trainer''s fixed list of movement categories (Empuje inclinado, Tracción vertical…). Muscle weights attach here later, for volume analytics.';
comment on column public.movement_categories.id is 'Primary key.';
comment on column public.movement_categories.trainer_id is 'The trainer who owns this category.';
comment on column public.movement_categories.name is
  'Category name. Unique per trainer among non-archived rows, ignoring case.';
comment on column public.movement_categories.position is 'Display order within the trainer''s list.';
comment on column public.movement_categories.archived_at is
  'When the category was archived. Null means it is in use.';
comment on column public.movement_categories.created_at is 'When the row was created.';
comment on column public.movement_categories.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create unique index movement_categories_trainer_id_name_active_idx
  on public.movement_categories (trainer_id, lower(name))
  where archived_at is null;

create index movement_categories_trainer_id_idx on public.movement_categories (trainer_id);

alter table public.movement_categories enable row level security;

create trigger set_updated_at
  before insert or update on public.movement_categories
  for each row execute function private.set_updated_at();

revoke all on table public.movement_categories from anon, authenticated;
grant select, insert, update, delete on table public.movement_categories to authenticated;

create policy "trainers manage their own movement categories"
  on public.movement_categories for all to authenticated
  using (trainer_id = (select auth.uid()))
  with check (trainer_id = (select auth.uid()));

create policy "athletes read their active trainer's movement categories"
  on public.movement_categories for select to authenticated
  using (private.is_athlete_of(trainer_id));

-- ===========================================================================
-- exercises
-- ===========================================================================

create table public.exercises (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  name text not null,
  movement_category_id uuid,
  technique_notes text,
  video_url text,
  source text not null default 'manual',
  source_ref text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercises_pkey primary key (id),
  constraint exercises_id_trainer_id_key unique (id, trainer_id),
  constraint exercises_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  -- Composite: the category must belong to the same trainer. With the default
  -- MATCH SIMPLE the check is skipped when movement_category_id is null.
  constraint exercises_movement_category_id_trainer_id_fkey
    foreign key (movement_category_id, trainer_id)
    references public.movement_categories (id, trainer_id) on delete restrict,
  constraint exercises_source_check check (source in ('manual', 'sheet_import'))
);

comment on table public.exercises is
  'A trainer''s exercise library. Plans reference it with (exercise_id, trainer_id).';
comment on column public.exercises.id is 'Primary key.';
comment on column public.exercises.trainer_id is 'The trainer who owns this exercise.';
comment on column public.exercises.name is
  'Exercise name. Unique per trainer among non-archived rows, ignoring case.';
comment on column public.exercises.movement_category_id is
  'Movement category of the same trainer. Null if uncategorised.';
comment on column public.exercises.technique_notes is
  'How to perform the exercise; shown wherever the exercise appears.';
comment on column public.exercises.video_url is 'Link to a demonstration video.';
comment on column public.exercises.source is
  'Where the row came from: manual or sheet_import.';
comment on column public.exercises.source_ref is
  'Reference in the source, e.g. sheet and row. Null for manual rows.';
comment on column public.exercises.archived_at is
  'When the exercise was archived. Null means it is in use.';
comment on column public.exercises.created_at is 'When the row was created.';
comment on column public.exercises.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create unique index exercises_trainer_id_name_active_idx
  on public.exercises (trainer_id, lower(name))
  where archived_at is null;

create index exercises_trainer_id_idx on public.exercises (trainer_id);
create index exercises_movement_category_id_trainer_id_idx
  on public.exercises (movement_category_id, trainer_id);

alter table public.exercises enable row level security;

create trigger set_updated_at
  before insert or update on public.exercises
  for each row execute function private.set_updated_at();

revoke all on table public.exercises from anon, authenticated;
grant select, insert, update, delete on table public.exercises to authenticated;

create policy "trainers manage their own exercises"
  on public.exercises for all to authenticated
  using (trainer_id = (select auth.uid()))
  with check (trainer_id = (select auth.uid()));

create policy "athletes read their active trainer's exercises"
  on public.exercises for select to authenticated
  using (private.is_athlete_of(trainer_id));

-- ===========================================================================
-- foods
-- ===========================================================================

create table public.foods (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  name text not null,
  brand text,
  protein_g numeric(5, 2) not null,
  carbs_g numeric(5, 2) not null,
  fat_g numeric(5, 2) not null,
  unit_name text,
  unit_grams numeric(7, 2),
  source text not null default 'manual',
  source_ref text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint foods_pkey primary key (id),
  constraint foods_id_trainer_id_key unique (id, trainer_id),
  constraint foods_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  constraint foods_protein_g_check check (protein_g between 0 and 100),
  constraint foods_carbs_g_check check (carbs_g between 0 and 100),
  constraint foods_fat_g_check check (fat_g between 0 and 100),
  constraint foods_unit_together_check check ((unit_name is null) = (unit_grams is null)),
  constraint foods_unit_grams_check check (unit_grams > 0),
  constraint foods_source_check check (source in ('manual', 'sheet_import'))
);

comment on table public.foods is
  'A trainer''s food library: macros per 100 g of raw food, with an optional unit (D8). kcal is never stored (4P + 4C + 9F). Plans reference it with (food_id, trainer_id).';
comment on column public.foods.id is 'Primary key.';
comment on column public.foods.trainer_id is 'The trainer who owns this food.';
comment on column public.foods.name is 'Food name.';
comment on column public.foods.brand is 'Brand, if it matters.';
comment on column public.foods.protein_g is 'Grams of protein per 100 g (ml is treated as g).';
comment on column public.foods.carbs_g is 'Grams of carbohydrate per 100 g (ml is treated as g).';
comment on column public.foods.fat_g is 'Grams of fat per 100 g (ml is treated as g).';
comment on column public.foods.unit_name is
  'Name of the optional unit, e.g. "huevo L". Set together with unit_grams.';
comment on column public.foods.unit_grams is
  'Weight of one unit in grams. Set together with unit_name.';
comment on column public.foods.source is
  'Where the row came from: manual or sheet_import.';
comment on column public.foods.source_ref is
  'Reference in the source, e.g. sheet and row. Null for manual rows.';
comment on column public.foods.archived_at is
  'When the food was archived. Null means it is in use.';
comment on column public.foods.created_at is 'When the row was created.';
comment on column public.foods.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

create index foods_trainer_id_idx on public.foods (trainer_id);

alter table public.foods enable row level security;

create trigger set_updated_at
  before insert or update on public.foods
  for each row execute function private.set_updated_at();

revoke all on table public.foods from anon, authenticated;
grant select, insert, update, delete on table public.foods to authenticated;

create policy "trainers manage their own foods"
  on public.foods for all to authenticated
  using (trainer_id = (select auth.uid()))
  with check (trainer_id = (select auth.uid()));

create policy "athletes read their active trainer's foods"
  on public.foods for select to authenticated
  using (private.is_athlete_of(trainer_id));

-- ===========================================================================
-- food_swaps
-- ===========================================================================

create table public.food_swaps (
  id uuid not null default gen_random_uuid(),
  trainer_id uuid not null,
  nutrient_group text not null,
  from_food_id uuid not null,
  to_food_id uuid not null,
  factor numeric(6, 3) not null,
  note text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_swaps_pkey primary key (id),
  constraint food_swaps_id_trainer_id_key unique (id, trainer_id),
  constraint food_swaps_from_food_id_to_food_id_key unique (from_food_id, to_food_id),
  constraint food_swaps_trainer_id_fkey
    foreign key (trainer_id) references public.trainers (profile_id) on delete restrict,
  -- Composite: both foods must belong to the same trainer as the swap.
  -- On delete restrict (decided 2026-11-10): a food can't be deleted while a
  -- swap mentions it, so no hand-tuned factor is lost silently.
  constraint food_swaps_from_food_id_trainer_id_fkey
    foreign key (from_food_id, trainer_id)
    references public.foods (id, trainer_id) on delete restrict,
  constraint food_swaps_to_food_id_trainer_id_fkey
    foreign key (to_food_id, trainer_id)
    references public.foods (id, trainer_id) on delete restrict,
  constraint food_swaps_nutrient_group_check check (nutrient_group in ('carbs', 'protein', 'fat')),
  constraint food_swaps_different_foods_check check (from_food_id <> to_food_id),
  constraint food_swaps_factor_check check (factor > 0)
);

comment on table public.food_swaps is
  'A trainer''s swap table, shared by all his athletes (D10). Directed: from → to × factor does not imply the reverse. No chaining.';
comment on column public.food_swaps.id is 'Primary key.';
comment on column public.food_swaps.trainer_id is 'The trainer who owns this swap.';
comment on column public.food_swaps.nutrient_group is
  'Group the swap belongs to: carbs, protein or fat.';
comment on column public.food_swaps.from_food_id is 'Food being replaced (same trainer).';
comment on column public.food_swaps.to_food_id is 'Food replacing it (same trainer, a different food).';
comment on column public.food_swaps.factor is
  'Multiplier applied to the grams of the original food. 1 means equivalent.';
comment on column public.food_swaps.note is 'Free-text note from the trainer.';
comment on column public.food_swaps.archived_at is
  'When the swap was archived. Null means it is in use.';
comment on column public.food_swaps.created_at is 'When the row was created.';
comment on column public.food_swaps.updated_at is
  'When the row was last written. Set by the set_updated_at trigger, never by the client.';

-- (from_food_id, trainer_id) lookups are served by the unique
-- (from_food_id, to_food_id) index, which leads with from_food_id.
create index food_swaps_trainer_id_idx on public.food_swaps (trainer_id);
create index food_swaps_to_food_id_trainer_id_idx on public.food_swaps (to_food_id, trainer_id);

alter table public.food_swaps enable row level security;

create trigger set_updated_at
  before insert or update on public.food_swaps
  for each row execute function private.set_updated_at();

revoke all on table public.food_swaps from anon, authenticated;
grant select, insert, update, delete on table public.food_swaps to authenticated;

create policy "trainers manage their own food swaps"
  on public.food_swaps for all to authenticated
  using (trainer_id = (select auth.uid()))
  with check (trainer_id = (select auth.uid()));

create policy "athletes read their active trainer's food swaps"
  on public.food_swaps for select to authenticated
  using (private.is_athlete_of(trainer_id));
