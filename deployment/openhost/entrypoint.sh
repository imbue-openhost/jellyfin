#!/bin/sh
# OpenHost entrypoint for Jellyfin.
#
# OpenHost mounts an app's persistent data at $OPENHOST_APP_DATA_DIR (backed up)
# and scratch space at $OPENHOST_APP_TEMP_DIR (not backed up). Point Jellyfin's
# data/config directory at the former and its regenerable cache at the latter so
# libraries, users, and settings survive redeploys while transcode/image caches
# stay out of backups. Fall back to the image defaults for non-OpenHost runs.
set -eu

export JELLYFIN_DATA_DIR="${OPENHOST_APP_DATA_DIR:-${JELLYFIN_DATA_DIR:-/config}}"
export JELLYFIN_CACHE_DIR="${OPENHOST_APP_TEMP_DIR:-${JELLYFIN_CACHE_DIR:-/cache}}"

mkdir -p "$JELLYFIN_DATA_DIR" "$JELLYFIN_CACHE_DIR"

exec /jellyfin/jellyfin \
  --datadir "$JELLYFIN_DATA_DIR" \
  --cachedir "$JELLYFIN_CACHE_DIR" \
  --webdir "${JELLYFIN_WEB_DIR:-/jellyfin/jellyfin-web}" \
  --ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg \
  "$@"
