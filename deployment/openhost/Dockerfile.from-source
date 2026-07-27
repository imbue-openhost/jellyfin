# Dockerfile for deploying Jellyfin on OpenHost.
#
# OpenHost builds this image with rootless podman from the repo root and runs it
# behind its reverse proxy. Three stages:
#   1. web-builder   — build the jellyfin-web UI bundle (separate upstream repo)
#   2. builder       — publish this repo's Jellyfin.Server from source (.NET)
#   3. runtime       — Debian + jellyfin-ffmpeg, assembled from the two above
#
# Designed for building on amd64 (linux-x64). The OpenHost hosts are x86_64.

ARG DOTNET_VERSION=10.0

FROM node:24-alpine AS web-builder
# The web UI lives in a separate repo. Track "master" to match this server's
# unstable 12.0.0 line; pin to a tag here if you want a reproducible bundle.
ARG JELLYFIN_WEB_VERSION=master
# Clone (rather than download a tarball) because jellyfin-web's webpack build
# shells out to `git describe` to stamp the bundle with a commit hash.
RUN apk add --no-cache git python3 make g++ gifsicle \
 && git clone --depth 1 --branch ${JELLYFIN_WEB_VERSION} https://github.com/jellyfin/jellyfin-web.git /jellyfin-web \
 && cd /jellyfin-web \
 && npm ci --no-audit --unsafe-perm \
 && npm run build:production \
 && mv dist /dist

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS builder
WORKDIR /repo
COPY . .
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
# Build serially (-m:1, BuildInParallel=false) to keep the publish step's peak
# memory low enough for small OpenHost VMs; a parallel self-contained publish of
# all Jellyfin projects can spike host RAM enough to disturb co-located services.
RUN dotnet publish Jellyfin.Server \
      --configuration Release \
      --output /jellyfin \
      --self-contained \
      --runtime linux-x64 \
      -m:1 -p:BuildInParallel=false \
      -p:DebugSymbols=false -p:DebugType=none

FROM debian:bookworm-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive

# Jellyfin resolves all of its writable paths from these; the entrypoint
# repoints them at the OpenHost-provided data + temp mounts at runtime.
ENV JELLYFIN_DATA_DIR=/config \
    JELLYFIN_CACHE_DIR=/cache \
    JELLYFIN_WEB_DIR=/jellyfin/jellyfin-web \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en

# jellyfin-ffmpeg (Jellyfin's patched ffmpeg build) provides software
# transcoding; hardware accel isn't available under rootless podman anyway.
RUN apt-get update \
 && apt-get install --no-install-recommends -y ca-certificates gnupg curl \
 && curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/debian-jellyfin.gpg \
 && echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" > /etc/apt/sources.list.d/jellyfin.list \
 && apt-get update \
 && apt-get install --no-install-recommends -y jellyfin-ffmpeg7 openssl locales \
 && apt-get remove -y gnupg \
 && apt-get clean autoclean -y \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

COPY --from=builder /jellyfin /jellyfin
COPY --from=web-builder /dist /jellyfin/jellyfin-web
COPY deployment/openhost/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8096
ENTRYPOINT ["/entrypoint.sh"]
