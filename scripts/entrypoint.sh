#!/usr/bin/env bash
# -------------------------------------------------------
# Docker Entrypoint script for `djazz-services` container.
# GitHub: https://github.com/djazz-cc/services
# Author: @azataiot, @djazz-cc
# Last update: 2024-05-13
# Services: Mailpit, MinIO, PostgreSQL, RabbitMQ, Redis
# -----------------------------------------------------

cat <<-'EOF'

     888  d8b
     888  Y8P
     888
 .d88888 8888  8888b.  88888888 88888888
d88" 888 "888     "88b    d88P     d88P
888  888  888 .d888888   d88P     d88P
Y88b 888  888 888  888  d88P     d88P
 "Y88888  888 "Y888888 88888888 88888888
          888
         d88P
       888P"

@azataiot - 2024 - Djazz!
https://djazz.cc
EOF
echo "djazz-services:$VERSION"

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
  echo "${HIGHLIGHT}[djazz] $*${RESET}"
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

# -------
# Mailpit
# /usr/local/bin/mailpit
create_folders() {
    mkdir -p /var/lib/mailpit/data
}

# Create a Mailpit password file for authentication
# https://mailpit.axllent.org/docs/configuration/passwords/
# usage: create_password_file "user" "password" "file"
create_password_file() {
    local user="$1"
    local password="$2"
    local file="$3"

    echo "$user:$password" > "$file"
    chmod 600 "$file"
}

setup_mailpit(){
  # Create the Mailpit password file
  set_default_env "MAILPIT_USER" "mailpit"
  set_default_env "MAILPIT_PASSWORD" "mailpit"
  create_password_file "$MAILPIT_USER" "$MAILPIT_PASSWORD" "/tmp/mpauth"

  # Set default environment variables
  # ---------------------------------
  set_default_env "MP_UI_AUTH_FILE" "/tmp/mpauth"
}

start_mailpit(){
  # Copy mailpit ini file
  cp /opt/djazz/supervisor.d/mailpit.ini /etc/supervisor.d/mailpit.ini
}

# -----
# minio
# /usr/bin/minio
setup_minio(){
  mkdir -p /var/lib/minio/data
}

start_minio(){
  # Start MinIO server
  cp /opt/djazz/supervisor.d/minio.ini /etc/supervisor.d/minio.ini
}

# --------
# Postgres
# Create the PostgreSQL cluster
# https://www.postgresql.org/docs/current/creating-cluster.html#CREATING-CLUSTER
pg_create_cluster() {
  info "Setting up PostgreSQL database cluster..."
  # Initialize the PostgreSQL database
  su-exec postgres initdb --auth-host=scram-sha-256 --encoding=UTF8 --user="$POSTGRES_USER" --pwfile=/tmp/pgpass -D "$PGDATA" > /dev/null 2>&1
  # Remove the password file
  rm /tmp/pgpass
  ok "PostgreSQL database cluster created successfully at $(highlight "$PGDATA")."
}

pg_configure_cluster() {
  info "Configuring PostgreSQL database cluster..."
  su-exec postgres sed -ri 's!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '\''*'\''!' "$PGDATA"/postgresql.conf
  su-exec postgres grep -q -F "host all all all scram-sha-256" "$PGDATA"/pg_hba.conf || su-exec postgres echo "host all all all scram-sha-256" >> "$PGDATA"/pg_hba.conf
}

# If the user has provided a different database name than the default `postgres`, create the database
pg_create_db() {
  if [ "$POSTGRES_DB" != 'postgres' ]; then
    info "Creating PostgreSQL database: $(highlight "$POSTGRES_DB") ..."
    # Create the PostgreSQL database
    echo "CREATE DATABASE $POSTGRES_DB;" | psql -b --username="$POSTGRES_USER" --no-password --no-psqlrc
  fi
}

setup_postgres(){
  # Check if the data directory is empty
  if [ ! -s "$(ls -A "$PGDATA")" ]; then
    # Initialize the PostgreSQL database
    pg_create_cluster
    # Configure the PostgreSQL database cluster
    pg_configure_cluster

  else
    warn "PostgreSQL Database directory appears to contain a database; Skipping initialization..."
  fi

  # Check if the PostgreSQL service is running
  if [ ! -f /var/lib/postgresql/data/postmaster.pid ]; then
    set -m
    su-exec postgres postgres -D "$PGDATA" >/dev/null 2>&1 &
    # Wait for the PostgreSQL service to start
    until su-exec postgres pg_isready; do
      info "Waiting for the PostgreSQL service to start..."
      sleep 1
    done
    # Create the PostgreSQL database if it doesn't exist (default: `postgres`)
    pg_create_db > /dev/null 2>&1
    # Stop the PostgreSQL service
    su-exec postgres pg_ctl -D "$PGDATA" stop > /dev/null 2>&1
  fi
}

start_postgres(){
  # Start the PostgreSQL service (Add to supervisord for process management)
  cp /opt/djazz/supervisor.d/postgres.ini /etc/supervisor.d/postgres.ini
}

# --------
# RabbitMQ
setup_rabbitmq(){
  # Set default environment variables
  set_default_env "RABBITMQ_USER" "admin"
  set_default_env "RABBITMQ_PASSWORD" "admin"
  set_default_env "RABBITMQ_ENABLE_MANAGEMENT_UI" "true"

  # Start the RabbitMQ server
  set -m
  rabbitmq-server > /dev/null 2>&1 &

  # Enable RabbitMQ Management UI
  if [ "$RABBITMQ_ENABLE_MANAGEMENT_UI" = "true" ]; then
    echo "Enabling RabbitMQ Management UI..."
    rabbitmq-plugins enable rabbitmq_management > /dev/null 2>&1 &
  fi

  # Stop the RabbitMQ service
  rabbitmqctl stop > /dev/null 2>&1
}

start_rabbitmq(){
  # Start RabbitMQ server
  cp /opt/djazz/supervisor.d/rabbitmq.ini /etc/supervisor.d/rabbitmq.ini
}

# -----
# Redis
# /usr/bin/redis-server
setup_redis(){
  mkdir -p /etc/redis
  mv /etc/redis.conf /etc/redis/redis.conf
  set_default_env "REDIS_PASSWORD" "redis"
  sed -i "s/# requirepass foobared/requirepass $REDIS_PASSWORD/" /etc/redis/redis.conf
  sed -i "s/bind 127.0.0.1/bind 0.0.0.0/" /etc/redis/redis.conf
  sed -i 's/^daemonize yes/daemonize no/' /etc/redis/redis.conf
  sed -i 's/^logfile .*/logfile ""/' /etc/redis/redis.conf
}

start_redis(){
  # Start Redis server
  cp /opt/djazz/supervisor.d/redis.ini /etc/supervisor.d/redis.ini
}


# ----------------------------------
# Process the command line arguments
# ----------------------------------


# shellcheck disable=SC2206
split_args=($@)
for arg in "${split_args[@]}"; do
    case $arg in
        mailpit)
            echo "Setting up Mailpit..."
            setup_mailpit
            start_mailpit
            ;;
        minio)
            echo "Setting up MinIO..."
            setup_minio
            start_minio
            ;;
        postgres)
            echo "Setting up PostgreSQL..."
            setup_postgres
            start_postgres
            ;;
        rabbitmq)
            echo "Setting up RabbitMQ..."
            setup_rabbitmq
            start_rabbitmq
            ;;
        redis)
            echo "Setting up Redis..."
            setup_redis
            start_redis
            ;;
        all)
            info "Setting up all services..."
            setup_mailpit
            start_mailpit
            setup_minio
            start_minio
            setup_postgres
            start_postgres
            setup_rabbitmq
            start_rabbitmq
            setup_redis
            start_redis
            ;;
        *)
            cat <<-'EOF'
            ERROR: Invalid argument provided; Should be one of the following:
            - postgres
            - minio
            - mailpit
            - redis
            - rabbitmq
            - all (default)
EOF
            exit 1;
            ;;
    esac
done


#-----------
# Supervisor
# -----------


echo "Enabling selected services..."
supervisord -c /etc/supervisord.conf
supervisorctl reread
supervisorctl update
supervisorctl start all
