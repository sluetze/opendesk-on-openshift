# OpenShift manifests (v1.19.1)

Started on default `restricted-v2`. After proven UID/seccomp admission failure
(#1), ship thin SCC `opendesk-uid-seccomp` only — **not** fat
`opendesk-anyuid-seccomp` from prior overlays.

Also ships:

- empty ConfigMap `opendesk-trusted-ca-bundle` labeled for CNO
  `inject-trusted-cabundle` (ClamAV mounts it; see `openshift-errors.md` #2)
- router TLS Secret RBAC + 14 Exact-path fix Routes (portal bootstrap;
  OpenShift drops `pathType: Exact` — see `openshift-errors.md` #4)

## Layout

```text
docs/openshift-manifests/
  base/
    kustomization.yaml
    opendesk-00-router-tls-secret-rbac.yaml
    opendesk-uid-seccomp-scc.yaml
    opendesk-trusted-ca-bundle.yaml
    opendesk-fix-univention-routes.yaml
  create-byo-certificate-secrets.sh
  overlays/
    example/                     # copy and rename for your site
      kustomization.yaml         # site knobs: namespace + portalHost
  README.md
```

| Resource | Scope | Notes |
| --- | --- | --- |
| `opendesk-uid-seccomp` SCC | cluster | thin; overlay sets `system:serviceaccounts:<namespace>` |
| `opendesk-trusted-ca-bundle` CM | namespace | CNO inject-trusted-cabundle |
| Router TLS Secret RBAC | namespace | Role/RoleBinding for `externalCertificate` on fix Routes |
| 14 `Route` fix objects | namespace | Host from overlay `portalHost` |

BYO TLS Secrets are created by `create-byo-certificate-secrets.sh` (outside Kustomize).

## Apply

```bash
oc apply -k docs/openshift-manifests/overlays/example
```

Preview: `kubectl kustomize docs/openshift-manifests/overlays/example`

## Customize for your site

1. Copy `overlays/example` → `overlays/<your-site>`.
2. Set `namespace:` and `portalHost=portal.<global.domain>` in the overlay
   `configMapGenerator` literals.
3. Create BYO Secret `opendesk-certificates-tls` before apply (fix Routes use
   `tls.externalCertificate`).
4. `oc apply -k docs/openshift-manifests/overlays/<your-site>`.
