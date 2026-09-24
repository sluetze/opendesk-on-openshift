#!/bin/sh
# SPDX-FileCopyrightText: 2026 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
# SPDX-License-Identifier: Apache-2.0

# Captured first so a yq failure is not masked by the pipe (no pipefail in sh).
manifest=$(yq eval --string-interpolation=false --exit-status --expression '
  select(.kind == "Ingress") |= (
    .spec.rules[].http.paths[] |=
      (select(.path | test("\(\.\*\)$")) | .path |= sub("\(\.\*\)$"; "") | .pathType = "Prefix") // .
  )
' -) || exit 1

# Also apply the Kyverno workarounds
printf '%s\n' "$manifest" | "$(dirname "$0")/post-renderer-openxchange-PSS-RESTRICTED.sh"
