# Changes rows — Option 2a only (superseded)

These rows lived in `docs/openshift-errors.md`'s Changes table during the
self-signed in-cluster CA phase. Errors doc keeps stub rows marked
**superseded** with a pointer here so numbering stays stable for cross-refs.

| # | File / Object | Setting | Value | Why (historical) |
| - | --- | --- | --- | --- |
| 6 (old rationale) | `values.yaml.gotmpl` | `certificate.selfSigned` | `true` | Originally meant “avoid ACME; let `opendesk-certificates` mint its own CA via cert-manager”. Under BYO the flag still is `true`, but meaning is **mount trust bundle only** — see main Changes row 6. |
| 9 | OpenShift `ClusterIssuer` (cert-manager) | `oc apply -f selfsigned-clusterissuer.yaml` | `ClusterIssuer/selfsigned-issuer` with `spec.selfSigned: {}` | `certificate.selfSigned: true` alone did not make the root CA self-signed; `issuerRef` had to point at a real self-signed issuer — see [failure-04](./failure-04-selfsigned-issuer.md) |
| 10 | same | `certificate.issuerRef.name` / `.kind` | `selfsigned-issuer` / `ClusterIssuer` | Paired with row 9 |
| 23 | `docs/openshift-manifests/selfsigned-clusterissuer.yaml` | deleted from live manifests | — | Unused under Option 1; YAML kept in this archive folder |
