FROM --platform=$TARGETPLATFORM elixir:1.13.4-alpine as builder

ENV MIX_ENV=prod

ARG PLEROMA_VER=develop
ARG DATA=/var/lib/pleroma

RUN apk add git gcc g++ musl-dev make cmake file-dev ffmpeg imagemagick exiftool patch

RUN git clone -b develop --depth=10 https://akkoma.dev/AkkomaGang/akkoma.git && \
    cd akkoma && git checkout "${PLEROMA_VER}"

RUN cd akkoma && wget -O- https://gist.githubusercontent.com/teslamint/1ca70d83197409be662966e8f1fea257/raw/35c7e2d85e7e1d08f45a67afcd1319c70f7b366b/patch-1.patch | patch -p1 && \
	cd ..

RUN cd akkoma && echo "import Mix.Config" > config/prod.secret.exs && \
	mix local.hex --force && \
	mix local.rebar --force && \
	mix deps.get --only prod && \
	mkdir release && \
	mix release --path release

FROM --platform=$TARGETPLATFORM alpine:3.16.2 as final

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
