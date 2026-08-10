# Deploying openDesk on OpenShift

How to reconstruct this openDesk-on-OpenShift pattern on **any** OpenShift
cluster. Contract: [`CURSOR.MD`](../CURSOR.MD). Cluster-specific failure history
(one reference deploy): [`openshift-errors.md`](./openshift-errors.md).

## Goal / scope

Core openDesk via helmfile environment `openshift` plus OpenShift-native
objects under `docs/openshift-manifests/` — no chart/template or application
source changes. Fill site-specific values in
`helmfile/environments/openshift/` before apply.

## Site-specific checklist (fill these)

Discover cluster facts, then set them in
`helmfile/environments/openshift/values.yaml.gotmpl` (and related
customizations). Do not treat any checked-in example domain/IP/StorageClass as
universal.

| Knob | Where | How to discover / choose |
| --- | --- | --- |
| Apps / router domain | `global.domain` | `oc get ingresses.config/cluster -o jsonpath='{.spec.domain}'` → typically `opendesk.apps.<cluster-domain>` (nested label under the apps wildcard avoids tenant collisions; keep under SSSD hostname limits) |
| IngressClass | `ingress.ingressClassName` | `oc get ingressclass` — use the cluster default (often `openshift-default`) |
| StorageClass RWO + RWX | `persistence.storageClassNames.RWO` / `.RWX` | `oc get storageclass` — need a class that supports **RWX** for shared volumes (NFS/file), not block-only |
| Container runtime | `cluster.container.engine` | Usually `cri-o` on OpenShift (`oc get node -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}'`) |
| TLS leaf + chain + key + CA | `helmfile/environments/openshift/certs/` | BYO PEMs clients trust: `tls-fullchain.crt`, `tls.key`, `ca.crt` (optional `intermediate.crt`). Gitignored. |
| JKS password | env `CERTIFICATES_JKS_PASSWORD` | Must match password used for `truststore.jks` / keystore Secret |
| Master passphrase | env `MASTER_PASSWORD` | Arbitrary non-empty passphrase for helmfile-generated secrets |
| Jitsi media reachability | `service.type.jitsiVideoBridge`, `cluster.networking.ingressGatewayIP`, `jitsi.jvb.nodePort` (customization) | UDP/10000 cannot use OpenShift Routes (TCP-only). Pick **NodePort + advertise IP** *or* wire TURN/LoadBalancer for your network. Node IP / NodePort are **per-site** — see comments in the values file and [`openshift-errors.md`](./openshift-errors.md) failure #16 for one worked example |
| OX path rewrites | `annotations.openxchangeAppsuiteIngress.*` | OpenShift HAProxy needs `haproxy.router.openshift.io/rewrite-target` (already patterned in the tracked values) |

Authoritative filled-in example for one site lives in the tracked
`values.yaml.gotmpl` / `customizations/` — copy/adapt, do not assume its
domain, StorageClass, or node IPs match yours.

## Prerequisites

| Need | Note |
| --- | --- |
| OpenShift cluster + `oc` kubeconfig | Cluster-admin or enough rights for namespace, SCC, Routes, Secrets |
| `helmfile`, `helm` | Apply environment `openshift` |
| `podman` | Only if `truststore.jks` must be built (script uses `eclipse-temurin:17-jdk`) |
| PEMs staged | Under `helmfile/environments/openshift/certs/` (see checklist) |
| Env vars | `MASTER_PASSWORD`, `CERTIFICATES_JKS_PASSWORD` |

## Reconstruction

Private keys stay out of git. Namespace + BYO TLS Secrets are the only
imperative pieces; everything else is declarative.

**Secrets created (Option 1 BYO):**

| Secret | Type | Contents |
| --- | --- | --- |
| `opendesk-certificates-tls` | `kubernetes.io/tls` | leaf+intermediate PEM + private key (Routes `externalCertificate`) |
| `opendesk-certificates-ca-tls` | Opaque | `ca.crt` + **`truststore.jks`** (apps mount these keys) |
| `opendesk-certificates-keystore-jks` | Opaque | key `password` for the JKS |

**Chart constraint:** with `apps.certificates.enabled: false`, charts still
volume-mount `truststore.jks` from `opendesk-certificates-ca-tls`.
`create-byo-certificate-secrets.sh` builds it with `keytool` when missing.

```shell
oc create namespace opendesk

# 1. Edit helmfile/environments/openshift/values.yaml.gotmpl (checklist above)
# 2. Stage PEMs under helmfile/environments/openshift/certs/
export CERTIFICATES_JKS_PASSWORD='<jks password>'
bash docs/openshift-manifests/create-byo-certificate-secrets.sh

# RBAC filename sorts before routes that use externalCertificate
oc apply -f docs/openshift-manifests/

export MASTER_PASSWORD='<your passphrase>'
helmfile apply -e openshift -n opendesk
```

No ad-hoc `oc create route` / `jq` pipelines on the reconstruct path. Every
OpenShift object fix is a static YAML under `docs/openshift-manifests/`
(exception: the BYO secrets script for private TLS material).

## What lives where

| Path | Role |
| --- | --- |
| `helmfile/environments/openshift/values.yaml.gotmpl` | Site helm values (**tracked** — edit for your cluster) |
| `helmfile/environments/openshift/customizations/` | Release-scoped fixes (**tracked**) via `customization.release.*` |
| `helmfile/environments/openshift/certs/` | Gitignored PEMs + optional `truststore.jks` |
| `docs/openshift-manifests/` | SCC, router TLS RBAC, Exact-path Routes, BYO secrets script |
| [`CURSOR.MD`](../CURSOR.MD) | Reconstruction contract |
| [`openshift-errors.md`](./openshift-errors.md) | Historical failures / Changes (reference deploy) |
| [`openshift-legacy-selfsigned-ca/`](./openshift-legacy-selfsigned-ca/) | Archived Option 2a — **do not use** for reconstruct |

## App set / hosts

**Enabled in the tracked `openshift` values:** `nubus`, `migrations`,
`mariadb`, `postgresql`, `redis`, `memcached`, `home`, `staticFiles`,
`seaweedfs`, `collabora`, `nextcloud`, `openproject`, `clamavSimple`,
`oxAppSuite`, `dovecot`, `postfix`, `cryptpad`, `element`, `jitsi`, `xwiki`.
(`apps.certificates.enabled: false` — Option 1 BYO.)

**Left off on purpose:** `cassandra`, `clamavDistributed`, `minio`, `dkimpy`,
`notes`, `elementAdmin`, `elementGroupsync`, `collaboraController`.

Hard deps: `seaweedfs` required by Nubus; `clamavSimple` required once
Nextcloud/OX are on.

Hosts are `<prefix>.<global.domain>`:

| Prefix | App |
| --- | --- |
| `portal` | Nubus portal (primary entry) |
| `id` | Keycloak |
| `office` | Collabora |
| `files` | Nextcloud |
| `projects` | OpenProject |
| `webmail` | OX App Suite |
| `meet` | Jitsi |
| chat / Matrix hosts | Element |
| `wiki` | XWiki |

Entry: `https://portal.<global.domain>/`. Bare apex
`https://<global.domain>/` → portal redirect may be unsolved on OpenShift
(cosmetic); see [`openshift-errors.md` Unsolved](./openshift-errors.md#unsolved).

## TLS strategy

**Option 1 BYO.** Provide a leaf+chain+key whose issuing CA your **clients**
already trust (corp PKI, public CA, etc.). Stage PEMs under gitignored
`helmfile/environments/openshift/certs/`;
`create-byo-certificate-secrets.sh` creates the three Secrets and builds
`truststore.jks` when missing. Routes use `tls.externalCertificate` (no
embedded PEMs) plus `opendesk-00-router-tls-secret-rbac.yaml`.

**Naming trap:** `certificate.selfSigned: true` means **mount the CA trust
bundle** — not “mint a self-signed CA”. With `apps.certificates.enabled:
false`, cert-manager mints nothing.

Do **not** use archived Option 2a under
[`openshift-legacy-selfsigned-ca/`](./openshift-legacy-selfsigned-ca/).

## Values file

Authoritative copy:
[`helmfile/environments/openshift/values.yaml.gotmpl`](../helmfile/environments/openshift/values.yaml.gotmpl)
(inline comments explain *why*). Adapt the site-specific checklist fields
before `helmfile apply -e openshift`. Failure writeups referenced in comments:
[`openshift-errors.md`](./openshift-errors.md).
