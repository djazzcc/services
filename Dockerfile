# -------------------------
# Djazz-Services Dockerfile
# https://djazz.cc
# Author: @azataiot
# Date: 2024-05-27
# ----------------
ARG VERSION=0.1.0
ARG BASE_IMAGE=azataiot/alpine:latest
FROM ${BASE_IMAGE} as builder
ENV LANG en_US.utf8
# Update and upgrade the system
RUN set -eux; \
    apk update; \
    apk upgrade

# ---------------
# Mailpit Builder
# ---------------

RUN set -eux; \
    apk add --no-cache \
        curl; \
    MP_VERSION=$(curl --silent --location --max-time "90" "https://api.github.com/repos/axllent/mailpit/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'); \
    BUILDOS=$(uname -s | tr '[:upper:]' '[:lower:]'); \
    BUILDARCH=$(uname -m); \
    if [ "$BUILDARCH" = "aarch64" ]; then \
        BUILDARCH="arm64"; \
    elif [ "$BUILDARCH" = "x86_64" ]; then \
        BUILDARCH="amd64"; \
    fi; \
    MP_GO_BIN="mailpit-${BUILDOS}-${BUILDARCH}.tar.gz"; \
    echo "Downloading Mailpit ${MP_VERSION} for ${BUILDOS}-${BUILDARCH}"; \
    mkdir -p /tmp/mailpit; \
    wget -O /tmp/mailpit/${MP_GO_BIN} https://github.com/axllent/mailpit/releases/download/${MP_VERSION}/${MP_GO_BIN}; \
    tar -xzf /tmp/mailpit/${MP_GO_BIN} -C /tmp/mailpit; \
    mv /tmp/mailpit/mailpit /usr/local/bin/mailpit; \
    chmod +x /usr/local/bin/mailpit; \
    rm -rf /tmp/mailpit

# ----------------
# RabbitMQ Builder
# ----------------

RUN set -eux; \
    apk add --no-cache \
        erlang

# Download "Generic Binary Build" of RabbitMQ server
RUN set -eux; \
    \
    wget https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.13.2/rabbitmq-server-generic-unix-3.13.2.tar.xz; \
    tar -xf rabbitmq-server-generic-unix-3.13.2.tar.xz; \
    mv rabbitmq_server-3.13.2 /opt/rabbitmq; \
    ls -la /opt/rabbitmq; \
    rm rabbitmq-server-generic-unix-3.13.2.tar.xz; \
    echo 'export PATH=/opt/rabbitmq/sbin:$PATH' >> ~/.bashrc ; \
    echo "loopback_users.guest = false" >> /opt/rabbitmq/etc/rabbitmq/rabbitmq.conf; \
    echo "log.console = true" >> /opt/rabbitmq/etc/rabbitmq/rabbitmq.conf



ARG VERSION
FROM ${BASE_IMAGE} as final
ENV LANG en_US.utf8
ENV VERSION=${VERSION}
# Add packages
RUN set -eux; \
    apk add --no-cache \
        ncurses \
        postgresql \
        postgresql-contrib \
        redis \
        minio \
        erlang \
        supervisor ;\
    mkdir -p /etc/supervisor.d ;\
    mkdir -p /opt/djazz/supervisor.d

# -------
# Mailpit
# -------
ENV MAILPIT_USER=mailpit
ENV MAILPIT_PASSWORD=mailpit
COPY --from=builder /usr/local/bin/mailpit /usr/local/bin/mailpit
EXPOSE 8025
EXPOSE 1025

# -----
# Minio
# -----
ENV MINIO_ROOT_USER=minio
ENV MINIO_ROOT_PASSWORD=minio123
EXPOSE 9000 9001
VOLUME /var/lib/minio/data

# --------
# Postgres
# --------
ENV PGDATA=/var/lib/postgresql/data
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=postgres
ENV TZ=UTC
RUN set -eux; \
      \
        mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 700 "$PGDATA"; \
        mkdir -p /run/postgresql && chown -R postgres:postgres /run/postgresql && chmod 3777 /var/run/postgresql ; \
        echo "$POSTGRES_PASSWORD" > /tmp/pgpass
EXPOSE 5432
VOLUME /var/lib/postgresql/data

# --------
# RabbitMQ
# --------
ENV RABBITMQ_ENABLE_MANAGEMENT_UI=true
COPY --from=builder /root/.bashrc /root/.bashrc
COPY --from=builder /opt/rabbitmq/escript /opt/rabbitmq/escript
COPY --from=builder /opt/rabbitmq/etc /opt/rabbitmq/etc
COPY --from=builder /opt/rabbitmq/plugins /opt/rabbitmq/plugins
COPY --from=builder /opt/rabbitmq/sbin /opt/rabbitmq/sbin
COPY --from=builder /opt/rabbitmq/share /opt/rabbitmq/share
EXPOSE 5672 15672
VOLUME /opt/rabbitmq/var

# -----
# Redis
# -----
ENV REDIS_PASSWORD=redis
EXPOSE 6379
VOLUME /etc/redis/



# Copy the docker-entrypoint.sh script into the Docker image
COPY ./scripts/entrypoint.sh /usr/local/bin/
COPY ./scripts/logger.sh /usr/local/bin/logger
COPY ./scripts/supervisord.conf /etc/supervisord.conf
copy ./scripts/supervisor.d/* /opt/djazz/supervisor.d/

# Make the script executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Use the script as the entrypoint
ENTRYPOINT ["entrypoint.sh"]
CMD ["all"]





