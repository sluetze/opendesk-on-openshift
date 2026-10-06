# OpenShift manifests (Kustomize)

Cluster- and namespace-scoped fixes for openDesk on OpenShift that are not
expressed in Helm charts. Apply with Kustomize so hostname, namespace, and
related site values are set in one place per overlay.

## Layout

```text
docs/openshift-manifests/
  base/                          # shared manifests (placeholder host/namespace)
    kustomization.yaml
    opendesk-00-router-tls-secret-rbac.yaml
    opendesk-anyuid-seccomp-scc.yaml
    opendesk-fix-univention-routes.yaml
  create-byo-certificate-secrets.sh   # BYO TLS Secrets (not Kustomize)
  overlays/
    example/                     # copy and rename for your site
      kustomization.yaml         # site knobs: namespace + configMapGenerator literals
  README.md
```

| Resource | Scope | Notes |
| --- | --- | --- |
| `opendesk-anyuid-seccomp` SCC | cluster | `groups` targets `system:serviceaccounts:<namespace>` via overlay replacement |
| Router TLS Secret RBAC | namespace | Role/RoleBinding for `externalCertificate` on fix Routes |
| 14 `Route` fix objects | namespace | Host set from overlay `portalHost`; namespace from overlay `namespace:` |

BYO TLS Secrets are created by `create-byo-certificate-secrets.sh` (outside Kustomize).

## Apply

Preview:

```bash
kubectl kustomize docs/openshift-manifests/overlays/example
# or: kustomize build docs/openshift-manifests/overlays/example
```

Apply (after editing the overlay for your site):

```bash
oc apply -k docs/openshift-manifests/overlays/example
# equivalent: kubectl kustomize ... | oc apply -f -
```

Drift check:

```bash
oc apply --dry-run=server -k docs/openshift-manifests/overlays/example
```

## Customize for your site

1. Copy the example overlay:

   ```bash
   cp -r docs/openshift-manifests/overlays/example \
         docs/openshift-manifests/overlays/my-site
   ```

2. In `overlays/my-site/kustomization.yaml`, set:

   - **`namespace:`** — openDesk namespace (default `opendesk`). Applied to all
     namespace-scoped resources (the Routes). Does not affect the SCC object
     kind itself (cluster-scoped).
   - **`configMapGenerator` literals** — `portalHost` (portal Route hostname)
     and `namespace` (must match `namespace:` for the SCC
     `system:serviceaccounts:<namespace>` group). openDesk convention:
     `portalHost=portal.<global.domain>`, where `global.domain` is
     `helmfile/environments/openshift/values.yaml.gotmpl` → `global.domain`.

   Example: if `global.domain` is `opendesk.apps.cluster.example.com`, set
   `portalHost=portal.opendesk.apps.cluster.example.com`.

3. Apply with `oc apply -k docs/openshift-manifests/overlays/my-site`.

A small `opendesk-site-config` ConfigMap is emitted as the Kustomize replacement
source; safe to leave in the namespace or delete after apply.

Routes use TLS `externalCertificate` → Secret `opendesk-certificates-tls`
(BYO Option 1). Create that Secret with `create-byo-certificate-secrets.sh`
before apply; router RBAC is in `base/opendesk-00-router-tls-secret-rbac.yaml`.

## Deploy doc

Full reconstruct steps: [`openshift-deployment.md`](../openshift-deployment.md).
This README only covers these Kustomize manifests and the BYO secrets script.
