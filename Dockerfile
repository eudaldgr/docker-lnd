# Global arguments
ARG APP_UID=1000
ARG APP_GID=1000

FROM ghcr.io/eudaldgr/scratchless AS scratchless

# Build stage
FROM docker.io/alpine AS build
ARG APP_VERSION \
  APP_ROOT \
  TARGETARCH \
  TARGETVARIANT

RUN set -ex; \
  apk --no-cache --update add \
  clang \
  curl \
  git \
  go \
  gnupg \
  make;

RUN set -ex; \
  git clone --branch v${APP_VERSION} https://github.com/lightningnetwork/lnd.git;

RUN set -ex; \
  gpgconf --kill all; \
  curl -s \
  https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc |\
  gpg --import;

RUN set -ex; \
  cd lnd; \
  git verify-tag v${APP_VERSION};

RUN set -ex; \
  cd lnd; \
  GOPATH=$(pwd) NO_PROXY="*" make release-install;

RUN set -ex; \
  cd lnd; \
  strip bin/lncli; \
  strip bin/lnd;

COPY --from=scratchless / ${APP_ROOT}/

RUN set -ex; \
  mkdir -p \
  ${APP_ROOT}/bin \
  ${APP_ROOT}/data \
  ${APP_ROOT}/etc \
  ${APP_ROOT}/lib;

RUN set -ex; \
  cd lnd; \
  cp bin/lncli ${APP_ROOT}/bin/; \
  cp bin/lnd ${APP_ROOT}/bin/;

# Final scratch image
FROM scratch

ARG TARGETPLATFORM \
  TARGETOS \
  TARGETARCH \
  TARGETVARIANT \
  APP_IMAGE \
  APP_NAME \
  APP_VERSION \
  APP_ROOT \
  APP_UID \
  APP_GID \
  APP_NO_CACHE

ENV APP_IMAGE=${APP_IMAGE} \
  APP_NAME=${APP_NAME} \
  APP_VERSION=${APP_VERSION} \
  APP_ROOT=${APP_ROOT}

COPY --from=build ${APP_ROOT}/ /

ENV HOME=/data
VOLUME /data/.lnd

# 10009 RPC
# 9735  P2P
# 8080  REST
# 9911  Watchtower
EXPOSE 10009 9735 8080 9911

USER ${APP_UID}:${APP_GID} 
ENTRYPOINT ["/bin/lnd", "--lnddir=/data/.lnd"]