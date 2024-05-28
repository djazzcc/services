#!/usr/bin/env bash
# -------------------------------------------------------
# Docker Entrypoint script for `djazz-services` container.
# GitHub: https://github.com/djazz-cc/services
# Author: @azataiot, @djazz-cc
# Last update: 2024-05-13
# Services: Mailpit, MinIO, PostgreSQL, RabbitMQ, Redis
# -----------------------------------------------------

# Source common functions and variables
source common.sh

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

@azataiot - 2024 - (djazz-cc/services)
https://djazz.cc
EOF

info "Starting the djazz services..."

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
  ok "Mailpit user $(highlight "$MAILPIT_USER")"

  # Set default environment variables
  # ---------------------------------
  set_default_env "MP_UI_AUTH_FILE" "/tmp/mpauth"
}

prepare_mailpit(){
  # Copy mailpit ini file
  cp /opt/djazz/supervisor.d/mailpit.ini /etc/supervisor.d/mailpit.ini
  ok "Mailpit Web UI: $(highlight "http://localhost:8025")."
  ok "Mailpit SMTP: $(highlight "localhost:1025")."
}

# -----
# minio
# /usr/bin/minio
setup_minio(){
  mkdir -p /var/lib/minio/data && chown -R minio:minio /var/lib/minio/data
  ok "MinIO data directory created at $(highlight "/var/lib/minio/data")."
  ok "MinIO Web UI: $(highlight "http://localhost:9001")."
  ok "MinIO S3-API: $(highlight "http://localhost:9000")."
}

prepare_minio(){
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
    ok "PostgreSQL accepting connections on $(highlight "localhost:5432")."
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

prepare_postgres(){
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
  ok "RabbitMQ Web UI: $(highlight "http://localhost:15672")"
}

prepare_rabbitmq(){
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
  ok "Redis accepting connections on $(highlight "localhost:6379")"
}

prepare_redis(){
  # Start Redis server
  cp /opt/djazz/supervisor.d/redis.ini /etc/supervisor.d/redis.ini
}


# ----------------------------------
# Process the command line arguments
# ----------------------------------

start_mailpit(){
  echo "Setting up Mailpit..."
  info "📫 MAILPIT"
  setup_mailpit
  prepare_mailpit
}

start_minio(){
  echo "Setting up MinIO..."
  info "💾 MINIO"
  setup_minio
  prepare_minio
}

start_postgres(){
  echo "Setting up PostgreSQL..."
  info "🐘 POSTGRES"
  setup_postgres
  prepare_postgres
}

start_rabbitmq(){
  echo "Setting up RabbitMQ..."
  info "🐰 RABBITMQ"
  setup_rabbitmq
  prepare_rabbitmq
}

start_redis(){
  echo "Setting up Redis..."
  info "📌 REDIS"
  setup_redis
  prepare_redis
}

# shellcheck disable=SC2206
split_args=($@)
for arg in "${split_args[@]}"; do
    case $arg in
        all)
            info "Setting up all services..."
            start_mailpit
            start_minio
            start_postgres
            start_rabbitmq
            start_redis
            ok "All services are up and running."
            ;;
        mailpit)
            start_mailpit
            ;;
        minio)
            start_minio
            ;;
        postgres)
            start_postgres
            ;;
        rabbitmq)
            start_rabbitmq
            ;;
        redis)
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


info "Adding selected services to supervisor..."
supervisord -c /etc/supervisord.conf
supervisorctl reread
supervisorctl update
supervisorctl start all
