-- Views: meal_option_macros, macro_targets_current, daily_metrics_weekly,
-- body_fat_estimates (docs/schema-v1.md §4 "Views", D8, D9, D11).
-- Fixtures (supabase/seed.sql): t1 (self-linked trainer) with a1, a2; t2 with b1;
-- x former athlete of t1; u with no links.
--
-- Every input is invented, and every expected number is computed in the test
-- from the formula, never copied from a result.
--
-- Row ids are fixed. The last four digits are <table><owner>:
--   table  11 meal_plans · 12 meals · 13 meal_options · 14 meal_option_items
--          15 macro_targets · 25 body_measurements
--   owner  …02 A1   …03 A2   …04 X   …07 B1 (by T2)
--   A second row of the same table and owner has the third digit raised.
-- Foods: …f1 oats · …f3 egg (unit of 63 g) · …f4 olive oil (T1) · …f2 rice (T2).
-- 2026-01-05, 2026-01-19, 2026-01-26 and 2026-02-02 are Mondays; 2026-01-25 is a Sunday.
-- Rows for macro_targets_current are dated relative to current_date.

begin;

select plan(22);

-- ---------------------------------------------------------------------------
-- Inputs (as postgres; rolled back at the end)
-- ---------------------------------------------------------------------------

insert into public.foods (id, trainer_id, name, protein_g, carbs_g, fat_g, unit_name, unit_grams)
values
  ('00000000-0000-0000-0000-0000000000f1', tests.user_id('t1'), 'Avena', 13.5, 58.7, 7, null, null),
  ('00000000-0000-0000-0000-0000000000f3', tests.user_id('t1'), 'Huevo', 12.6, 0.7, 9.5, 'huevo L', 63),
  ('00000000-0000-0000-0000-0000000000f4', tests.user_id('t1'), 'Aceite de oliva', 0, 0, 100, null, null),
  ('00000000-0000-0000-0000-0000000000f2', tests.user_id('t2'), 'Arroz', 7, 78, 0.6, null, null);

insert into public.meal_plans (id, trainer_id, athlete_id, name, status)
values
  ('00000000-0000-0000-0000-000000001102', tests.user_id('t1'), tests.user_id('a1'), 'Volumen', 'active'),
  ('00000000-0000-0000-0000-000000001103', tests.user_id('t1'), tests.user_id('a2'), 'Volumen', 'active'),
  ('00000000-0000-0000-0000-000000001107', tests.user_id('t2'), tests.user_id('b1'), 'Definición', 'active');

insert into public.meals (
  id, trainer_id, athlete_id, meal_plan_id, name, target_protein_g, target_carbs_g, target_fat_g
)
values
  ('00000000-0000-0000-0000-000000001202', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001102', 'Desayuno', 30, 60, 15),
  ('00000000-0000-0000-0000-000000001203', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000001103', 'Desayuno', 30, 60, 15),
  ('00000000-0000-0000-0000-000000001207', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001107', 'Comida', 40, 80, 10);

insert into public.meal_options (id, trainer_id, athlete_id, meal_id, position)
values
  ('00000000-0000-0000-0000-000000001302', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001202', 1),
  ('00000000-0000-0000-0000-000000001312', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001202', 2),
  ('00000000-0000-0000-0000-000000001322', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001202', 3),
  ('00000000-0000-0000-0000-000000001303', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000001203', 1),
  ('00000000-0000-0000-0000-000000001307', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001207', 1);

-- Option …1302: 80 g oats, 2 eggs (unit), 10 g oil. Option …1312: 3 eggs only.
-- Option …1322: no items.
insert into public.meal_option_items (
  id, trainer_id, athlete_id, meal_option_id, food_id, position, amount, amount_unit
)
values
  ('00000000-0000-0000-0000-000000001402', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f1', 1, 80, 'g'),
  ('00000000-0000-0000-0000-000000001412', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f3', 2, 2, 'unit'),
  ('00000000-0000-0000-0000-000000001422', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001302', '00000000-0000-0000-0000-0000000000f4', 3, 10, 'g'),
  ('00000000-0000-0000-0000-000000001432', tests.user_id('t1'), tests.user_id('a1'),
   '00000000-0000-0000-0000-000000001312', '00000000-0000-0000-0000-0000000000f3', 1, 3, 'unit'),
  ('00000000-0000-0000-0000-000000001403', tests.user_id('t1'), tests.user_id('a2'),
   '00000000-0000-0000-0000-000000001303', '00000000-0000-0000-0000-0000000000f1', 1, 50, 'g'),
  ('00000000-0000-0000-0000-000000001407', tests.user_id('t2'), tests.user_id('b1'),
   '00000000-0000-0000-0000-000000001307', '00000000-0000-0000-0000-0000000000f2', 1, 100, 'g');

-- A1: an old, a current and a future training target; an old rest target and
-- one that starts today. A2 and B1: one current training target each.
insert into public.macro_targets (id, trainer_id, athlete_id, effective_on, day_type, protein_g, carbs_g, fat_g, note)
values
  ('00000000-0000-0000-0000-000000001502', tests.user_id('t1'), tests.user_id('a1'),
   current_date - 30, 'training', 150, 300, 70, 'old'),
  ('00000000-0000-0000-0000-000000001512', tests.user_id('t1'), tests.user_id('a1'),
   current_date - 3, 'training', 160, 280, 65, 'current'),
  ('00000000-0000-0000-0000-000000001522', tests.user_id('t1'), tests.user_id('a1'),
   current_date + 5, 'training', 170, 260, 60, 'future'),
  ('00000000-0000-0000-0000-000000001532', tests.user_id('t1'), tests.user_id('a1'),
   current_date - 30, 'rest', 150, 200, 80, 'old'),
  ('00000000-0000-0000-0000-000000001542', tests.user_id('t1'), tests.user_id('a1'),
   current_date, 'rest', 155, 180, 85, 'from today'),
  ('00000000-0000-0000-0000-000000001503', tests.user_id('t1'), tests.user_id('a2'),
   current_date - 1, 'training', 120, 250, 60, null),
  ('00000000-0000-0000-0000-000000001507', tests.user_id('t2'), tests.user_id('b1'),
   current_date - 1, 'training', 110, 200, 50, null);

-- A1's weights around today: only the 7 days before today count (−7 … −1).
insert into public.daily_metrics (athlete_id, recorded_on, fasted_weight_kg, steps)
values
  (tests.user_id('a1'), current_date, 100.0, null),
  (tests.user_id('a1'), current_date - 1, 80.0, null),
  (tests.user_id('a1'), current_date - 2, null, 12000),
  (tests.user_id('a1'), current_date - 3, 81.0, null),
  (tests.user_id('a1'), current_date - 7, 79.5, null),
  (tests.user_id('a1'), current_date - 8, 90.0, null);

-- A1's weeks of January 2026: two days with a weight and one without; no row
-- in the week of 01-12; a Monday and a Sunday; a week with steps only; a week
-- with one weight.
insert into public.daily_metrics (athlete_id, recorded_on, fasted_weight_kg, steps, sleep_minutes, stress)
values
  (tests.user_id('a1'), '2026-01-05', 80.0, 10000, 420, 3),
  (tests.user_id('a1'), '2026-01-06', 80.6, 8000, 450, 4),
  (tests.user_id('a1'), '2026-01-07', null, 9000, null, null),
  (tests.user_id('a1'), '2026-01-19', 79.95, null, null, null),
  (tests.user_id('a1'), '2026-01-25', 79.40, null, null, null),
  (tests.user_id('a1'), '2026-01-27', null, 7000, null, null),
  (tests.user_id('a1'), '2026-02-02', 79.0, null, null, null),
  (tests.user_id('a2'), '2026-01-05', 70.0, 6000, 400, 5),
  (tests.user_id('b1'), '2026-01-05', 60.0, 5000, 480, 2);

insert into public.athlete_profiles (athlete_id, sex, height_cm)
values
  (tests.user_id('a1'), 'male', 180),
  (tests.user_id('a2'), 'female', 165),
  (tests.user_id('b1'), 'male', null);

insert into public.body_measurements (id, athlete_id, measured_on, navel_cm, hip_cm, neck_cm)
values
  ('00000000-0000-0000-0000-000000002502', tests.user_id('a1'), '2026-01-05', 85.0, null, 38.0),
  ('00000000-0000-0000-0000-000000002512', tests.user_id('a1'), '2026-01-12', 85.0, null, null),
  ('00000000-0000-0000-0000-000000002522', tests.user_id('a1'), '2026-01-19', 38.0, null, 40.0),
  ('00000000-0000-0000-0000-000000002503', tests.user_id('a2'), '2026-01-05', 75.0, 95.0, 32.0),
  ('00000000-0000-0000-0000-000000002513', tests.user_id('a2'), '2026-01-12', 75.0, null, 32.0),
  ('00000000-0000-0000-0000-000000002504', tests.user_id('x'), '2026-01-05', 90.0, null, 40.0),
  ('00000000-0000-0000-0000-000000002507', tests.user_id('b1'), '2026-01-05', 80.0, null, 38.0);

-- ---------------------------------------------------------------------------
-- meal_option_macros
-- ---------------------------------------------------------------------------

select results_eq(
  $$ select protein_g, carbs_g, fat_g, kcal from public.meal_option_macros
     where meal_option_id = '00000000-0000-0000-0000-000000001302' $$,
  $$ with raw (p, c, f) as (
       values (
         80 * 13.5 / 100 + (2 * 63) * 12.6 / 100 + 10 * 0.0 / 100,
         80 * 58.7 / 100 + (2 * 63) * 0.7 / 100 + 10 * 0.0 / 100,
         80 * 7.0 / 100 + (2 * 63) * 9.5 / 100 + 10 * 100.0 / 100
       )
     )
     select round(p, 1), round(c, 1), round(f, 1), round(4 * p + 4 * c + 9 * f, 1) from raw $$,
  'an option''s macros are the sum of grams / 100 × food values; kcal = 4P + 4C + 9F (1 decimal)'
);

select results_eq(
  $$ select protein_g, carbs_g, fat_g, kcal from public.meal_option_macros
     where meal_option_id = '00000000-0000-0000-0000-000000001312' $$,
  $$ with raw (p, c, f) as (
       values ((3 * 63) * 12.6 / 100, (3 * 63) * 0.7 / 100, (3 * 63) * 9.5 / 100)
     )
     select round(p, 1), round(c, 1), round(f, 1), round(4 * p + 4 * c + 9 * f, 1) from raw $$,
  'a ''unit'' item counts amount × unit_grams grams (3 eggs = 189 g)'
);

select results_eq(
  $$ select athlete_id, trainer_id, protein_g, carbs_g, fat_g, kcal from public.meal_option_macros
     where meal_option_id = '00000000-0000-0000-0000-000000001322' $$,
  $$ values (tests.user_id('a1'), tests.user_id('t1'), 0::numeric, 0::numeric, 0::numeric, 0::numeric) $$,
  'an option without items has 0 macros, and carries its athlete and trainer'
);

-- ---------------------------------------------------------------------------
-- macro_targets_current
-- ---------------------------------------------------------------------------

select results_eq(
  $$ select macro_target_id, day_type from public.macro_targets_current
     where athlete_id = tests.user_id('a1') order by day_type $$,
  $$ values ('00000000-0000-0000-0000-000000001542'::uuid, 'rest'::text),
            ('00000000-0000-0000-0000-000000001512'::uuid, 'training'::text) $$,
  'one row per day type: the latest target already in effect (today counts, the future one does not)'
);

select results_eq(
  $$ select protein_g, carbs_g, fat_g, kcal, avg_weight_kg,
            protein_g_per_kg, carbs_g_per_kg, fat_g_per_kg
     from public.macro_targets_current
     where macro_target_id = '00000000-0000-0000-0000-000000001512' $$,
  $$ with w (avg) as (values ((80.0 + 81.0 + 79.5) / 3))
     select 160::numeric, 280::numeric, 65::numeric, (4 * 160 + 4 * 280 + 9 * 65)::numeric,
            round(avg, 2), round(160 / avg, 2), round(280 / avg, 2), round(65 / avg, 2)
     from w $$,
  'kcal = 4/4/9; g/kg use the average fasted weight of the 7 days before today (not today, not day −8)'
);

select results_eq(
  $$ select kcal, avg_weight_kg, protein_g_per_kg, carbs_g_per_kg, fat_g_per_kg
     from public.macro_targets_current
     where macro_target_id = '00000000-0000-0000-0000-000000001503' $$,
  $$ values ((4 * 120 + 4 * 250 + 9 * 60)::numeric, null::numeric, null::numeric, null::numeric, null::numeric) $$,
  'with no weight in the last 7 days, the average and g/kg are null'
);

-- ---------------------------------------------------------------------------
-- daily_metrics_weekly
-- ---------------------------------------------------------------------------

select results_eq(
  $$ select week_starts_on, avg_weight_kg, avg_steps, avg_sleep_minutes, avg_stress,
            weight_days, weight_change_kg
     from public.daily_metrics_weekly
     where athlete_id = tests.user_id('a1') and week_starts_on < '2026-03-01'
     order by week_starts_on $$,
  $$ with w (w1, w3) as (values (round((80.0 + 80.6) / 2, 2), round((79.95 + 79.40) / 2, 2)))
     select * from (
       select '2026-01-05'::date, w1, round((10000 + 8000 + 9000) / 3.0), round((420 + 450) / 2.0),
              round((3 + 4) / 2.0, 1), 2::bigint, null::numeric
       from w
       union all
       select '2026-01-19'::date, w3, null, null, null, 2::bigint, w3 - w1 from w
       union all
       select '2026-01-26'::date, null, 7000::numeric, null, null, 0::bigint, null from w
       union all
       select '2026-02-02'::date, 79.00, null, null, null, 1::bigint, 79.00 - w3 from w
     ) expected $$,
  'weekly averages per ISO week (Sunday counts in its Monday''s week), days with a weight, and the change vs the latest earlier week with a weight'
);

-- ---------------------------------------------------------------------------
-- body_fat_estimates
-- ---------------------------------------------------------------------------

select results_eq(
  $$ select body_measurement_id, body_fat_pct from public.body_fat_estimates
     where athlete_id = tests.user_id('a1') order by measured_on $$,
  $$ values
       ('00000000-0000-0000-0000-000000002502'::uuid,
        round(86.010 * log((85.0 - 38.0) / 2.54) - 70.041 * log(180.0 / 2.54) + 36.76, 2)),
       ('00000000-0000-0000-0000-000000002512'::uuid, null),
       ('00000000-0000-0000-0000-000000002522'::uuid, null) $$,
  'men: Navy inch formula on navel and neck; null without a neck, and null when navel − neck ≤ 0'
);

select results_eq(
  $$ select body_measurement_id, body_fat_pct from public.body_fat_estimates
     where athlete_id = tests.user_id('a2') order by measured_on $$,
  $$ values
       ('00000000-0000-0000-0000-000000002503'::uuid,
        round(163.205 * log((75.0 + 95.0 - 32.0) / 2.54) - 97.684 * log(165.0 / 2.54) - 78.387, 2)),
       ('00000000-0000-0000-0000-000000002513'::uuid, null) $$,
  'women: Navy inch formula on navel, hip and neck; null without a hip'
);

select results_eq(
  $$ select body_measurement_id, body_fat_pct from public.body_fat_estimates
     where athlete_id in (tests.user_id('x'), tests.user_id('b1')) order by body_measurement_id $$,
  $$ values ('00000000-0000-0000-0000-000000002504'::uuid, null::numeric),
            ('00000000-0000-0000-0000-000000002507'::uuid, null::numeric) $$,
  'null with no athlete profile (no sex), and null with no height'
);

-- ---------------------------------------------------------------------------
-- RLS through the views (security_invoker)
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('a1'));

select set_eq(
  'select meal_option_id from public.meal_option_macros',
  array[
    '00000000-0000-0000-0000-000000001302'::uuid, '00000000-0000-0000-0000-000000001312'::uuid,
    '00000000-0000-0000-0000-000000001322'::uuid
  ],
  'A1 sees the macros of his own options only'
);

select set_eq(
  $$ select athlete_id from public.macro_targets_current
     union select athlete_id from public.daily_metrics_weekly
     union select athlete_id from public.body_fat_estimates $$,
  array[tests.user_id('a1')],
  'A1 sees only his own targets, weekly metrics and body-fat estimates'
);

select results_eq(
  $$ select body_fat_pct from public.body_fat_estimates
     where body_measurement_id = '00000000-0000-0000-0000-000000002502' $$,
  $$ values (round(86.010 * log((85.0 - 38.0) / 2.54) - 70.041 * log(180.0 / 2.54) + 36.76, 2)) $$,
  'A1 gets his body-fat estimate through RLS (he can read his athlete profile)'
);

select tests.authenticate_as(tests.user_id('t1'));

select set_eq(
  'select meal_option_id from public.meal_option_macros',
  array[
    '00000000-0000-0000-0000-000000001302'::uuid, '00000000-0000-0000-0000-000000001312'::uuid,
    '00000000-0000-0000-0000-000000001322'::uuid, '00000000-0000-0000-0000-000000001303'::uuid
  ],
  'T1 sees the option macros of A1 and A2, not B1''s'
);

select set_eq(
  'select athlete_id from public.macro_targets_current',
  array[tests.user_id('a1'), tests.user_id('a2')],
  'T1 sees the current targets of A1 and A2, not B1''s'
);

select set_eq(
  'select athlete_id from public.daily_metrics_weekly',
  array[tests.user_id('a1'), tests.user_id('a2')],
  'T1 sees the weekly metrics of A1 and A2, not B1''s'
);

select set_eq(
  'select athlete_id from public.body_fat_estimates',
  array[tests.user_id('a1'), tests.user_id('a2')],
  'T1 sees the body-fat estimates of A1 and A2: not B1''s, and not X''s since his link ended'
);

select tests.authenticate_as(tests.user_id('u'));

select is_empty(
  $$ select meal_option_id from public.meal_option_macros
     union all select athlete_id from public.macro_targets_current
     union all select athlete_id from public.daily_metrics_weekly
     union all select athlete_id from public.body_fat_estimates $$,
  'U sees nothing through the views'
);

select tests.clear_authentication();
set local role anon;

select throws_ok('select 1 from public.meal_option_macros', '42501', null, 'anon cannot read meal_option_macros');
select throws_ok('select 1 from public.macro_targets_current', '42501', null, 'anon cannot read macro_targets_current');
select throws_ok('select 1 from public.daily_metrics_weekly', '42501', null, 'anon cannot read daily_metrics_weekly');
select throws_ok('select 1 from public.body_fat_estimates', '42501', null, 'anon cannot read body_fat_estimates');

select * from finish();

rollback;
