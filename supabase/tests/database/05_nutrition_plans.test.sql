-- Nutrition plans: meal_plans, meals, meal_options, meal_option_items, macro_targets,
-- the unit triggers and the foods "used in own plans" policy
-- (docs/schema-v1.md §4, §5, §6).
-- Fixtures (supabase/seed.sql): t1 (self-linked trainer) with a1, a2; t2 with b1;
-- x former athlete of t1; u with no links.
--
-- Row ids are fixed. The last four digits are <table><tree>:
--   table  11 meal_plans · 12 meals · 13 meal_options · 14 meal_option_items
--          15 macro_targets
--   tree   …02 A1 (by T1)         …03 A2 (by T1)      …04 X (by T1, old)
--          …05 T1 as his own athlete                  …07 B1 (by T2)
--          …08 B1 (by T1, old: written when B1 trained with T1)
--   A second row of the same table and tree has the third digit raised:
--   …1412 is A1's second item.
-- Foods of T1: …f1 Arroz · …f3 Pasta · …f4 Huevo (unit) · …f6 Yogur (unit)
--              …f7 Pan (unit, in no plan). Food of T2: …f2 Avena (unit).

begin;

select plan(86);

-- ---------------------------------------------------------------------------
-- Rows T1 does not create himself (as postgres; rolled back at the end)
-- ---------------------------------------------------------------------------

insert into public.foods (id, trainer_id, name, protein_g, carbs_g, fat_g, unit_name, unit_grams)
values
  ('00000000-0000-0000-0000-0000000000f1', tests.user_id('t1'), 'Arroz', 7, 78, 0.6, null, null),
  ('00000000-0000-0000-0000-0000000000f3', tests.user_id('t1'), 'Pasta', 12, 72, 1.5, null, null),
  ('00000000-0000-0000-0000-0000000000f4', tests.user_id('t1'), 'Huevo', 12.5, 0.7, 9.7, 'huevo L', 60),
  ('00000000-0000-0000-0000-0000000000f6', tests.user_id('t1'), 'Yogur', 4, 5, 3, 'unidad', 125),
  ('00000000-0000-0000-0000-0000000000f7', tests.user_id('t1'), 'Pan', 9, 50, 3, 'rebanada', 30),
  ('00000000-0000-0000-0000-0000000000f2', tests.user_id('t2'), 'Avena', 13.5, 58.7, 7, 'cucharada', 10);

insert into public.meal_plans (id, trainer_id, athlete_id, name, status)
values
  ('00000000-0000-0000-0000-000000001103', tests.user_id('t1'), tests.user_id('a2'), 'Volumen de A2', 'active'),
  ('00000000-0000-0000-0000-000000001104', tests.user_id('t1'), tests.user_id('x'), 'Plan antiguo de X', 'archived'),
  ('00000000-0000-0000-0000-000000001107', tests.user_id('t2'), tests.user_id('b1'), 'Plan de B1', 'active'),
  ('00000000-0000-0000-0000-000000001108', tests.user_id('t1'), tests.user_id('b1'), 'Plan antiguo de B1 con T1', 'archived');

insert into public.meals (
  id, trainer_id, athlete_id, meal_plan_id, name, position,
  target_protein_g, target_carbs_g, target_fat_g
)
values
  ('00000000-0000-0000-0000-000000001203', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000001103', 'Comida', 1, 40, 80, 15),
  ('00000000-0000-0000-0000-000000001204', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000001104', 'Comida', 1, 40, 80, 15),
  ('00000000-0000-0000-0000-000000001207', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001107', 'Comida', 1, 40, 80, 15),
  ('00000000-0000-0000-0000-000000001208', tests.user_id('t1'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001108', 'Comida', 1, 40, 80, 15);

insert into public.meal_options (id, trainer_id, athlete_id, meal_id, position)
values
  ('00000000-0000-0000-0000-000000001303', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000001203', 1),
  ('00000000-0000-0000-0000-000000001304', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000001204', 1),
  ('00000000-0000-0000-0000-000000001307', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001207', 1);

-- X's old plan uses Arroz in grams and Huevo in units.
insert into public.meal_option_items (
  id, trainer_id, athlete_id, meal_option_id, food_id, position, amount, amount_unit
)
values
  ('00000000-0000-0000-0000-000000001403', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000001303', '00000000-0000-0000-0000-0000000000f3', 1, 120, 'g'),
  ('00000000-0000-0000-0000-000000001404', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000001304', '00000000-0000-0000-0000-0000000000f1', 1, 100, 'g'),
  ('00000000-0000-0000-0000-000000001414', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000001304', '00000000-0000-0000-0000-0000000000f4', 2, 2, 'unit'),
  ('00000000-0000-0000-0000-000000001407', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001307', '00000000-0000-0000-0000-0000000000f2', 1, 6, 'unit');

insert into public.macro_targets (
  id, trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g
)
values
  ('00000000-0000-0000-0000-000000001503', tests.user_id('t1'), tests.user_id('a2'), '2026-11-02', 'training', 160, 400, 70),
  ('00000000-0000-0000-0000-000000001504', tests.user_id('t1'), tests.user_id('x'), '2026-09-07', 'training', 150, 300, 60),
  ('00000000-0000-0000-0000-000000001507', tests.user_id('t2'), tests.user_id('b1'), '2026-11-02', 'rest', 120, 200, 55),
  ('00000000-0000-0000-0000-000000001508', tests.user_id('t1'), tests.user_id('b1'), '2026-09-07', 'rest', 120, 200, 55);

-- ---------------------------------------------------------------------------
-- T1 builds A1's meal plan and his own
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('t1'));

select lives_ok(
  $$ insert into public.meal_plans (id, trainer_id, athlete_id, name, status, guidelines, copied_from_id)
     values ('00000000-0000-0000-0000-000000001102', tests.user_id('t1'), tests.user_id('a1'),
             'Volumen', 'active', 'Pesa la comida en crudo',
             '00000000-0000-0000-0000-000000001103') $$,
  'T1 can create an active meal plan for A1, duplicated from A2''s'
);

select lives_ok(
  $$ insert into public.meals (
       id, trainer_id, athlete_id, meal_plan_id, name, position, day_type,
       target_protein_g, target_carbs_g, target_fat_g
     )
     values
       ('00000000-0000-0000-0000-000000001202', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000001102', 'Desayuno', 1, 'all', 30, 60.5, 15),
       ('00000000-0000-0000-0000-000000001212', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000001102', 'Intraentreno', 2, 'training', 0, 40, 0) $$,
  'T1 can add meals to A1''s plan, one of them for training days only'
);

select lives_ok(
  $$ insert into public.meal_options (id, trainer_id, athlete_id, meal_id, position, label)
     values ('00000000-0000-0000-0000-000000001302', tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001202', 1, 'Salado') $$,
  'T1 can add an option to A1''s meal'
);

select lives_ok(
  $$ insert into public.meal_option_items (
       id, trainer_id, athlete_id, meal_option_id, food_id, position, amount, amount_unit
     )
     values
       ('00000000-0000-0000-0000-000000001402', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f1', 1, 80, 'g'),
       ('00000000-0000-0000-0000-000000001412', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f4', 2, 1.5, 'unit'),
       ('00000000-0000-0000-0000-000000001422', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f6', 3, 250, 'g') $$,
  'T1 can add items in grams, and in units for a food that has a unit'
);

select lives_ok(
  $$ insert into public.macro_targets (
       id, trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g, note
     )
     values
       ('00000000-0000-0000-0000-000000001502', tests.user_id('t1'), tests.user_id('a1'),
        '2026-11-02', 'training', 170, 450.5, 75, 'superávit'),
       ('00000000-0000-0000-0000-000000001512', tests.user_id('t1'), tests.user_id('a1'),
        '2026-11-02', 'rest', 170, 350, 75, 'superávit') $$,
  'T1 can set A1''s training and rest targets for the same date'
);

select lives_ok(
  $$ insert into public.meal_plans (id, trainer_id, athlete_id, name)
     values ('00000000-0000-0000-0000-000000001105', tests.user_id('t1'), tests.user_id('t1'),
             'Plan propio') $$,
  'T1 can create a meal plan for himself (self-link)'
);

select results_eq(
  $$ select status from public.meal_plans where id = '00000000-0000-0000-0000-000000001105' $$,
  $$ values ('draft'::text) $$,
  'a new meal plan defaults to draft'
);

select isnt_empty(
  $$ update public.meals set target_carbs_g = 65
     where id = '00000000-0000-0000-0000-000000001202' returning id $$,
  'T1 can update a meal of A1''s plan'
);

-- T1 reads his active athletes' plans, nothing else ----------------------------

select set_eq(
  'select id from public.meal_plans',
  array[
    '00000000-0000-0000-0000-000000001102'::uuid,
    '00000000-0000-0000-0000-000000001103'::uuid,
    '00000000-0000-0000-0000-000000001105'::uuid
  ],
  'T1 sees A1''s, A2''s and his own meal plan: not X''s, and not B1''s (not even the one that carries his trainer_id)'
);

select set_eq(
  $$ select id from public.meals
     union all select id from public.meal_options
     union all select id from public.meal_option_items
     union all select id from public.macro_targets $$,
  array[
    '00000000-0000-0000-0000-000000001202'::uuid,
    '00000000-0000-0000-0000-000000001212'::uuid,
    '00000000-0000-0000-0000-000000001203'::uuid,
    '00000000-0000-0000-0000-000000001302'::uuid,
    '00000000-0000-0000-0000-000000001303'::uuid,
    '00000000-0000-0000-0000-000000001402'::uuid,
    '00000000-0000-0000-0000-000000001412'::uuid,
    '00000000-0000-0000-0000-000000001422'::uuid,
    '00000000-0000-0000-0000-000000001403'::uuid,
    '00000000-0000-0000-0000-000000001502'::uuid,
    '00000000-0000-0000-0000-000000001512'::uuid,
    '00000000-0000-0000-0000-000000001503'::uuid
  ],
  'T1 sees the meals, options, items and macro targets of those athletes only'
);

-- T1 cannot write plans for B1, for X or in T2's name --------------------------

select throws_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name)
     values (tests.user_id('t1'), tests.user_id('b1'), 'Intruso') $$,
  '42501', 'new row violates row-level security policy for table "meal_plans"',
  'T1 cannot create a meal plan for B1, who is not his athlete'
);

select throws_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name)
     values (tests.user_id('t2'), tests.user_id('b1'), 'Intruso') $$,
  '42501', 'new row violates row-level security policy for table "meal_plans"',
  'T1 cannot create a meal plan for B1 in T2''s name'
);

select throws_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name)
     values (tests.user_id('t1'), tests.user_id('x'), 'Vuelta') $$,
  '42501', 'new row violates row-level security policy for table "meal_plans"',
  'T1 cannot create a meal plan for X, whose link ended'
);

select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t1'), tests.user_id('x'),
             '00000000-0000-0000-0000-000000001104', 'Cena', 30, 40, 10) $$,
  '42501', 'new row violates row-level security policy for table "meals"',
  'T1 cannot add a meal to X''s old plan'
);

select throws_ok(
  $$ insert into public.macro_targets (trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g)
     values
       (tests.user_id('t1'), tests.user_id('x'), '2026-11-16', 'training', 150, 300, 60) $$,
  '42501', 'new row violates row-level security policy for table "macro_targets"',
  'T1 cannot set a macro target for X'
);

select throws_ok(
  $$ insert into public.macro_targets (trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g)
     values
       (tests.user_id('t1'), tests.user_id('b1'), '2026-11-16', 'training', 150, 300, 60) $$,
  '42501', 'new row violates row-level security policy for table "macro_targets"',
  'T1 cannot set a macro target for B1'
);

select throws_ok(
  $$ insert into public.meal_options (trainer_id, athlete_id, meal_id)
     values (tests.user_id('t1'), tests.user_id('x'), '00000000-0000-0000-0000-000000001204') $$,
  '42501', 'new row violates row-level security policy for table "meal_options"',
  'T1 cannot add an option to X''s old meal'
);

select throws_ok(
  $$ insert into public.meal_option_items (trainer_id, athlete_id, meal_option_id, food_id, amount)
     values (tests.user_id('t1'), tests.user_id('x'),
             '00000000-0000-0000-0000-000000001304', '00000000-0000-0000-0000-0000000000f3', 50) $$,
  '42501', 'new row violates row-level security policy for table "meal_option_items"',
  'T1 cannot add an item to X''s old option'
);

select throws_ok(
  $$ update public.meal_plans set athlete_id = tests.user_id('x')
     where id = '00000000-0000-0000-0000-000000001105' $$,
  '42501', 'new row violates row-level security policy for table "meal_plans"',
  'T1 cannot hand one of his meal plans over to X'
);

-- macro_targets has no parent row: only the policy stops this.
select throws_ok(
  $$ update public.macro_targets set athlete_id = tests.user_id('x')
     where id = '00000000-0000-0000-0000-000000001502' $$,
  '42501', 'new row violates row-level security policy for table "macro_targets"',
  'T1 cannot move one of A1''s macro targets to X'
);

select is_empty(
  $$ with p as (
       update public.meal_plans set name = 'Hacked'
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     m as (
       update public.meals set name = 'Hacked'
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     o as (
       update public.meal_options set label = 'Hacked'
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     i as (
       update public.meal_option_items set amount = 999
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     t as (
       update public.macro_targets set note = 'Hacked'
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     )
     select id from p union all select id from m union all select id from o
     union all select id from i union all select id from t $$,
  'T1 cannot update any row of X''s or B1''s nutrition (no row is updated)'
);

select is_empty(
  $$ with i as (
       delete from public.meal_option_items
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     o as (
       delete from public.meal_options
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     m as (
       delete from public.meals
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     p as (
       delete from public.meal_plans
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     t as (
       delete from public.macro_targets
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     )
     select id from p union all select id from m union all select id from o
     union all select id from i union all select id from t $$,
  'T1 cannot delete any row of X''s or B1''s nutrition (no row is deleted)'
);

select throws_ok(
  $$ update public.meal_plans set trainer_id = tests.user_id('t2')
     where id = '00000000-0000-0000-0000-000000001105' $$,
  '42501', 'new row violates row-level security policy for table "meal_plans"',
  'T1 cannot hand one of his meal plans over to T2'
);

-- Composite FKs: what a plan row may point at ----------------------------------

select throws_ok(
  $$ insert into public.meal_option_items (trainer_id, athlete_id, meal_option_id, food_id, amount)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f2', 50) $$,
  '23503',
  'insert or update on table "meal_option_items" violates foreign key constraint "meal_option_items_food_id_trainer_id_fkey"',
  'T1 cannot use T2''s food in his plan'
);

select throws_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name, copied_from_id)
     values (tests.user_id('t1'), tests.user_id('a1'), 'Copia ajena',
             '00000000-0000-0000-0000-000000001107') $$,
  '23503',
  'insert or update on table "meal_plans" violates foreign key constraint "meal_plans_copied_from_id_trainer_id_fkey"',
  'copied_from_id cannot point at T2''s meal plan'
);

select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001103', 'Comida cruzada', 30, 40, 10) $$,
  '23503',
  'insert or update on table "meals" violates foreign key constraint "meals_meal_plan_id_athlete_id_trainer_id_fkey"',
  'A1''s meal under A2''s meal plan is rejected'
);

select throws_ok(
  $$ insert into public.meal_options (trainer_id, athlete_id, meal_id)
     values (tests.user_id('t1'), tests.user_id('a1'), '00000000-0000-0000-0000-000000001203') $$,
  '23503',
  'insert or update on table "meal_options" violates foreign key constraint "meal_options_meal_id_athlete_id_trainer_id_fkey"',
  'A1''s option under A2''s meal is rejected'
);

select throws_ok(
  $$ insert into public.meal_option_items (trainer_id, athlete_id, meal_option_id, food_id, amount)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001303', '00000000-0000-0000-0000-0000000000f1', 50) $$,
  '23503',
  'insert or update on table "meal_option_items" violates foreign key constraint "meal_option_items_meal_option_id_athlete_id_trainer_id_fkey"',
  'A1''s item under A2''s option is rejected'
);

-- A plan cannot be moved to another athlete: its meals still point at
-- (meal plan, athlete, trainer). T1 is his own athlete, so the policy lets it through.
select throws_ok(
  $$ update public.meal_plans set athlete_id = tests.user_id('t1'), status = 'draft'
     where id = '00000000-0000-0000-0000-000000001102' $$,
  '23503',
  'update or delete on table "meal_plans" violates foreign key constraint "meals_meal_plan_id_athlete_id_trainer_id_fkey" on table "meals"',
  'A1''s meal plan cannot be moved to another athlete by editing athlete_id'
);

-- Unit trigger on meal_option_items ---------------------------------------------

select throws_ok(
  $$ insert into public.meal_option_items (trainer_id, athlete_id, meal_option_id, food_id, amount, amount_unit)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f3', 2, 'unit') $$,
  '23514', 'food_has_no_unit',
  'an item in units for a food without unit_grams is rejected'
);

select throws_ok(
  $$ update public.meal_option_items set amount_unit = 'unit'
     where id = '00000000-0000-0000-0000-000000001402' $$,
  '23514', 'food_has_no_unit',
  'switching an item to units is rejected when its food has no unit_grams'
);

select throws_ok(
  $$ update public.meal_option_items set food_id = '00000000-0000-0000-0000-0000000000f3'
     where id = '00000000-0000-0000-0000-000000001412' $$,
  '23514', 'food_has_no_unit',
  'pointing an item in units at a food without unit_grams is rejected'
);

select lives_ok(
  $$ update public.meal_option_items set amount_unit = 'unit', amount = 2
     where id = '00000000-0000-0000-0000-000000001422' $$,
  'switching an item to units is accepted when its food has unit_grams'
);

select lives_ok(
  $$ update public.meal_option_items set amount_unit = 'g', amount = 250
     where id = '00000000-0000-0000-0000-000000001422' $$,
  'an item can go back to grams'
);

-- A food that does not exist is left to the foreign key, in units too.
select throws_ok(
  $$ insert into public.meal_option_items (trainer_id, athlete_id, meal_option_id, food_id, amount, amount_unit)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000ff', 2, 'unit') $$,
  '23503',
  'insert or update on table "meal_option_items" violates foreign key constraint "meal_option_items_food_id_trainer_id_fkey"',
  'an item in units for a food that does not exist is rejected by the foreign key'
);

-- Unit trigger on foods -----------------------------------------------------------

select throws_ok(
  $$ update public.foods set unit_name = null, unit_grams = null
     where id = '00000000-0000-0000-0000-0000000000f4' $$,
  '23514', 'food_unit_in_use',
  'removing the unit of a food is rejected while an item uses it in units'
);

-- Pan (…f7) is used in units only by a plan T1 cannot read: X's.
select tests.clear_authentication();

insert into public.meal_option_items (
  id, trainer_id, athlete_id, meal_option_id, food_id, position, amount, amount_unit
)
values (
  '00000000-0000-0000-0000-000000001424', tests.user_id('t1'), tests.user_id('x'),
  '00000000-0000-0000-0000-000000001304', '00000000-0000-0000-0000-0000000000f7', 3, 2, 'unit'
);

select tests.authenticate_as(tests.user_id('t1'));

select throws_ok(
  $$ update public.foods set unit_name = null, unit_grams = null
     where id = '00000000-0000-0000-0000-0000000000f7' $$,
  '23514', 'food_unit_in_use',
  'removing the unit is rejected even when the only item in units is in a former athlete''s plan'
);

select lives_ok(
  $$ update public.foods set unit_grams = 55 where id = '00000000-0000-0000-0000-0000000000f4' $$,
  'changing unit_grams to another value is accepted while items use the unit'
);

select lives_ok(
  $$ update public.foods set unit_name = null, unit_grams = null
     where id = '00000000-0000-0000-0000-0000000000f6' $$,
  'removing the unit of a food is accepted when its items are all in grams'
);

-- Checks ----------------------------------------------------------------------

select throws_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name, status)
     values (tests.user_id('t1'), tests.user_id('a1'), 'Segundo activo', 'active') $$,
  '23505', 'duplicate key value violates unique constraint "meal_plans_one_active_per_athlete_idx"',
  'a second active meal plan for the same athlete is rejected'
);

select lives_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name, status)
     values (tests.user_id('t1'), tests.user_id('t1'), 'Siguiente plan', 'draft') $$,
  'an athlete can have a draft next to other meal plans'
);

select throws_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name, status)
     values (tests.user_id('t1'), tests.user_id('a1'), 'Estado raro', 'paused') $$,
  '23514', 'new row for relation "meal_plans" violates check constraint "meal_plans_status_check"',
  'a status outside draft / active / archived is rejected'
);

select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, day_type,
       target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001102', 'Recarga', 'refeed', 30, 40, 10) $$,
  '23514', 'new row for relation "meals" violates check constraint "meals_day_type_check"',
  'a meal day_type outside all / training / rest is rejected'
);

select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001102', 'Negativa', -1, 40, 10) $$,
  '23514', 'new row for relation "meals" violates check constraint "meals_target_protein_g_check"',
  'a negative protein target on a meal is rejected'
);

select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001102', 'Negativa', 30, -0.5, 10) $$,
  '23514', 'new row for relation "meals" violates check constraint "meals_target_carbs_g_check"',
  'a negative carbs target on a meal is rejected'
);

select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001102', 'Negativa', 30, 40, -10) $$,
  '23514', 'new row for relation "meals" violates check constraint "meals_target_fat_g_check"',
  'a negative fat target on a meal is rejected'
);

select throws_ok(
  $$ insert into public.meal_option_items (trainer_id, athlete_id, meal_option_id, food_id, amount)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f1', 0) $$,
  '23514', 'new row for relation "meal_option_items" violates check constraint "meal_option_items_amount_check"',
  'an item with amount 0 is rejected'
);

select throws_ok(
  $$ insert into public.meal_option_items (trainer_id, athlete_id, meal_option_id, food_id, amount, amount_unit)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f1', 200, 'ml') $$,
  '23514', 'new row for relation "meal_option_items" violates check constraint "meal_option_items_amount_unit_check"',
  'an amount_unit outside g / unit is rejected (ml is entered as g)'
);

select throws_ok(
  $$ insert into public.macro_targets (trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g)
     values (tests.user_id('t1'), tests.user_id('a1'), '2026-11-02', 'training', 180, 500, 80) $$,
  '23505', 'duplicate key value violates unique constraint "macro_targets_athlete_id_effective_on_day_type_key"',
  'a second macro target for the same athlete, date and day type is rejected'
);

select lives_ok(
  $$ insert into public.macro_targets (id, trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g)
     values ('00000000-0000-0000-0000-000000001522', tests.user_id('t1'), tests.user_id('a1'),
             '2026-11-16', 'training', 180, 1050, 80) $$,
  'a later macro target for the same day type is a new row of the history (and a daily target can pass 1000 g)'
);

select throws_ok(
  $$ insert into public.macro_targets (trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g)
     values (tests.user_id('t1'), tests.user_id('a1'), '2026-11-23', 'all', 180, 500, 80) $$,
  '23514', 'new row for relation "macro_targets" violates check constraint "macro_targets_day_type_check"',
  'a macro target day_type outside training / rest is rejected'
);

select throws_ok(
  $$ insert into public.macro_targets (trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g)
     values (tests.user_id('t1'), tests.user_id('a1'), '2026-11-23', 'rest', 180, 500, -1) $$,
  '23514', 'new row for relation "macro_targets" violates check constraint "macro_targets_fat_g_check"',
  'a negative macro target is rejected'
);

-- A used food cannot be deleted (on delete restrict) ----------------------------

select throws_ok(
  $$ delete from public.foods where id = '00000000-0000-0000-0000-0000000000f1' $$,
  '23503',
  'update or delete on table "foods" violates foreign key constraint "meal_option_items_food_id_trainer_id_fkey" on table "meal_option_items"',
  'T1 cannot delete a food a plan uses'
);

-- ---------------------------------------------------------------------------
-- A1: reads his own plan and cannot write any plan row
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('a1'));

select set_eq(
  $$ select id from public.meal_plans
     union all select id from public.meals
     union all select id from public.meal_options
     union all select id from public.meal_option_items
     union all select id from public.macro_targets $$,
  array[
    '00000000-0000-0000-0000-000000001102'::uuid,
    '00000000-0000-0000-0000-000000001202'::uuid,
    '00000000-0000-0000-0000-000000001212'::uuid,
    '00000000-0000-0000-0000-000000001302'::uuid,
    '00000000-0000-0000-0000-000000001402'::uuid,
    '00000000-0000-0000-0000-000000001412'::uuid,
    '00000000-0000-0000-0000-000000001422'::uuid,
    '00000000-0000-0000-0000-000000001502'::uuid,
    '00000000-0000-0000-0000-000000001512'::uuid,
    '00000000-0000-0000-0000-000000001522'::uuid
  ],
  'A1 reads his own meal plan and macro targets only: nothing of A2''s, B1''s, X''s or T1''s own'
);

select throws_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name)
     values (tests.user_id('t1'), tests.user_id('a1'), 'Mi plan') $$,
  '42501', 'new row violates row-level security policy for table "meal_plans"',
  'A1 cannot create a meal plan for himself'
);

select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001102', 'Merienda', 20, 30, 10) $$,
  '42501', 'new row violates row-level security policy for table "meals"',
  'A1 cannot add a meal to his own plan'
);

select throws_ok(
  $$ insert into public.meal_options (trainer_id, athlete_id, meal_id)
     values (tests.user_id('t1'), tests.user_id('a1'), '00000000-0000-0000-0000-000000001202') $$,
  '42501', 'new row violates row-level security policy for table "meal_options"',
  'A1 cannot add an option to his own meal'
);

select throws_ok(
  $$ insert into public.meal_option_items (trainer_id, athlete_id, meal_option_id, food_id, amount)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f1', 50) $$,
  '42501', 'new row violates row-level security policy for table "meal_option_items"',
  'A1 cannot add an item to his own option'
);

select throws_ok(
  $$ insert into public.macro_targets (trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g)
     values (tests.user_id('t1'), tests.user_id('a1'), '2026-11-30', 'rest', 100, 100, 100) $$,
  '42501', 'new row violates row-level security policy for table "macro_targets"',
  'A1 cannot set his own macro target'
);

-- Unlike a template, a nutrition row always has an athlete, so a row in A1's
-- own name as trainer never passes the policy.
select throws_ok(
  $$ insert into public.meal_plans (trainer_id, athlete_id, name)
     values (tests.user_id('a1'), tests.user_id('a1'), 'Plan propio') $$,
  '42501', 'new row violates row-level security policy for table "meal_plans"',
  'A1 cannot create a meal plan as his own trainer'
);

select is_empty(
  $$ with p as (update public.meal_plans set name = 'Hacked' returning id),
          m as (update public.meals set name = 'Hacked' returning id),
          o as (update public.meal_options set label = 'Hacked' returning id),
          i as (update public.meal_option_items set amount = 999 returning id),
          t as (update public.macro_targets set note = 'Hacked' returning id)
     select id from p union all select id from m union all select id from o
     union all select id from i union all select id from t $$,
  'A1 cannot update any nutrition row, his own included (no row is updated)'
);

select is_empty(
  $$ with i as (delete from public.meal_option_items returning id),
          o as (delete from public.meal_options returning id),
          m as (delete from public.meals returning id),
          p as (delete from public.meal_plans returning id),
          t as (delete from public.macro_targets returning id)
     select id from p union all select id from m union all select id from o
     union all select id from i union all select id from t $$,
  'A1 cannot delete any nutrition row, his own included (no row is deleted)'
);

-- ---------------------------------------------------------------------------
-- B1 and T2: the other trainer's side
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('b1'));

select set_eq(
  $$ select id from public.meal_plans
     union all select id from public.meals
     union all select id from public.meal_options
     union all select id from public.meal_option_items
     union all select id from public.macro_targets $$,
  array[
    '00000000-0000-0000-0000-000000001107'::uuid,
    '00000000-0000-0000-0000-000000001207'::uuid,
    '00000000-0000-0000-0000-000000001307'::uuid,
    '00000000-0000-0000-0000-000000001407'::uuid,
    '00000000-0000-0000-0000-000000001507'::uuid,
    '00000000-0000-0000-0000-000000001108'::uuid,
    '00000000-0000-0000-0000-000000001208'::uuid,
    '00000000-0000-0000-0000-000000001508'::uuid
  ],
  'B1 reads his plan and targets from T2 and the old ones from T1: nothing of T1''s athletes'
);

select tests.authenticate_as(tests.user_id('t2'));

select set_eq(
  $$ select id from public.meal_plans
     union all select id from public.meals
     union all select id from public.meal_options
     union all select id from public.meal_option_items
     union all select id from public.macro_targets $$,
  array[
    '00000000-0000-0000-0000-000000001107'::uuid,
    '00000000-0000-0000-0000-000000001207'::uuid,
    '00000000-0000-0000-0000-000000001307'::uuid,
    '00000000-0000-0000-0000-000000001407'::uuid,
    '00000000-0000-0000-0000-000000001507'::uuid
  ],
  'T2 sees B1''s plan and target: nothing of T1''s, not even what T1 wrote for B1'
);

select is_empty(
  $$ update public.meal_plans set name = 'Hacked'
     where trainer_id = tests.user_id('t1') returning id $$,
  'T2 cannot update T1''s meal plans (no row is updated)'
);

-- B1's old plan belongs to T1. The policy stops T2 from writing a row in T1's
-- name; the trainer column of the composite FK stops him from attaching his
-- own row to it.
select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t1'), tests.user_id('b1'),
             '00000000-0000-0000-0000-000000001108', 'Cena', 30, 40, 10) $$,
  '42501', 'new row violates row-level security policy for table "meals"',
  'T2 cannot add a meal in T1''s name to the plan T1 wrote for B1'
);

select throws_ok(
  $$ insert into public.meals (
       trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
     )
     values (tests.user_id('t2'), tests.user_id('b1'),
             '00000000-0000-0000-0000-000000001108', 'Cena', 30, 40, 10) $$,
  '23503',
  'insert or update on table "meals" violates foreign key constraint "meals_meal_plan_id_athlete_id_trainer_id_fkey"',
  'T2 cannot attach his own meal to the plan T1 wrote for B1'
);

-- ---------------------------------------------------------------------------
-- X (former athlete of T1): reads his old plan and the foods it uses
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('x'));

select set_eq(
  $$ select id from public.meal_plans
     union all select id from public.meals
     union all select id from public.meal_options
     union all select id from public.meal_option_items
     union all select id from public.macro_targets $$,
  array[
    '00000000-0000-0000-0000-000000001104'::uuid,
    '00000000-0000-0000-0000-000000001204'::uuid,
    '00000000-0000-0000-0000-000000001304'::uuid,
    '00000000-0000-0000-0000-000000001404'::uuid,
    '00000000-0000-0000-0000-000000001414'::uuid,
    '00000000-0000-0000-0000-000000001424'::uuid,
    '00000000-0000-0000-0000-000000001504'::uuid
  ],
  'X still reads his old meal plan, its whole tree and his macro targets after his link ended'
);

select set_eq(
  'select name from public.foods',
  array['Arroz', 'Huevo', 'Pan'],
  'X reads the foods his old plan uses, not T1''s other foods'
);

select is_empty(
  $$ with p as (update public.meal_plans set name = 'Hacked' returning id),
          i as (update public.meal_option_items set amount = 999 returning id),
          f as (update public.foods set name = 'Hacked' returning id)
     select id from p union all select id from i union all select id from f $$,
  'X cannot update his old plan or the foods it uses (no row is updated)'
);

-- ---------------------------------------------------------------------------
-- U (no links): nothing
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('u'));

select is_empty(
  $$ select id from public.meal_plans
     union all select id from public.meals
     union all select id from public.meal_options
     union all select id from public.meal_option_items
     union all select id from public.macro_targets $$,
  'U reads no nutrition row'
);

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------

select tests.clear_authentication();
set local role anon;

select throws_ok('select 1 from public.meal_plans', '42501', null, 'anon cannot read meal_plans');
select throws_ok('select 1 from public.meals', '42501', null, 'anon cannot read meals');
select throws_ok('select 1 from public.meal_options', '42501', null, 'anon cannot read meal_options');
select throws_ok(
  'select 1 from public.meal_option_items', '42501', null,
  'anon cannot read meal_option_items'
);
select throws_ok('select 1 from public.macro_targets', '42501', null, 'anon cannot read macro_targets');

-- ---------------------------------------------------------------------------
-- Self-link: T1 reads his own meal plan through the athlete policy too.
-- With his self-link ended (as postgres) the trainer policy no longer covers
-- that plan, so what he still reads comes from the athlete policy.
-- ---------------------------------------------------------------------------

select tests.clear_authentication();

update public.trainer_athletes
set ended_at = now()
where trainer_id = tests.user_id('t1') and athlete_id = tests.user_id('t1');

select tests.authenticate_as(tests.user_id('t1'));

select set_eq(
  $$ select name from public.meal_plans where athlete_id = tests.user_id('t1') $$,
  array['Plan propio', 'Siguiente plan'],
  'with his self-link ended, T1 still reads his own meal plans as their athlete'
);

select is_empty(
  $$ update public.meal_plans set name = 'Hacked'
     where athlete_id = tests.user_id('t1') returning id $$,
  'with his self-link ended, T1 can no longer write his own meal plans (he reads them as an athlete)'
);

-- ---------------------------------------------------------------------------
-- Deletes: cascade down the tree, lineage set to null, athletes cascade
-- ---------------------------------------------------------------------------

select isnt_empty(
  $$ delete from public.meal_plans
     where id = '00000000-0000-0000-0000-000000001103' returning id $$,
  'T1 can delete A2''s meal plan'
);

select tests.clear_authentication();

select is_empty(
  $$ select id from public.meals where id = '00000000-0000-0000-0000-000000001203'
     union all
     select id from public.meal_options where id = '00000000-0000-0000-0000-000000001303'
     union all
     select id from public.meal_option_items where id = '00000000-0000-0000-0000-000000001403' $$,
  'deleting a meal plan removes its meals, options and items'
);

select results_eq(
  $$ select copied_from_id, trainer_id = tests.user_id('t1'), athlete_id = tests.user_id('a1')
     from public.meal_plans where id = '00000000-0000-0000-0000-000000001102' $$,
  $$ values (null::uuid, true, true) $$,
  'deleting the source sets copied_from_id to null on the copy and leaves its trainer_id and athlete_id'
);

select results_eq(
  $$ select count(*) from public.macro_targets where id = '00000000-0000-0000-0000-000000001503' $$,
  $$ values (1::bigint) $$,
  'deleting a meal plan leaves the athlete''s macro targets (they belong to the athlete, not the plan)'
);

select lives_ok(
  $$ delete from auth.users where id = tests.user_id('a1') $$,
  'deleting an athlete''s user is allowed while he has a meal plan'
);

select is_empty(
  $$ select id from public.meal_plans where id = '00000000-0000-0000-0000-000000001102'
     union all
     select id from public.meals where meal_plan_id = '00000000-0000-0000-0000-000000001102'
     union all
     select id from public.meal_options where meal_id = '00000000-0000-0000-0000-000000001202'
     union all
     select id from public.meal_option_items
     where meal_option_id = '00000000-0000-0000-0000-000000001302'
     union all
     select id from public.macro_targets
     where id in (
       '00000000-0000-0000-0000-000000001502', '00000000-0000-0000-0000-000000001512',
       '00000000-0000-0000-0000-000000001522'
     ) $$,
  'deleting an athlete''s user removes his meal plan and his macro targets'
);

select results_eq(
  $$ select count(*) from public.meal_option_items where athlete_id = tests.user_id('x') $$,
  $$ values (3::bigint) $$,
  'deleting an athlete''s user leaves another athlete''s plan untouched'
);

-- ---------------------------------------------------------------------------
-- The food_swaps index asked for by the advisor
-- ---------------------------------------------------------------------------

select has_index(
  'public', 'food_swaps', 'food_swaps_from_food_id_trainer_id_idx',
  array['from_food_id', 'trainer_id'],
  'food_swaps has an index on (from_food_id, trainer_id), the columns of its from_food FK'
);

select * from finish();

rollback;
