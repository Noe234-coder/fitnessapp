-- Athlete logs: training_sessions, set_logs, meal_logs, daily_metrics,
-- body_measurements, weekly_checkins (docs/schema-v1.md §4 "Athlete logs" and
-- "Log integrity rules", §5, §6).
-- Fixtures (supabase/seed.sql): t1 (self-linked trainer) with a1, a2; t2 with b1;
-- x former athlete of t1; u with no links.
--
-- Row ids are fixed. The last four digits are <table><owner>:
--   table  01 mesocycles · 02 training_days · 03 day_exercises
--          11 meal_plans · 12 meals · 13 meal_options
--          21 training_sessions · 22 set_logs · 23 meal_logs
--          24 daily_metrics · 25 body_measurements · 26 weekly_checkins
--   owner  …01 T1's template   …02 A1   …03 A2   …04 X (old, by T1)
--          …05 T1 as his own athlete   …07 B1 (by T2)
--   A second row of the same table and owner has the third digit raised:
--   …0212 is A1's second training day, …2112 his week-2 session.
-- Library: …e1 / …e3 exercises of T1 · …e2 exercise of T2.
-- 2026-11-02, 2026-11-09 and 2026-09-07 are Mondays; 2026-11-03 is a Tuesday.

begin;

select plan(82);

-- ---------------------------------------------------------------------------
-- Plans and other athletes' logs (as postgres; rolled back at the end)
-- ---------------------------------------------------------------------------

insert into public.exercises (id, trainer_id, name)
values
  ('00000000-0000-0000-0000-0000000000e1', tests.user_id('t1'), 'Press inclinado'),
  ('00000000-0000-0000-0000-0000000000e3', tests.user_id('t1'), 'Sentadilla'),
  ('00000000-0000-0000-0000-0000000000e2', tests.user_id('t2'), 'Dominadas');

insert into public.mesocycles (id, trainer_id, athlete_id, name, starts_on, status)
values
  ('00000000-0000-0000-0000-000000000101', tests.user_id('t1'), null, 'Plantilla', null, 'draft'),
  ('00000000-0000-0000-0000-000000000102', tests.user_id('t1'), tests.user_id('a1'),
   'Bloque de A1', '2026-11-02', 'active'),
  ('00000000-0000-0000-0000-000000000103', tests.user_id('t1'), tests.user_id('a2'),
   'Bloque de A2', '2026-11-02', 'active'),
  ('00000000-0000-0000-0000-000000000104', tests.user_id('t1'), tests.user_id('x'),
   'Bloque antiguo de X', '2026-09-07', 'archived'),
  ('00000000-0000-0000-0000-000000000105', tests.user_id('t1'), tests.user_id('t1'),
   'Bloque de T1', '2026-11-02', 'active'),
  ('00000000-0000-0000-0000-000000000107', tests.user_id('t2'), tests.user_id('b1'),
   'Bloque de B1', '2026-11-02', 'active');

insert into public.training_days (id, trainer_id, athlete_id, mesocycle_id, name, position, kind)
values
  ('00000000-0000-0000-0000-000000000201', tests.user_id('t1'), null,
   '00000000-0000-0000-0000-000000000101', 'Torso', 1, 'training'),
  ('00000000-0000-0000-0000-000000000202', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000000102', 'Torso', 1, 'training'),
  ('00000000-0000-0000-0000-000000000212', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000000102', 'Pierna', 2, 'training'),
  ('00000000-0000-0000-0000-000000000222', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000000102', 'Movilidad', 0, 'warmup'),
  ('00000000-0000-0000-0000-000000000203', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000000103', 'Torso', 1, 'training'),
  ('00000000-0000-0000-0000-000000000204', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000000104', 'Torso', 1, 'training'),
  ('00000000-0000-0000-0000-000000000205', tests.user_id('t1'), tests.user_id('t1'),
   '00000000-0000-0000-0000-000000000105', 'Torso', 1, 'training'),
  ('00000000-0000-0000-0000-000000000207', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000000107', 'Cuerpo completo', 1, 'training');

insert into public.day_exercises (id, trainer_id, athlete_id, training_day_id, exercise_id, position)
values
  ('00000000-0000-0000-0000-000000000302', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-0000000000e1', 1),
  ('00000000-0000-0000-0000-000000000312', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000000212', '00000000-0000-0000-0000-0000000000e3', 1),
  ('00000000-0000-0000-0000-000000000303', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-0000000000e1', 1),
  ('00000000-0000-0000-0000-000000000304', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000000204', '00000000-0000-0000-0000-0000000000e1', 1),
  ('00000000-0000-0000-0000-000000000305', tests.user_id('t1'), tests.user_id('t1'),
   '00000000-0000-0000-0000-000000000205', '00000000-0000-0000-0000-0000000000e1', 1),
  ('00000000-0000-0000-0000-000000000307', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000000207', '00000000-0000-0000-0000-0000000000e2', 1);

insert into public.meal_plans (id, trainer_id, athlete_id, name, status)
values
  ('00000000-0000-0000-0000-000000001102', tests.user_id('t1'), tests.user_id('a1'), 'Volumen', 'active'),
  ('00000000-0000-0000-0000-000000001103', tests.user_id('t1'), tests.user_id('a2'), 'Volumen', 'active'),
  ('00000000-0000-0000-0000-000000001104', tests.user_id('t1'), tests.user_id('x'), 'Antiguo', 'archived'),
  ('00000000-0000-0000-0000-000000001107', tests.user_id('t2'), tests.user_id('b1'), 'Definición', 'active');

insert into public.meals (
  id, trainer_id, athlete_id, meal_plan_id, name, position,
  target_protein_g, target_carbs_g, target_fat_g
)
values
  ('00000000-0000-0000-0000-000000001202', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001102', 'Desayuno', 1, 30, 60, 15),
  ('00000000-0000-0000-0000-000000001212', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001102', 'Comida', 2, 40, 80, 20),
  ('00000000-0000-0000-0000-000000001203', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000001103', 'Desayuno', 1, 30, 60, 15),
  ('00000000-0000-0000-0000-000000001204', tests.user_id('t1'), tests.user_id('x'),
   '00000000-0000-0000-0000-000000001104', 'Desayuno', 1, 30, 60, 15),
  ('00000000-0000-0000-0000-000000001207', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001107', 'Desayuno', 1, 30, 60, 15);

insert into public.meal_options (id, trainer_id, athlete_id, meal_id, position, label)
values
  ('00000000-0000-0000-0000-000000001302', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001202', 1, 'Avena'),
  ('00000000-0000-0000-0000-000000001322', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001202', 2, 'Tostadas'),
  ('00000000-0000-0000-0000-000000001312', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001212', 1, 'Arroz');

-- Logs of A2, X (written while he trained with T1) and B1.
insert into public.training_sessions (id, athlete_id, training_day_id, program_week, performed_on)
values
  ('00000000-0000-0000-0000-000000002103', tests.user_id('a2'),
   '00000000-0000-0000-0000-000000000203', 1, '2026-11-03'),
  ('00000000-0000-0000-0000-000000002104', tests.user_id('x'),
   '00000000-0000-0000-0000-000000000204', 1, '2026-09-08'),
  ('00000000-0000-0000-0000-000000002107', tests.user_id('b1'),
   '00000000-0000-0000-0000-000000000207', 1, '2026-11-03');

insert into public.set_logs (
  id, athlete_id, training_session_id, training_day_id, day_exercise_id, set_number, reps, weight_kg
)
values
  ('00000000-0000-0000-0000-000000002203', tests.user_id('a2'), '00000000-0000-0000-0000-000000002103',
   '00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000303', 1, 10, 40),
  ('00000000-0000-0000-0000-000000002204', tests.user_id('x'), '00000000-0000-0000-0000-000000002104',
   '00000000-0000-0000-0000-000000000204', '00000000-0000-0000-0000-000000000304', 1, 10, 40),
  ('00000000-0000-0000-0000-000000002207', tests.user_id('b1'), '00000000-0000-0000-0000-000000002107',
   '00000000-0000-0000-0000-000000000207', '00000000-0000-0000-0000-000000000307', 1, 10, 0);

insert into public.meal_logs (id, athlete_id, meal_id, logged_on)
values
  ('00000000-0000-0000-0000-000000002303', tests.user_id('a2'),
   '00000000-0000-0000-0000-000000001203', '2026-11-03'),
  ('00000000-0000-0000-0000-000000002304', tests.user_id('x'),
   '00000000-0000-0000-0000-000000001204', '2026-09-08'),
  ('00000000-0000-0000-0000-000000002307', tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001207', '2026-11-03');

insert into public.daily_metrics (id, athlete_id, recorded_on, fasted_weight_kg)
values
  ('00000000-0000-0000-0000-000000002403', tests.user_id('a2'), '2026-11-04', 70),
  ('00000000-0000-0000-0000-000000002404', tests.user_id('x'), '2026-09-08', 90),
  ('00000000-0000-0000-0000-000000002407', tests.user_id('b1'), '2026-11-03', 60);

insert into public.body_measurements (id, athlete_id, measured_on, navel_cm)
values
  ('00000000-0000-0000-0000-000000002503', tests.user_id('a2'), '2026-11-09', 80),
  ('00000000-0000-0000-0000-000000002504', tests.user_id('x'), '2026-09-07', 95),
  ('00000000-0000-0000-0000-000000002507', tests.user_id('b1'), '2026-11-02', 70);

insert into public.weekly_checkins (id, athlete_id, week_starts_on, energy)
values
  ('00000000-0000-0000-0000-000000002603', tests.user_id('a2'), '2026-11-02', 'high'),
  ('00000000-0000-0000-0000-000000002604', tests.user_id('x'), '2026-09-07', 'low'),
  ('00000000-0000-0000-0000-000000002607', tests.user_id('b1'), '2026-11-02', 'medium');

-- ---------------------------------------------------------------------------
-- A1 logs his week
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('a1'));

select lives_ok(
  $$ insert into public.training_sessions (id, athlete_id, training_day_id, program_week, performed_on)
     values
       ('00000000-0000-0000-0000-000000002102', tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000202', 1, '2026-11-03'),
       ('00000000-0000-0000-0000-000000002112', tests.user_id('a1'),
        '00000000-0000-0000-0000-000000000202', 2, '2026-11-10') $$,
  'A1 can log sessions of his own training day in weeks 1 and 2'
);

select lives_ok(
  $$ insert into public.set_logs (
       id, athlete_id, training_session_id, training_day_id, day_exercise_id, set_number, reps, weight_kg
     )
     values
       ('00000000-0000-0000-0000-000000002202', tests.user_id('a1'),
        '00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000000202',
        '00000000-0000-0000-0000-000000000302', 1, 8, 60),
       ('00000000-0000-0000-0000-000000002212', tests.user_id('a1'),
        '00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000000202',
        '00000000-0000-0000-0000-000000000302', 2, 7, 60),
       ('00000000-0000-0000-0000-000000002222', tests.user_id('a1'),
        '00000000-0000-0000-0000-000000002112', '00000000-0000-0000-0000-000000000202',
        '00000000-0000-0000-0000-000000000302', 1, 8, 62.5) $$,
  'A1 can log sets of the exercises of his session''s day'
);

select lives_ok(
  $$ insert into public.set_logs (
       id, athlete_id, training_session_id, training_day_id, day_exercise_id, set_number
     )
     values ('00000000-0000-0000-0000-000000002232', tests.user_id('a1'),
             '00000000-0000-0000-0000-000000002102', '00000000-0000-0000-0000-000000000202',
             '00000000-0000-0000-0000-000000000302', 3) $$,
  'A1 can save a set before typing its reps and weight (both nullable)'
);

select lives_ok(
  $$ insert into public.meal_logs (id, athlete_id, meal_id, logged_on, meal_option_id)
     values
       ('00000000-0000-0000-0000-000000002302', tests.user_id('a1'),
        '00000000-0000-0000-0000-000000001202', '2026-11-03', '00000000-0000-0000-0000-000000001302'),
       ('00000000-0000-0000-0000-000000002312', tests.user_id('a1'),
        '00000000-0000-0000-0000-000000001212', '2026-11-03', null) $$,
  'A1 can tick two meals: one with the option eaten, one without'
);

select lives_ok(
  $$ insert into public.daily_metrics (
       id, athlete_id, recorded_on, fasted_weight_kg, steps, sleep_minutes, stress
     )
     values ('00000000-0000-0000-0000-000000002402', tests.user_id('a1'),
             '2026-11-03', 80.5, 9000, 420, 3) $$,
  'A1 can log his daily metrics'
);

select lives_ok(
  $$ insert into public.body_measurements (
       id, athlete_id, measured_on, chest_cm, navel_cm, hip_cm, glute_cm, neck_cm
     )
     values ('00000000-0000-0000-0000-000000002502', tests.user_id('a1'),
             '2026-11-02', 100, 85.5, 95, 98, 38) $$,
  'A1 can log his body measurements'
);

select lives_ok(
  $$ insert into public.weekly_checkins (
       id, athlete_id, week_starts_on, training_adherence, recovery, can_progress, energy,
       motivation, diet_adherence, satiety, diet_satisfaction, sleep_quality, message_to_trainer
     )
     values ('00000000-0000-0000-0000-000000002602', tests.user_id('a1'), '2026-11-02',
             'gt_80', 'slight_soreness', 'yes_some', 'high', 'very_high', '100', 3, 'medium',
             'good', 'Buena semana') $$,
  'A1 can send his weekly check-in with codes from every list'
);

select isnt_empty(
  $$ update public.set_logs set reps = 9
     where id = '00000000-0000-0000-0000-000000002212' returning id $$,
  'A1 can update his own set log'
);

select isnt_empty(
  $$ delete from public.meal_logs
     where id = '00000000-0000-0000-0000-000000002312' returning id $$,
  'A1 can untick a meal (delete his own meal log)'
);

-- Upsert on the natural key (D12): select, insert and update policies all apply.
select lives_ok(
  $$ insert into public.daily_metrics (athlete_id, recorded_on, steps)
     values (tests.user_id('a1'), '2026-11-03', 12000)
     on conflict (athlete_id, recorded_on) do update set steps = excluded.steps $$,
  'A1 can upsert his daily metrics on (athlete_id, recorded_on)'
);

select results_eq(
  $$ select id, fasted_weight_kg, steps from public.daily_metrics
     where athlete_id = tests.user_id('a1') $$,
  $$ values ('00000000-0000-0000-0000-000000002402'::uuid, 80.50::numeric, 12000) $$,
  'the upsert updated the same row: one row, the new steps, the weight kept'
);

select set_eq(
  $$ select id from public.training_sessions
     union all select id from public.set_logs
     union all select id from public.meal_logs
     union all select id from public.daily_metrics
     union all select id from public.body_measurements
     union all select id from public.weekly_checkins $$,
  array[
    '00000000-0000-0000-0000-000000002102'::uuid, '00000000-0000-0000-0000-000000002112'::uuid,
    '00000000-0000-0000-0000-000000002202'::uuid, '00000000-0000-0000-0000-000000002212'::uuid,
    '00000000-0000-0000-0000-000000002222'::uuid, '00000000-0000-0000-0000-000000002232'::uuid,
    '00000000-0000-0000-0000-000000002302'::uuid, '00000000-0000-0000-0000-000000002402'::uuid,
    '00000000-0000-0000-0000-000000002502'::uuid, '00000000-0000-0000-0000-000000002602'::uuid
  ],
  'A1 reads his own logs only: nothing of A2''s, B1''s or X''s'
);

-- ---------------------------------------------------------------------------
-- A1 cannot write for others
-- ---------------------------------------------------------------------------

select throws_ok(
  $$ insert into public.daily_metrics (athlete_id, recorded_on, steps)
     values (tests.user_id('a2'), '2026-11-04', 5000) $$,
  '42501', 'new row violates row-level security policy for table "daily_metrics"',
  'A1 cannot log daily metrics for A2'
);

select throws_ok(
  $$ insert into public.training_sessions (athlete_id, training_day_id, program_week, performed_on)
     values (tests.user_id('a2'), '00000000-0000-0000-0000-000000000203', 2, '2026-11-10') $$,
  '42501', 'new row violates row-level security policy for table "training_sessions"',
  'A1 cannot log a session for A2'
);

select is_empty(
  $$ with s as (
       update public.training_sessions set notes = 'Hacked'
       where athlete_id <> tests.user_id('a1') returning id
     ),
     l as (
       update public.set_logs set reps = 0
       where athlete_id <> tests.user_id('a1') returning id
     ),
     m as (
       update public.meal_logs set logged_on = '2026-01-01'
       where athlete_id <> tests.user_id('a1') returning id
     ),
     d as (
       update public.daily_metrics set steps = 0
       where athlete_id <> tests.user_id('a1') returning id
     ),
     b as (
       update public.body_measurements set navel_cm = 1
       where athlete_id <> tests.user_id('a1') returning id
     ),
     c as (
       update public.weekly_checkins set energy = 'low'
       where athlete_id <> tests.user_id('a1') returning id
     )
     select id from s union all select id from l union all select id from m
     union all select id from d union all select id from b union all select id from c $$,
  'A1 cannot update anyone else''s logs (no row is updated)'
);

select is_empty(
  $$ with l as (
       delete from public.set_logs where athlete_id <> tests.user_id('a1') returning id
     ),
     s as (
       delete from public.training_sessions where athlete_id <> tests.user_id('a1') returning id
     ),
     m as (
       delete from public.meal_logs where athlete_id <> tests.user_id('a1') returning id
     ),
     d as (
       delete from public.daily_metrics where athlete_id <> tests.user_id('a1') returning id
     ),
     b as (
       delete from public.body_measurements where athlete_id <> tests.user_id('a1') returning id
     ),
     c as (
       delete from public.weekly_checkins where athlete_id <> tests.user_id('a1') returning id
     )
     select id from s union all select id from l union all select id from m
     union all select id from d union all select id from b union all select id from c $$,
  'A1 cannot delete anyone else''s logs (no row is deleted)'
);

-- ---------------------------------------------------------------------------
-- FK guarantees: a log only points at the athlete's own plan, consistently
-- ---------------------------------------------------------------------------

select throws_ok(
  $$ insert into public.set_logs (
       athlete_id, training_session_id, training_day_id, day_exercise_id, set_number, reps
     )
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000002103',
             '00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000302', 1, 5) $$,
  '23503', null,
  'A1''s set log pointing at A2''s session is rejected'
);

select throws_ok(
  $$ insert into public.set_logs (
       athlete_id, training_session_id, training_day_id, day_exercise_id, set_number, reps
     )
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000002102',
             '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000312', 1, 5) $$,
  '23503',
  'insert or update on table "set_logs" violates foreign key constraint "set_logs_day_exercise_id_training_day_id_fkey"',
  'a set of an exercise of another day of the mesocycle is rejected (training_day_id = the session''s day)'
);

select throws_ok(
  $$ insert into public.set_logs (
       athlete_id, training_session_id, training_day_id, day_exercise_id, set_number, reps
     )
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000002102',
             '00000000-0000-0000-0000-000000000212', '00000000-0000-0000-0000-000000000312', 1, 5) $$,
  '23503',
  'insert or update on table "set_logs" violates foreign key constraint "set_logs_training_session_id_training_day_id_fkey"',
  'a set of an exercise of another day of the mesocycle is rejected (training_day_id = the exercise''s day)'
);

select throws_ok(
  $$ insert into public.training_sessions (athlete_id, training_day_id, program_week, performed_on)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000000201', 1, '2026-11-03') $$,
  '23503',
  'insert or update on table "training_sessions" violates foreign key constraint "training_sessions_training_day_id_athlete_id_fkey"',
  'a session on a template day is rejected'
);

select throws_ok(
  $$ insert into public.training_sessions (athlete_id, training_day_id, program_week, performed_on)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000000203', 2, '2026-11-10') $$,
  '23503',
  'insert or update on table "training_sessions" violates foreign key constraint "training_sessions_training_day_id_athlete_id_fkey"',
  'A1 cannot log a session on A2''s training day'
);

select throws_ok(
  $$ insert into public.meal_logs (athlete_id, meal_id, logged_on, meal_option_id)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000001202', '2026-11-04',
             '00000000-0000-0000-0000-000000001312') $$,
  '23503',
  'insert or update on table "meal_logs" violates foreign key constraint "meal_logs_meal_option_id_meal_id_fkey"',
  'a meal log whose option belongs to another meal is rejected'
);

select throws_ok(
  $$ insert into public.meal_logs (athlete_id, meal_id, logged_on)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000001203', '2026-11-04') $$,
  '23503',
  'insert or update on table "meal_logs" violates foreign key constraint "meal_logs_meal_id_athlete_id_fkey"',
  'A1 cannot tick a meal of A2''s plan'
);

-- ---------------------------------------------------------------------------
-- Triggers and checks
-- ---------------------------------------------------------------------------

select throws_ok(
  $$ insert into public.training_sessions (athlete_id, training_day_id, program_week, performed_on)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000000222', 1, '2026-11-03') $$,
  '23514', 'warmup_day_not_loggable',
  'a session on a warm-up day is rejected'
);

select throws_ok(
  $$ insert into public.training_sessions (athlete_id, training_day_id, program_week, performed_on)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000000202', 1, '2026-11-05') $$,
  '23505', null,
  'a second session of the same day in the same program week is rejected'
);

select throws_ok(
  $$ insert into public.training_sessions (athlete_id, training_day_id, program_week, performed_on)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000000212', 0, '2026-11-03') $$,
  '23514',
  'new row for relation "training_sessions" violates check constraint "training_sessions_program_week_check"',
  'program week 0 is rejected'
);

select throws_ok(
  $$ update public.set_logs set reps = -1 where id = '00000000-0000-0000-0000-000000002202' $$,
  '23514', 'new row for relation "set_logs" violates check constraint "set_logs_reps_check"',
  'negative reps are rejected'
);

select throws_ok(
  $$ update public.daily_metrics set sleep_minutes = 1441
     where id = '00000000-0000-0000-0000-000000002402' $$,
  '23514',
  'new row for relation "daily_metrics" violates check constraint "daily_metrics_sleep_minutes_check"',
  'more than 1440 minutes of sleep is rejected'
);

select throws_ok(
  $$ update public.daily_metrics set stress = 11 where id = '00000000-0000-0000-0000-000000002402' $$,
  '23514', 'new row for relation "daily_metrics" violates check constraint "daily_metrics_stress_check"',
  'stress above 10 is rejected'
);

select throws_ok(
  $$ update public.body_measurements set neck_cm = 0
     where id = '00000000-0000-0000-0000-000000002502' $$,
  '23514',
  'new row for relation "body_measurements" violates check constraint "body_measurements_neck_cm_check"',
  'a measurement of 0 cm is rejected'
);

select throws_ok(
  $$ insert into public.weekly_checkins (athlete_id, week_starts_on, training_adherence)
     values (tests.user_id('a1'), '2026-11-09', 'gt_90') $$,
  '23514',
  'new row for relation "weekly_checkins" violates check constraint "weekly_checkins_training_adherence_check"',
  'an adherence code outside the list is rejected'
);

select throws_ok(
  $$ insert into public.weekly_checkins (athlete_id, week_starts_on, recovery)
     values (tests.user_id('a1'), '2026-11-09', 'Muy buena') $$,
  '23514',
  'new row for relation "weekly_checkins" violates check constraint "weekly_checkins_recovery_check"',
  'a recovery answer that is a label, not a code, is rejected'
);

select throws_ok(
  $$ insert into public.weekly_checkins (athlete_id, week_starts_on, sleep_quality)
     values (tests.user_id('a1'), '2026-11-09', 'very_good') $$,
  '23514',
  'new row for relation "weekly_checkins" violates check constraint "weekly_checkins_sleep_quality_check"',
  'a sleep quality code from another list is rejected'
);

select throws_ok(
  $$ insert into public.weekly_checkins (athlete_id, week_starts_on)
     values (tests.user_id('a1'), '2026-11-10') $$,
  '23514',
  'new row for relation "weekly_checkins" violates check constraint "weekly_checkins_week_starts_on_monday_check"',
  'a check-in week that does not start on a Monday is rejected'
);

select throws_ok(
  $$ insert into public.weekly_checkins (athlete_id, week_starts_on, satiety)
     values (tests.user_id('a1'), '2026-11-09', 0) $$,
  '23514', 'new row for relation "weekly_checkins" violates check constraint "weekly_checkins_satiety_check"',
  'satiety 0 is rejected'
);

select throws_ok(
  $$ insert into public.weekly_checkins (athlete_id, week_starts_on, satiety)
     values (tests.user_id('a1'), '2026-11-09', 6) $$,
  '23514', 'new row for relation "weekly_checkins" violates check constraint "weekly_checkins_satiety_check"',
  'satiety 6 is rejected'
);

-- Ownership columns are immutable (§4 "Log integrity rules").
select throws_ok(
  $$ update public.daily_metrics set athlete_id = tests.user_id('a2')
     where id = '00000000-0000-0000-0000-000000002402' $$,
  '23514', 'log_ownership_immutable',
  'A1 cannot move his daily metrics to A2 (ownership trigger)'
);

select throws_ok(
  $$ update public.set_logs set training_session_id = '00000000-0000-0000-0000-000000002112'
     where id = '00000000-0000-0000-0000-000000002212' $$,
  '23514', 'log_ownership_immutable',
  'A1 cannot move a set to his other session of the same day (ownership trigger)'
);

-- ---------------------------------------------------------------------------
-- T1: reads his active athletes' logs, corrects three tables, writes nothing else
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('t1'));

select set_eq(
  $$ select id from public.training_sessions
     union all select id from public.set_logs
     union all select id from public.meal_logs
     union all select id from public.daily_metrics
     union all select id from public.body_measurements
     union all select id from public.weekly_checkins $$,
  array[
    '00000000-0000-0000-0000-000000002102'::uuid, '00000000-0000-0000-0000-000000002112'::uuid,
    '00000000-0000-0000-0000-000000002202'::uuid, '00000000-0000-0000-0000-000000002212'::uuid,
    '00000000-0000-0000-0000-000000002222'::uuid, '00000000-0000-0000-0000-000000002232'::uuid,
    '00000000-0000-0000-0000-000000002302'::uuid, '00000000-0000-0000-0000-000000002402'::uuid,
    '00000000-0000-0000-0000-000000002502'::uuid, '00000000-0000-0000-0000-000000002602'::uuid,
    '00000000-0000-0000-0000-000000002103'::uuid, '00000000-0000-0000-0000-000000002203'::uuid,
    '00000000-0000-0000-0000-000000002303'::uuid, '00000000-0000-0000-0000-000000002403'::uuid,
    '00000000-0000-0000-0000-000000002503'::uuid, '00000000-0000-0000-0000-000000002603'::uuid
  ],
  'T1 reads A1''s and A2''s logs: not B1''s, and not X''s since his link ended'
);

select isnt_empty(
  $$ update public.set_logs set reps = 10, weight_kg = 57.5
     where id = '00000000-0000-0000-0000-000000002202' returning id $$,
  'T1 can correct the reps and weight of A1''s set log'
);

select isnt_empty(
  $$ update public.daily_metrics set fasted_weight_kg = 80.2
     where id = '00000000-0000-0000-0000-000000002402' returning id $$,
  'T1 can correct A1''s daily metrics'
);

select isnt_empty(
  $$ update public.body_measurements set navel_cm = 85
     where id = '00000000-0000-0000-0000-000000002502' returning id $$,
  'T1 can correct A1''s body measurements'
);

select results_eq(
  $$ select s.reps, s.weight_kg, d.fasted_weight_kg, b.navel_cm
     from public.set_logs s, public.daily_metrics d, public.body_measurements b
     where s.id = '00000000-0000-0000-0000-000000002202'
       and d.id = '00000000-0000-0000-0000-000000002402'
       and b.id = '00000000-0000-0000-0000-000000002502' $$,
  $$ values (10::smallint, 57.50::numeric, 80.20::numeric, 85.0::numeric) $$,
  'the corrections are stored'
);

select is_empty(
  $$ with c as (
       update public.weekly_checkins set energy = 'low'
       where athlete_id = tests.user_id('a1') returning id
     ),
     m as (
       update public.meal_logs set meal_option_id = null
       where athlete_id = tests.user_id('a1') returning id
     ),
     s as (
       update public.training_sessions set notes = 'Corrected'
       where athlete_id = tests.user_id('a1') returning id
     )
     select id from c union all select id from m union all select id from s $$,
  'T1 cannot update A1''s check-ins, meal logs or sessions (no row is updated)'
);

select is_empty(
  $$ with l as (
       update public.set_logs set reps = 0
       where athlete_id in (tests.user_id('b1'), tests.user_id('x')) returning id
     ),
     d as (
       update public.daily_metrics set steps = 0
       where athlete_id in (tests.user_id('b1'), tests.user_id('x')) returning id
     ),
     b as (
       update public.body_measurements set navel_cm = 1
       where athlete_id in (tests.user_id('b1'), tests.user_id('x')) returning id
     )
     select id from l union all select id from d union all select id from b $$,
  'T1 cannot correct B1''s or X''s logs (no row is updated)'
);

select throws_ok(
  $$ update public.daily_metrics set athlete_id = tests.user_id('a2')
     where id = '00000000-0000-0000-0000-000000002402' $$,
  '23514', 'log_ownership_immutable',
  'T1 cannot move A1''s daily metrics to A2 (ownership trigger; the policy would accept it)'
);

select throws_ok(
  $$ update public.body_measurements set athlete_id = tests.user_id('a2')
     where id = '00000000-0000-0000-0000-000000002502' $$,
  '23514', 'log_ownership_immutable',
  'T1 cannot move A1''s body measurements to A2 (ownership trigger)'
);

select throws_ok(
  $$ update public.set_logs set training_session_id = '00000000-0000-0000-0000-000000002112'
     where id = '00000000-0000-0000-0000-000000002212' $$,
  '23514', 'log_ownership_immutable',
  'T1 cannot move A1''s set to another session (ownership trigger)'
);

select throws_ok(
  $$ insert into public.training_sessions (athlete_id, training_day_id, program_week, performed_on)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000000212', 1, '2026-11-04') $$,
  '42501', 'new row violates row-level security policy for table "training_sessions"',
  'T1 cannot log a session for A1'
);

select throws_ok(
  $$ insert into public.set_logs (
       athlete_id, training_session_id, training_day_id, day_exercise_id, set_number, reps
     )
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000002102',
             '00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000302', 4, 5) $$,
  '42501', 'new row violates row-level security policy for table "set_logs"',
  'T1 cannot log a set for A1'
);

select throws_ok(
  $$ insert into public.meal_logs (athlete_id, meal_id, logged_on)
     values (tests.user_id('a1'), '00000000-0000-0000-0000-000000001212', '2026-11-04') $$,
  '42501', 'new row violates row-level security policy for table "meal_logs"',
  'T1 cannot tick a meal for A1'
);

select throws_ok(
  $$ insert into public.daily_metrics (athlete_id, recorded_on, steps)
     values (tests.user_id('a1'), '2026-11-04', 5000) $$,
  '42501', 'new row violates row-level security policy for table "daily_metrics"',
  'T1 cannot log daily metrics for A1'
);

select throws_ok(
  $$ insert into public.body_measurements (athlete_id, measured_on, navel_cm)
     values (tests.user_id('a1'), '2026-11-09', 84) $$,
  '42501', 'new row violates row-level security policy for table "body_measurements"',
  'T1 cannot log measurements for A1'
);

select throws_ok(
  $$ insert into public.weekly_checkins (athlete_id, week_starts_on, energy)
     values (tests.user_id('a1'), '2026-11-09', 'high') $$,
  '42501', 'new row violates row-level security policy for table "weekly_checkins"',
  'T1 cannot send a check-in for A1'
);

select is_empty(
  $$ with l as (
       delete from public.set_logs where athlete_id <> tests.user_id('t1') returning id
     ),
     s as (
       delete from public.training_sessions where athlete_id <> tests.user_id('t1') returning id
     ),
     m as (
       delete from public.meal_logs where athlete_id <> tests.user_id('t1') returning id
     ),
     d as (
       delete from public.daily_metrics where athlete_id <> tests.user_id('t1') returning id
     ),
     b as (
       delete from public.body_measurements where athlete_id <> tests.user_id('t1') returning id
     ),
     c as (
       delete from public.weekly_checkins where athlete_id <> tests.user_id('t1') returning id
     )
     select id from s union all select id from l union all select id from m
     union all select id from d union all select id from b union all select id from c $$,
  'T1 cannot delete any athlete''s logs (no row is deleted)'
);

-- ---------------------------------------------------------------------------
-- Self-link: T1 logs his own training
-- ---------------------------------------------------------------------------

select lives_ok(
  $$ insert into public.training_sessions (id, athlete_id, training_day_id, program_week, performed_on)
     values ('00000000-0000-0000-0000-000000002105', tests.user_id('t1'),
             '00000000-0000-0000-0000-000000000205', 1, '2026-11-03') $$,
  'T1 can log a session of his own mesocycle'
);

select lives_ok(
  $$ insert into public.set_logs (
       id, athlete_id, training_session_id, training_day_id, day_exercise_id, set_number, reps, weight_kg
     )
     values ('00000000-0000-0000-0000-000000002205', tests.user_id('t1'),
             '00000000-0000-0000-0000-000000002105', '00000000-0000-0000-0000-000000000205',
             '00000000-0000-0000-0000-000000000305', 1, 6, 80) $$,
  'T1 can log a set of his own session'
);

select isnt_empty(
  $$ delete from public.set_logs
     where id = '00000000-0000-0000-0000-000000002205' returning id $$,
  'T1 can delete his own set log (as his own athlete)'
);

-- ---------------------------------------------------------------------------
-- Former athlete X: reads his logs, writes nothing
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('x'));

select set_eq(
  $$ select id from public.training_sessions
     union all select id from public.set_logs
     union all select id from public.meal_logs
     union all select id from public.daily_metrics
     union all select id from public.body_measurements
     union all select id from public.weekly_checkins $$,
  array[
    '00000000-0000-0000-0000-000000002104'::uuid, '00000000-0000-0000-0000-000000002204'::uuid,
    '00000000-0000-0000-0000-000000002304'::uuid, '00000000-0000-0000-0000-000000002404'::uuid,
    '00000000-0000-0000-0000-000000002504'::uuid, '00000000-0000-0000-0000-000000002604'::uuid
  ],
  'X still reads all his own logs after his link ended'
);

select throws_ok(
  $$ insert into public.daily_metrics (athlete_id, recorded_on, steps)
     values (tests.user_id('x'), '2026-11-04', 5000) $$,
  '42501', 'new row violates row-level security policy for table "daily_metrics"',
  'X cannot log daily metrics'
);

select throws_ok(
  $$ insert into public.training_sessions (athlete_id, training_day_id, program_week, performed_on)
     values (tests.user_id('x'), '00000000-0000-0000-0000-000000000204', 2, '2026-09-15') $$,
  '42501', 'new row violates row-level security policy for table "training_sessions"',
  'X cannot log a session of his old mesocycle'
);

select is_empty(
  $$ with l as (
       update public.set_logs set reps = 0 where athlete_id = tests.user_id('x') returning id
     ),
     d as (
       update public.daily_metrics set steps = 0 where athlete_id = tests.user_id('x') returning id
     ),
     c as (
       update public.weekly_checkins set energy = 'high' where athlete_id = tests.user_id('x') returning id
     )
     select id from l union all select id from d union all select id from c $$,
  'X cannot update his logs (no row is updated)'
);

select is_empty(
  $$ with l as (
       delete from public.set_logs where athlete_id = tests.user_id('x') returning id
     ),
     m as (
       delete from public.meal_logs where athlete_id = tests.user_id('x') returning id
     ),
     b as (
       delete from public.body_measurements where athlete_id = tests.user_id('x') returning id
     )
     select id from l union all select id from m union all select id from b $$,
  'X cannot delete his logs (no row is deleted)'
);

-- ---------------------------------------------------------------------------
-- U and anon read nothing
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('u'));

select is_empty(
  $$ select id from public.training_sessions
     union all select id from public.set_logs
     union all select id from public.meal_logs
     union all select id from public.daily_metrics
     union all select id from public.body_measurements
     union all select id from public.weekly_checkins $$,
  'U reads no logs'
);

select tests.clear_authentication();
set local role anon;

select throws_ok('select 1 from public.training_sessions', '42501', null, 'anon cannot read training_sessions');
select throws_ok('select 1 from public.set_logs', '42501', null, 'anon cannot read set_logs');
select throws_ok('select 1 from public.meal_logs', '42501', null, 'anon cannot read meal_logs');
select throws_ok('select 1 from public.daily_metrics', '42501', null, 'anon cannot read daily_metrics');
select throws_ok('select 1 from public.body_measurements', '42501', null, 'anon cannot read body_measurements');
select throws_ok('select 1 from public.weekly_checkins', '42501', null, 'anon cannot read weekly_checkins');

-- ---------------------------------------------------------------------------
-- Deletes: plan rows with logs are kept, options are released, athletes go whole
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('t1'));

select throws_ok(
  $$ delete from public.training_days where id = '00000000-0000-0000-0000-000000000202' $$,
  '23503', null,
  'T1 cannot delete a training day that has sessions'
);

select throws_ok(
  $$ delete from public.day_exercises where id = '00000000-0000-0000-0000-000000000302' $$,
  '23503', null,
  'T1 cannot delete a day exercise that has set logs'
);

select throws_ok(
  $$ delete from public.mesocycles where id = '00000000-0000-0000-0000-000000000102' $$,
  '23503', null,
  'T1 cannot delete a mesocycle whose days have logs'
);

select throws_ok(
  $$ delete from public.meals where id = '00000000-0000-0000-0000-000000001202' $$,
  '23503', null,
  'T1 cannot delete a meal that has meal logs'
);

select isnt_empty(
  $$ delete from public.training_days where id = '00000000-0000-0000-0000-000000000212' returning id $$,
  'T1 can still delete a training day that has no logs'
);

select isnt_empty(
  $$ delete from public.meal_options where id = '00000000-0000-0000-0000-000000001302' returning id $$,
  'T1 can delete a meal option that was logged'
);

select results_eq(
  $$ select meal_id, meal_option_id from public.meal_logs
     where id = '00000000-0000-0000-0000-000000002302' $$,
  $$ values ('00000000-0000-0000-0000-000000001202'::uuid, null::uuid) $$,
  'deleting the option keeps the meal log and sets only meal_option_id to null'
);

select tests.authenticate_as(tests.user_id('a1'));

select isnt_empty(
  $$ delete from public.training_sessions
     where id = '00000000-0000-0000-0000-000000002112' returning id $$,
  'A1 can delete one of his sessions'
);

select is_empty(
  $$ select id from public.set_logs
     where training_session_id = '00000000-0000-0000-0000-000000002112' $$,
  'deleting a session deletes its set logs'
);

select tests.clear_authentication();

select lives_ok(
  $$ delete from auth.users where id = tests.user_id('a1') $$,
  'deleting an athlete''s user is allowed while he has plans and logs'
);

select is_empty(
  $$ select id from public.mesocycles where id = '00000000-0000-0000-0000-000000000102'
     union all select id from public.training_days where mesocycle_id = '00000000-0000-0000-0000-000000000102'
     union all select id from public.meal_plans where id = '00000000-0000-0000-0000-000000001102'
     union all select id from public.training_sessions where id = '00000000-0000-0000-0000-000000002102'
     union all select id from public.set_logs
       where id in ('00000000-0000-0000-0000-000000002202', '00000000-0000-0000-0000-000000002212',
                    '00000000-0000-0000-0000-000000002232')
     union all select id from public.meal_logs where id = '00000000-0000-0000-0000-000000002302'
     union all select id from public.daily_metrics where id = '00000000-0000-0000-0000-000000002402'
     union all select id from public.body_measurements where id = '00000000-0000-0000-0000-000000002502'
     union all select id from public.weekly_checkins where id = '00000000-0000-0000-0000-000000002602' $$,
  'deleting an athlete''s user removes his plans and logs in one statement'
);

select results_eq(
  $$ select count(*) from public.set_logs where athlete_id = tests.user_id('a2') $$,
  $$ values (1::bigint) $$,
  'deleting an athlete''s user leaves another athlete''s logs untouched'
);

select * from finish();

rollback;
