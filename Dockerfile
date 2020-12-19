FROM elixir:1.13.4-alpine as builder

ENV MIX_ENV=prod

ARG PLEROMA_VER=stable
ARG DATA=/var/lib/pleroma

RUN apk add git gcc g++ musl-dev make cmake file-dev

RUN git clone -b stable --depth=10 https://git.pleroma.social/pleroma/pleroma.git && \
    cd pleroma && git checkout "${PLEROMA_VER}"

RUN cd pleroma && echo "import Mix.Config" > config/prod.secret.exs && \
	mix local.hex --force && \
	mix local.rebar --force && \
	mix deps.get --only prod && \
	mkdir release && \
	mix release --path release

FROM alpine:3.15.4 as final

ENV UID=911 GID=911

ARG DATA=/var/lib/pleroma

RUN apk update && \
	apk add exiftool imagemagick libmagic ncurses postgresql-client && \
	addgroup -g ${GID} pleroma && \
	adduser --system --shell /bin/false --home ${HOME} -u ${UID} pleroma

RUN mkdir -p /etc/pleroma \
    && chown -R pleroma /etc/pleroma \
    && mkdir -p ${DATA}/uploads \
    && mkdir -p ${DATA}/static \
    && chown -R pleroma ${DATA}

USER pleroma

COPY --from=builder --chown=pleroma:0 /pleroma/release ${HOME}
COPY --from=builder --chown=pleroma:0 /pleroma/docker-entrypoint.sh /pleroma/docker-entrypoint.sh

COPY config/secret.exs ${DATA}/config/secret.exs

COPY ./config/docker.exs /etc/pleroma/config.exs
COPY ./docker-entrypoint.sh ${HOME}

EXPOSE 4000

VOLUME /var/lib/pleroma/uploads/

ENTRYPOINT ["/opt/pleroma/docker-entrypoint.sh"]
