#!/usr/bin/env bash
# -----------------------
# Docker utils functions.
# GitHub: https://github.com/djazz-cc/services
# Author: @azataiot, @djazz-cc
# Last update: 2024-05-13
# -----------------------
set -eux;

# Set default environment variable if not set and export it
# usage: set_default_env "VAR" "default_value"
set_default_env() {
    local var="$1"
    local default_value="$2"

    if [ -z "${!var}" ]; then
        export "$var"="$default_value"
    fi
}

# Run SQL commands in the PostgreSQL database
# usage: run_sql "SQL_COMMAND"
run_sql() {
    local sql_command="$1"

    psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        $sql_command
EOSQL
}






