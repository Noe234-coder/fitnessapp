-- Group 7 (docs/schema-v1.md §7, step 2b-2b): the four read-only views of
-- §4 "Views": meal_option_macros, macro_targets_current, daily_metrics_weekly
-- and body_fat_estimates.
--
-- Derived values are computed here, never stored (kcal = 4P + 4C + 9F, D8).
-- Every view is security_invoker: it reads the base tables as the caller, so
-- their RLS applies and a caller sees exactly the rows he could select from
-- the tables. Select is granted to authenticated only.
--
-- "Today" is current_date, the database's date (UTC). Around midnight in
-- Spain the current target may switch 1–2 h late; accepted (§4 "Views").

-- ===========================================================================
-- meal_option_macros
-- ===========================================================================

create view public.meal_option_macros
with (security_invoker = true)
as
with item_grams as (
  -- Grams of each item: the amount for 'g', amount × unit_grams for 'unit'
  -- (the unit triggers guarantee unit_grams is set for 'unit' items).
  select
    i.meal_option_id,
    case i.amount_unit
      when 'unit' then i.amount * f.unit_grams
      else i.amount
    end as grams,
    f.protein_g,
    f.carbs_g,
    f.fat_g
  from public.meal_option_items i
  join public.foods f on f.id = i.food_id
),
totals as (
  select
    o.id,
    o.athlete_id,
    o.trainer_id,
    coalesce(sum(g.grams * g.protein_g / 100), 0) as protein_g,
    coalesce(sum(g.grams * g.carbs_g / 100), 0) as carbs_g,
    coalesce(sum(g.grams * g.fat_g / 100), 0) as fat_g
  from public.meal_options o
  left join item_grams g on g.meal_option_id = o.id
  group by o.id
)
select
  t.id as meal_option_id,
  t.athlete_id,
  t.trainer_id,
  round(t.protein_g, 1) as protein_g,
  round(t.carbs_g, 1) as carbs_g,
  round(t.fat_g, 1) as fat_g,
  -- From the unrounded grams, then rounded.
  round(4 * t.protein_g + 4 * t.carbs_g + 9 * t.fat_g, 1) as kcal
from totals t;

comment on view public.meal_option_macros is
  'Protein, carbs, fat and kcal of each meal option, from its items and their foods (per 100 g, D8). kcal = 4P + 4C + 9F. An option without items has 0 everywhere. Rounded to 1 decimal.';
comment on column public.meal_option_macros.meal_option_id is 'The meal option.';
comment on column public.meal_option_macros.athlete_id is 'The athlete of the plan.';
comment on column public.meal_option_macros.trainer_id is 'The trainer who wrote the plan.';
comment on column public.meal_option_macros.protein_g is
  'Protein of the option, in grams: sum of grams / 100 × the food''s protein_g. A ''unit'' item counts amount × unit_grams grams.';
comment on column public.meal_option_macros.carbs_g is 'Carbohydrates of the option, in grams.';
comment on column public.meal_option_macros.fat_g is 'Fat of the option, in grams.';
comment on column public.meal_option_macros.kcal is
  'Energy of the option: 4 × protein + 4 × carbs + 9 × fat, from the unrounded grams.';

revoke all on table public.meal_option_macros from anon, authenticated;
grant select on table public.meal_option_macros to authenticated;

-- ===========================================================================
-- macro_targets_current
-- ===========================================================================

create view public.macro_targets_current
with (security_invoker = true)
as
select
  t.id as macro_target_id,
  t.athlete_id,
  t.trainer_id,
  t.day_type,
  t.effective_on,
  t.protein_g,
  t.carbs_g,
  t.fat_g,
  4 * t.protein_g + 4 * t.carbs_g + 9 * t.fat_g as kcal,
  round(w.avg_weight_kg, 2) as avg_weight_kg,
  round(t.protein_g / w.avg_weight_kg, 2) as protein_g_per_kg,
  round(t.carbs_g / w.avg_weight_kg, 2) as carbs_g_per_kg,
  round(t.fat_g / w.avg_weight_kg, 2) as fat_g_per_kg,
  t.note
from (
  -- The latest target per athlete and day type that is already in effect.
  select distinct on (m.athlete_id, m.day_type) m.*
  from public.macro_targets m
  where m.effective_on <= current_date
  order by m.athlete_id, m.day_type, m.effective_on desc
) t
left join lateral (
  -- Average fasted weight of the 7 days before today (D9); null if none.
  select avg(d.fasted_weight_kg) as avg_weight_kg
  from public.daily_metrics d
  where d.athlete_id = t.athlete_id
    and d.recorded_on >= current_date - 7
    and d.recorded_on < current_date
) w on true;

comment on view public.macro_targets_current is
  'The macro target in effect today (current_date, UTC) per athlete and day type: the latest macro_targets row with effective_on ≤ today (D9), with its kcal and grams per kg of the last 7 days'' average fasted weight.';
comment on column public.macro_targets_current.macro_target_id is 'The macro_targets row in effect.';
comment on column public.macro_targets_current.athlete_id is 'The athlete.';
comment on column public.macro_targets_current.trainer_id is 'The trainer who set the target.';
comment on column public.macro_targets_current.day_type is 'training or rest.';
comment on column public.macro_targets_current.effective_on is 'The day the target took effect.';
comment on column public.macro_targets_current.protein_g is 'Daily protein target, in grams.';
comment on column public.macro_targets_current.carbs_g is 'Daily carbohydrate target, in grams.';
comment on column public.macro_targets_current.fat_g is 'Daily fat target, in grams.';
comment on column public.macro_targets_current.kcal is
  'Daily energy target: 4 × protein + 4 × carbs + 9 × fat (exact, from the stored grams).';
comment on column public.macro_targets_current.avg_weight_kg is
  'Average fasted weight of the 7 days before today (daily_metrics), rounded to 2 decimals. Null when none was logged.';
comment on column public.macro_targets_current.protein_g_per_kg is
  'Protein target per kg of avg_weight_kg, rounded to 2 decimals. Null when avg_weight_kg is null.';
comment on column public.macro_targets_current.carbs_g_per_kg is
  'Carbohydrate target per kg of avg_weight_kg, rounded to 2 decimals. Null when avg_weight_kg is null.';
comment on column public.macro_targets_current.fat_g_per_kg is
  'Fat target per kg of avg_weight_kg, rounded to 2 decimals. Null when avg_weight_kg is null.';
comment on column public.macro_targets_current.note is 'The trainer''s note on the target.';

revoke all on table public.macro_targets_current from anon, authenticated;
grant select on table public.macro_targets_current to authenticated;

-- ===========================================================================
-- daily_metrics_weekly
-- ===========================================================================

create view public.daily_metrics_weekly
with (security_invoker = true)
as
with weeks as (
  select
    d.athlete_id,
    -- Monday of the ISO week.
    d.recorded_on - (extract(isodow from d.recorded_on)::integer - 1) as week_starts_on,
    round(avg(d.fasted_weight_kg), 2) as avg_weight_kg,
    round(avg(d.steps)) as avg_steps,
    round(avg(d.sleep_minutes)) as avg_sleep_minutes,
    round(avg(d.stress), 1) as avg_stress,
    count(d.fasted_weight_kg) as weight_days
  from public.daily_metrics d
  group by d.athlete_id, 2
)
select
  w.athlete_id,
  w.week_starts_on,
  w.avg_weight_kg,
  w.avg_steps,
  w.avg_sleep_minutes,
  w.avg_stress,
  w.weight_days,
  -- Difference of the two rounded averages, so it matches what is shown.
  w.avg_weight_kg - p.avg_weight_kg as weight_change_kg
from weeks w
left join lateral (
  -- The latest earlier week of the same athlete that has a weight.
  select w2.avg_weight_kg
  from weeks w2
  where w2.athlete_id = w.athlete_id
    and w2.week_starts_on < w.week_starts_on
    and w2.avg_weight_kg is not null
  order by w2.week_starts_on desc
  limit 1
) p on true;

comment on view public.daily_metrics_weekly is
  'Weekly averages of an athlete''s daily metrics (his SEGUIMIENTO DIARIO), per ISO week, with the weight change against the previous week that has a weight. Only weeks with at least one daily_metrics row appear.';
comment on column public.daily_metrics_weekly.athlete_id is 'The athlete.';
comment on column public.daily_metrics_weekly.week_starts_on is 'Monday of the ISO week.';
comment on column public.daily_metrics_weekly.avg_weight_kg is
  'Average fasted weight of the week, in kg, rounded to 2 decimals. Null when no weight was logged.';
comment on column public.daily_metrics_weekly.avg_steps is 'Average daily steps, rounded to a whole number.';
comment on column public.daily_metrics_weekly.avg_sleep_minutes is
  'Average sleep per night, in minutes, rounded to a whole number.';
comment on column public.daily_metrics_weekly.avg_stress is 'Average stress (0–10), rounded to 1 decimal.';
comment on column public.daily_metrics_weekly.weight_days is 'Number of days of the week with a weight.';
comment on column public.daily_metrics_weekly.weight_change_kg is
  'avg_weight_kg minus the avg_weight_kg of the latest earlier week that has one. Null for the first such week, or when this week has no weight.';

revoke all on table public.daily_metrics_weekly from anon, authenticated;
grant select on table public.daily_metrics_weekly to authenticated;

-- ===========================================================================
-- body_fat_estimates
-- ===========================================================================

create view public.body_fat_estimates
with (security_invoker = true)
as
select
  m.id as body_measurement_id,
  m.athlete_id,
  m.measured_on,
  round(
    case
      -- A null input makes the condition null, so the case returns null.
      when p.sex = 'male'
        and m.navel_cm - m.neck_cm > 0
        and p.height_cm > 0
      then 86.010 * log((m.navel_cm - m.neck_cm) / 2.54)
        - 70.041 * log(p.height_cm / 2.54)
        + 36.76
      when p.sex = 'female'
        and m.navel_cm + m.hip_cm - m.neck_cm > 0
        and p.height_cm > 0
      then 163.205 * log((m.navel_cm + m.hip_cm - m.neck_cm) / 2.54)
        - 97.684 * log(p.height_cm / 2.54)
        - 78.387
    end,
    2
  ) as body_fat_pct
from public.body_measurements m
left join public.athlete_profiles p on p.athlete_id = m.athlete_id;

comment on view public.body_fat_estimates is
  'Body-fat estimate per body measurement: US Navy formula, inch version (D11), with sex and height from athlete_profiles. Waist = navel_cm; hip (women) = hip_cm, 2 cm below the navel, not the Navy''s widest point of the glutes.';
comment on column public.body_fat_estimates.body_measurement_id is 'The body_measurements row.';
comment on column public.body_fat_estimates.athlete_id is 'The athlete.';
comment on column public.body_fat_estimates.measured_on is 'The day of the measurement.';
comment on column public.body_fat_estimates.body_fat_pct is
  'Body fat in %, rounded to 2 decimals, with every length converted from cm to inches (÷ 2.54). Men: 86.010·log10(navel − neck) − 70.041·log10(height) + 36.76. Women: 163.205·log10(navel + hip − neck) − 97.684·log10(height) − 78.387. Null when sex, height_cm, neck_cm, navel_cm or (women) hip_cm is missing, or a log argument is ≤ 0.';

revoke all on table public.body_fat_estimates from anon, authenticated;
grant select on table public.body_fat_estimates to authenticated;
