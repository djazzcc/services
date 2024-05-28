#!/usr/bin/env bash
# -------------------------
# Supervisor Logger script.
# Author: @azataiot
# Last update: 2024-05-28
# -----------------------

# Get the process name from the environment variable
printf -v PREFIX "%-10.10s" "${SUPERVISOR_PROCESS_NAME}"

# Prefix the log message with the process name
# Prefix stdout and stderr
exec 1> >( awk '{ print "'"$PREFIX"' | " $0 }' >&1)
exec 2> >( awk '{ print "'"$PREFIX"' | " $0 }' >&2)

# Run the command with the arguments
exec "$@"