FROM alpine:3.19
ENV LANG en_US.utf8
# Install PostgreSQL
RUN set -eux; \
    apk update; \
    apk add --no-cache \
    bash \
    su-exec \
    postgresql \
    postgresql-contrib


# Create a directory for the database and set the owner to the postgres user
RUN set -eux; \
    mkdir -p /var/lib/postgresql/data; \
    chown -R postgres:postgres /var/lib/postgresql/data \
    mkdir -p /var/run/postgresql; \
    chown -R postgres:postgres /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data


RUN chmod +x scripts/*.sh
COPY scripts/*.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 5432
CMD ["bash"]





