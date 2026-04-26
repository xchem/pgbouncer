FROM alpine:3.22.4 AS build
ARG VERSION=1.25.1

# Inspiration from https://github.com/gmr/alpine-pgbouncer/blob/master/Dockerfile
# hadolint ignore=DL3003,DL3018
RUN apk add --no-cache \
      autoconf \
      automake \
      curl \
      gcc \
      libc-dev \
      libevent-dev \
      libtool \
      make \
      openssl-dev \
      pkgconfig

# build version for release
RUN curl -sS -o /pgbouncer.tar.gz -L https://pgbouncer.github.io/downloads/files/$VERSION/pgbouncer-$VERSION.tar.gz \
    && tar -xzf /pgbouncer.tar.gz \
    && mv /pgbouncer-$VERSION /pgbouncer

RUN cd /pgbouncer \
    && ./configure --prefix=/usr \
    && make -j$(nproc) pgbouncer \
    && strip pgbouncer

FROM alpine:3.22.4

RUN apk add --no-cache \
      libevent \
      postgresql-client \
    && mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer \
    && touch /etc/pgbouncer/userlist.txt \
    && chown -R postgres /var/log/pgbouncer /var/run/pgbouncer /etc/pgbouncer

COPY entrypoint.sh /entrypoint.sh
COPY --from=build /pgbouncer/pgbouncer /usr/bin
COPY --from=build /pgbouncer/etc/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.example
COPY --from=build /pgbouncer/etc/userlist.txt /etc/pgbouncer/userlist.txt.example

# Set fragalysis-friendly defaults
ENV AUTH_TYPE="scram-sha-256"
ENV CANCEL_WAIT_TIMEOUT="0"
ENV DEFAULT_POOL_SIZE="16"
ENV LOG_CONNECTIONS="0"
ENV LOG_DISCONNECTIONS="1"
ENV MAX_CLIENT_CONN="1000"
ENV MAX_DB_CONNECTIONS="16"
ENV MIN_POOL_SIZE="16"
ENV POOL_MODE="transaction"
ENV QUERY_WAIT_TIMEOUT="0"
ENV QUERY_WAIT_NOTIFY="0"
ENV SERVER_IDLE_TIMEOUT="14400"
ENV SERVER_RESET_QUERY="DISCARD ALL"
ENV STATS_PERIOD="300"

EXPOSE 5432
USER postgres
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
