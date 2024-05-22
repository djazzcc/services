#!/usr/bin/env bash
# -------------------------------------------------------
# Docker Entrypoint script for `djazz-services` container.
# GitHub: https://github.com/djazz-cc/services
# Author: @azataiot, @djazz-cc
# Last update: 2024-05-13
# -----------------------
set -eux;

cat <<-'EOF'
         88  88
         88  ""
         88
 ,adPPYb,88  88  ,adPPYYba,  888888888  888888888
a8"    `Y88  88  ""     `Y8       a8P"       a8P"
8b       88  88  ,88djazz88    ,d8P'      ,d8P'
"8a,   ,d88  88  88,    ,88  ,d8"       ,d8"
 `"8bbdP"Y8  88  `"8bbdP"Y8  888888888  888888888
            ,88
          888P"

@azataiot - 2024 - Djazz! project
https://djazz.cc
EOF

# source the utils script
source bash-utils.sh

echo "Starting the Djazz! services ..."

echo "Setting up the djazz::PostgreSQL database ..."

# ----------
# PostgreSQL
# 1. setup env
#
# ----------

# Setup the PostgreSQL environment variables
set_default_env "PGDATA" "/var/lib/postgresql/data"
set_default_env "POSTGRES_PORT" "5432"
set_default_env "POSTGRES_DB" "djazz"
set_default_env "POSTGRES_USER" "postgres"
set_default_env "POSTGRES_PASSWORD" "postgres"
set_default_env "POSTGRES_INITDB_ARGS" ""

declare -g DATABASE_ALREADY_EXISTS: "${DATABASE_ALREADY_EXISTS:=}"
if [ -s "$PGDATA/PG_VERSION" ]; then
		DATABASE_ALREADY_EXISTS='true'
		echo "PostgreSQL database already exists in the data directory, skipping initialization ..."
fi

if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
  eval 'initdb --username="$POSTGRES_USER" --pwfile=<(printf "%s\n" "$POSTGRES_PASSWORD") '"$POSTGRES_INITDB_ARGS"' "$@"'
fi

if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
	run_sql "CREATE DATABASE $POSTGRES_DB;"
fi

echo "Starting the PostgreSQL database ..."
set -- "$@" -c listen_addresses='*' -p "${POSTGRES_PORT:-5432}"
pgctl -D "$PGDATA" -o "$@" start




