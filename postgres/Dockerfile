ARG POSTGRES_TAG
FROM postgres:${POSTGRES_TAG}


# change permissions
RUN mkdir -p "$PGDATA" && chmod -R 700 "$PGDATA" && chown -R postgres:postgres "$PGDATA"