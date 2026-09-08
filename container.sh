#!/usr/bin/env bash
#
# Build and run Build Check Statistics in a podman container.
#
#   ./container.sh build     build the image
#   ./container.sh web       run the web server (default, after a build)
#   ./container.sh update    scrape OBS and publish the results, then exit
#   ./container.sh shell     interactive shell in the image
#
# Environment:
#   BCS_IMAGE   image name           (default: localhost/build-check-statistics)
#   BCS_DATA    host state directory (default: ./data)
#   BCS_PORT    published address    (default: 127.0.0.1:8080)
#   BCS_CONFIG  config file to use instead of the one baked into the image
#
set -euo pipefail
thisdir="$(dirname "$(readlink -f "$0")")"

IMAGE="${BCS_IMAGE:-localhost/build-check-statistics}"
DATA="${BCS_DATA:-${thisdir}/data}"
PORT="${BCS_PORT:-127.0.0.1:8080}"
CONFIG="${BCS_CONFIG:-}"

# The whole persistent state is this one directory. SQLite needs to create
# -wal/-shm files next to the database, so mount the directory, not the file.
mounts=(-v "${DATA}:/var/lib/build_check_statistics:Z")
[ -n "$CONFIG" ] &&
  mounts+=(-v "${CONFIG}:/app/build_check_statistics.conf:ro,Z")

build() {
  podman build --pull=newer -t "$IMAGE" -f "${thisdir}/Dockerfile" "${thisdir}"
}

web() {
  mkdir -p "$DATA"
  podman run -it --rm=true --name bcs -p "${PORT}:8080" "${mounts[@]}" "$IMAGE"
}

update() {
  mkdir -p "$DATA"
  podman run --rm=true "${mounts[@]}" "$IMAGE" update
  podman run --rm=true "${mounts[@]}" "$IMAGE" deploy
}

shell() {
  mkdir -p "$DATA"
  podman run -it --rm=true --entrypoint /bin/bash "${mounts[@]}" "$IMAGE"
}

case "${1:-}" in
  build)  build ;;
  web)    web ;;
  update) update ;;
  shell)  shell ;;
  '')     build && web ;;
  *)      echo "usage: $0 [build|web|update|shell]" >&2; exit 1 ;;
esac
