#!/usr/bin/env bash
# ----------------------
# Common bash utilities.
# Author: @azataiot
# Last update: 2023-02-11
# -----------------------

# This script may not always work as expected,
# It depends on the context where it is used.

# Source the bash profile
source /root/.bashrc

# ----------------
# Global variables
# ----------------
# 0 – Black
# 1 – Red
# 2 – Green
# 3 – Yellow
# 4 – Blue
# 5 – Magenta
# 6 – Cyan
# 7 – White

declare OK
declare ERR
declare WARN
declare INFO
declare HIGHLIGHT
declare RESET

OK=$(tput setaf 2) # green
ERR=$(tput setaf 1) # red
WARN=$(tput setaf 3) # yellow
INFO=$(tput setaf 4) # blue
HIGHLIGHT=$(tput setaf 6) # cyan
BOLD=$(tput bold)

RESET=$(tput sgr0)

# -----------------
# Utility functions
# -----------------
info() {
  echo "${INFO}[djazz] INFO: $*${RESET}"
}

error() {
  echo "${ERR}[djazz] ERROR: $*${RESET}"
}

warn() {
  echo "${WARN}[djazz] WARNING: $*${RESET}"
}

highlight() {
  echo "${HIGHLIGHT}$*${RESET}"
}

ok() {
  echo "${OK}[djazz] $*${RESET}"
}

bold() {
  echo "${BOLD}$*${RESET}"
}

# Set default environment variable if not set and export it
# usage: set_default_env "VAR" "default_value"
set_default_env() {
    local var="$1"
    local default_value="$2"

    if [ -z "${!var}" ]; then
        export "$var"="$default_value"
    fi
}

file_exists() {
  if [ -f "$1" ]; then
    return 0
  else
    return 1
  fi
}

dir_exists() {
  if [ -d "$1" ]; then
    return 0
  else
    return 1
  fi
}

cmd_exists() {
  if command -v "$1" &> /dev/null; then
    return 0
  else
    return 1
  fi
}

# Exports
export OK
export ERR
export WARN
export INFO
export HIGHLIGHT
export RESET
export BOLD

export info
export error
export warn
export highlight
export ok
export bold

export set_default_env
export file_exists
export dir_exists
export cmd_exists

