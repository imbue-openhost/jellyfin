#!/bin/sh
# OpenHost entrypoint for Jellyfin.
#
# OpenHost mounts an app's persistent data at $OPENHOST_APP_DATA_DIR (backed up)
# and scratch space at $OPENHOST_APP_TEMP_DIR (not backed up). Point Jellyfin's
# data/config directory at the former and its regenerable cache at the latter so
# libraries, users, and settings survive redeploys while transcode/image caches
# stay out of backups. Fall back to the image defaults for non-OpenHost runs.
#
# Written to work both on the official jellyfin/jellyfin image and on an
# image built from this repo's source, by auto-detecting the binary, web
# bundle, and ffmpeg locations rather than hard-coding them.
set -eu

export JELLYFIN_DATA_DIR="${OPENHOST_APP_DATA_DIR:-${JELLYFIN_DATA_DIR:-/config}}"
export JELLYFIN_CACHE_DIR="${OPENHOST_APP_TEMP_DIR:-${JELLYFIN_CACHE_DIR:-/cache}}"

# The official image pins JELLYFIN_CONFIG_DIR/JELLYFIN_LOG_DIR under its
# ephemeral /config, so server settings (system.xml, which holds the
# StartupWizardCompleted flag) and logs would be lost on every reload. Anchor
# them under the persistent data mount instead — this mirrors Jellyfin's own
# default derivation (DATA_DIR/config, DATA_DIR/log) but on backed-up storage.
export JELLYFIN_CONFIG_DIR="${JELLYFIN_DATA_DIR}/config"
export JELLYFIN_LOG_DIR="${JELLYFIN_DATA_DIR}/log"

mkdir -p "$JELLYFIN_DATA_DIR" "$JELLYFIN_CACHE_DIR" "$JELLYFIN_CONFIG_DIR" "$JELLYFIN_LOG_DIR"

# Pre-seed empty media library folders under the persistent data mount. OpenHost
# apps don't get a UI for creating arbitrary host folders, so without this the
# user would have nowhere to point a library at. These are just directories —
# point Jellyfin libraries at /data/app_data/jellyfin/media/{Movies,Shows,Music}
# (or upload into them via the file browser). Idempotent; never touched again.
for lib in Movies Shows Music; do
  mkdir -p "$JELLYFIN_DATA_DIR/media/$lib"
done

# Locate the Jellyfin server binary.
if [ -x /jellyfin/jellyfin ]; then
  JELLYFIN_BIN=/jellyfin/jellyfin
else
  JELLYFIN_BIN="$(command -v jellyfin)"
fi

set -- --datadir "$JELLYFIN_DATA_DIR" --cachedir "$JELLYFIN_CACHE_DIR"

# Pass --webdir only if we can find the bundled web client.
for d in "${JELLYFIN_WEB_DIR:-}" /jellyfin/jellyfin-web /usr/share/jellyfin/web /usr/lib/jellyfin/bin/jellyfin-web; do
  if [ -n "$d" ] && [ -d "$d" ]; then
    set -- "$@" --webdir "$d"
    break
  fi
done

# Prefer jellyfin-ffmpeg if present; otherwise let Jellyfin find ffmpeg on PATH.
if [ -x /usr/lib/jellyfin-ffmpeg/ffmpeg ]; then
  set -- "$@" --ffmpeg /usr/lib/jellyfin-ffmpeg/ffmpeg
fi

exec "$JELLYFIN_BIN" "$@"
