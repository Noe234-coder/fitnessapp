# FitnessApp — Schema v1

> **APPROVED 2026-11-10.** Not applied anywhere yet. Written 2026-11-09 (roadmap step 2a), reviewed with Noé on 2026-11-10 (D1–D12 and §5–6, one choice at a time).
> This document is the reference for the migrations of step 2b. Inputs: decisions.md, trainer-workflow.md, reference-oct28-schema.md.
> Open items that don't block the migrations are in §9; notes for later steps are in §11.

## 1. Overview

25 tables in five groups, plus four read-only views.

```
Identity        profiles · trainers · trainer_athletes · invitations · athlete_profiles
Libraries       movement_categories · exercises · foods · food_swaps        (owned by a trainer)
Training plan   mesocycles → training_days → day_exercises → exercise_prescriptions → prescribed_sets
                (templates and athletes' mesocycles share these tables)
Nutrition plan  meal_plans → meals → meal_options → meal_option_items  ·  macro_targets
Athlete logs    training_sessions → set_logs · meal_logs · daily_metrics · body_measurements · weekly_checkins
```

| Group | Trainer | Athlete |
|---|---|---|
| Libraries | create/edit his own | read his trainer's; after the link ends, only rows used in his own plans |
| Training templates | create/edit his own | no access |
| Plans (training + nutrition) | create/edit for his active athletes | read own (also after the link ends) |
| Logs | read his active athletes' | create/edit/delete own while he has an active trainer, offline; read own always |
| Identity | through Edge Functions / SQL only | read linked people; edit own name and language |

A trainer can also be his own athlete (D1): he then has both columns' rights on his own data.

## 2. Naming and conventions

- Tables: plural snake_case (`exercises`). Columns: singular snake_case.
- Primary key: `id uuid default gen_random_uuid()`. The client may send its own UUID (offline writes). Tables keyed by the user id instead: `profiles.id`, `trainers.profile_id`, `athlete_profiles.athlete_id`.
- Foreign keys: `<singular>_id` (`exercise_id`, `meal_option_id`).
- Every table has `created_at` and `updated_at` (timestamptz, not null, default now()). One shared trigger function (`private.set_updated_at()`) keeps `updated_at` current; every table has the trigger. The client never sets `updated_at`.
- Timestamps end in `_at` (timestamptz). Calendar dates end in `_on` (date).
- Units go in the column name: `_kg`, `_cm`, `_g`, `_minutes`, `_pct`.
- Booleans: `is_…`. Ordering: `position smallint`.
- Fixed vocabularies: `text` plus a named check constraint, not Postgres enum types. An enum value can't easily be removed or renamed; a check constraint is replaced in one migration.
- **Stored values of fixed vocabularies are stable English codes** (`slight_soreness`, `gt_80`, `very_high`). The Spanish/English labels live in i18n, never in the database. That keeps the English UI translatable and lets a label be reworded without rewriting rows.
- Library rows are never hard-deleted once used: they get `archived_at`, and foreign keys from plans use `on delete restrict`.
- Every table and column gets a `comment on`.
- Schemas: `public` is exposed through the API. `private` holds RLS helper functions and triggers and is not exposed.
- Policy names say who can do what: `"athletes read own rows"`, `"trainers manage their athletes' plans"`.
- Migration file names: `<timestamp>_<verb>_<subject>.sql`, e.g. `…_create_training_plans.sql`.

## 3. Design choices

### D1 · A trainer is a row in `trainers`, not a role enum
- One person can be a trainer and also another trainer's athlete. Adding trainers later means adding rows, not changing the schema.
- **A trainer can be his own athlete** (approved 2026-11-10): there's no `trainer_id <> athlete_id` check on `trainer_athletes`. His self-link is created with SQL, like his `trainers` row (he can't invite himself by email).
- No admin role in v1. The trainer row is created once with SQL; there's no UI for it in the MVP.
- **Rejected:** a global `user_role` enum on `profiles` (Oct 28). It allows one role per person and mixes identity with permissions.

### D2 · Athletes are linked to a trainer through `trainer_athletes`
- One active link per athlete (partial unique index). Ended links are kept, with `ended_at` set.
- Logs belong to the athlete only, so an athlete who changes trainer keeps his history.
- Access follows the **active** link: the new trainer can read the **whole** history (approved), the old trainer loses access immediately.
- **A former athlete (no active link) keeps read-only access:** he reads his logs and his old plans, including the names of the exercises, categories and foods those plans use (extra library select policy). He can't create, edit or delete logs.

### D3 · Ownership keys are copied down every tree (kept from Oct 28)
- Every plan row carries `athlete_id` and `trainer_id`. Every log row carries `athlete_id`. Training plan rows also carry `is_template` (D4).
- Children use composite FKs to their parent, so a child can never point at another athlete's or another trainer's row.
- Plans reference library rows with `(exercise_id, trainer_id)` and `(food_id, trainer_id)`, so a plan can only use its own trainer's exercises and foods.
- **Why composite FKs matter, not just RLS:** Postgres checks a foreign key against the parent row without applying RLS. With a plain FK, A1 could insert a set log (passing the `athlete_id = uid` policy) that points at A2's session. The composite FK makes the database reject it. RLS decides who may write a row; the composite FK decides what it may point at.
- **Result:** every policy is a one-column check plus at most one helper. It's boring and uniform on purpose: the same pattern in every table is easy for Claude Code to repeat and easy to review.
- **Trade-off:** a few extra uuid columns per plan row, `unique (id, athlete_id)`-style constraints on parents, and FKs of two or three columns (each indexed). Negligible at 40 athletes. A plan can't be moved to another athlete by editing `athlete_id`; reuse always copies (D4).

### D4 · Training: templates copied per athlete, in the same tables. Nutrition: individual plans.
- A **template** is a mesocycle without an athlete (`athlete_id` null, `is_template = true`). Assigning it deep-copies the whole tree into a new mesocycle for that athlete, which the trainer then individualizes. Editing a template never changes existing copies.
- One copy function covers three cases: template → athlete; an athlete's mesocycle → his next one; any plan → new template ("save as template"). `copied_from_id` keeps the lineage.
- **Why the same tables:** one builder screen, one copy function and one set of policies. Separate template tables would have to stay identical in shape forever.
- **Integrity:** with the default `MATCH SIMPLE`, Postgres skips a composite FK check when any of its columns is null, so templates (null `athlete_id`) need a second FK. Each training child therefore has two:
  1. `(parent_id, trainer_id, is_template)`, always checked: same trainer, and template rows and athlete rows can never be mixed.
  2. `(parent_id, athlete_id)`, checked for athlete rows: same athlete.
- **`is_template` is a generated column:** `is_template boolean generated always as (athlete_id is null) stored`. Nobody can send a wrong value. If Postgres refuses the generated column inside a FK, fall back to a plain column with `check (is_template = (athlete_id is null))`.
- Logs point at plan rows with `(x_id, athlete_id)`; a log's `athlete_id` is never null, so a log can never reference a template row.
- **Rejected:**
  - Separate template tables: five more tables to keep in sync by hand, plus a builder that edits two sets of tables.
  - `MATCH FULL`: it would reject every template row.
  - A "fake athlete" id for templates (e.g. the trainer's own id): collides with D1, where the trainer can be his own athlete.
  - Shared live programs, where edits reach every assigned athlete: contradicts "every plan is individualized".
- **Meal plans** stay individual per athlete; reuse means duplicating a plan. Macros depend on each athlete's weight and phase. Nutrition tables need only one composite FK each.

### D5 · Week-to-week prescription is stored as versions that carry forward
- `exercise_prescriptions (day_exercise_id, from_week)` holds the sets for one exercise. A version applies from `from_week` until a later version exists. Week W uses the version with the largest `from_week ≤ W`:
  ```sql
  select distinct on (day_exercise_id) *
  from exercise_prescriptions
  where from_week <= :week
  order by day_exercise_id, from_week desc;
  ```
- Every day exercise gets a week-1 version when it's added.
- **Why:** his mesocycles are open-ended (24 week slots, 15+ used), and changes are occasional. Storing every week explicitly would force someone to create next week's rows every week, or the athlete would open the app to an empty day. With versions, he only records changes.
- **Confirmed 2026-11-10:** he does one-off weeks (deloads, test weeks) regularly, so the builder needs "only this week" (§11). Edits apply from the current week on; past weeks keep their targets (§11).
- **Trade-off:** "the plan for week W" needs a small lookup instead of a plain filter. The athlete's phone caches all versions for the active mesocycle (a few hundred rows) and resolves any week offline.
- **Rejected:** one row per week (dense storage); one prescription per mesocycle (Oct 28; it can't express week-to-week changes).

### D6 · Weeks, sessions and day status
- An athlete's `mesocycles.starts_on` must be a Monday. Program week N is the calendar week starting `starts_on + 7·(N−1)`.
- A session stores `program_week` and `performed_on`. Storing the week keeps history correct if `starts_on` is moved later (a holiday pause), and the phone sets it when the session is created, so a session synced late still lands in the right week.
- One session per training day per program week: `unique (training_day_id, program_week)`. Confirmed: an athlete never does the same day twice in one week.
- **Day status is derived, never stored**, per training day and past program week: no session → **skipped**; a session with sets but `completed_at` null → **incomplete** (logged sets stay visible); `completed_at` set → **done**. Judged by program week number, not by date, so a paused week (after moving `starts_on`) is never shown as skipped.
- **Why derived:** stored "skipped" rows need a writer every Monday (a scheduled job, or the client, with duplicates and offline delays). Derived is always correct and costs nothing to sync.
- **Rejected:** storing skipped rows; weekday pinning (earlier decision).

### D7 · Warm-up/mobility is a non-logged day of the mesocycle
- `training_days.kind = 'warmup'`, at most one per mesocycle (partial unique index). It uses the same tables as a training day (library exercises, versioned prescriptions, `target_effort` null). It's shown before every session and is never logged or counted as skipped.
- **A trigger on `training_sessions` rejects a session whose training day has `kind = 'warmup'`** (a foreign key can't check a column's value).
- **Why a day:** the routine is the same for every training day of a block (his single MOVILIDAD tab). Attaching it to each day would mean entering it five times.

### D8 · Foods store macros per 100 g, with an optional unit
- `foods` stores protein, carbs and fat per 100 g, plus an optional unit (`unit_name` such as "huevo L", and `unit_grams`; both set or both null). Option items use grams or units; 'unit' is allowed only for foods with `unit_grams` (trigger).
- **Why:** EU labels must declare values per 100 g, so that's what the trainer types, and one formula covers every calculation. "Huevo (L) × 2" still works (2 × `unit_grams`).
- **kcal = 4·P + 4·C + 9·F everywhere** (targets, meals, options) and is never stored. **Verified 2026-11-10:** his current RESUMEN targets match 4/4/9 exactly. His older history rows were typed by hand and differ by up to ~16 kcal (rounding).
- Foods are raw values (his guideline: weigh raw). Something prescribed cooked is its own food row.
- **Liquids: ml is treated as g** (labels are per 100 ml; ~3% error for milk). The UI shows "g / ml". **Rejected:** an 'ml' unit with a density per food.

### D9 · Daily macro targets keep a history; meal targets live on meals
- `macro_targets` has one row per athlete, effective date and day type (training or rest), with P/C/F and a note ("superávit → déficit"). The current target per day type is the latest row with `effective_on ≤ today`, looked up independently, so changing only training days writes one row. It belongs to the athlete, not the meal plan, because his history spans plan changes.
- Each meal keeps its own current P/C/F target and a `day_type` ('all', 'training' or 'rest'). The intra-workout meal is 'training'; every other meal is 'all'.
- **Two sources of truth on purpose:** the daily target is what he wants, the meals are what he planned (his sheet has both). The builder shows the difference so a mismatch is always visible.
- The bodyweight and g/kg columns of his history table are **computed** from `daily_metrics` (average of the 7 days before the effective date), not typed. No data → shown as "—".

### D10 · Swaps come from the trainer's table: directed, factor applied to grams
- `food_swaps (from_food, to_food, factor, nutrient_group carbs/protein/fat)`, unique per pair. "Equivalente" = factor 1.
- **One table per trainer, shared by all his athletes** (confirmed 2026-11-10).
- Directed: A→B ×1.25 doesn't imply B→A ×0.8, because his factors are hand-tuned. No chaining (A→B + B→C doesn't create A→C).
- **Rejected:** computing swaps from macros (matches one macro, drifts on the others; overrides his judgment).
- The athlete applies a swap on screen. v1 logs which option was eaten, not which swaps were applied.

### D11 · Measurements and check-ins use fixed columns
- `body_measurements` has his MEDIDAS sites plus `neck_cm`. His measuring instructions ("contracted, except glute", "hip 2 cm below the navel") go in the column comments and UI hints.
- `weekly_checkins` mirrors his FORMULARIO questions; every fixed answer is a text code plus a check constraint (§2: English codes, labels in i18n). **Adherence answers are buckets, not numbers** ('100', 'gt_80', 'gt_50' …).
- `week_starts_on` is the Monday of the week the check-in is **about**.
- **Body fat = US Navy formula, inch version** (verified 2026-11-10 against his calculator: it uses waist, neck and height only; weight is shown but unused). Computed in a view from `sex` and `height_cm` (`athlete_profiles`), converting cm to inches:
  - men: 86.010·log10(waist − neck) − 70.041·log10(height) + 36.76, with **waist = `navel_cm`**;
  - women: 163.205·log10(waist + hip − neck) − 97.684·log10(height) − 78.387; which measurement is the hip is open (§9).
- **Why fixed columns:** typed, validated, plain tables for the trainer. His check-in has had the same questions from week 85 to 108; adding one later is a ~10-minute migration.
- **Rejected:** configurable forms or key-value measurements. Only worth it if a second trainer needs different questions.

### D12 · Offline writes use client UUIDs and natural keys
Each athlete table has a natural unique key. The outbox upserts on that key, so a retry, a second device or a reinstalled app updates the same row instead of creating a duplicate.

| Table | Upsert key |
|---|---|
| daily_metrics | athlete_id, recorded_on |
| meal_logs | athlete_id, meal_id, logged_on |
| training_sessions | training_day_id, program_week |
| set_logs | training_session_id, day_exercise_id, set_number |
| body_measurements | athlete_id, measured_on |
| weekly_checkins | athlete_id, week_starts_on |

- An upsert needs select, insert and update policies: Postgres checks all three for `insert … on conflict do update`.
- **Session ids are deterministic: UUID v5 of `(training_day_id, program_week)`** with a fixed namespace constant in the repo (decided 2026-11-10). Sessions have children (set logs); with random ids, two devices creating the same session offline would leave one device's set logs pointing at an id that doesn't exist. Other log tables have no children and use random v4 ids (`crypto.randomUUID()`).
- The hosted database runs Postgres 17.11, which has no built-in UUID v7; v4 is fine.

## 4. Tables

Columns are listed without `id`, `created_at` and `updated_at`. "↑" marks the composite FK(s) to the parent described in D3/D4.

### Identity

**profiles** — one per auth user, created by a trigger on sign-up.
`id` (= auth.users.id) · `full_name` · `locale` ('es' | 'en', default 'es').
Users can update only `full_name` and `locale` (column-level grant).

**trainers** — a row means this person is a trainer. Created with SQL; no UI in the MVP.
`profile_id` (pk → profiles).

**trainer_athletes** — who trains whom.
`trainer_id` → trainers · `athlete_id` → profiles · `started_at` · `ended_at` (null = active).
One active link per athlete. No self-link check (a trainer can be his own athlete, D1). `ended_at ≥ started_at`. Written only by the invite flow (Edge Function) or SQL.

**invitations** — record of invites sent.
`trainer_id` · `email` (lowercase) · `expires_at` · `accepted_at` · `accepted_by` → profiles.
Written only by the invite Edge Function (step 4).

**athlete_profiles** — data the trainer keeps per athlete.
`athlete_id` (pk → profiles) · `sex` ('male' | 'female') · `height_cm` · `long_term_goal` · `short_term_goal`.
Written by the athlete's trainer, read by both.

### Libraries

Every library table has `trainer_id` → trainers, `archived_at` and `unique (id, trainer_id)` (target of the composite FKs). Exercises and foods also have `source` ('manual' | 'sheet_import', later 'open_food_facts') and `source_ref` (sheet and row, barcode…).

**movement_categories** — his fixed list (Empuje inclinado, Tracción vertical…).
`name` · `position`. Unique name per trainer. Muscle weights attach here later, for volume analytics.

**exercises** — `name` · `movement_category_id` (nullable, same trainer) · `technique_notes` · `video_url` · `source` · `source_ref`. Unique name per trainer among non-archived rows.

**foods** — `name` · `brand` · `protein_g` · `carbs_g` · `fat_g` (per 100 g; ml treated as g) · `unit_name` · `unit_grams` (both set or both null) · `source` · `source_ref`.

**food_swaps** — `nutrient_group` ('carbs' | 'protein' | 'fat') · `from_food_id` · `to_food_id` (both same trainer, different foods) · `factor` (> 0, applied to grams) · `note`. Unique (from_food_id, to_food_id).

### Training plan

Every table has `trainer_id`, `athlete_id` (null for templates) and `is_template` (generated, D4).

**mesocycles** — a template, or one athlete's block.
`name` ("7º mesociclo", "Torso/Pierna 5 días") · `starts_on` (a Monday; null for templates) · `status` ('draft' | 'active' | 'archived') · `copied_from_id` → mesocycles (lineage; set to null if the source is deleted).
Checks: templates have no `starts_on`; an active athlete mesocycle has one. One active mesocycle per athlete (templates excluded).

**training_days** — `mesocycle_id` ↑ · `name` ("Torso") · `position` · `kind` ('training' | 'warmup'; at most one warmup per mesocycle).

**day_exercises** — the fixed exercise list of a day.
`training_day_id` ↑ · `exercise_id` (→ exercises, same trainer, on delete restrict) · `position` · `notes` (coach notes for this program, in addition to the exercise's technique notes).

**exercise_prescriptions** — a version of the sets, valid from a given week on.
`day_exercise_id` ↑ · `from_week` (≥ 1). Unique (day_exercise_id, from_week).

**prescribed_sets** — `exercise_prescription_id` ↑ · `set_number` · `target_reps_min` · `target_reps_max` · `is_per_side` · `target_effort` ('rir' | 'failure' | 'failure_partials'; null for warm-up) · `target_rir_min` · `target_rir_max` · `technique` (null, or a code from his glossary: drop set, rest-pause, myo-reps, cluster…; exact list in §9) · `notes`.

How his sheet maps:

| In his sheet | Stored as |
|---|---|
| "5/8" | reps 5–8 |
| "20" | reps 20–20 |
| "8/10 x lado" | reps 8–10, per side |
| "1 A 0" | effort rir, RIR 0–1 |
| "F + P" | effort failure_partials |

Checks: `target_reps_min ≤ target_reps_max`; the RIR columns are set if and only if effort is 'rir'; `target_rir_min ≤ target_rir_max`.

### Nutrition plan

Every table has `athlete_id` and `trainer_id` (always an athlete; no templates).

**meal_plans** — `name` ("Volumen") · `status` · `guidelines` (hydration, weigh food raw…, **and his supplement list as free text**: amount and timing) · `copied_from_id` → meal_plans. One active per athlete.

**meals** — `meal_plan_id` ↑ · `name` ("Desayuno") · `position` · `day_type` ('all' | 'training' | 'rest') · `target_protein_g` · `target_carbs_g` · `target_fat_g` · `notes` (portions, "verdura libre").

**meal_options** — `meal_id` ↑ · `position` · `label` · `notes` (recipe idea).

**meal_option_items** — `meal_option_id` ↑ · `food_id` (→ foods, same trainer, on delete restrict) · `position` · `amount` (> 0) · `amount_unit` ('g' | 'unit'). 'unit' is allowed only for foods with `unit_grams`; a trigger checks this.

**macro_targets** — daily targets with history.
`effective_on` · `day_type` ('training' | 'rest') · `protein_g` · `carbs_g` · `fat_g` · `note`. Unique (athlete_id, effective_on, day_type).

### Athlete logs

Every table has `athlete_id`. Logs point into plans with `(x_id, athlete_id)`, so they can never point at a template.

**training_sessions** — `training_day_id` ↑ · `program_week` (≥ 1) · `performed_on` · `completed_at` (null = in progress) · `notes`. Unique (training_day_id, program_week). Id = UUID v5 (D12). Trigger: rejects warm-up days (D7).

**set_logs** — `training_session_id` ↑ · `day_exercise_id` ↑ · `set_number` · `reps` · `weight_kg`. One row per set, which is what the later volume and progress features need.

**meal_logs** — a ticked meal.
`meal_id` ↑ · `logged_on` · `meal_option_id` (null = not specified). Unticking deletes the row.

**daily_metrics** — `recorded_on` · `fasted_weight_kg` · `steps` · `sleep_minutes` (0–1440) · `stress` (0–10). All nullable, because they're filled in through the day.

**body_measurements** — `measured_on` · `chest_cm` · `biceps_left_cm` · `biceps_right_cm` · `upper_abdomen_cm` · `navel_cm` · `hip_cm` · `glute_cm` · `quad_left_cm` · `quad_right_cm` · `calf_left_cm` · `calf_right_cm` · `neck_cm`. All nullable (> 0 when set).

**weekly_checkins** — `week_starts_on` (a Monday; the week the check-in is about).
- Training: `training_adherence` (bucket) · `recovery` · `can_progress` · `energy` · `motivation` · `training_notes`.
- Nutrition: `diet_adherence` (bucket) · `satiety` (1–5) · `diet_satisfaction` · `diet_notes` · `diet_missed_reason`.
- Rest: `sleep_quality`.
- `message_to_trainer`.

Answer codes seen in his form so far (the full dropdown lists are pending, §9):

| Column | Codes (es label) |
|---|---|
| training_adherence, diet_adherence | `100` (100%) · `gt_80` (>80%) · `gt_50` (>50%) |
| recovery | `very_good` (Muy buena) · `good` (Buena) · `slight_soreness` (Ligeras agujetas) |
| can_progress | `yes_most` (Sí en la mayoría) · `yes_some` (En algunos sí) |
| energy, motivation, diet_satisfaction | `very_high` (Muy alto) · `high` (Alto) · `medium` (Medio) |
| satiety | 1 Tengo muchísima hambre · 2 Tengo hambre · 3 Estoy bien · 4 Me encuentro saciado · 5 Me cuesta acabar la comida |
| sleep_quality | `excellent` (Excelente) · `good` (Buena) · `fair` (Regular) |

### Views

All views use `security_invoker = true`, so the caller's RLS applies.
- **meal_option_macros** — P/C/F/kcal per option (items × foods; 4/4/9).
- **macro_targets_current** — current training/rest target per athlete, with kcal and g/kg (from the last 7 days' average weight).
- **daily_metrics_weekly** — weekly averages and change vs the previous week (his SEGUIMIENTO DIARIO).
- **body_fat_estimates** — body-fat % per measurement (Navy, inch version, D11).
- Day status (done / incomplete / skipped, D6) — a view or a query, decided in step 8.

## 5. RLS strategy

- RLS is enabled, with explicit policies, in the same migration that creates each table. `anon` has no access to anything (revoke plus default privileges).
- Helper functions live in `private` (security definer, `stable`, `search_path = ''`, execute granted to `authenticated` only):

| Helper | Returns |
|---|---|
| `private.is_trainer()` | the caller has a `trainers` row |
| `private.trainer_athlete_ids()` | `setof uuid`: the caller's **active** athletes (includes himself if self-linked) |
| `private.is_athlete_of(trainer_id)` | the caller is an active athlete of that trainer |
| `private.has_active_trainer()` | the caller has an active link |

- Policies use `(select auth.uid())`, and trainer checks use `athlete_id in (select private.trainer_athlete_ids())`. Both run once per query instead of once per row (Supabase's RLS performance pattern). It matters for `set_logs` (~250k rows a year at 40 athletes).

| Tables | Athlete | Trainer |
|---|---|---|
| Libraries | select if `is_athlete_of(trainer_id)`; **plus** select of rows used in his own plans (exercises via day_exercises, their movement categories, foods via meal_option_items) | all if `trainer_id = uid` |
| Training plans | select if `athlete_id = uid` (never templates) | all if `trainer_id = uid and (athlete_id is null or athlete_id in (trainer_athlete_ids()))` |
| Nutrition plans | select if `athlete_id = uid` | all if `trainer_id = uid and athlete_id in (trainer_athlete_ids())` |
| Logs | select if `athlete_id = uid`; insert/update/delete if `athlete_id = uid and has_active_trainer()` | select if `athlete_id in (trainer_athlete_ids())` |
| profiles | own row + own active trainer | own row + his athletes; update own `full_name`/`locale` only (column grant) |
| athlete_profiles | select own | all for his athletes |
| trainers, trainer_athletes, invitations | select own rows | select own rows; writes only through the Edge Function (service role) or SQL |

- Permissive policies are ORed, so a self-linked trainer passes the athlete policies on his own rows and the trainer policies on everyone's.
- When a link ends, the old trainer loses read and write on that athlete's plans and logs immediately (the athlete leaves `trainer_athlete_ids()`); his templates are unaffected.
- Athletes can read their trainer's **whole** library while linked: the swap table points at foods outside the plan, and the offline cache needs them. **Trade-off:** athletes can see his full exercise and food lists.
- Trainers can't edit athletes' logs in v1 (read-only). If the trainer wants to correct logged numbers (§9), that's one extra update policy, not a schema change.
- The "rows used in his own plans" library policies are added in the plans migrations (they reference plan tables).

## 6. Policy tests (pgTAP, `npx supabase test db`)

Fixtures: trainer **T1** with athletes A1 and A2, one template and a self-link; trainer **T2** with athlete B1; **X**, a former athlete of T1 (link ended); **U**, a user with no links; **anon**.

| Area | Tests |
|---|---|
| Isolation | A1 can't read A2's or B1's rows in any table; athletes never see templates; T1 can't read B1 or T2's templates; U and anon read nothing |
| Write rules | Athletes can't write plans or libraries; T1 can't write athlete logs or plans for B1; a plan can't use T2's exercises or foods |
| FK guarantees | A1's set log pointing at A2's session is rejected (D3); a template day under an athlete mesocycle is rejected, and the reverse; a session on a template day is rejected |
| Triggers | A session on a warm-up day is rejected; an option item in 'unit' for a food without `unit_grams` is rejected |
| Former athlete X | Reads his logs and old plans with exercise and food names; can't insert, update or delete logs; T1 reads nothing of X |
| Self-link | T1 logs his own session; his own mesocycle is not a template |
| Upsert | The same `daily_metrics` natural key written twice → one row (select + insert + update policies) |
| Meta | Every `public` table has RLS on, a comment on the table and on every column, `created_at`/`updated_at`, and the `updated_at` trigger |

Each migration step adds the tests for the tables it creates; the meta tests cover every table automatically.

## 7. Migration plan (step 2b)

**2b-1** (one session):
1. `…_create_private_helpers` — private schema, `set_updated_at()` trigger function, anon revokes.
2. `…_create_identity` — profiles (+ sign-up trigger), trainers, trainer_athletes, invitations, athlete_profiles, helper functions, RLS.
3. `…_create_libraries` — movement_categories, exercises, foods, food_swaps, RLS.

**2b-2** (one session, maybe two):
4. `…_create_training_plans` (+ library "used in own plans" policies for exercises/categories, warm-up partial index)
5. `…_create_nutrition_plans` (+ foods "used in own plans" policy, unit trigger)
6. `…_create_athlete_logs` (+ warm-up session trigger)
7. `…_create_views`

Plus `supabase/tests/database/*.test.sql`, and `supabase/seed.sql` with test-only helpers and a few local fixtures (seed.sql is never pushed to the hosted project).
The copy function for templates and plans is written in step 6 with the builder, with its own test.
Everything runs on the local stack only. Pushing to the hosted project is a separate step, done after confirmation.

## 8. Not in v1, and where each fits later

- Meal plan templates (individual plans for now; duplicating covers reuse).
- Pushing a template change to athletes who already have a copy (not wanted: plans are individualized).
- Weekly volume per muscle → `exercise_muscles (exercise_id, muscle, weight)`, or weights on `movement_categories`. Sets are already logged one by one.
- Exercise substitution during a session (machine taken) → nullable `performed_exercise_id` on `set_logs`.
- Recording which swaps were applied → `meal_log_swaps`.
- Supplements as a table athletes tick off (free text in `guidelines` for now).
- Trainer corrections of athlete logs → one update policy.
- Per-trainer custom check-in questions or measurement sites.
- Open Food Facts foods → `source = 'open_food_facts'`, `source_ref` = barcode.

## 9. Open items (asked to the trainer 2026-11-10; none blocks 2b-1)

- Full option list of each check-in dropdown (only the answers actually used are known, §4). Needed before 2b-2 (`weekly_checkins` checks).
- Body fat for women: which measurement is the hip — `glute_cm` (widest point, the Navy definition) or `hip_cm` (his "2 cm below the navel")? Needed before the views migration.
- Technique glossary codes for `prescribed_sets.technique` (what is "windows maker"?). Needed before 2b-2.
- Is he OK with importing his exercises and notes from the sheets? Needed before step 5.
- Does he want to correct athletes' logged numbers himself? Can be added any time (§5).

Resolved 2026-11-10: kcal = 4/4/9 (D8); body-fat formula = Navy, inch version (D11); swap table is shared per trainer (D10).

## 10. Changes vs decisions.md

All logged in decisions.md on 2026-11-10 ("Schema v1 approved").

## 11. Notes for later steps (UI and client rules decided during the review)

- **Step 6 (workout builder):**
  - "Only this week": creates version W with the change plus version W+1 restoring the previous sets, unless W+1 already has a version.
  - Edits to the prescription apply from the current week on (new version); weeks already trained keep their targets.
  - `starts_on` defaults to next Monday.
  - The copy function (template ↔ athlete plans) with its own test.
- **Step 7 (meal builder):** show the sum of the meal targets against the daily target, with the difference. Show "g / ml" for amounts.
- **Step 8 (athlete week view):** day status done / incomplete / skipped (D6); warm-up shown before every session; a swap that lands on a unit food shows both ("≈ 1,5 huevos L (95 g)"); a "my training" switch so a trainer who is his own athlete can use the athlete screens.
- **Step 10 (check-in):** the form picks the week by day — Fri–Sun → this week, Mon–Thu → last week — and the athlete can change it.
- **Step 12 (offline):**
  - Session ids are UUID v5 of `(training_day_id, program_week)`; namespace constant in the repo.
  - The outbox sends only the fields that changed (daily metrics are filled through the day).
  - Writes rejected because the athlete's link ended are shown as an error, not retried forever.
