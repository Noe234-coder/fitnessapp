-- Training plans: mesocycles, training_days, day_exercises, exercise_prescriptions,
-- prescribed_sets, and the library "used in own plans" policies
-- (docs/schema-v1.md §4, §5, §6).
-- Fixtures (supabase/seed.sql): t1 (self-linked trainer) with a1, a2; t2 with b1;
-- x former athlete of t1; u with no links.
--
-- Row ids are fixed. The last four digits are <table><tree>:
--   table  01 mesocycles · 02 training_days · 03 day_exercises
--          04 exercise_prescriptions · 05 prescribed_sets
--   tree   …01 T1's template      …02 A1 (by T1)      …03 A2 (by T1)
--          …04 X (by T1, old)     …05 T1 as his own athlete
--          …06 T2's template      …07 B1 (by T2)
--          …08 B1 (by T1, old: written when B1 trained with T1)
--   A second row of the same table and tree has the third digit raised:
--   …0211 is the template's warm-up day, …0512 is A1's second set.
-- Library: …c1 / …c3 categories of T1 · …e1 / …e3 exercises of T1 · …e2 exercise of T2.
-- 2026-11-02 and 2026-09-07 are Mondays; 2026-11-03 is a Tuesday.

begin;

select plan(103);

-- ---------------------------------------------------------------------------
-- Rows T1 does not create himself (as postgres; rolled back at the end)
-- ---------------------------------------------------------------------------

insert into public.movement_categories (id, trainer_id, name, position)
values
  ('00000000-0000-0000-0000-0000000000c1', tests.user_id('t1'), 'Empuje inclinado', 1),
  ('00000000-0000-0000-0000-0000000000c3', tests.user_id('t1'), 'Tracción vertical', 2);

insert into public.exercises (id, trainer_id, name, movement_category_id)
values
  ('00000000-0000-0000-0000-0000000000e1', tests.user_id('t1'), 'Press inclinado',
   '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000e3', tests.user_id('t1'), 'Remo con barra',
   '00000000-0000-0000-0000-0000000000c3'),
  ('00000000-0000-0000-0000-0000000000e2', tests.user_id('t2'), 'Dominadas', null);

insert into public.mesocycles (id, trainer_id, athlete_id, name, starts_on, status)
values
  ('00000000-0000-0000-0000-000000000103', tests.user_id('t1'), tests.user_id('a2'),
   'Bloque de A2', '2026-11-02', 'active'),
  ('00000000-0000-0000-0000-000000000104', tests.user_id('t1'), tests.user_id('x'),
   'Bloque antiguo de X', '2026-09-07', 'archived'),
  ('00000000-0000-0000-0000-000000000106', tests.user_id('t2'), null,
   'Plantilla de T2', null, 'draft'),
  ('00000000-0000-0000-0000-000000000107', tests.user_id('t2'), tests.user_id('b1'),
   'Bloque de B1', '2026-11-02', 'active'),
  ('00000000-0000-0000-0000-000000000108', tests.user_id('t1'), tests.user_id('b1'),
   'Bloque antiguo de B1 con T1', '2026-09-07', 'archived');

insert into public.training_days (id, trainer_id, athlete_id, mesocycle_id, name, position)
values
  ('00000000-0000-0000-0000-000000000203', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000000103', 'Torso', 1),
  ('00000000-0000-0000-0000-000000000204', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000000104', 'Torso', 1),
  ('00000000-0000-0000-0000-000000000206', tests.user_id('t2'), null,
   '00000000-0000-0000-0000-000000000106', 'Cuerpo completo', 1),
  ('00000000-0000-0000-0000-000000000207', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000000107', 'Cuerpo completo', 1),
  ('00000000-0000-0000-0000-000000000208', tests.user_id('t1'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000000108', 'Torso', 1);

insert into public.day_exercises (id, trainer_id, athlete_id, training_day_id, exercise_id, position)
values
  ('00000000-0000-0000-0000-000000000303', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-0000000000e3', 1),
  ('00000000-0000-0000-0000-000000000304', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000000204', '00000000-0000-0000-0000-0000000000e1', 1),
  ('00000000-0000-0000-0000-000000000306', tests.user_id('t2'), null,
   '00000000-0000-0000-0000-000000000206', '00000000-0000-0000-0000-0000000000e2', 1),
  ('00000000-0000-0000-0000-000000000307', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000000207', '00000000-0000-0000-0000-0000000000e2', 1);

insert into public.exercise_prescriptions (id, trainer_id, athlete_id, day_exercise_id, from_week)
values
  ('00000000-0000-0000-0000-000000000403', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000000303', 1),
  ('00000000-0000-0000-0000-000000000404', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000000304', 1),
  ('00000000-0000-0000-0000-000000000406', tests.user_id('t2'), null,
   '00000000-0000-0000-0000-000000000306', 1),
  ('00000000-0000-0000-0000-000000000407', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000000307', 1);

insert into public.prescribed_sets (
  id, trainer_id, athlete_id, exercise_prescription_id, set_number,
  target_reps_min, target_reps_max, target_effort, target_rir_min, target_rir_max
)
values
  ('00000000-0000-0000-0000-000000000503', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000000403', 1, 8, 10, 'rir', 0, 1),
  ('00000000-0000-0000-0000-000000000504', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000000404', 1, 8, 10, 'rir', 0, 1),
  ('00000000-0000-0000-0000-000000000506', tests.user_id('t2'), null,
   '00000000-0000-0000-0000-000000000406', 1, 8, 10, 'rir', 0, 1),
  ('00000000-0000-0000-0000-000000000507', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000000407', 1, 8, 10, 'rir', 0, 1);

-- ---------------------------------------------------------------------------
-- T1 builds a template, A1's mesocycle and his own
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('t1'));

select lives_ok(
  $$ insert into public.mesocycles (id, trainer_id, name)
     values ('00000000-0000-0000-0000-000000000101', tests.user_id('t1'), 'Torso/Pierna') $$,
  'T1 can create a template'
);

select results_eq(
  $$ select status, is_template, starts_on from public.mesocycles
     where id = '00000000-0000-0000-0000-000000000101' $$,
  $$ values ('draft'::text, true, null::date) $$,
  'a mesocycle without an athlete is a template, in draft, with no start date'
);

select lives_ok(
  $$ insert into public.training_days (id, trainer_id, mesocycle_id, name, position, kind)
     values
       ('00000000-0000-0000-0000-000000000201', tests.user_id('t1'),
        '00000000-0000-0000-0000-000000000101', 'Torso', 1, 'training'),
       ('00000000-0000-0000-0000-000000000211', tests.user_id('t1'),
        '00000000-0000-0000-0000-000000000101', 'Movilidad', 0, 'warmup') $$,
  'T1 can add a training day and a warm-up day to his template'
);

select lives_ok(
  $$ insert into public.day_exercises (id, trainer_id, training_day_id, exercise_id, position)
     values ('00000000-0000-0000-0000-000000000301', tests.user_id('t1'),
             '00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-0000000000e1', 1) $$,
  'T1 can add one of his exercises to a template day'
);

select lives_ok(
  $$ insert into public.exercise_prescriptions (id, trainer_id, day_exercise_id, from_week)
     values ('00000000-0000-0000-0000-000000000401', tests.user_id('t1'),
             '00000000-0000-0000-0000-000000000301', 1) $$,
  'T1 can add the week-1 prescription of a template exercise'
);

select lives_ok(
  $$ insert into public.prescribed_sets (
       id, trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max,
       target_effort, target_rir_min, target_rir_max, technique
     )
     values
       ('00000000-0000-0000-0000-000000000501', tests.user_id('t1'),
        '00000000-0000-0000-0000-000000000401', 1, 5, 8, 'rir', 0, 1, null),
       ('00000000-0000-0000-0000-000000000511', tests.user_id('t1'),
        '00000000-0000-0000-0000-000000000401', 2, 8, 10, 'failure', null, null, 'partials') $$,
  'T1 can prescribe a RIR set and a failure set with partials'
);

select lives_ok(
  $$ insert into public.mesocycles (id, trainer_id, athlete_id, name, starts_on, status, copied_from_id)
     values ('00000000-0000-0000-0000-000000000102', tests.user_id('t1'), tests.user_id('a1'),
             'Bloque 1', '2026-11-02', 'active', '00000000-0000-0000-0000-000000000101') $$,
  'T1 can create an active mesocycle for A1, copied from his template'
);

select results_eq(
  $$ select is_template, copied_from_id from public.mesocycles
     where id = '00000000-0000-0000-0000-000000000102' $$,
  $$ values (false, '00000000-0000-0000-0000-000000000101'::uuid) $$,
  'an athlete''s mesocycle is not a template and keeps its lineage'
);

select lives_ok(
  $$ insert into public.training_days (id, trainer_id, athlete_id, mesocycle_id, name, position, kind)
     values
       ('00000000-0000-0000-0000-000000000202', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000102', 'Torso', 1, 'training'),
       ('00000000-0000-0000-0000-000000000212', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000102', 'Movilidad', 0, 'warmup') $$,
  'T1 can add a training day and a warm-up day to A1''s mesocycle'
);

select lives_ok(
  $$ insert into public.day_exercises (id, trainer_id, athlete_id, training_day_id, exercise_id, position, notes)
     values
       ('00000000-0000-0000-0000-000000000302', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-0000000000e1', 1, 'Pausa abajo'),
       ('00000000-0000-0000-0000-000000000312', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-0000000000e3', 2, null),
       ('00000000-0000-0000-0000-000000000322', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000212', '00000000-0000-0000-0000-0000000000e3', 1, null) $$,
  'T1 can add his exercises to A1''s days'
);

select lives_ok(
  $$ insert into public.exercise_prescriptions (id, trainer_id, athlete_id, day_exercise_id, from_week)
     values
       ('00000000-0000-0000-0000-000000000402', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000302', 1),
       ('00000000-0000-0000-0000-000000000412', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000312', 1),
       ('00000000-0000-0000-0000-000000000422', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000322', 1) $$,
  'T1 can add the week-1 prescriptions of A1''s exercises'
);

select lives_ok(
  $$ insert into public.prescribed_sets (
       id, trainer_id, athlete_id, exercise_prescription_id, set_number, target_reps_min,
       target_reps_max, is_per_side, target_effort, target_rir_min, target_rir_max, technique
     )
     values
       ('00000000-0000-0000-0000-000000000502', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000402', 1, 5, 8, false, 'rir', 0, 1, null),
       ('00000000-0000-0000-0000-000000000512', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000402', 2, 8, 10, false, 'failure', null, null, 'partials'),
       ('00000000-0000-0000-0000-000000000522', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000412', 1, 20, 20, true, 'rir', 1, 1, 'myo_reps'),
       ('00000000-0000-0000-0000-000000000532', tests.user_id('t1'), tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000422', 1, 10, 10, false, null, null, null, null) $$,
  'T1 can prescribe A1''s sets: RIR, failure with partials, a technique on a RIR set, and a warm-up set with no effort'
);

select lives_ok(
  $$ insert into public.mesocycles (id, trainer_id, athlete_id, name)
     values ('00000000-0000-0000-0000-000000000105', tests.user_id('t1'), tests.user_id('t1'),
             'Bloque propio') $$,
  'T1 can create a mesocycle for himself (self-link)'
);

select lives_ok(
  $$ insert into public.training_days (id, trainer_id, athlete_id, mesocycle_id, name, position)
     values ('00000000-0000-0000-0000-000000000205', tests.user_id('t1'), tests.user_id('t1'),
             '00000000-0000-0000-0000-000000000105', 'Pierna', 1) $$,
  'T1 can add a day to his own mesocycle'
);

select results_eq(
  $$ select is_template from public.mesocycles
     where id = '00000000-0000-0000-0000-000000000105' $$,
  $$ values (false) $$,
  'T1''s own mesocycle is not a template'
);

select isnt_empty(
  $$ update public.prescribed_sets set notes = 'Controla la bajada'
     where id = '00000000-0000-0000-0000-000000000502' returning id $$,
  'T1 can update a set of A1''s plan'
);

select isnt_empty(
  $$ update public.mesocycles set name = 'Bloque de A2, revisado'
     where id = '00000000-0000-0000-0000-000000000103' returning id $$,
  'T1 can update A2''s mesocycle'
);

-- T1 reads his templates and his active athletes' plans, nothing else ----------

select set_eq(
  'select id from public.mesocycles',
  array[
    '00000000-0000-0000-0000-000000000101'::uuid,
    '00000000-0000-0000-0000-000000000102'::uuid,
    '00000000-0000-0000-0000-000000000103'::uuid,
    '00000000-0000-0000-0000-000000000105'::uuid
  ],
  'T1 sees his template, A1''s, A2''s and his own mesocycle: not X''s, not T2''s, and not B1''s (not even the one that carries his trainer_id)'
);

select set_eq(
  $$ select id from public.training_days
     union all select id from public.day_exercises
     union all select id from public.exercise_prescriptions
     union all select id from public.prescribed_sets $$,
  array[
    '00000000-0000-0000-0000-000000000201'::uuid,
    '00000000-0000-0000-0000-000000000211'::uuid,
    '00000000-0000-0000-0000-000000000202'::uuid,
    '00000000-0000-0000-0000-000000000212'::uuid,
    '00000000-0000-0000-0000-000000000203'::uuid,
    '00000000-0000-0000-0000-000000000205'::uuid,
    '00000000-0000-0000-0000-000000000301'::uuid,
    '00000000-0000-0000-0000-000000000302'::uuid,
    '00000000-0000-0000-0000-000000000312'::uuid,
    '00000000-0000-0000-0000-000000000322'::uuid,
    '00000000-0000-0000-0000-000000000303'::uuid,
    '00000000-0000-0000-0000-000000000401'::uuid,
    '00000000-0000-0000-0000-000000000402'::uuid,
    '00000000-0000-0000-0000-000000000412'::uuid,
    '00000000-0000-0000-0000-000000000422'::uuid,
    '00000000-0000-0000-0000-000000000403'::uuid,
    '00000000-0000-0000-0000-000000000501'::uuid,
    '00000000-0000-0000-0000-000000000511'::uuid,
    '00000000-0000-0000-0000-000000000502'::uuid,
    '00000000-0000-0000-0000-000000000512'::uuid,
    '00000000-0000-0000-0000-000000000522'::uuid,
    '00000000-0000-0000-0000-000000000532'::uuid,
    '00000000-0000-0000-0000-000000000503'::uuid
  ],
  'T1 sees the days, exercises, prescriptions and sets of those mesocycles only'
);

-- T1 cannot write plans for B1, for X or in T2's name --------------------------

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, athlete_id, name)
     values (tests.user_id('t1'), tests.user_id('b1'), 'Intruso') $$,
  '42501', 'new row violates row-level security policy for table "mesocycles"',
  'T1 cannot create a mesocycle for B1, who is not his athlete'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, athlete_id, name)
     values (tests.user_id('t2'), tests.user_id('b1'), 'Intruso') $$,
  '42501', 'new row violates row-level security policy for table "mesocycles"',
  'T1 cannot create a mesocycle for B1 in T2''s name'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, name) values (tests.user_id('t2'), 'Intruso') $$,
  '42501', 'new row violates row-level security policy for table "mesocycles"',
  'T1 cannot create a template in T2''s name'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, athlete_id, name)
     values (tests.user_id('t1'), tests.user_id('x'), 'Vuelta') $$,
  '42501', 'new row violates row-level security policy for table "mesocycles"',
  'T1 cannot create a mesocycle for X, whose link ended'
);

select throws_ok(
  $$ insert into public.training_days (trainer_id, athlete_id, mesocycle_id, name)
     values (tests.user_id('t1'), tests.user_id('x'),
             '00000000-0000-0000-0000-000000000104', 'Extra') $$,
  '42501', 'new row violates row-level security policy for table "training_days"',
  'T1 cannot add a day to X''s old mesocycle'
);

select throws_ok(
  $$ insert into public.day_exercises (trainer_id, athlete_id, training_day_id, exercise_id)
     values (tests.user_id('t1'), tests.user_id('x'),
             '00000000-0000-0000-0000-000000000204', '00000000-0000-0000-0000-0000000000e1') $$,
  '42501', 'new row violates row-level security policy for table "day_exercises"',
  'T1 cannot add an exercise to X''s old day'
);

select throws_ok(
  $$ insert into public.exercise_prescriptions (trainer_id, athlete_id, day_exercise_id, from_week)
     values (tests.user_id('t1'), tests.user_id('x'),
             '00000000-0000-0000-0000-000000000304', 2) $$,
  '42501', 'new row violates row-level security policy for table "exercise_prescriptions"',
  'T1 cannot add a prescription to X''s old exercise'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, athlete_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max
     )
     values (tests.user_id('t1'), tests.user_id('x'),
             '00000000-0000-0000-0000-000000000404', 2, 8, 10) $$,
  '42501', 'new row violates row-level security policy for table "prescribed_sets"',
  'T1 cannot add a set to X''s old prescription'
);

select throws_ok(
  $$ update public.mesocycles set athlete_id = tests.user_id('x')
     where id = '00000000-0000-0000-0000-000000000105' $$,
  '42501', 'new row violates row-level security policy for table "mesocycles"',
  'T1 cannot hand one of his mesocycles over to X'
);

select is_empty(
  $$ with m as (
       update public.mesocycles set name = 'Hacked'
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     d as (
       update public.training_days set name = 'Hacked'
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     e as (
       update public.day_exercises set notes = 'Hacked'
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     p as (
       update public.exercise_prescriptions set from_week = 9
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     s as (
       update public.prescribed_sets set notes = 'Hacked'
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     )
     select id from m union all select id from d union all select id from e
     union all select id from p union all select id from s $$,
  'T1 cannot update any row of X''s or B1''s plans (no row is updated)'
);

select is_empty(
  $$ with s as (
       delete from public.prescribed_sets
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     p as (
       delete from public.exercise_prescriptions
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     e as (
       delete from public.day_exercises
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     d as (
       delete from public.training_days
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     ),
     m as (
       delete from public.mesocycles
       where athlete_id in (tests.user_id('x'), tests.user_id('b1')) returning id
     )
     select id from m union all select id from d union all select id from e
     union all select id from p union all select id from s $$,
  'T1 cannot delete any row of X''s or B1''s plans (no row is deleted)'
);

select is_empty(
  $$ delete from public.mesocycles
     where id = '00000000-0000-0000-0000-000000000106' returning id $$,
  'T1 cannot delete T2''s template (no row is deleted)'
);

select throws_ok(
  $$ update public.mesocycles set trainer_id = tests.user_id('t2')
     where id = '00000000-0000-0000-0000-000000000105' $$,
  '42501', 'new row violates row-level security policy for table "mesocycles"',
  'T1 cannot hand one of his mesocycles over to T2'
);

-- is_template is generated ------------------------------------------------------

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, athlete_id, name, is_template)
     values (tests.user_id('t1'), tests.user_id('a1'), 'Falsa plantilla', true) $$,
  '428C9', null,
  'is_template cannot be written on insert'
);

select throws_ok(
  $$ update public.mesocycles set is_template = true
     where id = '00000000-0000-0000-0000-000000000102' $$,
  '428C9', null,
  'is_template cannot be written on update'
);

-- Composite FKs: what a plan row may point at ----------------------------------

select throws_ok(
  $$ insert into public.day_exercises (trainer_id, training_day_id, exercise_id)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000201',
             '00000000-0000-0000-0000-0000000000e2') $$,
  '23503',
  'insert or update on table "day_exercises" violates foreign key constraint "day_exercises_exercise_id_trainer_id_fkey"',
  'T1 cannot use T2''s exercise in his plan'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, name, copied_from_id)
     values (tests.user_id('t1'), 'Copia ajena', '00000000-0000-0000-0000-000000000106') $$,
  '23503',
  'insert or update on table "mesocycles" violates foreign key constraint "mesocycles_copied_from_id_trainer_id_fkey"',
  'copied_from_id cannot point at T2''s mesocycle'
);

-- A template row under an athlete's parent: only the first FK is checked
-- (athlete_id is null), and it rejects the row.
select throws_ok(
  $$ insert into public.training_days (trainer_id, mesocycle_id, name)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000102', 'Plantilla colada') $$,
  '23503',
  'insert or update on table "training_days" violates foreign key constraint "training_days_mesocycle_id_template_fkey"',
  'a template day under an athlete''s mesocycle is rejected'
);

select throws_ok(
  $$ insert into public.day_exercises (trainer_id, training_day_id, exercise_id)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000202',
             '00000000-0000-0000-0000-0000000000e1') $$,
  '23503',
  'insert or update on table "day_exercises" violates foreign key constraint "day_exercises_training_day_id_template_fkey"',
  'a template exercise under an athlete''s day is rejected'
);

select throws_ok(
  $$ insert into public.exercise_prescriptions (trainer_id, day_exercise_id, from_week)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000302', 5) $$,
  '23503',
  'insert or update on table "exercise_prescriptions" violates foreign key constraint "exercise_prescriptions_day_exercise_id_template_fkey"',
  'a template prescription under an athlete''s exercise is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000402', 9, 8, 10) $$,
  '23503',
  'insert or update on table "prescribed_sets" violates foreign key constraint "prescribed_sets_exercise_prescription_id_template_fkey"',
  'a template set under an athlete''s prescription is rejected'
);

-- The reverse: both FKs reject it, so only the error code is checked.
select throws_ok(
  $$ insert into public.training_days (trainer_id, athlete_id, mesocycle_id, name)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000101', 'Día de atleta colado') $$,
  '23503', null,
  'an athlete''s day under a template is rejected'
);

-- An athlete's row under another athlete's parent of the same trainer: the
-- first FK passes (same trainer, neither is a template); the second rejects it.
select throws_ok(
  $$ insert into public.training_days (trainer_id, athlete_id, mesocycle_id, name)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000103', 'Día cruzado') $$,
  '23503',
  'insert or update on table "training_days" violates foreign key constraint "training_days_mesocycle_id_athlete_id_fkey"',
  'A1''s day under A2''s mesocycle is rejected'
);

select throws_ok(
  $$ insert into public.day_exercises (trainer_id, athlete_id, training_day_id, exercise_id)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-0000000000e1') $$,
  '23503',
  'insert or update on table "day_exercises" violates foreign key constraint "day_exercises_training_day_id_athlete_id_fkey"',
  'A1''s exercise under A2''s day is rejected'
);

select throws_ok(
  $$ insert into public.exercise_prescriptions (trainer_id, athlete_id, day_exercise_id, from_week)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000303', 5) $$,
  '23503',
  'insert or update on table "exercise_prescriptions" violates foreign key constraint "exercise_prescriptions_day_exercise_id_athlete_id_fkey"',
  'A1''s prescription under A2''s exercise is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, athlete_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max
     )
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000403', 9, 8, 10) $$,
  '23503',
  'insert or update on table "prescribed_sets" violates foreign key constraint "prescribed_sets_exercise_prescription_id_athlete_id_fkey"',
  'A1''s set under A2''s prescription is rejected'
);

-- A plan cannot be moved to another athlete: its days still point at
-- (mesocycle, athlete). T1 is his own athlete, so the policy lets it through.
select throws_ok(
  $$ update public.mesocycles set athlete_id = tests.user_id('t1'), status = 'draft'
     where id = '00000000-0000-0000-0000-000000000102' $$,
  '23503',
  'update or delete on table "mesocycles" violates foreign key constraint "training_days_mesocycle_id_athlete_id_fkey" on table "training_days"',
  'A1''s mesocycle cannot be moved to another athlete by editing athlete_id'
);

-- Checks: mesocycles -------------------------------------------------------------

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, athlete_id, name, starts_on)
     values (tests.user_id('t1'), tests.user_id('a1'), 'En martes', '2026-11-03') $$,
  '23514', 'new row for relation "mesocycles" violates check constraint "mesocycles_starts_on_monday_check"',
  'a starts_on that is not a Monday is rejected'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, name, starts_on)
     values (tests.user_id('t1'), 'Plantilla con fecha', '2026-11-02') $$,
  '23514', 'new row for relation "mesocycles" violates check constraint "mesocycles_template_no_starts_on_check"',
  'a template with a starts_on is rejected'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, athlete_id, name, status)
     values (tests.user_id('t1'), tests.user_id('t1'), 'Activo sin fecha', 'active') $$,
  '23514', 'new row for relation "mesocycles" violates check constraint "mesocycles_active_needs_starts_on_check"',
  'an active athlete mesocycle without a starts_on is rejected'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, athlete_id, name, starts_on, status)
     values (tests.user_id('t1'), tests.user_id('a1'), 'Segundo activo', '2026-11-09', 'active') $$,
  '23505', 'duplicate key value violates unique constraint "mesocycles_one_active_per_athlete_idx"',
  'a second active mesocycle for the same athlete is rejected'
);

select lives_ok(
  $$ insert into public.mesocycles (id, trainer_id, athlete_id, name, starts_on, status)
     values
       (gen_random_uuid(), tests.user_id('t1'), null, 'Plantilla activa 1', null, 'active'),
       (gen_random_uuid(), tests.user_id('t1'), null, 'Plantilla activa 2', null, 'active'),
       ('00000000-0000-0000-0000-000000000115', tests.user_id('t1'), tests.user_id('t1'),
        'Siguiente bloque', '2026-11-09', 'draft') $$,
  'templates are not limited to one active, and an athlete can have a draft next to other mesocycles'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, name, status)
     values (tests.user_id('t1'), 'Estado raro', 'paused') $$,
  '23514', 'new row for relation "mesocycles" violates check constraint "mesocycles_status_check"',
  'a status outside draft / active / archived is rejected'
);

-- Checks: training_days and exercise_prescriptions -----------------------------

select throws_ok(
  $$ insert into public.training_days (trainer_id, mesocycle_id, name, kind)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000101', 'Otra movilidad', 'warmup') $$,
  '23505', 'duplicate key value violates unique constraint "training_days_one_warmup_per_mesocycle_idx"',
  'a second warm-up day in the same mesocycle is rejected'
);

select throws_ok(
  $$ insert into public.training_days (trainer_id, mesocycle_id, name, kind)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000101', 'Cardio', 'cardio') $$,
  '23514', 'new row for relation "training_days" violates check constraint "training_days_kind_check"',
  'a kind outside training / warmup is rejected'
);

select throws_ok(
  $$ insert into public.exercise_prescriptions (trainer_id, day_exercise_id, from_week)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000301', 0) $$,
  '23514', 'new row for relation "exercise_prescriptions" violates check constraint "exercise_prescriptions_from_week_check"',
  'a prescription from week 0 is rejected'
);

select throws_ok(
  $$ insert into public.exercise_prescriptions (trainer_id, day_exercise_id, from_week)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000301', 1) $$,
  '23505', 'duplicate key value violates unique constraint "exercise_prescriptions_day_exercise_id_from_week_key"',
  'a second prescription for the same exercise and week is rejected'
);

select lives_ok(
  $$ insert into public.exercise_prescriptions (trainer_id, day_exercise_id, from_week)
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000301', 3) $$,
  'a later version of the same exercise (from week 3) is accepted'
);

-- Checks: prescribed_sets ---------------------------------------------------------
-- Each insert is valid except for the one thing its test names.

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 1, 8, 10) $$,
  '23505', 'duplicate key value violates unique constraint "prescribed_sets_exercise_prescription_id_set_number_key"',
  'a second set with the same set_number is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 0, 8, 10) $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_set_number_check"',
  'set_number 0 is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 10, 8) $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_reps_check"',
  'target_reps_min above target_reps_max is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 0, 8) $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_reps_check"',
  'target_reps_min 0 is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max, target_effort
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, 'failure_partials') $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_effort_check"',
  'a target_effort outside rir / failure is rejected (failure_partials is no longer an effort)'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max,
       target_effort, technique
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, 'failure', 'cluster') $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_technique_check"',
  'a technique outside the four codes is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max,
       target_effort, technique
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, null, 'drop_set') $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_technique_needs_effort_check"',
  'a technique on a warm-up set (no target_effort) is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max,
       target_effort, target_rir_min, target_rir_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, 'failure', 0, 1) $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_rir_effort_check"',
  'RIR values with effort failure are rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max,
       target_effort, target_rir_min, target_rir_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, null, 0, 1) $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_rir_effort_check"',
  'RIR values on a warm-up set (no target_effort) are rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max, target_effort
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, 'rir') $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_rir_effort_check"',
  'effort rir without RIR values is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max,
       target_effort, target_rir_min, target_rir_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, 'rir', 1, null) $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_rir_effort_check"',
  'effort rir with only one RIR value is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max,
       target_effort, target_rir_min, target_rir_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, 'rir', 2, 1) $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_rir_range_check"',
  'target_rir_min above target_rir_max is rejected'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max,
       target_effort, target_rir_min, target_rir_max
     )
     values (tests.user_id('t1'), '00000000-0000-0000-0000-000000000401', 9, 8, 10, 'rir', -1, 1) $$,
  '23514', 'new row for relation "prescribed_sets" violates check constraint "prescribed_sets_target_rir_range_check"',
  'a negative RIR is rejected'
);

-- A used exercise cannot be deleted (on delete restrict) ------------------------

select throws_ok(
  $$ delete from public.exercises where id = '00000000-0000-0000-0000-0000000000e1' $$,
  '23503',
  'update or delete on table "exercises" violates foreign key constraint "day_exercises_exercise_id_trainer_id_fkey" on table "day_exercises"',
  'T1 cannot delete an exercise a plan uses'
);

-- ---------------------------------------------------------------------------
-- A1: reads his own plan, never templates, and cannot write any plan row
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('a1'));

select set_eq(
  $$ select id from public.mesocycles
     union all select id from public.training_days
     union all select id from public.day_exercises
     union all select id from public.exercise_prescriptions
     union all select id from public.prescribed_sets $$,
  array[
    '00000000-0000-0000-0000-000000000102'::uuid,
    '00000000-0000-0000-0000-000000000202'::uuid,
    '00000000-0000-0000-0000-000000000212'::uuid,
    '00000000-0000-0000-0000-000000000302'::uuid,
    '00000000-0000-0000-0000-000000000312'::uuid,
    '00000000-0000-0000-0000-000000000322'::uuid,
    '00000000-0000-0000-0000-000000000402'::uuid,
    '00000000-0000-0000-0000-000000000412'::uuid,
    '00000000-0000-0000-0000-000000000422'::uuid,
    '00000000-0000-0000-0000-000000000502'::uuid,
    '00000000-0000-0000-0000-000000000512'::uuid,
    '00000000-0000-0000-0000-000000000522'::uuid,
    '00000000-0000-0000-0000-000000000532'::uuid
  ],
  'A1 reads his own plan only: no template, nothing of A2''s, B1''s, X''s or T1''s own'
);

select throws_ok(
  $$ insert into public.mesocycles (trainer_id, athlete_id, name)
     values (tests.user_id('t1'), tests.user_id('a1'), 'Mi bloque') $$,
  '42501', 'new row violates row-level security policy for table "mesocycles"',
  'A1 cannot create a mesocycle for himself'
);

select throws_ok(
  $$ insert into public.training_days (trainer_id, athlete_id, mesocycle_id, name)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000102', 'Día extra') $$,
  '42501', 'new row violates row-level security policy for table "training_days"',
  'A1 cannot add a day to his own mesocycle'
);

select throws_ok(
  $$ insert into public.day_exercises (trainer_id, athlete_id, training_day_id, exercise_id)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-0000000000e1') $$,
  '42501', 'new row violates row-level security policy for table "day_exercises"',
  'A1 cannot add an exercise to his own day'
);

select throws_ok(
  $$ insert into public.exercise_prescriptions (trainer_id, athlete_id, day_exercise_id, from_week)
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000302', 2) $$,
  '42501', 'new row violates row-level security policy for table "exercise_prescriptions"',
  'A1 cannot add a prescription to his own exercise'
);

select throws_ok(
  $$ insert into public.prescribed_sets (
       trainer_id, athlete_id, exercise_prescription_id, set_number, target_reps_min, target_reps_max
     )
     values (tests.user_id('t1'), tests.user_id('a1'),
             '00000000-0000-0000-0000-000000000402', 3, 8, 10) $$,
  '42501', 'new row violates row-level security policy for table "prescribed_sets"',
  'A1 cannot add a set to his own prescription'
);

-- The trainer policy lets a row through when trainer_id is the caller and
-- athlete_id is null; the FK to trainers then rejects it.
select throws_ok(
  $$ insert into public.mesocycles (trainer_id, name) values (tests.user_id('a1'), 'Plantilla propia') $$,
  '23503',
  'insert or update on table "mesocycles" violates foreign key constraint "mesocycles_trainer_id_fkey"',
  'A1 cannot create a template of his own (he is not a trainer)'
);

select is_empty(
  $$ with m as (update public.mesocycles set name = 'Hacked' returning id),
          d as (update public.training_days set name = 'Hacked' returning id),
          e as (update public.day_exercises set notes = 'Hacked' returning id),
          p as (update public.exercise_prescriptions set from_week = 9 returning id),
          s as (update public.prescribed_sets set notes = 'Hacked' returning id)
     select id from m union all select id from d union all select id from e
     union all select id from p union all select id from s $$,
  'A1 cannot update any plan row, his own included (no row is updated)'
);

select is_empty(
  $$ with s as (delete from public.prescribed_sets returning id),
          p as (delete from public.exercise_prescriptions returning id),
          e as (delete from public.day_exercises returning id),
          d as (delete from public.training_days returning id),
          m as (delete from public.mesocycles returning id)
     select id from m union all select id from d union all select id from e
     union all select id from p union all select id from s $$,
  'A1 cannot delete any plan row, his own included (no row is deleted)'
);

-- ---------------------------------------------------------------------------
-- B1 and T2: the other trainer's side
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('b1'));

select set_eq(
  $$ select id from public.mesocycles
     union all select id from public.training_days
     union all select id from public.day_exercises
     union all select id from public.exercise_prescriptions
     union all select id from public.prescribed_sets $$,
  array[
    '00000000-0000-0000-0000-000000000107'::uuid,
    '00000000-0000-0000-0000-000000000207'::uuid,
    '00000000-0000-0000-0000-000000000307'::uuid,
    '00000000-0000-0000-0000-000000000407'::uuid,
    '00000000-0000-0000-0000-000000000507'::uuid,
    '00000000-0000-0000-0000-000000000108'::uuid,
    '00000000-0000-0000-0000-000000000208'::uuid
  ],
  'B1 reads his plan from T2 and his old plan from T1: no template, nothing of T1''s athletes'
);

select tests.authenticate_as(tests.user_id('t2'));

select set_eq(
  $$ select id from public.mesocycles
     union all select id from public.training_days
     union all select id from public.day_exercises
     union all select id from public.exercise_prescriptions
     union all select id from public.prescribed_sets $$,
  array[
    '00000000-0000-0000-0000-000000000106'::uuid,
    '00000000-0000-0000-0000-000000000206'::uuid,
    '00000000-0000-0000-0000-000000000306'::uuid,
    '00000000-0000-0000-0000-000000000406'::uuid,
    '00000000-0000-0000-0000-000000000506'::uuid,
    '00000000-0000-0000-0000-000000000107'::uuid,
    '00000000-0000-0000-0000-000000000207'::uuid,
    '00000000-0000-0000-0000-000000000307'::uuid,
    '00000000-0000-0000-0000-000000000407'::uuid,
    '00000000-0000-0000-0000-000000000507'::uuid
  ],
  'T2 sees his template and B1''s plan: nothing of T1''s, not even the plan T1 wrote for B1'
);

select is_empty(
  $$ update public.mesocycles set name = 'Hacked'
     where trainer_id = tests.user_id('t1') returning id $$,
  'T2 cannot update T1''s mesocycles (no row is updated)'
);

-- B1's old plan belongs to T1. The policy stops T2 from writing a row in T1's
-- name; the composite FK stops him from attaching his own row to it.
select throws_ok(
  $$ insert into public.training_days (trainer_id, athlete_id, mesocycle_id, name)
     values (tests.user_id('t1'), tests.user_id('b1'),
             '00000000-0000-0000-0000-000000000108', 'Día nuevo') $$,
  '42501', 'new row violates row-level security policy for table "training_days"',
  'T2 cannot add a day in T1''s name to the plan T1 wrote for B1'
);

select throws_ok(
  $$ insert into public.training_days (trainer_id, athlete_id, mesocycle_id, name)
     values (tests.user_id('t2'), tests.user_id('b1'),
             '00000000-0000-0000-0000-000000000108', 'Día nuevo') $$,
  '23503',
  'insert or update on table "training_days" violates foreign key constraint "training_days_mesocycle_id_template_fkey"',
  'T2 cannot attach his own day to the plan T1 wrote for B1'
);

-- ---------------------------------------------------------------------------
-- X (former athlete of T1): reads his old plan and the library rows it uses
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('x'));

select set_eq(
  $$ select id from public.mesocycles
     union all select id from public.training_days
     union all select id from public.day_exercises
     union all select id from public.exercise_prescriptions
     union all select id from public.prescribed_sets $$,
  array[
    '00000000-0000-0000-0000-000000000104'::uuid,
    '00000000-0000-0000-0000-000000000204'::uuid,
    '00000000-0000-0000-0000-000000000304'::uuid,
    '00000000-0000-0000-0000-000000000404'::uuid,
    '00000000-0000-0000-0000-000000000504'::uuid
  ],
  'X still reads his old mesocycle and its whole tree after his link ended'
);

select set_eq(
  'select name from public.exercises',
  array['Press inclinado'],
  'X reads the exercise his old plan uses, not T1''s other exercises'
);

select set_eq(
  'select name from public.movement_categories',
  array['Empuje inclinado'],
  'X reads the category of that exercise, not T1''s other categories'
);

select is_empty(
  $$ with m as (update public.mesocycles set name = 'Hacked' returning id),
          s as (update public.prescribed_sets set notes = 'Hacked' returning id),
          e as (update public.exercises set name = 'Hacked' returning id)
     select id from m union all select id from s union all select id from e $$,
  'X cannot update his old plan or the exercise it uses (no row is updated)'
);

-- ---------------------------------------------------------------------------
-- U (no links): nothing
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('u'));

select is_empty(
  $$ select id from public.mesocycles
     union all select id from public.training_days
     union all select id from public.day_exercises
     union all select id from public.exercise_prescriptions
     union all select id from public.prescribed_sets $$,
  'U reads no plan row'
);

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------

select tests.clear_authentication();
set local role anon;

select throws_ok('select 1 from public.mesocycles', '42501', null, 'anon cannot read mesocycles');
select throws_ok('select 1 from public.training_days', '42501', null, 'anon cannot read training_days');
select throws_ok('select 1 from public.day_exercises', '42501', null, 'anon cannot read day_exercises');
select throws_ok(
  'select 1 from public.exercise_prescriptions', '42501', null,
  'anon cannot read exercise_prescriptions'
);
select throws_ok('select 1 from public.prescribed_sets', '42501', null, 'anon cannot read prescribed_sets');

-- ---------------------------------------------------------------------------
-- Self-link: T1 reads his own mesocycle through the athlete policy too.
-- With his self-link ended (as postgres) the trainer policy no longer covers
-- that mesocycle, so what he still reads comes from the athlete policy.
-- ---------------------------------------------------------------------------

select tests.clear_authentication();

update public.trainer_athletes
set ended_at = now()
where trainer_id = tests.user_id('t1') and athlete_id = tests.user_id('t1');

select tests.authenticate_as(tests.user_id('t1'));

select set_eq(
  $$ select id from public.mesocycles where athlete_id = tests.user_id('t1')
     union all select id from public.training_days where athlete_id = tests.user_id('t1') $$,
  array[
    '00000000-0000-0000-0000-000000000105'::uuid,
    '00000000-0000-0000-0000-000000000115'::uuid,
    '00000000-0000-0000-0000-000000000205'::uuid
  ],
  'with his self-link ended, T1 still reads his own mesocycles as their athlete'
);

select is_empty(
  $$ update public.mesocycles set name = 'Hacked'
     where athlete_id = tests.user_id('t1') returning id $$,
  'with his self-link ended, T1 can no longer write his own mesocycles (he reads them as an athlete)'
);

-- ---------------------------------------------------------------------------
-- Deletes: cascade down the tree, lineage set to null, athletes cascade
-- ---------------------------------------------------------------------------

select isnt_empty(
  $$ delete from public.mesocycles
     where id = '00000000-0000-0000-0000-000000000101' returning id $$,
  'T1 can delete his template'
);

select is_empty(
  $$ select id from public.training_days where is_template
     union all select id from public.day_exercises where is_template
     union all select id from public.exercise_prescriptions where is_template
     union all select id from public.prescribed_sets where is_template $$,
  'deleting a template removes its days, exercises, prescriptions and sets'
);

select results_eq(
  $$ select copied_from_id, trainer_id = tests.user_id('t1') from public.mesocycles
     where id = '00000000-0000-0000-0000-000000000102' $$,
  $$ values (null::uuid, true) $$,
  'deleting the source sets copied_from_id to null on the copy and leaves its trainer_id'
);

select tests.clear_authentication();

select lives_ok(
  $$ delete from auth.users where id = tests.user_id('a1') $$,
  'deleting an athlete''s user is allowed while he has plans'
);

select is_empty(
  $$ select id from public.mesocycles where id = '00000000-0000-0000-0000-000000000102'
     union all
     select id from public.training_days
     where mesocycle_id = '00000000-0000-0000-0000-000000000102'
     union all
     select id from public.day_exercises
     where training_day_id in (
       '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000212'
     )
     union all
     select id from public.exercise_prescriptions
     where day_exercise_id in (
       '00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000312',
       '00000000-0000-0000-0000-000000000322'
     )
     union all
     select id from public.prescribed_sets
     where exercise_prescription_id in (
       '00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-000000000412',
       '00000000-0000-0000-0000-000000000422'
     ) $$,
  'deleting an athlete''s user removes his whole plan'
);

select results_eq(
  $$ select count(*) from public.prescribed_sets where athlete_id = tests.user_id('a2') $$,
  $$ values (1::bigint) $$,
  'deleting an athlete''s user leaves another athlete''s plan untouched'
);

select * from finish();

rollback;
