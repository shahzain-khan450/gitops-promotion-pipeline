#!/usr/bin/env bash
# Builds every overlay with kustomize and fails if any of them don't
# produce valid output. Run this locally before pushing, and it's also
# meant to be wired into a PR-check workflow (not included by default here,
# to keep the workflow count minimal — see docs/SETUP.md for how to add it).
#
# Usage: ./validate-overlays.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Validating base"
kustomize build k8s/base > /dev/null
echo "    OK"

for env in dev staging prod; do
  echo "==> Validating overlays/${env}"
  OUTPUT=$(kustomize build "k8s/overlays/${env}")
  echo "${OUTPUT}" > /dev/null

  # Sanity checks beyond "did it build" — catch copy-paste mistakes between
  # overlays before they reach a real cluster.
  NS=$(echo "${OUTPUT}" | grep -m1 "namespace:" | awk '{print $2}')
  if [ "${NS}" != "${env}" ]; then
    echo "    FAIL: expected namespace '${env}', got '${NS}'"
    exit 1
  fi

  ENV_VALUE=$(echo "${OUTPUT}" | grep "ENVIRONMENT:" | awk '{print $2}')
  if [ "${ENV_VALUE}" != "${env}" ]; then
    echo "    FAIL: expected ENVIRONMENT=${env} in ConfigMap, got '${ENV_VALUE}'"
    exit 1
  fi

  echo "    OK (namespace=${NS}, ENVIRONMENT=${ENV_VALUE})"
done

echo ""
echo "All overlays validated successfully."
