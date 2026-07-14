#!/usr/bin/env bash
# Updates the APP_VERSION literal in an overlay's configMapGenerator so the
# app itself reports the correct version at /  (not just the image tag —
# this is what you'd curl to prove what's actually running).
#
# Usage: ./bump-image-tag.sh <dev|staging|prod> <version>

set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <dev|staging|prod> <version>}"
VERSION="${2:?Usage: $0 <dev|staging|prod> <version>}"

KUSTOMIZATION_FILE="k8s/overlays/${ENVIRONMENT}/kustomization.yaml"

if [ ! -f "${KUSTOMIZATION_FILE}" ]; then
  echo "ERROR: ${KUSTOMIZATION_FILE} not found" >&2
  exit 1
fi

# Portable in-place sed (works on both GNU and BSD sed)
sed -i.bak -E "s/APP_VERSION=.*/APP_VERSION=${VERSION}/" "${KUSTOMIZATION_FILE}"
rm -f "${KUSTOMIZATION_FILE}.bak"

echo "Updated ${KUSTOMIZATION_FILE}: APP_VERSION=${VERSION}"
