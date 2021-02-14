#!/bin/bash

set -Eeuo pipefail

function usage {
  cat <<EOF >&2
Usage: $(basename "$0") [OPTIONS...] -d DATABASE <backup|restore>"

Backup / restore small ClickHouse databases.

  -d, --database DATABASE   use this database
  -v, --verbose             show verbose output
  -?, --help                display this help and exit

If no FILE or FILE is -, this will use standard input/output.

Other OPTIONS will be passed to clickhouse-client, e.g., --host, --port.
EOF
}

CLICKHOUSE_OPTIONS=()
COMMAND=
DATABASE=
VERBOSE=

while true; do
  if [ $# = 0 ]; then
    break
  elif [ $# = 1 ]; then
    COMMAND="$1"
    break
  elif [ "$1" = "-d" ] || [ "$1" = "--database" ]; then
    shift
    DATABASE="$1"
  elif [ "$1" = "-v" ] || [ "$1" = "--verbose" ]; then
    VERBOSE=1
  elif [ "$1" = "-?" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
  else
    CLICKHOUSE_OPTIONS+=("$1")
  fi
  shift
done

if ( [ "$COMMAND" != backup ] && [ "$COMMAND" != restore ] ) || \
   [ -z "$DATABASE" ]; then
  usage
  exit 1
fi

if [ -z "$(which clickhouse-client)" ]; then
  echo "ERROR: clickhouse-client not found" >&2
  echo "See https://clickhouse.tech/docs/en/getting-started/install/" >&2
  exit 1
fi

function log {
  if [ "$VERBOSE" = 1 ]; then
    echo "$@" >&2
  fi
}

function cc {
  clickhouse-client "${CLICKHOUSE_OPTIONS[@]}" "$@" 2>&1
}


TMP_DIR="$(mktemp -d)"
trap '{ set +eu; cd /; rm -rf "$TMP_DIR"; }' EXIT
cd "$TMP_DIR"

if [ "$COMMAND" = "backup" ]; then

  log "Backing up $DATABASE"

  for table in $(cc -q "SHOW TABLES FROM $DATABASE"); do
    log "  table $table"
    cc -d "$DATABASE" -q "SHOW CREATE TABLE ${table} FORMAT RawBLOB" \
      > "$table.sql"
    echo ";" >> "$table.sql"
    perl -pi -e "s/CREATE TABLE ${DATABASE}./CREATE TABLE /" $table.sql
    cc -d "$DATABASE" -q "SELECT * FROM ${table} FORMAT TSV" \
      > "$table.tsv"
  done

  tar cz .

else

  log "Restoring to $DATABASE"
  tar zxf -

  cc -q "DROP DATABASE IF EXISTS $DATABASE"
  cc -q "CREATE DATABASE $DATABASE"

  for table_sql in $(ls *.sql); do
    table="${table_sql%.sql}"
    log -n "  table $table"
    cat "$table_sql" | cc -d "$DATABASE"
    if test -s "$table.tsv"; then
      log
      cat "$table.tsv" | cc -d "$DATABASE" -q "INSERT INTO $table FORMAT TSV"
    else
      log " (empty)"
    fi
  done

fi

cd /
rm -rf "$TMP_DIR"
