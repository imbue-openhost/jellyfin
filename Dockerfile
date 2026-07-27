# Dockerfile for deploying Jellyfin on OpenHost.
#
# OpenHost clones this repo and builds the Dockerfile with rootless podman
# directly on the host VM. Compiling Jellyfin from source there (a self-contained
# .NET publish plus a jellyfin-web webpack build) needs several GB of RAM and
# disk and can overwhelm a small VM, so by default we layer only the thin
# OpenHost entrypoint on top of the official, prebuilt Jellyfin image. This keeps
# the on-VM build to a single image pull.
#
# To instead build the server from *this repo's* source (e.g. to test local C#
# changes), point the manifest's `image` at deployment/openhost/Dockerfile.from-source
# and deploy on a VM with headroom (~4 GB RAM, ~10 GB free disk).

FROM jellyfin/jellyfin:latest

COPY deployment/openhost/entrypoint.sh /openhost-entrypoint.sh
RUN chmod +x /openhost-entrypoint.sh

EXPOSE 8096
ENTRYPOINT ["/openhost-entrypoint.sh"]
