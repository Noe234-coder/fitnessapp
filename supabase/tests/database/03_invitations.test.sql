-- Invitations: public.accept_invitation(), the athlete's half of the invite
-- flow (CLAUDE.md "Invites"). The trainer's half, the invite-athlete Edge
-- Function, is checked by scripts/test-invite-function.mjs.
-- Fixtures (supabase/seed.sql): t1 (self-linked trainer) with a1, a2; t2 with b1;
-- x former athlete of t1; u with no links.

begin;

select plan(41);

-- ---------------------------------------------------------------------------
-- The function itself
-- ---------------------------------------------------------------------------

select has_function(
  'public', 'accept_invitation', array[]::text[],
  'public.accept_invitation() exists'
);

select function_returns(
  'public', 'accept_invitation', array[]::text[], 'uuid',
  'accept_invitation() returns a uuid (the trainer''s id)'
);

select is_definer(
  'public', 'accept_invitation', array[]::text[],
  'accept_invitation() is security definer'
);

select ok(
  (select coalesce(p.proconfig, '{}') @> array['search_path=""']
   from pg_catalog.pg_proc p
   where p.oid = 'public.accept_invitation()'::regprocedure),
  'accept_invitation() sets search_path to empty'
);

select isnt(
  pg_catalog.obj_description('public.accept_invitation()'::regprocedure, 'pg_proc'),
  null,
  'accept_invitation() has a comment'
);

select ok(
  not has_function_privilege('anon', 'public.accept_invitation()', 'execute'),
  'anon has no execute privilege on accept_invitation()'
);

-- grantee 0 is PUBLIC.
select is_empty(
  $$ select 1
     from pg_catalog.pg_proc p,
          aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
     where p.oid = 'public.accept_invitation()'::regprocedure
       and a.grantee = 0 $$,
  'accept_invitation() is not executable by PUBLIC'
);

select ok(
  has_function_privilege('authenticated', 'public.accept_invitation()', 'execute'),
  'authenticated can execute accept_invitation()'
);

-- ---------------------------------------------------------------------------
-- Extra rows for this file (as postgres; rolled back at the end)
-- ---------------------------------------------------------------------------

select tests.create_user('nobody@fitnessapp.test');
select tests.create_user('late@fitnessapp.test');
select tests.create_user('taken@fitnessapp.test');
select tests.create_user('two@fitnessapp.test');

insert into public.invitations (trainer_id, email, expires_at, created_at)
values
  -- u: one pending invitation from t1.
  (tests.user_id('t1'), 'u@fitnessapp.test', now() + interval '24 hours', now()),
  -- An invitation for somebody who never calls the function. It must still be
  -- pending at the end: nobody else may accept it.
  (tests.user_id('t1'), 'bystander@fitnessapp.test', now() + interval '24 hours', now()),
  -- late: only an expired invitation.
  (tests.user_id('t1'), 'late@fitnessapp.test', now() - interval '1 minute', now() - interval '25 hours'),
  -- b1 already trains with t2.
  (tests.user_id('t1'), 'b1@fitnessapp.test', now() + interval '24 hours', now()),
  -- x, a former athlete of t1, is invited by t2.
  (tests.user_id('t2'), 'x@fitnessapp.test', now() + interval '24 hours', now()),
  -- two: an older invitation from t1 and a newer one from t2.
  (tests.user_id('t1'), 'two@fitnessapp.test', now() + interval '20 hours', now() - interval '4 hours'),
  (tests.user_id('t2'), 'two@fitnessapp.test', now() + interval '24 hours', now());

-- taken: the invitation for his email was accepted by another user.
insert into public.invitations (trainer_id, email, expires_at, accepted_at, accepted_by)
values (tests.user_id('t1'), 'taken@fitnessapp.test', now() + interval '24 hours', now(), tests.user_id('a2'));

-- ---------------------------------------------------------------------------
-- Happy path: u accepts t1's invitation
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('u'));

select is(
  public.accept_invitation(),
  tests.user_id('t1'),
  'U accepts his invitation and gets his trainer''s id'
);

select results_eq(
  $$ select trainer_id, started_at = now(), ended_at is null
     from public.trainer_athletes where athlete_id = tests.user_id('u') $$,
  $$ values (tests.user_id('t1'), true, true) $$,
  'accepting creates one active link to the inviting trainer, starting now'
);

select results_eq(
  $$ select accepted_at = now(), accepted_by
     from public.invitations where email = 'u@fitnessapp.test' $$,
  $$ values (true, tests.user_id('u')) $$,
  'accepting sets accepted_at and accepted_by on the invitation'
);

select set_eq(
  'select id from public.profiles',
  array[tests.user_id('u'), tests.user_id('t1')],
  'after accepting, U can read his trainer''s profile'
);

-- Idempotent retry ----------------------------------------------------------

select is(
  public.accept_invitation(),
  tests.user_id('t1'),
  'a retry with no pending invitation left returns the same trainer'
);

select is(
  (select count(*) from public.trainer_athletes where athlete_id = tests.user_id('u')),
  1::bigint,
  'the retry does not create a second link'
);

-- A second pending invitation from the same trainer --------------------------

select tests.clear_authentication();

insert into public.invitations (trainer_id, email, expires_at)
values (tests.user_id('t1'), 'u@fitnessapp.test', now() + interval '24 hours');

select tests.authenticate_as(tests.user_id('u'));

select is(
  public.accept_invitation(),
  tests.user_id('t1'),
  'a second invitation from the trainer U is already linked to is accepted without error'
);

select results_eq(
  $$ select count(*), count(*) filter (where ended_at is null)
     from public.trainer_athletes where athlete_id = tests.user_id('u') $$,
  $$ values (1::bigint, 1::bigint) $$,
  'it does not create a second link either'
);

select is_empty(
  $$ select 1 from public.invitations
     where email = 'u@fitnessapp.test' and accepted_by is distinct from tests.user_id('u') $$,
  'and that invitation is marked as accepted too'
);

-- ---------------------------------------------------------------------------
-- Refusals
-- ---------------------------------------------------------------------------

-- No invitation for the caller's email. The bystander's invitation is pending
-- and unexpired at this point: the email match is what keeps it out of reach.
select tests.authenticate_as(tests.user_id('nobody'));

select throws_ok(
  'select public.accept_invitation()',
  'P0001', 'invitation_not_found',
  'a caller with no invitation for his email gets invitation_not_found'
);

select is_empty(
  $$ select 1 from public.trainer_athletes where athlete_id = tests.user_id('nobody') $$,
  'and he gets no link'
);

-- Only an expired invitation.
select tests.authenticate_as(tests.user_id('late'));

select throws_ok(
  'select public.accept_invitation()',
  'P0001', 'invitation_expired',
  'a caller whose only invitation has expired gets invitation_expired'
);

select is_empty(
  $$ select 1 from public.trainer_athletes where athlete_id = tests.user_id('late') $$,
  'and he gets no link'
);

-- The invitation for his email was accepted by someone else.
select tests.authenticate_as(tests.user_id('taken'));

select throws_ok(
  'select public.accept_invitation()',
  'P0001', 'invitation_not_found',
  'an invitation already accepted by another user gives invitation_not_found'
);

-- An active link to another trainer.
select tests.authenticate_as(tests.user_id('b1'));

select throws_ok(
  'select public.accept_invitation()',
  'P0001', 'already_has_trainer',
  'B1, who trains with T2, cannot accept T1''s invitation: already_has_trainer'
);

select results_eq(
  $$ select trainer_id, ended_at is null
     from public.trainer_athletes where athlete_id = tests.user_id('b1') $$,
  $$ values (tests.user_id('t2'), true) $$,
  'B1''s link to T2 is unchanged'
);

-- A JWT without an email claim.
select set_config(
  'request.jwt.claims',
  json_build_object('sub', tests.user_id('nobody'), 'role', 'authenticated')::text,
  true
);

select throws_ok(
  'select public.accept_invitation()',
  'P0001', 'not_authenticated',
  'a JWT with no email claim gets not_authenticated'
);

-- ---------------------------------------------------------------------------
-- The latest invitation wins
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('two'));

select is(
  public.accept_invitation(),
  tests.user_id('t2'),
  'with two pending invitations, the latest one (T2''s) is accepted'
);

select tests.clear_authentication();

select results_eq(
  $$ select trainer_id, accepted_by is null
     from public.invitations where email = 'two@fitnessapp.test' order by created_at $$,
  $$ values (tests.user_id('t1'), true), (tests.user_id('t2'), false) $$,
  'the older invitation from T1 stays pending'
);

select tests.authenticate_as(tests.user_id('two'));

select throws_ok(
  'select public.accept_invitation()',
  'P0001', 'already_has_trainer',
  'and it cannot be accepted afterwards: already_has_trainer'
);

-- ---------------------------------------------------------------------------
-- Former athlete X (link to T1 ended) accepts T2's invitation.
-- The email claim is in mixed case: the match is case-insensitive.
-- ---------------------------------------------------------------------------

select tests.clear_authentication();

select set_config(
  'request.jwt.claims',
  json_build_object(
    'sub', tests.user_id('x'), 'role', 'authenticated', 'email', 'X@Fitnessapp.Test'
  )::text,
  true
);
set local role authenticated;

select is(
  public.accept_invitation(),
  tests.user_id('t2'),
  'former athlete X accepts T2''s invitation (email claim in mixed case)'
);

select results_eq(
  $$ select trainer_id, ended_at is null
     from public.trainer_athletes where athlete_id = tests.user_id('x') order by started_at $$,
  $$ values (tests.user_id('t1'), false), (tests.user_id('t2'), true) $$,
  'X has a new active link to T2 and his ended link to T1 is kept'
);

-- ---------------------------------------------------------------------------
-- The tables are still closed to direct writes
-- ---------------------------------------------------------------------------

select tests.authenticate_as(tests.user_id('a1'));

select throws_ok(
  $$ insert into public.trainer_athletes (trainer_id, athlete_id)
     values (tests.user_id('t2'), tests.user_id('a1')) $$,
  '42501', null,
  'an athlete cannot insert into trainer_athletes'
);

select throws_ok(
  $$ insert into public.invitations (trainer_id, email, expires_at)
     values (tests.user_id('t1'), 'a1@fitnessapp.test', now() + interval '24 hours') $$,
  '42501', null,
  'an athlete cannot insert into invitations'
);

select throws_ok(
  $$ update public.invitations set accepted_at = now(), accepted_by = tests.user_id('a1') $$,
  '42501', null,
  'an athlete cannot update invitations'
);

select throws_ok(
  $$ update public.trainer_athletes set ended_at = null $$,
  '42501', null,
  'an athlete cannot update trainer_athletes'
);

select tests.authenticate_as(tests.user_id('t1'));

select throws_ok(
  $$ insert into public.invitations (trainer_id, email, expires_at)
     values (tests.user_id('t1'), 'direct@fitnessapp.test', now() + interval '24 hours') $$,
  '42501', null,
  'a trainer cannot insert into invitations either (only the Edge Function does)'
);

select throws_ok(
  $$ insert into public.trainer_athletes (trainer_id, athlete_id)
     values (tests.user_id('t1'), tests.user_id('nobody')) $$,
  '42501', null,
  'a trainer cannot insert into trainer_athletes'
);

select set_eq(
  $$ select athlete_id from public.trainer_athletes where ended_at is null $$,
  array[tests.user_id('t1'), tests.user_id('a1'), tests.user_id('a2'), tests.user_id('u')],
  'T1 sees U among his active athletes after the acceptance'
);

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------

select tests.clear_authentication();
set local role anon;

select throws_ok(
  'select public.accept_invitation()',
  '42501', null,
  'anon cannot execute accept_invitation()'
);

-- ---------------------------------------------------------------------------
-- Nobody accepted an invitation that was not for his email (as postgres)
-- ---------------------------------------------------------------------------

select tests.clear_authentication();

select results_eq(
  $$ select accepted_at is null, accepted_by is null
     from public.invitations where email = 'bystander@fitnessapp.test' $$,
  $$ values (true, true) $$,
  'the bystander''s invitation is still pending'
);

select results_eq(
  $$ select accepted_at is null from public.invitations where email = 'late@fitnessapp.test' $$,
  $$ values (true) $$,
  'the expired invitation was not accepted'
);

select results_eq(
  $$ select accepted_at is null from public.invitations where email = 'b1@fitnessapp.test' $$,
  $$ values (true) $$,
  'the invitation B1 could not accept is still pending'
);

select * from finish();

rollback;
