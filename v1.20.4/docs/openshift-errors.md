# openDesk 1.20.4 on OpenShift — failures log

Carried from v1.19.1 overlay (path a). Re-prove on this tag; drop if gone.
Do **not** assume older failures still apply. Classify each new failure:

| Class | Meaning |
| --- | --- |
| **OpenShift** | SCC, Ingress→Route Exact drop, rewrite-target, UID ranges, seccomp, … |
| **Environment** | LoadBalancer/NodePort/TURN/UDP, CPU, timeouts, storage class, DNS, client trust |

## Policy (1.20.4)

Do **not** reuse fat `opendesk-anyuid-seccomp` (extra caps from Collabora/Jitsi
history). Start on default `restricted-v2`. After a proven SCC admission failure,
prefer the thinnest new fix.

## 1.20.4 deploy log

Path **a** from `v1.19.1` overlay. In-place **upgrade** then second
`helmfile apply` (**redeploy**) on ocp22 `opendesk` ns (no ns wipe).

`MASTER_PASSWORD` recovered from pre-1.20 Helm release values:
`helm get values ums -n opendesk -a` → `global.secrets.masterPassword`
(see upstream `docs/migrations-manual.md`).

| # | Class | Symptom | Status | Fix (only if proven) |
| --- | --- | --- | --- | --- |
| 1 | OpenShift | `opendesk-migrations-pre` rejected by `restricted-v2` (UID/fsGroup 1000, empty seLinux, seccomp) | fixed (thin SCC) | `opendesk-uid-seccomp` — carried; migrations Jobs Complete on 1.20.4 |
| 2 | OpenShift | `clamav-simple-0` CrashLoop: freshclam SSL verify fail to gitlab.opencode.de CVD mirror | fixed | inject-trusted-cabundle + clamav customization — carried; SelfCheck OK after upgrade |
| 3 | Environment / app | `matrix-neodatefix-bot` CrashLoop: `M_UNKNOWN_TOKEN` / Token is not active | watch | Upstream `tokenRotation.generation` on bootstrap; bot Running after upgrade — remint only if CrashLoop returns |
| 4 | OpenShift | Portal Exact Ingress rules never become Routes | fixed | 14 fix Routes + router TLS RBAC — carried; `/univention/languages.json` + `portal.json` → 200 |
| 5 | App / Keycloak + XWiki OIDC | relative `post_logout_redirect_uri` / missing ICS callback | fixed | XWiki `oidc.afterLogoutURL` + KC ICS/`rootUrl` customizations — carried |
| 6 | Environment / upgrade | `ums-portal-consumer-0` `CreateContainerConfigError`: secret `ums-portal-consumer-object-storage` not found | fixed (ops) | STS already pointed at `objectstore-nubus-secret-key` (`username`/`secretKey`); stuck pod on old revision — `oc delete pod ums-portal-consumer-0` rolled it. **No overlay change.** |

**Upgrade result:** logs in deploy worktree
`/home/rhel/opencode/opendesk-1.20.4/logs/helmfile-apply-1.20.4-upgrade.log` +
`helmfile-apply-1.20.4-redeploy.log`. **40** releases `deployed`, **0** failed;
migrations-pre/post Complete; all pods Running/Completed after consumer roll;
portal Exact probes 200 with fix Routes.

### Carried detail from 1.19.1 (still authoritative for #1–#5 mechanics)

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

**Ordered redeploy:** thin SCC applied before helmfile; migrations-pre release
`deployed`, Job Complete (no `context canceled` leftover).

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
OpenShift-specific; **not** fixed by Exact-path Routes or SCC.

**Ordered redeploy:** **recurred** with Routes/SCC/CA applied before helmfile →
refutes “late Routes caused inactive token”. Remint still required after settle.

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

helmfile -e openshift -n opendesk -l name=matrix-neodatefix-bot-bootstrap apply \
  --skip-diff-on-install
# post-install Job remints token into the Secret
```

(Direct `helm install` of chart 6.2.7 with matching values is an equivalent
fallback if helmfile render is too slow.)

**Proven:** Job Completed; Secret recreated; pod `matrix-neodatefix-bot` `1/1
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

**Apply before helmfile** (with BYO TLS Secret present) so Routes using
`externalCertificate` admit immediately; converter still drops Exact Ingress
from charts, so these fix Routes remain required.

**Proven after apply:** all 14 fix Routes admitted (`True`); external probes
return correct types (`portal.json` / `meta.json` / `languages.json` JSON;
login JS / `theme.css` JS/CSS; `api/v1/me` JSON). TLS SAN
`*.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com` from BYO Secret.

**Residual Exact gaps (non-blocking):** `/favicon.ico`, `/univention`,
`/univention/`, `/univention/portal`, `/univention/selfservice` still lack
dedicated Routes; Prefix Routes already serve the HTML shells
(`/univention/portal/`, `/univention/selfservice/`). Add only if a probe proves
need.

### 5. Portal VIEW ALL / XWiki OIDC logout `invalid_redirect_uri` (relative `post_logout_redirect_uri`)

**Evidence** (`oc logs ums-keycloak-0`, realm `opendesk`):

```
type="LOGOUT_ERROR", clientId="opendesk-xwiki", error="invalid_redirect_uri",
redirect_uri="/bin/view/Main/"
```

Failing browser URL (decoded):
`…/protocol/openid-connect/logout?post_logout_redirect_uri=/bin/view/Main/&client_id=opendesk-xwiki`
(`aud`/`azp` = `opendesk-xwiki`). Trigger: portal newsfeed **VIEW ALL** (XWiki via ICS).

**Probes (before app-side fix):**

| `post_logout_redirect_uri` | HTTP |
| --- | --- |
| `/bin/view/Main/` (relative) | **400** |
| `https://wiki.<domain>/bin/view/Main/` | **302** |
| `https://portal.<domain>/` | **302** |

Upstream `opendesk-keycloak-bootstrap` already sets client attribute
`post.logout.redirect.uris` to absolute `https://wiki.*/*##https://portal.*/*`.
Allowlist was not missing the absolute wiki URL — Keycloak rejected the
**relative** URI XWiki OIDC sent (`oidc.logoutMechanism=rpInitiated`).

**Class:** app/config (Keycloak client + XWiki OIDC). Not OpenShift SCC/Route.

**Fix (durable overlay, no chart edit):**

1. **XWiki (preferred):** customization
   `helmfile/environments/openshift/customizations/xwiki-oidc-after-logout-url-fix.yaml.gotmpl`
   sets `customConfigs.xwiki.properties.oidc.afterLogoutURL` to
   `https://wiki.<domain>/bin/view/Main/` so RP-initiated logout sends an
   absolute `post_logout_redirect_uri` (XWiki OIDC Authenticator
   `oidc.afterLogoutURL`). Wired via `customization.release.xwiki`.
2. **Keycloak bootstrap:** customization
   `helmfile/environments/openshift/customizations/keycloak-xwiki-ics-redirect-fix.yaml.gotmpl`
   (same pattern as 1.19.0 ICS login fix) sets
   - `rootUrl: https://wiki.<domain>` (relative redirect resolution against wiki)
   - `redirectUris`: wiki + portal wildcards **plus**
     `https://ics.<domain>/oidc/authenticator/callback` (ICS login allowlist;
     related `LOGIN_ERROR` path from portal newsfeed).
   Wired via `customization.release.opendeskKeycloakBootstrap`.

**Apply:**

```bash
helmfile -e openshift -n opendesk -l name=opendesk-keycloak-bootstrap apply
helmfile -e openshift -n opendesk -l name=xwiki apply
```

**Proven:**

- Bootstrap Secret `opendesk-keycloak-bootstrap` values include `rootUrl` and ICS
  callback on `opendesk-xwiki`; Job revision completed (`kcom.py` reconcile).
- ICS auth probe with
  `redirect_uri=https://ics…/oidc/authenticator/callback` → **200** login page;
  `https://evil.example/callback` → **400**.
- Absolute wiki logout probe → **302**; XWiki pod properties contain
  `oidc.afterLogoutURL=https://wiki…/bin/view/Main/`.
- Relative logout probe may still return **400** on this Keycloak build even with
  `rootUrl` — that is why the XWiki absolute `afterLogoutURL` is required for
  VIEW ALL. Absolute path matches existing Valid Post Logout Redirect URIs.
