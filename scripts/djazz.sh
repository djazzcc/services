#!/usr/bin/env bash
# -------------------------------------------------------
# Djazz Management script for `djazz-services` container.
# GitHub: https://github.com/djazz-cc/services
# Author: @azataiot, @djazz-cc
# Last update: 2024-05-13
# -----------------------

set -eux;

# source the utils script
source bash-utils.sh


# If no command provided, show help
if [ $# -eq 0 ]; then
    cat <<-'EOF'
    Usage: djazz [command] [options]

    Commands:
    - `db` for database management
EOF
    exit 1;
fi

# First argument is the command, and must be one of the following:
# - `db` for database management


# -------
# Database
# -------

# if command is `db` and no subcommand provided, show help
if [ "$1" = "db" ] && [ $# -eq 1 ]; then
    cat <<-'EOF'
    Usage: djazz db [subcommand] [options]

    Subcommands:
    - `ls` to list all databases
    - `migrate` to run database migrations
    - `seed` to seed the database
    - `reset` to reset the database
EOF
    exit 1;
fi




