-- Libraries: movement_categories, exercises, foods, food_swaps
-- (docs/schema-v1.md §4, §5, §6).
-- Fixtures (supabase/seed.sql): t1 (self-linked trainer) with a1, a2; t2 with b1;
-- x former athlete of t1; u with no links.
--
-- Row ids are fixed so the tests can refer to them (the client may send its own UUIDs):
--   …c1 / …c2  category of T1 / T2        …e1 / …e2  exercise of T1 / T2
--   …f1, …f3, …f4  foods of T1            …f2  food of T2
--   …51 / …52  swap of T1 / T2

begin;

select plan(62);

-- ---------------------------------------------------------------------------
-- T2's library (as postgres; rolled back at the end)
-- ---------------------------------------------------------------------------

insert into public.movement_categories (id, trainer_id, name, position)
values ('00000000-0000-0000-0000-0000000000c2', tests.user_id('t2'), 'Tracción vertical', 1);

insert into public.exercises (id, trainer_id, name, movement_category_id)
values (
  '00000000-0000-0000-0000-0000000000e2', tests.user_id('t2'), 'Dominadas',
  '00000000-0000-0000-0000-0000000000c2'
);

insert into public.foods (id, trainer_id, name, protein_g, carbs_g, fat_g)
values
  ('00000000-0000-0000-0000-0000000000f2', tests.user_id('t2'), 'Avena', 13.5, 58.7, 7),
  ('00000000-0000-0000-0000-0000000000f5', tests.user_id('t2'), 'Patata', 2, 17, 0.1);

insert into public.food_swaps (id, trainer_id, nutrient_group, from_food_id, to_food_id, factor)
values (
  '00000000-0000-0000-0000-000000000052', tests.user_id('t2'), 'carbs',
  '00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000f5', 3.5
);

-- ---------------------------------------------------------------------------
-- T1 builds his library
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('t1'));

select lives_ok(
  $$ insert into public.movement_categories (id, trainer_id, name, position)
     values ('00000000-0000-0000-0000-0000000000c1', tests.user_id('t1'), 'Empuje inclinado', 1) $$,
  'T1 can create a movement category'
);

select lives_ok(
  $$ insert into public.exercises (id, trainer_id, name, movement_category_id, technique_notes)
     values (
       '00000000-0000-0000-0000-0000000000e1', tests.user_id('t1'), 'Press inclinado',
       '00000000-0000-0000-0000-0000000000c1', 'Codos a 45º'
     ) $$,
  'T1 can create an exercise in his category'
);

select lives_ok(
  $$ insert into public.foods (id, trainer_id, name, protein_g, carbs_g, fat_g, unit_name, unit_grams)
     values
       ('00000000-0000-0000-0000-0000000000f1', tests.user_id('t1'), 'Arroz', 7, 78, 0.6, null, null),
       ('00000000-0000-0000-0000-0000000000f3', tests.user_id('t1'), 'Pasta', 12, 72, 1.5, null, null),
       ('00000000-0000-0000-0000-0000000000f4', tests.user_id('t1'), 'Huevo', 12.5, 0.7, 9.7, 'huevo L', 60) $$,
  'T1 can create foods, with and without a unit'
);

select lives_ok(
  $$ insert into public.food_swaps (id, trainer_id, nutrient_group, from_food_id, to_food_id, factor, note)
     values (
       '00000000-0000-0000-0000-000000000051', tests.user_id('t1'), 'carbs',
       '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f3', 1.25, 'en crudo'
     ) $$,
  'T1 can create a swap between two of his foods'
);

select results_eq(
  $$ select source, source_ref, archived_at from public.exercises
     where id = '00000000-0000-0000-0000-0000000000e1' $$,
  $$ values ('manual'::text, null::text, null::timestamptz) $$,
  'a new exercise defaults to source manual and is not archived'
);

select isnt_empty(
  $$ update public.foods set brand = 'Marca'
     where id = '00000000-0000-0000-0000-0000000000f1' returning id $$,
  'T1 can update his food'
);

-- T1 cannot read T2's library ------------------------------------------------

select set_eq(
  'select id from public.movement_categories',
  array['00000000-0000-0000-0000-0000000000c1'::uuid],
  'T1 sees only his own categories'
);

select set_eq(
  'select id from public.exercises',
  array['00000000-0000-0000-0000-0000000000e1'::uuid],
  'T1 sees only his own exercises'
);

select set_eq(
  'select id from public.foods',
  array[
    '00000000-0000-0000-0000-0000000000f1'::uuid,
    '00000000-0000-0000-0000-0000000000f3'::uuid,
    '00000000-0000-0000-0000-0000000000f4'::uuid
  ],
  'T1 sees only his own foods'
);

select set_eq(
  'select id from public.food_swaps',
  array['00000000-0000-0000-0000-000000000051'::uuid],
  'T1 sees only his own swaps'
);

-- T1 cannot write T2's library -----------------------------------------------

select is_empty(
  $$ update public.exercises set name = 'Hacked'
     where id = '00000000-0000-0000-0000-0000000000e2' returning id $$,
  'T1 cannot update T2''s exercise (no row is updated)'
);

select is_empty(
  $$ delete from public.food_swaps
     where id = '00000000-0000-0000-0000-000000000052' returning id $$,
  'T1 cannot delete T2''s swap (no row is deleted)'
);

select throws_ok(
  $$ insert into public.movement_categories (trainer_id, name)
     values (tests.user_id('t2'), 'Intruso') $$,
  '42501', null,
  'T1 cannot create a category in T2''s library'
);

select throws_ok(
  $$ insert into public.exercises (trainer_id, name) values (tests.user_id('t2'), 'Intruso') $$,
  '42501', null,
  'T1 cannot create an exercise in T2''s library'
);

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g)
     values (tests.user_id('t2'), 'Intruso', 1, 1, 1) $$,
  '42501', null,
  'T1 cannot create a food in T2''s library'
);

select throws_ok(
  $$ update public.foods set trainer_id = tests.user_id('t2')
     where id = '00000000-0000-0000-0000-0000000000f4' $$,
  '42501', null,
  'T1 cannot hand one of his foods over to T2'
);

-- Composite FKs: a row can only point at its own trainer's rows ---------------

select throws_ok(
  $$ insert into public.exercises (trainer_id, name, movement_category_id)
     values (tests.user_id('t1'), 'Remo', '00000000-0000-0000-0000-0000000000c2') $$,
  '23503', null,
  'an exercise of T1 using T2''s category is rejected (composite FK)'
);

select throws_ok(
  $$ insert into public.food_swaps (trainer_id, nutrient_group, from_food_id, to_food_id, factor)
     values (
       tests.user_id('t1'), 'carbs',
       '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f2', 1
     ) $$,
  '23503', null,
  'a swap from a T1 food to a T2 food is rejected (composite FK)'
);

select throws_ok(
  $$ insert into public.food_swaps (trainer_id, nutrient_group, from_food_id, to_food_id, factor)
     values (
       tests.user_id('t1'), 'carbs',
       '00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000f1', 1
     ) $$,
  '23503', null,
  'a swap from a T2 food to a T1 food is rejected (composite FK)'
);

-- Checks ----------------------------------------------------------------------

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g, unit_name)
     values (tests.user_id('t1'), 'Yogur', 4, 5, 3, 'unidad') $$,
  '23514', null,
  'a food with unit_name but no unit_grams is rejected'
);

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g, unit_grams)
     values (tests.user_id('t1'), 'Yogur', 4, 5, 3, 125) $$,
  '23514', null,
  'a food with unit_grams but no unit_name is rejected'
);

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g, unit_name, unit_grams)
     values (tests.user_id('t1'), 'Yogur', 4, 5, 3, 'unidad', 0) $$,
  '23514', null,
  'a food with unit_grams = 0 is rejected'
);

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g)
     values (tests.user_id('t1'), 'Imposible', 100.1, 0, 0) $$,
  '23514', null,
  'protein_g above 100 is rejected'
);

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g)
     values (tests.user_id('t1'), 'Imposible', 0, -1, 0) $$,
  '23514', null,
  'negative carbs_g is rejected'
);

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g)
     values (tests.user_id('t1'), 'Imposible', 0, 0, 101) $$,
  '23514', null,
  'fat_g above 100 is rejected'
);

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g, source)
     values (tests.user_id('t1'), 'Importado', 1, 1, 1, 'open_food_facts') $$,
  '23514', null,
  'a food source outside manual / sheet_import is rejected'
);

select throws_ok(
  $$ insert into public.exercises (trainer_id, name, source)
     values (tests.user_id('t1'), 'Importado', 'wger') $$,
  '23514', null,
  'an exercise source outside manual / sheet_import is rejected'
);

select throws_ok(
  $$ insert into public.food_swaps (trainer_id, nutrient_group, from_food_id, to_food_id, factor)
     values (
       tests.user_id('t1'), 'carbs',
       '00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-0000000000f1', 0
     ) $$,
  '23514', null,
  'a swap with factor = 0 is rejected'
);

select throws_ok(
  $$ insert into public.food_swaps (trainer_id, nutrient_group, from_food_id, to_food_id, factor)
     values (
       tests.user_id('t1'), 'carbs',
       '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f1', 1
     ) $$,
  '23514', null,
  'a swap from a food to itself is rejected'
);

select throws_ok(
  $$ insert into public.food_swaps (trainer_id, nutrient_group, from_food_id, to_food_id, factor)
     values (
       tests.user_id('t1'), 'fiber',
       '00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-0000000000f1', 1
     ) $$,
  '23514', null,
  'a swap with an unknown nutrient_group is rejected'
);

select throws_ok(
  $$ insert into public.food_swaps (trainer_id, nutrient_group, from_food_id, to_food_id, factor)
     values (
       tests.user_id('t1'), 'protein',
       '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f3', 2
     ) $$,
  '23505', null,
  'a second swap for the same (from, to) pair is rejected'
);

select lives_ok(
  $$ insert into public.food_swaps (trainer_id, nutrient_group, from_food_id, to_food_id, factor)
     values (
       tests.user_id('t1'), 'carbs',
       '00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-0000000000f1', 0.8
     ) $$,
  'swaps are directed: the reverse pair is a separate row'
);

-- Unique names among non-archived rows ----------------------------------------

select throws_ok(
  $$ insert into public.exercises (trainer_id, name) values (tests.user_id('t1'), 'PRESS INCLINADO') $$,
  '23505', null,
  'a second non-archived exercise with the same name (any case) is rejected'
);

select throws_ok(
  $$ insert into public.movement_categories (trainer_id, name)
     values (tests.user_id('t1'), 'empuje INCLINADO') $$,
  '23505', null,
  'a second non-archived category with the same name (any case) is rejected'
);

select lives_ok(
  $$ update public.exercises set archived_at = now()
     where id = '00000000-0000-0000-0000-0000000000e1' $$,
  'T1 can archive his exercise'
);

select lives_ok(
  $$ insert into public.exercises (trainer_id, name) values (tests.user_id('t1'), 'Press inclinado') $$,
  'the name of an archived exercise can be used again'
);

-- On delete restrict ----------------------------------------------------------

select throws_ok(
  $$ delete from public.movement_categories where id = '00000000-0000-0000-0000-0000000000c1' $$,
  '23503', null,
  'a category used by an exercise cannot be deleted'
);

select throws_ok(
  $$ delete from public.foods where id = '00000000-0000-0000-0000-0000000000f3' $$,
  '23503', null,
  'a food used by a swap cannot be deleted'
);

select isnt_empty(
  $$ delete from public.foods where id = '00000000-0000-0000-0000-0000000000f4' returning id $$,
  'T1 can delete a food nothing points at'
);

-- ---------------------------------------------------------------------------
-- A1: reads his trainer's library, cannot write it
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('a1'));

select set_eq(
  'select id from public.movement_categories',
  array['00000000-0000-0000-0000-0000000000c1'::uuid],
  'A1 reads T1''s categories, not T2''s'
);

select set_eq(
  'select name, archived_at is not null as is_archived from public.exercises',
  $$ values ('Press inclinado'::text, true), ('Press inclinado'::text, false) $$,
  'A1 reads T1''s exercises (archived ones included), not T2''s'
);

select set_eq(
  'select id from public.foods',
  array[
    '00000000-0000-0000-0000-0000000000f1'::uuid,
    '00000000-0000-0000-0000-0000000000f3'::uuid
  ],
  'A1 reads T1''s foods, not T2''s'
);

select set_eq(
  'select from_food_id, to_food_id, factor from public.food_swaps',
  $$ values
       ('00000000-0000-0000-0000-0000000000f1'::uuid, '00000000-0000-0000-0000-0000000000f3'::uuid, 1.25::numeric(6,3)),
       ('00000000-0000-0000-0000-0000000000f3'::uuid, '00000000-0000-0000-0000-0000000000f1'::uuid, 0.8::numeric(6,3)) $$,
  'A1 reads T1''s swaps, not T2''s'
);

select throws_ok(
  $$ insert into public.movement_categories (trainer_id, name)
     values (tests.user_id('t1'), 'De atleta') $$,
  '42501', null,
  'A1 cannot create a category in T1''s library'
);

select throws_ok(
  $$ insert into public.exercises (trainer_id, name) values (tests.user_id('t1'), 'De atleta') $$,
  '42501', null,
  'A1 cannot create an exercise in T1''s library'
);

select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g)
     values (tests.user_id('t1'), 'De atleta', 1, 1, 1) $$,
  '42501', null,
  'A1 cannot create a food in T1''s library'
);

select throws_ok(
  $$ insert into public.food_swaps (trainer_id, nutrient_group, from_food_id, to_food_id, factor)
     values (
       tests.user_id('t1'), 'fat',
       '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f3', 1
     ) $$,
  '42501', null,
  'A1 cannot create a swap in T1''s library'
);

-- The trainer policy lets a row through when trainer_id is the caller; the FK
-- to trainers then rejects it, because A1 is not a trainer.
select throws_ok(
  $$ insert into public.foods (trainer_id, name, protein_g, carbs_g, fat_g)
     values (tests.user_id('a1'), 'Biblioteca propia', 1, 1, 1) $$,
  '23503', null,
  'A1 cannot start a library of his own (he is not a trainer)'
);

select is_empty(
  $$ update public.exercises set technique_notes = 'Hacked' returning id $$,
  'A1 cannot update T1''s exercises (no row is updated)'
);

select is_empty(
  $$ update public.foods set protein_g = 99 returning id $$,
  'A1 cannot update T1''s foods (no row is updated)'
);

select is_empty(
  $$ delete from public.food_swaps returning id $$,
  'A1 cannot delete T1''s swaps (no row is deleted)'
);

select is_empty(
  $$ delete from public.movement_categories returning id $$,
  'A1 cannot delete T1''s categories (no row is deleted)'
);

-- ---------------------------------------------------------------------------
-- B1 and T2: the other trainer's side
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('b1'));

select set_eq(
  'select id from public.foods',
  array[
    '00000000-0000-0000-0000-0000000000f2'::uuid,
    '00000000-0000-0000-0000-0000000000f5'::uuid
  ],
  'B1 reads T2''s foods, not T1''s'
);

select tests.authenticate_as(tests.user_id('t2'));

select set_eq(
  $$ select id from public.movement_categories
     union all select id from public.exercises
     union all select id from public.foods
     union all select id from public.food_swaps $$,
  array[
    '00000000-0000-0000-0000-0000000000c2'::uuid,
    '00000000-0000-0000-0000-0000000000e2'::uuid,
    '00000000-0000-0000-0000-0000000000f2'::uuid,
    '00000000-0000-0000-0000-0000000000f5'::uuid,
    '00000000-0000-0000-0000-000000000052'::uuid
  ],
  'T2 sees his whole library and nothing of T1''s'
);

select is_empty(
  $$ update public.foods set name = 'Hacked'
     where id = '00000000-0000-0000-0000-0000000000f1' returning id $$,
  'T2 cannot update T1''s food (no row is updated)'
);

-- ---------------------------------------------------------------------------
-- X (former athlete of T1) and U (no links): nothing
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('x'));

select is_empty(
  $$ select id from public.movement_categories
     union all select id from public.exercises
     union all select id from public.foods
     union all select id from public.food_swaps $$,
  'X reads nothing of T1''s library after his link ended'
);

select tests.authenticate_as(tests.user_id('u'));

select is_empty(
  $$ select id from public.movement_categories
     union all select id from public.exercises
     union all select id from public.foods
     union all select id from public.food_swaps $$,
  'U reads no library'
);

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------

select tests.clear_authentication();
set local role anon;

select throws_ok('select 1 from public.movement_categories', '42501', null, 'anon cannot read movement_categories');
select throws_ok('select 1 from public.exercises', '42501', null, 'anon cannot read exercises');
select throws_ok('select 1 from public.foods', '42501', null, 'anon cannot read foods');
select throws_ok('select 1 from public.food_swaps', '42501', null, 'anon cannot read food_swaps');

-- ---------------------------------------------------------------------------
-- Trainer protection (as postgres): a trainer with a library cannot be removed
-- ---------------------------------------------------------------------------

select tests.clear_authentication();

select throws_ok(
  $$ delete from public.trainers where profile_id = tests.user_id('t2') $$,
  '23503', null,
  'a trainers row cannot be deleted while his links and library exist'
);

select * from finish();

rollback;
