-- Step 4a: the athlete's half of the invite flow.
--
-- The trainer's half is the invite-athlete Edge Function
-- (supabase/functions/invite-athlete): it creates the auth user and the
-- invitations row with the service role. Once the athlete has a session
-- (verifyOtp, and a password for a new account), his app calls
-- rpc('accept_invitation'), which links him to the trainer who invited him.
--
-- This is the one deliberate exception to "identity tables are written only
-- by an Edge Function or SQL": authenticated still has no insert, update or
-- delete privilege on trainer_athletes or invitations. The function writes
-- them as its owner, and only for the caller's own id and email.

create function public.accept_invitation()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller_id uuid := (select auth.uid());
  caller_email text := lower((select auth.jwt()) ->> 'email');
  pending public.invitations%rowtype;
  active_trainer_id uuid;
begin
  if caller_id is null or coalesce(caller_email, '') = '' then
    raise exception 'not_authenticated';
  end if;

  -- The latest invitation for the caller's email that can still be accepted.
  -- The row lock makes a double tap wait for the first call, and then take
  -- the "already accepted" path below.
  select i.*
  into pending
  from public.invitations i
  where i.email = caller_email
    and i.accepted_at is null
    and i.expires_at > now()
  order by i.created_at desc, i.id desc
  limit 1
  for update;

  select ta.trainer_id
  into active_trainer_id
  from public.trainer_athletes ta
  where ta.athlete_id = caller_id
    and ta.ended_at is null;

  if pending.id is null then
    -- A retry after the first call succeeded but its answer was lost (weak
    -- signal): same result, nothing written.
    if active_trainer_id is not null and exists (
      select 1
      from public.invitations i
      where i.accepted_by = caller_id
        and i.trainer_id = active_trainer_id
    ) then
      return active_trainer_id;
    end if;

    if exists (
      select 1
      from public.invitations i
      where i.email = caller_email
        and i.accepted_at is null
    ) then
      raise exception 'invitation_expired';
    end if;

    raise exception 'invitation_not_found';
  end if;

  if active_trainer_id is not null and active_trainer_id <> pending.trainer_id then
    raise exception 'already_has_trainer';
  end if;

  -- Already linked to this trainer (he sent two invitations and the athlete
  -- accepted the other one): there is nothing to link, the invitation is
  -- just marked as used.
  if active_trainer_id is null then
    insert into public.trainer_athletes (trainer_id, athlete_id, started_at)
    values (pending.trainer_id, caller_id, now());
  end if;

  update public.invitations
  set accepted_at = now(),
      accepted_by = caller_id
  where id = pending.id;

  return pending.trainer_id;
end;
$$;

comment on function public.accept_invitation() is
  'Called by an invited athlete after signing in: accepts the latest pending, unexpired invitation for the email in his JWT, links him to that trainer (trainer_athletes) and returns the trainer''s id. Safe to retry. Errors are stable codes in the message: not_authenticated, invitation_not_found, invitation_expired, already_has_trainer.';

-- New functions get no implicit execute right (migration 1); be explicit anyway.
revoke all on function public.accept_invitation() from public, anon;
grant execute on function public.accept_invitation() to authenticated;

-- The table comments named the only writers; accept_invitation() is now one.
comment on table public.trainer_athletes is
  'Who trains whom (D2). One active link per athlete; ended links are kept. A trainer may be linked to himself (D1). Written only by accept_invitation() (the invite flow) or SQL.';
comment on table public.invitations is
  'Record of invites sent by a trainer. Inserted only by the invite-athlete Edge Function (service role); marked as accepted only by accept_invitation().';
