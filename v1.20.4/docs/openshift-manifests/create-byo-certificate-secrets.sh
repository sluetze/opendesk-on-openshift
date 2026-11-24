#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Option 1 BYO: create certificate Secrets from PEM files under
# helmfile/environments/openshift/certs/. Not applied by `oc apply -f`
# (private material stays out of git).
#
# Creates:
#   opendesk-certificates-tls          (kubernetes.io/tls) — leaf+chain + key
#   opendesk-certificates-ca-tls       (kubernetes.io/tls) — ca.crt + truststore.jks
#   opendesk-certificates-keystore-jks (Opaque) — password key (chart requirement)
#
# Chart constraint: Nubus/OX/XWiki mount truststore.jks from the CA secret.
# With apps.certificates.enabled=false, cert-manager does not build it.
# If truststore.jks is missing, this script builds it with a one-liner keytool
# (via podman eclipse-temurin) from ca.crt (+ intermediate.crt when present).
#
# Prerequisites:
#   export KUBECONFIG=...
#   export CERTIFICATES_JKS_PASSWORD=...
#   PEM files under helmfile/environments/openshift/certs/:
#     tls-fullchain.crt, tls.key, ca.crt
#   optional: intermediate.crt (also imported into the JKS)
#   optional: truststore.jks (skipped generation if already present)
#   podman (only if truststore.jks must be generated)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CERTS="${ROOT}/helmfile/environments/openshift/certs"
NS="${NAMESPACE:-opendesk}"

: "${CERTIFICATES_JKS_PASSWORD:?set CERTIFICATES_JKS_PASSWORD}"
test -f "${CERTS}/tls-fullchain.crt"
test -f "${CERTS}/tls.key"
test -f "${CERTS}/ca.crt"

if [[ ! -f "${CERTS}/truststore.jks" ]]; then
  command -v podman >/dev/null || {
    echo "ERROR: truststore.jks missing and podman not found for keytool one-liner" >&2
    exit 1
  }
  echo "Building ${CERTS}/truststore.jks via keytool (podman eclipse-temurin:17-jdk)..."
  rm -f "${CERTS}/truststore.jks"
  podman run --rm --network=none \
    -v "${CERTS}:/certs:Z" \
    -e STOREPASS="${CERTIFICATES_JKS_PASSWORD}" \
    docker.io/library/eclipse-temurin:17-jdk \
    bash -c '
      set -euo pipefail
      keytool -importcert -noprompt -alias rh-internal-root \
        -file /certs/ca.crt -keystore /certs/truststore.jks \
        -storepass "$STOREPASS"
      if [[ -f /certs/intermediate.crt ]]; then
        keytool -importcert -noprompt -alias rhcsv2-intermediate \
          -file /certs/intermediate.crt -keystore /certs/truststore.jks \
          -storepass "$STOREPASS"
      fi
    '
fi

oc create secret tls opendesk-certificates-tls -n "$NS" \
  --cert="${CERTS}/tls-fullchain.crt" \
  --key="${CERTS}/tls.key" \
  --dry-run=client -o yaml | oc apply -f -

# Opaque: charts only mount ca.crt + truststore.jks (not a matched TLS key pair).
oc create secret generic opendesk-certificates-ca-tls -n "$NS" \
  --from-file=ca.crt="${CERTS}/ca.crt" \
  --from-file=truststore.jks="${CERTS}/truststore.jks" \
  --dry-run=client -o yaml | oc apply -f -

oc create secret generic opendesk-certificates-keystore-jks -n "$NS" \
  --from-literal=password="${CERTIFICATES_JKS_PASSWORD}" \
  --dry-run=client -o yaml | oc apply -f -

echo "BYO secrets ready in namespace ${NS}"
