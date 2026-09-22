#!/usr/bin/env bash
#
# Build and version-tag peter-hartmann/ubuntu-lemp.
#
# Tagging scheme: php<major.minor>-mariadb<major.minor>-r<revision>
#   - major.minor reflects the *intended* pinned versions from the Dockerfile
#     (e.g. php7.4-fpm, mariadb-server on Ubuntu focal), not the exact patch
#     level, which floats with whatever Ubuntu's repo currently serves.
#   - revision (-rN) increments for rebuilds at the same php/mariadb
#     major.minor combo (Dockerfile fixes, package updates, config changes).
#   - Bump PHP_VERSION / MARIADB_VERSION below and reset REVISION to 1
#     whenever either major.minor actually changes.
#
# Usage: ./build.sh [revision]
#   If [revision] is omitted, the script auto-picks the next unused -rN
#   for the current php/mariadb version combo.

set -euo pipefail
cd "$(dirname "$0")"

IMAGE_NAME="peter-hartmann/ubuntu-lemp"

# Intended/pinned versions -- update these when the Dockerfile's PHP or
# MariaDB package selection changes to a new major.minor.
PHP_VERSION="8.2"
MARIADB_VERSION="10.11"

VERSION_TAG="php${PHP_VERSION}-mariadb${MARIADB_VERSION}"
GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")"
GIT_DIRTY=""
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
	GIT_DIRTY="-dirty"
fi

# Determine revision number
if [ "${1:-}" != "" ]; then
	REVISION="$1"
else
	REVISION=1
	while docker image inspect "${IMAGE_NAME}:${VERSION_TAG}-r${REVISION}" >/dev/null 2>&1; do
		REVISION=$((REVISION + 1))
	done
fi

FULL_TAG="${VERSION_TAG}-r${REVISION}"
SHA_TAG="${FULL_TAG}-g${GIT_SHA}${GIT_DIRTY}"

echo "==> Building ${IMAGE_NAME}:${FULL_TAG}"
docker build -t "${IMAGE_NAME}:building" .

echo "==> Resolving actual installed versions"
RESOLVED_PHP="$(docker run --rm --entrypoint php "${IMAGE_NAME}:building" -r 'echo PHP_VERSION;' 2>/dev/null || echo "unknown")"
RESOLVED_MARIADB="$(docker run --rm --entrypoint mysqld "${IMAGE_NAME}:building" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+-MariaDB' || echo "unknown")"

echo "    resolved php:      ${RESOLVED_PHP}"
echo "    resolved mariadb:  ${RESOLVED_MARIADB}"

echo "==> Committing labeled image"
# IMPORTANT: do NOT pass --entrypoint here. `docker commit` bakes the
# container's *current* entrypoint/cmd into the resulting image, so
# creating this container with an overridden entrypoint (e.g. /bin/true)
# would silently replace the image's real ENTRYPOINT -- which is exactly
# what broke production during testing. Leaving it unset here means the
# container is created with the image's own original entrypoint, which is
# what we want committed back (we never start this container, so it
# doesn't matter that the entrypoint would normally launch the full stack).
LABEL_CID="$(docker create "${IMAGE_NAME}:building")"
docker commit \
	--change "LABEL org.dostips.php.target=${PHP_VERSION}" \
	--change "LABEL org.dostips.php.resolved=${RESOLVED_PHP}" \
	--change "LABEL org.dostips.mariadb.target=${MARIADB_VERSION}" \
	--change "LABEL org.dostips.mariadb.resolved=${RESOLVED_MARIADB}" \
	--change "LABEL org.dostips.git.sha=${GIT_SHA}${GIT_DIRTY}" \
	--change "LABEL org.dostips.build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	"${LABEL_CID}" "${IMAGE_NAME}:${FULL_TAG}"
docker rm "${LABEL_CID}" >/dev/null 2>&1 || true
docker rmi "${IMAGE_NAME}:building" >/dev/null 2>&1 || true

echo "==> Verifying committed image keeps the correct entrypoint"
COMMITTED_ENTRYPOINT="$(docker inspect --format '{{json .Config.Entrypoint}}' "${IMAGE_NAME}:${FULL_TAG}")"
echo "    entrypoint: ${COMMITTED_ENTRYPOINT}"
if [ "${COMMITTED_ENTRYPOINT}" = "null" ] || [ -z "${COMMITTED_ENTRYPOINT}" ]; then
	echo "ERROR: committed image has no entrypoint -- refusing to tag as latest/stable. Aborting." >&2
	exit 1
fi

echo "==> Smoke-testing the built image actually starts and stays up"
SMOKE_CID="$(docker run -d "${IMAGE_NAME}:${FULL_TAG}")"
sleep 8
SMOKE_STATUS="$(docker inspect --format '{{.State.Status}}' "${SMOKE_CID}")"
docker rm -f "${SMOKE_CID}" >/dev/null 2>&1 || true
echo "    smoke test container status after 8s: ${SMOKE_STATUS}"
if [ "${SMOKE_STATUS}" != "running" ]; then
	echo "ERROR: smoke test container did not stay running -- refusing to tag as latest/stable. Aborting." >&2
	exit 1
fi

docker tag "${IMAGE_NAME}:${FULL_TAG}" "${IMAGE_NAME}:${SHA_TAG}"
docker tag "${IMAGE_NAME}:${FULL_TAG}" "${IMAGE_NAME}:latest"

echo ""
echo "==> Done. Tagged as:"
echo "    ${IMAGE_NAME}:${FULL_TAG}"
echo "    ${IMAGE_NAME}:${SHA_TAG}"
echo "    ${IMAGE_NAME}:latest"
echo ""
echo "Update docker-compose.yml's image: line to pin ${IMAGE_NAME}:${FULL_TAG} if desired."
