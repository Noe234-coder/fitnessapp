-- Identity: profiles, trainers, trainer_athletes, invitations, athlete_profiles,
-- the sign-up trigger and the RLS helpers (docs/schema-v1.md §4, §5, §6).
-- Fixtures (supabase/seed.sql): t1 (self-linked trainer) with a1, a2; t2 with b1;
-- x former athlete of t1; u with no links.

begin;

select plan(80);

-- ---------------------------------------------------------------------------
-- Extra rows for this file (as postgres; rolled back at the end)
-- ---------------------------------------------------------------------------

insert into public.athlete_profiles (athlete_id, sex, height_cm)
values
  (tests.user_id('b1'), 'female', 165),
  (tests.user_id('x'), 'male', 180);

insert into public.invitations (trainer_id, email, expires_at, accepted_at, accepted_by)
values
  (tests.user_id('t1'), 'a1@fitnessapp.test', now() + interval '7 days', now(), tests.user_id('a1')),
  (tests.user_id('t1'), 'pending@fitnessapp.test', now() + interval '7 days', null, null),
  (tests.user_id('t2'), 'other@fitnessapp.test', now() + interval '7 days', null, null);

-- ---------------------------------------------------------------------------
-- Sign-up trigger
-- ---------------------------------------------------------------------------

select tests.create_user(
  'new@fitnessapp.test',
  '{"full_name": "  New User  ", "locale": "en", "is_trainer": true}'
);

select results_eq(
  $$ select full_name, locale from public.profiles where id = tests.user_id('new') $$,
  $$ values ('New User'::text, 'es'::text) $$,
  'sign-up creates a profile with the trimmed full_name and locale es; other metadata is ignored'
);

select is_empty(
  $$ select 1 from public.trainers where profile_id = tests.user_id('new') $$,
  'sign-up metadata cannot make a user a trainer'
);

select tests.create_user('noname@fitnessapp.test');

select results_eq(
  $$ select full_name, locale from public.profiles where id = tests.user_id('noname') $$,
  $$ values (null::text, 'es'::text) $$,
  'sign-up without metadata creates a profile with a null full_name'
);

-- ---------------------------------------------------------------------------
-- Constraints (as postgres: authenticated cannot write these tables at all)
-- ---------------------------------------------------------------------------

select throws_ok(
  $$ insert into public.trainer_athletes (trainer_id, athlete_id)
     values (tests.user_id('t2'), tests.user_id('a1')) $$,
  '23505', null,
  'a second active link for the same athlete is rejected'
);

select throws_ok(
  $$ insert into public.trainer_athletes (trainer_id, athlete_id, started_at, ended_at)
     values (tests.user_id('t1'), tests.user_id('u'), now(), now() - interval '1 day') $$,
  '23514', null,
  'a link that ends before it starts is rejected'
);

select throws_ok(
  $$ insert into public.trainer_athletes (trainer_id, athlete_id)
     values (tests.user_id('a1'), tests.user_id('u')) $$,
  '23503', null,
  'a link whose trainer_id is not a trainer is rejected'
);

select throws_ok(
  $$ insert into public.invitations (trainer_id, email, expires_at)
     values (tests.user_id('t1'), 'Mixed@Fitnessapp.test', now() + interval '7 days') $$,
  '23514', null,
  'an invitation email that is not lowercase is rejected'
);

select throws_ok(
  $$ insert into public.invitations (trainer_id, email, expires_at, accepted_at)
     values (tests.user_id('t1'), 'half@fitnessapp.test', now() + interval '7 days', now()) $$,
  '23514', null,
  'an invitation with accepted_at but no accepted_by is rejected'
);

select throws_ok(
  $$ insert into public.invitations (trainer_id, email, expires_at, accepted_by)
     values (tests.user_id('t1'), 'half@fitnessapp.test', now() + interval '7 days', tests.user_id('u')) $$,
  '23514', null,
  'an invitation with accepted_by but no accepted_at is rejected'
);

select throws_ok(
  $$ update public.profiles set locale = 'fr' where id = tests.user_id('u') $$,
  '23514', null,
  'a locale other than es or en is rejected'
);

select throws_ok(
  $$ update public.athlete_profiles set sex = 'other' where athlete_id = tests.user_id('b1') $$,
  '23514', null,
  'a sex other than male or female is rejected'
);

-- ---------------------------------------------------------------------------
-- A1: athlete with an active trainer
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('a1'));

select set_eq(
  'select id from public.profiles',
  array[tests.user_id('a1'), tests.user_id('t1')],
  'A1 sees his own profile and his active trainer''s, nobody else''s'
);

select lives_ok(
  $$ update public.profiles set full_name = 'Ana Uno', locale = 'en'
     where id = tests.user_id('a1') $$,
  'A1 can update his own full_name and locale'
);

select results_eq(
  $$ select full_name, locale, updated_at = now()
     from public.profiles where id = tests.user_id('a1') $$,
  $$ values ('Ana Uno'::text, 'en'::text, true) $$,
  'A1''s update is stored and the trigger sets updated_at'
);

select throws_ok(
  $$ update public.profiles set id = gen_random_uuid() where id = tests.user_id('a1') $$,
  '42501', null,
  'A1 cannot update profiles.id'
);

select throws_ok(
  $$ update public.profiles set created_at = now() where id = tests.user_id('a1') $$,
  '42501', null,
  'A1 cannot update profiles.created_at'
);

select throws_ok(
  $$ update public.profiles set updated_at = now() + interval '1 year'
     where id = tests.user_id('a1') $$,
  '42501', null,
  'A1 cannot update profiles.updated_at'
);

select throws_ok(
  $$ update public.profiles set locale = 'fr' where id = tests.user_id('a1') $$,
  '23514', null,
  'A1 cannot set an unknown locale'
);

select is_empty(
  $$ update public.profiles set full_name = 'Hacked'
     where id = tests.user_id('t1') returning id $$,
  'A1 cannot update his trainer''s profile (no row is updated)'
);

select is_empty(
  $$ update public.profiles set full_name = 'Hacked'
     where id = tests.user_id('a2') returning id $$,
  'A1 cannot update another athlete''s profile (no row is updated)'
);

select throws_ok(
  $$ insert into public.profiles (id) values (gen_random_uuid()) $$,
  '42501', null,
  'A1 cannot insert a profile'
);

select throws_ok(
  $$ delete from public.profiles where id = tests.user_id('a1') $$,
  '42501', null,
  'A1 cannot delete his profile'
);

select is_empty(
  'select profile_id from public.trainers',
  'A1 sees no trainers row (he is not a trainer)'
);

select set_eq(
  'select trainer_id, athlete_id from public.trainer_athletes',
  $$ select tests.user_id('t1') as trainer_id, tests.user_id('a1') as athlete_id $$,
  'A1 sees only his own link'
);

select set_eq(
  'select email from public.invitations',
  array['a1@fitnessapp.test'],
  'A1 sees only the invitation he accepted'
);

select throws_ok(
  $$ insert into public.trainers (profile_id) values (tests.user_id('a1')) $$,
  '42501', null,
  'A1 cannot make himself a trainer'
);

select throws_ok(
  $$ update public.trainer_athletes set ended_at = now()
     where athlete_id = tests.user_id('a1') $$,
  '42501', null,
  'A1 cannot end his own link'
);

select ok(not private.is_trainer(), 'is_trainer() is false for A1');
select ok(private.has_active_trainer(), 'has_active_trainer() is true for A1');
select ok(private.is_athlete_of(tests.user_id('t1')), 'A1 is an athlete of T1');
select ok(not private.is_athlete_of(tests.user_id('t2')), 'A1 is not an athlete of T2');

select is_empty(
  'select private.trainer_athlete_ids()',
  'trainer_athlete_ids() is empty for A1'
);

-- athlete_profiles: A1 has none yet and cannot create one.
select throws_ok(
  $$ insert into public.athlete_profiles (athlete_id, sex, height_cm)
     values (tests.user_id('a1'), 'male', 170) $$,
  '42501', null,
  'A1 cannot insert his own athlete profile'
);

-- ---------------------------------------------------------------------------
-- T1: trainer, self-linked, with A1 and A2
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('t1'));

select set_eq(
  'select id from public.profiles',
  array[tests.user_id('t1'), tests.user_id('a1'), tests.user_id('a2')],
  'T1 sees his own profile and his active athletes'', not X, T2, B1 or U'
);

select is_empty(
  $$ update public.profiles set full_name = 'Renamed by trainer'
     where id = tests.user_id('a1') returning id $$,
  'T1 cannot update an athlete''s profile (no row is updated)'
);

select set_eq(
  'select profile_id from public.trainers',
  array[tests.user_id('t1')],
  'T1 sees only his own trainers row'
);

select set_eq(
  'select athlete_id from public.trainer_athletes',
  array[tests.user_id('t1'), tests.user_id('a1'), tests.user_id('a2'), tests.user_id('x')],
  'T1 sees his own links (active and ended), not T2''s'
);

select set_eq(
  'select email from public.invitations',
  array['a1@fitnessapp.test', 'pending@fitnessapp.test'],
  'T1 sees only the invitations he sent'
);

select throws_ok(
  $$ insert into public.trainers (profile_id) values (tests.user_id('a1')) $$,
  '42501', null,
  'T1 cannot insert into trainers'
);

select throws_ok(
  $$ insert into public.trainer_athletes (trainer_id, athlete_id)
     values (tests.user_id('t1'), tests.user_id('u')) $$,
  '42501', null,
  'T1 cannot insert into trainer_athletes'
);

select throws_ok(
  $$ delete from public.trainer_athletes where athlete_id = tests.user_id('a2') $$,
  '42501', null,
  'T1 cannot delete from trainer_athletes'
);

select throws_ok(
  $$ insert into public.invitations (trainer_id, email, expires_at)
     values (tests.user_id('t1'), 'direct@fitnessapp.test', now() + interval '7 days') $$,
  '42501', null,
  'T1 cannot insert into invitations'
);

select throws_ok(
  $$ update public.invitations set expires_at = now() + interval '1 year' $$,
  '42501', null,
  'T1 cannot update invitations'
);

select ok(private.is_trainer(), 'is_trainer() is true for T1');
select ok(private.has_active_trainer(), 'has_active_trainer() is true for T1 (self-link)');
select ok(private.is_athlete_of(tests.user_id('t1')), 'T1 is an athlete of himself');

select set_eq(
  'select private.trainer_athlete_ids()',
  array[tests.user_id('t1'), tests.user_id('a1'), tests.user_id('a2')],
  'trainer_athlete_ids() for T1 is {T1, A1, A2}: active links only, X excluded'
);

-- athlete_profiles: all operations for his active athletes.
select lives_ok(
  $$ insert into public.athlete_profiles (athlete_id, sex, height_cm, long_term_goal)
     values (tests.user_id('a1'), 'male', 178.5, 'Compete in 2028') $$,
  'T1 can insert A1''s athlete profile'
);

select lives_ok(
  $$ insert into public.athlete_profiles (athlete_id, sex, height_cm)
     values (tests.user_id('t1'), 'male', 182) $$,
  'T1 can insert his own athlete profile (self-link)'
);

select isnt_empty(
  $$ update public.athlete_profiles set short_term_goal = 'Bench 100 kg'
     where athlete_id = tests.user_id('a1') returning athlete_id $$,
  'T1 can update A1''s athlete profile'
);

select set_eq(
  'select athlete_id from public.athlete_profiles',
  array[tests.user_id('a1'), tests.user_id('t1')],
  'T1 sees his active athletes'' athlete profiles, not B1''s or X''s'
);

select is_empty(
  $$ update public.athlete_profiles set height_cm = 1
     where athlete_id in (tests.user_id('b1'), tests.user_id('x')) returning athlete_id $$,
  'T1 cannot update B1''s or X''s athlete profile (no row is updated)'
);

select is_empty(
  $$ delete from public.athlete_profiles
     where athlete_id in (tests.user_id('b1'), tests.user_id('x')) returning athlete_id $$,
  'T1 cannot delete B1''s or X''s athlete profile (no row is deleted)'
);

select throws_ok(
  $$ insert into public.athlete_profiles (athlete_id, sex, height_cm)
     values (tests.user_id('u'), 'male', 175) $$,
  '42501', null,
  'T1 cannot insert an athlete profile for someone who is not his active athlete'
);

select throws_ok(
  $$ update public.athlete_profiles set athlete_id = tests.user_id('u')
     where athlete_id = tests.user_id('a1') $$,
  '42501', null,
  'T1 cannot move an athlete profile to someone who is not his active athlete'
);

-- ---------------------------------------------------------------------------
-- A1 again: reads his athlete profile, cannot write it
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('a1'));

select results_eq(
  'select athlete_id, height_cm, short_term_goal from public.athlete_profiles',
  $$ select tests.user_id('a1') as athlete_id, 178.5::numeric(4,1) as height_cm, 'Bench 100 kg'::text as short_term_goal $$,
  'A1 reads his own athlete profile and only his'
);

select is_empty(
  $$ update public.athlete_profiles set height_cm = 190
     where athlete_id = tests.user_id('a1') returning athlete_id $$,
  'A1 cannot update his athlete profile (no row is updated)'
);

select is_empty(
  $$ delete from public.athlete_profiles
     where athlete_id = tests.user_id('a1') returning athlete_id $$,
  'A1 cannot delete his athlete profile (no row is deleted)'
);

-- ---------------------------------------------------------------------------
-- T2 and B1: the other trainer's side
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('t2'));

select set_eq(
  'select id from public.profiles',
  array[tests.user_id('t2'), tests.user_id('b1')],
  'T2 sees himself and B1 only'
);

select set_eq(
  'select athlete_id from public.athlete_profiles',
  array[tests.user_id('b1')],
  'T2 sees B1''s athlete profile, not A1''s, T1''s or X''s'
);

select set_eq(
  'select private.trainer_athlete_ids()',
  array[tests.user_id('b1')],
  'trainer_athlete_ids() for T2 is {B1}'
);

-- ---------------------------------------------------------------------------
-- X: former athlete of T1
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('x'));

select set_eq(
  'select id from public.profiles',
  array[tests.user_id('x')],
  'X sees only his own profile, not his former trainer''s'
);

select ok(not private.has_active_trainer(), 'has_active_trainer() is false for X');
select ok(not private.is_athlete_of(tests.user_id('t1')), 'X is no longer an athlete of T1');

select set_eq(
  'select trainer_id, athlete_id, ended_at is not null from public.trainer_athletes',
  $$ select tests.user_id('t1') as trainer_id, tests.user_id('x') as athlete_id, true as is_ended $$,
  'X still sees his own ended link'
);

select set_eq(
  'select athlete_id from public.athlete_profiles',
  array[tests.user_id('x')],
  'X still reads his own athlete profile'
);

-- ---------------------------------------------------------------------------
-- U: no links
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('u'));

select set_eq(
  'select id from public.profiles',
  array[tests.user_id('u')],
  'U sees only his own profile'
);

select ok(not private.has_active_trainer(), 'has_active_trainer() is false for U');

select is_empty(
  $$ select 1 from public.trainers
     union all select 1 from public.trainer_athletes
     union all select 1 from public.invitations
     union all select 1 from public.athlete_profiles $$,
  'U sees no trainers, links, invitations or athlete profiles'
);

select throws_ok(
  $$ insert into public.trainers (profile_id) values (tests.user_id('u')) $$,
  '42501', null,
  'U cannot make himself a trainer'
);

select throws_ok(
  $$ insert into public.trainer_athletes (trainer_id, athlete_id)
     values (tests.user_id('t1'), tests.user_id('u')) $$,
  '42501', null,
  'U cannot link himself to a trainer'
);

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------

select tests.clear_authentication();
set local role anon;

select throws_ok('select 1 from public.profiles', '42501', null, 'anon cannot read profiles');
select throws_ok('select 1 from public.trainers', '42501', null, 'anon cannot read trainers');
select throws_ok('select 1 from public.trainer_athletes', '42501', null, 'anon cannot read trainer_athletes');
select throws_ok('select 1 from public.invitations', '42501', null, 'anon cannot read invitations');
select throws_ok('select 1 from public.athlete_profiles', '42501', null, 'anon cannot read athlete_profiles');
select throws_ok('select private.is_trainer()', '42501', null, 'anon cannot call the RLS helpers');

-- ---------------------------------------------------------------------------
-- Deleting users (as postgres): athletes cascade, trainers are protected
-- ---------------------------------------------------------------------------

select tests.clear_authentication();

select throws_ok(
  $$ delete from auth.users where id = tests.user_id('t1') $$,
  '23503', null,
  'deleting a trainer''s user is blocked (his trainers row protects his data)'
);

select lives_ok(
  $$ delete from auth.users where id = tests.user_id('x') $$,
  'deleting an athlete''s user is allowed'
);

select is_empty(
  $$ select 1 from public.profiles where full_name = 'Former Athlete X'
     union all
     select 1 from public.trainer_athletes where ended_at is not null
     union all
     select 1 from public.athlete_profiles where height_cm = 180 $$,
  'deleting an athlete''s user removes his profile, links and athlete profile'
);

select * from finish();

rollback;
