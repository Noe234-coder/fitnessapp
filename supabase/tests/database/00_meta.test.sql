-- Meta tests: conventions every public table must follow (docs/schema-v1.md §2, §5, §6).
-- They read the catalog, so every new table is covered automatically.

begin;

select plan(21);

-- Every ordinary or partitioned table in public.
create temp view public_tables as
select c.oid, c.relname::text as table_name
from pg_catalog.pg_class c
where c.relnamespace = 'public'::regnamespace
  and c.relkind in ('r', 'p');

select isnt_empty(
  'select table_name from public_tables',
  'there are public tables to check'
);

-- RLS ----------------------------------------------------------------------

select is_empty(
  $$ select t.table_name
     from public_tables t
     join pg_catalog.pg_class c on c.oid = t.oid
     where not c.relrowsecurity $$,
  'every public table has RLS enabled'
);

-- Comments -----------------------------------------------------------------

select is_empty(
  $$ select t.table_name
     from public_tables t
     where pg_catalog.obj_description(t.oid, 'pg_class') is null $$,
  'every public table has a comment'
);

select is_empty(
  $$ select t.table_name || '.' || a.attname
     from public_tables t
     join pg_catalog.pg_attribute a on a.attrelid = t.oid
     where a.attnum > 0
       and not a.attisdropped
       and pg_catalog.col_description(t.oid, a.attnum) is null $$,
  'every column of every public table has a comment'
);

-- Timestamps and trigger ---------------------------------------------------

select is_empty(
  $$ select t.table_name
     from public_tables t
     where not exists (
       select 1
       from information_schema.columns c
       where c.table_schema = 'public'
         and c.table_name = t.table_name
         and c.column_name = 'created_at'
         and c.data_type = 'timestamp with time zone'
         and c.is_nullable = 'NO'
         and c.column_default = 'now()'
     ) $$,
  'every public table has created_at timestamptz not null default now()'
);

select is_empty(
  $$ select t.table_name
     from public_tables t
     where not exists (
       select 1
       from information_schema.columns c
       where c.table_schema = 'public'
         and c.table_name = t.table_name
         and c.column_name = 'updated_at'
         and c.data_type = 'timestamp with time zone'
         and c.is_nullable = 'NO'
         and c.column_default = 'now()'
     ) $$,
  'every public table has updated_at timestamptz not null default now()'
);

-- tgtype bits: 1 = row level, 2 = before, 4 = insert, 16 = update.
select is_empty(
  $$ select t.table_name
     from public_tables t
     where not exists (
       select 1
       from pg_catalog.pg_trigger tg
       where tg.tgrelid = t.oid
         and not tg.tgisinternal
         and tg.tgenabled = 'O'
         and tg.tgfoid = 'private.set_updated_at()'::regprocedure
         and tg.tgtype & 1 = 1
         and tg.tgtype & 2 = 2
         and tg.tgtype & 4 = 4
         and tg.tgtype & 16 = 16
     ) $$,
  'every public table has the set_updated_at trigger (before insert or update, per row)'
);

-- Privileges on public tables ----------------------------------------------

select is_empty(
  $$ select t.table_name
     from public_tables t
     where has_table_privilege(
       'anon', t.oid,
       'select, insert, update, delete, truncate, references, trigger, maintain'
     ) $$,
  'anon has no table privilege on any public table'
);

select is_empty(
  $$ select t.table_name
     from public_tables t
     where has_any_column_privilege('anon', t.oid, 'select, insert, update, references') $$,
  'anon has no column privilege on any public table'
);

select is_empty(
  $$ select t.table_name
     from public_tables t
     where has_table_privilege('authenticated', t.oid, 'truncate, references, trigger, maintain') $$,
  'authenticated never has truncate, references, trigger or maintain on a public table'
);

-- The private schema --------------------------------------------------------

select ok(
  not has_schema_privilege('anon', 'private', 'usage'),
  'anon has no usage on the private schema'
);

select ok(
  has_schema_privilege('authenticated', 'private', 'usage'),
  'authenticated has usage on the private schema (policies call its helpers)'
);

select is_empty(
  $$ select p.oid::regprocedure::text
     from pg_catalog.pg_proc p
     where p.pronamespace = 'private'::regnamespace
       and has_function_privilege('anon', p.oid, 'execute') $$,
  'anon cannot execute any private function'
);

-- grantee 0 is PUBLIC.
select is_empty(
  $$ select p.oid::regprocedure::text
     from pg_catalog.pg_proc p
     where p.pronamespace = 'private'::regnamespace
       and exists (
         select 1
         from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
         where a.grantee = 0
       ) $$,
  'no private function is executable by PUBLIC'
);

select is_empty(
  $$ select p.oid::regprocedure::text
     from pg_catalog.pg_proc p
     where p.pronamespace = 'private'::regnamespace
       and not coalesce(p.proconfig, '{}') @> array['search_path=""'] $$,
  'every private function sets search_path to empty'
);

-- Default privileges --------------------------------------------------------
-- New objects created by the migration role must not be reachable by anon.
-- (Probes are created last so the checks above don't see them; rolled back.)

select is(
  current_user::text,
  'postgres',
  'tests run as postgres, the role that runs the migrations'
);

create table public.zz_default_privileges_probe (id bigint generated always as identity);
create function public.zz_default_privileges_probe() returns integer language sql as 'select 1';
create function private.zz_default_privileges_probe() returns integer language sql as 'select 1';

select ok(
  not has_table_privilege(
    'anon', 'public.zz_default_privileges_probe',
    'select, insert, update, delete, truncate, references, trigger, maintain'
  ),
  'anon gets no privilege on a new public table'
);

select ok(
  not has_sequence_privilege(
    'anon', 'public.zz_default_privileges_probe_id_seq', 'usage, select, update'
  ),
  'anon gets no privilege on a new public sequence'
);

select ok(
  not has_function_privilege('anon', 'public.zz_default_privileges_probe()', 'execute'),
  'anon cannot execute a new public function'
);

select ok(
  not has_function_privilege('anon', 'private.zz_default_privileges_probe()', 'execute'),
  'anon cannot execute a new private function'
);

select ok(
  not has_function_privilege('authenticated', 'private.zz_default_privileges_probe()', 'execute'),
  'authenticated cannot execute a new private function until it is granted'
);

select * from finish();

rollback;
