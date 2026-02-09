#!/bin/bash
# Multi-architecture Docker image build script for kdbx-tick
#
# Prerequisites:
#   1. QEMU binfmt handlers for cross-platform emulation:
#      docker run --privileged --rm tonistiigi/binfmt --install all
#   2. Docker buildx builder with multi-platform support:
#      docker buildx create --name multiarch --driver docker-container --bootstrap --use
#   3. Docker Hub login:
#      docker login
#   4. kdbx.env file with KX credentials (auto-sourced if present)
#
# Usage:
#   ./build.sh              # builds and pushes with tag 'latest'
#   ./build.sh v1.0.0       # builds and pushes with tag 'v1.0.0'

set -euo pipefail

# Source kdbx.env if it exists (export all vars so docker secrets can read them)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/kdbx.env" ]]; then
    set -a
    source "${SCRIPT_DIR}/kdbx.env"
    set +a
fi

# Configuration (override via environment)
DOCKER_REPO="${DOCKER_REPO:-peteclarkez/kdbx-tick}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER_NAME="${BUILDER_NAME:-multiarch}"
DOCKERFILE="docker/Dockerfile"

# Tag from first argument or default to 'latest'
TAG="${1:-latest}"
IMAGE="${DOCKER_REPO}:${TAG}"

# Validate required environment variables
if [[ -z "${KX_BEARER_TOKEN:-}" ]]; then
    echo "ERROR: KX_BEARER_TOKEN is not set. Run: source kdbx.env" >&2
    exit 1
fi
if [[ -z "${KX_LICENSE_B64:-}" ]]; then
    echo "ERROR: KX_LICENSE_B64 is not set. Run: source kdbx.env" >&2
    exit 1
fi

# Validate builder exists
if ! docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
    echo "ERROR: Buildx builder '${BUILDER_NAME}' not found." >&2
    echo "Create it with:" >&2
    echo "  docker run --privileged --rm tonistiigi/binfmt --install all" >&2
    echo "  docker buildx create --name ${BUILDER_NAME} --driver docker-container --bootstrap --use" >&2
    exit 1
fi

echo "============================================="
echo "Building multi-architecture image"
echo "============================================="
echo "Repository:  ${DOCKER_REPO}"
echo "Tag:         ${TAG}"
echo "Platforms:   ${PLATFORMS}"
echo "Builder:     ${BUILDER_NAME}"
echo "============================================="

# Build and push multi-platform image
docker buildx build \
    --builder "${BUILDER_NAME}" \
    --platform "${PLATFORMS}" \
    --secret id=kx_bearer_token,env=KX_BEARER_TOKEN \
    --secret id=kx_license_b64,env=KX_LICENSE_B64 \
    -t "${IMAGE}" \
    -f "${DOCKERFILE}" \
    --push \
    .

echo ""
echo "============================================="
echo "Successfully built and pushed: ${IMAGE}"
echo "Platforms: ${PLATFORMS}"
echo "============================================="

# Show manifest details
echo ""
echo "Manifest inspection:"
docker buildx imagetools inspect "${IMAGE}"
