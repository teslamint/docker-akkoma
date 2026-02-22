ARG OTP_VERSION='26.2.5.14-1'
ARG ELIXIR_VERSION='1.15.7'
ARG ALPINE_VERSION='3.21.3'
ARG EMQX_BUILDER_VERSION='5.6-3'

FROM ghcr.io/emqx/emqx-builder/${EMQX_BUILDER_VERSION}:${ELIXIR_VERSION}-${OTP_VERSION}-alpine${ALPINE_VERSION} AS builder

ENV MIX_ENV=prod

ARG PLEROMA_VER=develop
ARG BRANCH=develop
ARG DATA=/var/lib/pleroma

RUN apk -U add --no-cache cmake exiftool ffmpeg file-dev g++ gcc git imagemagick make musl-dev patch && \
    apk add --no-cache quilt --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community/

RUN git clone -b "${BRANCH}" --depth=10 https://akkoma.dev/AkkomaGang/akkoma.git

WORKDIR /akkoma

RUN git checkout "${PLEROMA_VER}"

# Comment out 2 lines below if you don't use Cloudflare R2
COPY ./patches /akkoma/patches/
RUN quilt push -a

RUN echo "import Mix.Config" > config/prod.secret.exs
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only ${MIX_ENV}
RUN mkdir release && mix release --path release

FROM alpine:${ALPINE_VERSION} AS final

ARG UID=911
ARG GID=911
ARG HOME=/pleroma
ARG DATA=/var/lib/pleroma

RUN apk add --update --no-cache exiftool ffmpeg imagemagick libmagic ncurses postgresql-client && \
    addgroup -g ${GID} pleroma && \
    adduser --system --shell /bin/false --home ${HOME} -D -G pleroma -u ${UID} pleroma && \
    mkdir -p /etc/pleroma \
    && chown -R pleroma:pleroma /etc/pleroma \
    && mkdir -p ${DATA}/uploads \
    && mkdir -p ${DATA}/static \
    && chown -R pleroma:pleroma ${DATA}

USER pleroma

COPY --from=builder --chown=pleroma /akkoma/release ${HOME}
COPY --chown=pleroma ./docker-entrypoint.sh ${HOME}/docker-entrypoint.sh

COPY --chown=pleroma --chmod=640 ./config.exs /etc/pleroma/config.exs

EXPOSE 4000

ENTRYPOINT ["/pleroma/docker-entrypoint.sh"]
