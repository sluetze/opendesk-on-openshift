# openDesk 1.19.1 on OpenShift — failures log

Do **not** assume 1.18.2 / 1.19.0 failures still apply. Classify each new failure:

| Class | Meaning |
| --- | --- |
| **OpenShift** | SCC, Ingress→Route Exact drop, rewrite-target, UID ranges, seccomp, … |
| **Environment** | LoadBalancer/NodePort/TURN/UDP, CPU, timeouts, storage class, DNS, client trust |

## Policy (1.19.1)

Do **not** reuse fat `opendesk-anyuid-seccomp` (extra caps from Collabora/Jitsi
history). Start on default `restricted-v2`. After a proven SCC admission failure,
prefer the thinnest new fix.

## 1.19.1 deploy log

| # | Class | Symptom | Status | Fix (only if proven) |
| --- | --- | --- | --- | --- |
| 1 | OpenShift | `opendesk-migrations-pre` rejected by `restricted-v2` (UID/fsGroup 1000, empty seLinux, seccomp) | fixed (thin SCC) | `opendesk-uid-seccomp` — anyuid + seccomp + seLinux RunAsAny; **no** extra caps |
| 2 | OpenShift | `clamav-simple-0` CrashLoop: freshclam SSL verify fail to gitlab.opencode.de CVD mirror | fixed | inject-trusted-cabundle CM + clamav helm customization — see below |
| 3 | Environment / app | `matrix-neodatefix-bot` CrashLoop: `M_UNKNOWN_TOKEN` / Token is not active | fixed (ops remint) | Re-install `matrix-neodatefix-bot-bootstrap` Job — see below |
| 4 | OpenShift | Portal login/bootstrap broken: Exact Ingress rules never become Routes | fixed | 14 fix Routes + router TLS RBAC — see below |
| 5 | Environment / app | `ums-stack-data-ums-1` pod Error (Job later Complete): UDM DELETE 500 on ox accessprofile | mitigated | Job completed on retry; stale Error pod left |

**helmfile apply (restart with thin SCC):** settled. ~40 releases deployed;
`opendesk-migrations-post` Complete. `opendesk-migrations-pre` helm release still
`failed` (`context canceled` from first attempt before thin SCC) — needs clean
re-apply. Fat SCC still absent; Jitsi ran without fat-SCC capability grants.

### 1. migrations-pre rejected by restricted-v2 (UID / fsGroup / seLinux / seccomp)

**Evidence** (`oc get events -n opendesk`, Job
`opendesk-migrations-pre-1`):

```
provider restricted-v2: .spec.securityContext.fsGroup: Invalid value: [1000]:
1000 is not an allowed group
provider restricted-v2: .containers[0].runAsUser: Invalid value: 1000: must be
in the ranges: [1001020000, 1001029999]
provider restricted-v2: .containers[0].seLinuxOptions.level: Invalid value: "":
must be s0:c32,c14
```

Pod securityContext (observed): `runAsUser: 1000`, `runAsGroup: 1000`,
`fsGroup: 1000`, `seLinuxOptions: {}`, `seccompProfile.type: RuntimeDefault`.

**Helm fix:** none — UIDs not exposed as helmfile values (same as 1.19.0 analysis).

**OpenShift fix (minimal, not the fat SCC):** apply
`docs/openshift-manifests/base/opendesk-uid-seccomp-scc.yaml` via kustomize.
Intentionally omits CHOWN/SYS_ADMIN/…; add those only if a later pod fails for caps.

### 2. clamav-simple freshclam SSL to public CVD mirror (BYO trust mount)

**Evidence** (`oc logs clamav-simple-0 -c clamav`):

```
WARNING: Download failed (60) WARNING:  Message: SSL peer certificate or SSH
remote key was not OK
ERROR: Can't download daily.cvd from
https://gitlab.opencode.de/bmi/opendesk/tooling/clamav-db-mirror/-/raw/main/daily.cvd
```

**Root cause:** with Option 1 BYO + `certificate.selfSigned: true` /
`trust.secret.mount: true`, `values-clamav-simple.yaml.gotmpl` mounts Secret
`opendesk-certificates-ca-tls` key `ca.crt` onto
`/etc/ssl/certs/ca-certificates.crt` (subPath). That **replaces** the image's
system CA bundle with only the site RH Internal CA (~1 cert). freshclam then
cannot verify gitlab.opencode.de's public cert.

**Class:** OpenShift — fix uses cluster-native CA injection (CNO
`inject-trusted-cabundle`), not hand-concatenated PEMs. Triggered by BYO thin
`ca.crt` mount pattern.

**Cluster trust (read-only check on ocp22):**
- `proxy/cluster` `spec.trustedCA.name: redhat-current-it-root-cas` (2 RH CAs)
- `image.config` has no `additionalTrustedCA`
- Injected bundle includes those RH fingerprints **plus** system roots

**Fix (applied, reconstructible):**

1. Manifest
   `docs/openshift-manifests/base/opendesk-trusted-ca-bundle.yaml` — empty
   ConfigMap labeled `config.openshift.io/inject-trusted-cabundle: "true"`.
   CNO fills `ca-bundle.crt` (~148 CAs / ~227 KiB on this cluster).
2. Helm customization
   `helmfile/environments/openshift/customizations/clamav-trusted-ca-inject.yaml`
   remounts that ConfigMap at Debian path
   `/etc/ssl/certs/ca-certificates.crt` (clamav/clamav image; not RHEL
   `/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem`). Wired via
   `customization.release.clamavSimple` in
   `helmfile/environments/openshift/values.yaml.gotmpl`.

**Proven:** after mount, freshclam downloads succeed (no SSL 60);
`clamav-simple-0` `2/2 Running`; in-pod `ca-certificates.crt` ~227567 bytes /
148 `BEGIN CERTIFICATE`.

**Residual risk:** other releases still mount thin Secret `ca.crt` the same
way (Nextcloud, Collabora, Matrix bots, OX, …). They talk mostly to in-cluster
or RH-Internal-TLS endpoints today; any pod that needs **public** HTTPS with
the BYO mount will hit the same SSL 60. Same inject CM can feed them later
(per-release customization or sync `ca-bundle.crt` into Secret `ca.crt`).

### 3. matrix-neodatefix-bot `M_UNKNOWN_TOKEN`

**Evidence:** Nest boot fails with `Error Code: M_UNKNOWN_TOKEN, Error: Token is
not active`. Pod CrashLoopBackOff. Not an SCC admission error (pod schedules and
runs). Synapse `GET /_matrix/client/v3/account/whoami` with Secret
`matrix-neodatefix-bot-account` key `access_token` returns the same
`401 M_UNKNOWN_TOKEN` / `Token is not active`. Bootstrap Job
`matrix-neodatefix-bot-bootstrap` (chart `opendesk-synapse-create-account`,
user `meetings-bot`) had completed once; Job pods deleted
(`deletePodsOnSuccess`). Token prefix `mct_` = MAS compatibility token.

**Class:** Environment / app bootstrap (Matrix access token inactive). Not
OpenShift-specific; not fixed by Exact-path Routes or SCC.

**Intended remint path** (chart `opendesk-synapse-create-account` 6.2.7):

- Install hook Job (`helm.sh/hook: post-install`) registers `meetings-bot` via
  `mas-cli manage register-user`, issues
  `mas-cli manage issue-compatibility-token … DEFAULT`, writes Secret
  `matrix-neodatefix-bot-account` (`access_token`).
- If Secret already exists, Job exits 0 with
  `secret … already exists (delete to recreate)` — no remint.
- Uninstall hook (`pre-delete`) deletes that Secret.

**Fix applied (operational, no overlay YAML):**

```bash
helm uninstall matrix-neodatefix-bot-bootstrap -n opendesk
# pre-delete removes Secret matrix-neodatefix-bot-account

helm pull oci://registry.opencode.de/bmi/opendesk/components/platform-development/charts/opendesk-element/opendesk-synapse-create-account \
  --version 6.2.7 --untar
helm install matrix-neodatefix-bot-bootstrap ./opendesk-synapse-create-account \
  -n opendesk -f <values matching values-matrix-neodatefix-bot-bootstrap.yaml.gotmpl> \
  --wait --timeout 10m
# post-install Job remints token into the Secret
```

(`helmfile -e openshift -l name=matrix-neodatefix-bot-bootstrap apply` is the
documented reconstruct path once env vars are set; direct `helm install` of the
same chart/version used here when helmfile render was too slow.)

**Proven:** Job Completed; Secret recreated; Synapse whoami → `200`
`@meetings-bot:…` / `device_id: DEFAULT`; pod `matrix-neodatefix-bot` `1/1
Running`, logs `Bot is running as @meetings-bot:…` / Nest started.

**No secrets in git.** No SCC/Route change.

### 4. Portal Exact Ingress → no Routes (login/bootstrap)

**Evidence** (before fix, ns `opendesk`, host
`portal.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com`):

- Ingress: **19** rules with `pathType: Exact` on portal host (frontend `/`,
  portal-server `portal.json` / `navigation.json` / `api/v1/me` / selfservice
  twins, umc-gateway `meta.json` / `languages.json` / `theme.css` / login JS).
- Routes from OpenShift Ingress→Route converter: **0** of those Exact paths
  (only Prefix / ImplementationSpecific converted).
- External probes: `/univention/portal/` → `200` HTML; `/univention/portal/portal.json`
  and `navigation.json` → `200` but **SPA HTML** (Prefix catch-all); 
  `/univention/meta.json`, `languages.json`, login JS, `theme.css` → **503**.

**Class:** OpenShift — Ingress→Route converter drops `pathType: Exact` (same
class as 1.19.0 failures #5/#6).

**Helm fix:** none — charts emit Exact rules; no values toggle to Prefix.

**OpenShift fix (applied, reconstructible):** port of 1.19.0 manifests into
kustomize base (thin SCC kept; fat SCC not reinstated):

1. `docs/openshift-manifests/base/opendesk-00-router-tls-secret-rbac.yaml` —
   Role/RoleBinding so `openshift-ingress:router` can read Secret
   `opendesk-certificates-tls` for `tls.externalCertificate`.
2. `docs/openshift-manifests/base/opendesk-fix-univention-routes.yaml` —
   14 Routes mirroring dropped Exact backends (portal-frontend `/`,
   portal-server JSON/XHR, umc-gateway bootstrap assets).
3. Overlay `overlays/example` sets `portalHost` + SCC namespace group via
   `configMapGenerator` / replacements.

```bash
oc apply -k docs/openshift-manifests/overlays/example
```

**Proven after apply:** all 14 fix Routes admitted (`True`); external probes
return correct types (`portal.json` / `meta.json` / `languages.json` JSON;
login JS / `theme.css` JS/CSS; `api/v1/me` JSON). TLS SAN
`*.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com` from BYO Secret.

**Residual Exact gaps (non-blocking):** `/favicon.ico`, `/univention`,
`/univention/`, `/univention/portal`, `/univention/selfservice` still lack
dedicated Routes; Prefix Routes already serve the HTML shells
(`/univention/portal/`, `/univention/selfservice/`). Add only if a probe proves
need.

### 5. ums-stack-data-ums Job pod Error then Complete

**Evidence:** first pod failed with UDM REST `DELETE .../oxmail/accessprofile/...`
→ HTTP 500 (`super(type, obj): obj must be an instance or subtype of type`).
Job `ums-stack-data-ums-1` later `Complete 1/1`; stale Error pod remains.

**Class:** app/UDM (not OpenShift). No overlay fix required if Job Complete.
