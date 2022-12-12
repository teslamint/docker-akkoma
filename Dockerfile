FROM --platform=$TARGETPLATFORM elixir:1.14.2-alpine as builder

ENV MIX_ENV=prod

ARG PLEROMA_VER=develop
ARG DATA=/var/lib/pleroma

RUN apk add git gcc g++ musl-dev make cmake file-dev ffmpeg imagemagick exiftool patch

RUN git clone -b develop --depth=10 https://akkoma.dev/AkkomaGang/akkoma.git

WORKDIR /akkoma

RUN git checkout "${PLEROMA_VER}"

RUN wget -O- https://gist.githubusercontent.com/teslamint/1ca70d83197409be662966e8f1fea257/raw/35c7e2d85e7e1d08f45a67afcd1319c70f7b366b/patch-1.patch | patch -p1

RUN echo "import Mix.Config" > config/prod.secret.exs
RUN mix local.hex --force && mix local.rebar --force
RUN	mix deps.get --only ${MIX_ENV}
RUN mkdir release && mix release --path release

FROM --platform=$TARGETPLATFORM alpine:3.17.0 as final

ENV UID=911 GID=911

ARG HOME=/pleroma
ARG DATA=/var/lib/pleroma

RUN apk add --update --no-cache exiftool imagemagick libmagic ncurses postgresql-client ffmpeg && \
	addgroup -g ${GID} pleroma && \
	adduser --system --shell /bin/false --home ${HOME} -D -G pleroma -u ${UID} pleroma

RUN mkdir -p /etc/pleroma \
    && chown -R pleroma:pleroma /etc/pleroma \
    && mkdir -p ${DATA}/uploads \
    && mkdir -p ${DATA}/static \
    && chown -R pleroma:pleroma ${DATA}

USER pleroma

COPY --from=builder --chown=pleroma /akkoma/release ${HOME}
COPY --chown=pleroma ./docker-entrypoint.sh ${HOME}/docker-entrypoint.sh

# COPY ./config.exs /etc/pleroma/config.exs

EXPOSE 4000

ENTRYPOINT ["/pleroma/docker-entrypoint.sh"]
