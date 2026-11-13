#!/usr/bin/env bash
# Dumps the data of a Supabase database and encrypts it with age, in one
# pipeline: the clear dump is never written to disk.
#
#   BACKUP_DB_URL='postgresql://…' BACKUP_AGE_RECIPIENT='age1…' \
#     scripts/backup-db.sh <output-file>.sql.gz.age
#
# Inputs (environment, so they never show up in a process list or a log):
#   BACKUP_DB_URL         connection string of the database to dump
#   BACKUP_AGE_RECIPIENT  age PUBLIC key (age1…) the dump is encrypted to
# Optional:
#   PG_DUMP               pg_dump to run (default: pg_dump); it must be the
#                         server's major version, see BACKUP_PG_MAJOR
#   AGE                   age to run (default: age)
#   BACKUP_PG_MAJOR       expected pg_dump major version (default: 17)
#
# There are no defaults for the two inputs: nothing here knows where the
# hosted project is. It only reads from the database.
#
# What the dump holds, and how to restore it: docs/backup-restore.md.
# It prints sizes only: never the URL, the dump or anything from a row.
set -euo pipefail

PG_DUMP="${PG_DUMP:-pg_dump}"
AGE="${AGE:-age}"
BACKUP_PG_MAJOR="${BACKUP_PG_MAJOR:-17}"

fail() {
  echo "backup-db: $1" >&2
  exit 1
}

[ "$#" -eq 1 ] || fail "usage: scripts/backup-db.sh <output-file>.sql.gz.age"
output="$1"

case "$output" in
  *.sql.gz.age) ;;
  *) fail "the output file must end in .sql.gz.age" ;;
esac
[ ! -e "$output" ] || fail "the output file already exists"
[ -d "$(dirname "$output")" ] || fail "the output folder does not exist"

[ -n "${BACKUP_DB_URL:-}" ] || fail "BACKUP_DB_URL is not set"
case "$BACKUP_DB_URL" in
  postgresql://* | postgres://*) ;;
  *) fail "BACKUP_DB_URL is not a postgresql:// connection string" ;;
esac

# The value is not echoed back: if it is not a public key it may be a private
# one pasted by mistake.
[ -n "${BACKUP_AGE_RECIPIENT:-}" ] || fail "BACKUP_AGE_RECIPIENT is not set"
[[ "$BACKUP_AGE_RECIPIENT" =~ ^age1[0-9a-z]{20,}$ ]] ||
  fail "BACKUP_AGE_RECIPIENT is not an age public key (age1…)"

command -v "$PG_DUMP" > /dev/null || fail "pg_dump not found: $PG_DUMP"
command -v "$AGE" > /dev/null || fail "age not found: $AGE"
command -v gzip > /dev/null || fail "gzip not found"

# A newer pg_dump writes dumps an older psql or server may not read, and an
# older one refuses to dump a newer server.
pg_dump_version="$("$PG_DUMP" --version)"
[[ "$pg_dump_version" =~ \)\ ([0-9]+) ]] ||
  fail "cannot read the pg_dump version"
[ "${BASH_REMATCH[1]}" = "$BACKUP_PG_MAJOR" ] ||
  fail "pg_dump is version ${BASH_REMATCH[1]}, expected $BACKUP_PG_MAJOR"

partial="$output.partial"
errors="$(mktemp)"
cleanup() {
  rm -f "$partial" "$errors"
}
trap cleanup EXIT

# Data only: the schema comes from the repo's migrations. One pg_dump run, so
# every table is read in the same snapshot.
#
# The dump starts by switching session_replication_role to `replica`, so that
# no trigger fires while it is loaded: the set_updated_at triggers would
# overwrite every updated_at with the time of the restore, and the trigger on
# auth.users would create a second profile for every user. A role that may
# not set it gets an error at the first line instead of a silent rewrite.
status=0
{
  cat << 'SQL'
-- FitnessApp backup: data only (every table of public, auth.users,
-- auth.identities). Load it into a database that has the repo's migrations
-- and no rows: docs/backup-restore.md.
SET session_replication_role = replica;
SQL
  "$PG_DUMP" \
    --dbname="$BACKUP_DB_URL" \
    --data-only \
    --no-owner \
    --no-privileges \
    --strict-names \
    --table='public.*' \
    --table='auth.users' \
    --table='auth.identities' \
    2> "$errors" || exit 1
  # Only reached when pg_dump succeeded (errexit is off inside this list):
  # a dump without this last line is incomplete.
  echo 'RESET session_replication_role;'
} | gzip -9 | "$AGE" --encrypt --recipient "$BACKUP_AGE_RECIPIENT" > "$partial" ||
  status=$?

if [ "$status" -ne 0 ]; then
  # pg_dump's messages name tables and columns, never row values. A
  # connection string is removed anyway.
  sed -E 's#postgres(ql)?://[^[:space:]]+#<connection string>#g' "$errors" >&2
  fail "the dump failed; nothing was written"
fi

[ "$(head -c 21 "$partial")" = "age-encryption.org/v1" ] ||
  fail "the output is not an age file; nothing was written"

mv "$partial" "$output"
echo "backup-db: wrote $(wc -c < "$output") bytes, encrypted ($pg_dump_version)"
