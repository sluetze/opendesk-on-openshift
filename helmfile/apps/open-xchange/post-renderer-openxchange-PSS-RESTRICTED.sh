#!/bin/sh
# SPDX-FileCopyrightText: 2026 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
# SPDX-License-Identifier: Apache-2.0

# Works around Kyverno findings the upstream OX chart does not allow to fix
# through values:
#
# - core-documentconverter / core-imageconverter (require-ro-rootfs):
#   The charts mount log, spool and config paths but no /tmp, and have no
#   extraVolumes. Add a /tmp emptyDir, point HOME into it (the documentconverter
#   user's home is the LibreOffice install dir /opt/cool, so it must not be
#   shadowed) and switch the root filesystem to read-only.
#
# - guard-ui (require-health-and-liveness-check):
#   The chart hardcodes both probes without periodSeconds. Set the Kubernetes
#   default of 10s explicitly, so the effective behavior does not change.

yq eval --exit-status --expression '
  (
    select(.kind == "Deployment" and (.metadata.name | test("-core-(document|image)converter$")))
    | .spec.template.spec
  ) |= (
    .volumes += [{"name": "tmp", "emptyDir": {}}]
    | .containers[] |= (
      .volumeMounts += [{"name": "tmp", "mountPath": "/tmp"}]
      | .env += [{"name": "HOME", "value": "/tmp"}]
      | .securityContext.readOnlyRootFilesystem = true
    )
  )
  | (
    select(.kind == "Deployment" and (.metadata.name | test("-guard-ui$")))
    | .spec.template.spec.containers[]
    | (.livenessProbe, .readinessProbe)
    | select(. != null and .periodSeconds == null)
    | .periodSeconds
  ) = 10
' -
