# syntax=docker/dockerfile:1

# #
#   Alpine Base Image with s6 overlay
#
#   @arch     x86_64
# #

FROM alpine:3.20 AS rootfs-stage

# #
#   Environment
# #

ENV ROOTFS=/root-out
ENV REL=v3.21
ENV ARCH=x86_64
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine
ENV PACKAGES=alpine-baselayout,\
alpine-keys,\
apk-tools,\
busybox,\
libc-utils

# #
#   Install packages
# #

RUN \
  apk add --no-cache \
    bash \
    xz

# #
#   Build rootfs
# #

RUN \
  mkdir -p "$ROOTFS/etc/apk" && \
  { \
    echo "$MIRROR/$REL/main"; \
    echo "$MIRROR/$REL/community"; \
  } > "$ROOTFS/etc/apk/repositories" && \
  apk --root "$ROOTFS" --no-cache --keys-dir /etc/apk/keys add --arch $ARCH --initdb ${PACKAGES//,/ } && \
  sed -i -e 's/^root::/root:!:/' /root-out/etc/shadow

# #
#   Set version for s6 overlay
# #

ARG S6_OVERLAY_VERSION="3.2.0.2"
ARG S6_OVERLAY_ARCH="x86_64"

# #
#   S6 > Add Overlay
# #

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz

# #
#   S6 > Add Optional Symlinks
# #

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz && unlink /root-out/usr/bin/with-contenv
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp
RUN tar -C /root-out -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

# #
#   Runtime stage
# #

FROM scratch
COPY --from=rootfs-stage /root-out/ /
ARG BUILD_DATE
ARG VERSION
ARG MODS_VERSION="v3"
ARG PKG_INST_VERSION="v1"
ARG KWWN_VERSION="v1"
ARG WITHCONTENV_VERSION="v1"
LABEL build_version="Keeweb v${VERSION} build-date: ${BUILD_DATE}"
LABEL maintainer="Aetherinox"

# #
#   Add CDN > Core
# #

ADD --chmod=755 "https://raw.githubusercontent.com/aetherinox/docker-alpine-base/cdn/core/docker-images.${MODS_VERSION}" "/docker-images"
ADD --chmod=755 "https://raw.githubusercontent.com/aetherinox/docker-alpine-base/cdn/core/package-install.${PKG_INST_VERSION}" "/etc/s6-overlay/s6-rc.d/init-mods-package-install/run"
ADD --chmod=755 "https://raw.githubusercontent.com/aetherinox/docker-alpine-base/cdn/core/kwwn.${KWWN_VERSION}" "/usr/bin/kwwn"
ADD --chmod=755 "https://raw.githubusercontent.com/aetherinox/docker-alpine-base/cdn/core/with-contenv.${WITHCONTENV_VERSION}" "/usr/bin/with-contenv"

# #
#   Env vars
# #

ENV PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
  HOME="/root" \
  TERM="xterm" \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  S6_VERBOSITY=1 \
  S6_STAGE2_HOOK=/docker-alpine-base \
  VIRTUAL_ENV=/kwpy \
  PATH="/kwpy/bin:$PATH"

RUN \
  echo "**** INSTALLING RUNTIME PACKAGES ****" && \
  apk add --no-cache \
    alpine-release \
    bash \
    ca-certificates \
    catatonit \
    coreutils \
    curl \
    findutils \
    jq \
    netcat-openbsd \
    procps-ng \
    shadow \
    tzdata && \
  echo "**** CREATE keeweb USER AND GENERATE STRUCTURE ****" && \
  groupmod -g 1000 users && \
  useradd -u 911 -U -d /config -s /bin/false keeweb && \
  usermod -G users keeweb && \
  mkdir -p \
    /app \
    /config \
    /defaults \
    /kwpy && \
  echo "**** CLEANUP ****" && \
  rm -rf \
    /tmp/*

# #
#   Add local files
# #

COPY root/ /

# #
#   Add entrypoint
# #

ENTRYPOINT ["/init"]
