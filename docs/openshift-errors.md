# openDesk on OpenShift (ocp22) — failure / change history

Historical failure log and change table for deploying openDesk on
`ocp22.stormshift.coe.muc.redhat.com`. For **current reconstruct / deploy
steps**, see [`openshift-deployment.md`](./openshift-deployment.md).

Do not treat this file as the deploy runbook. Solved failures and the Changes
table live here so the deploy doc stays short and reconstructible.

Superseded Option 2a (in-cluster self-signed CA) material:
[`openshift-legacy-selfsigned-ca/`](./openshift-legacy-selfsigned-ca/).

## Changes

| # | File / Object | Setting | Value | Why |
| - | --- | --- | --- | --- |
| 1 | `helmfile/environments/openshift/values.yaml.gotmpl` (new) | `global.domain` | `opendesk.apps.ocp22.stormshift.coe.muc.redhat.com` | No delegated DNS; reuse cluster's existing wildcard router domain, length-checked against the 94-char SSSD limit |
| 2 | same | `cluster.container.engine` | `cri-o` | Matches node's actual runtime |
| 3 | same | `cluster.service.type` | `ClusterIP` | No cloud LoadBalancer on this on-prem cluster; HTTP(S) goes through OpenShift Routes anyway |
| 4 | same | `ingress.ingressClassName` | `openshift-default` | Chart default (`haproxy`) doesn't exist here; this is OpenShift's actual IngressClass |
| 5 | same | `persistence.storageClassNames.RWO` / `.RWX` | `coe-netapp-nas` | Only StorageClass on the cluster that's NFS-backed (supports RWX); the other (`coe-netapp-san`) is block/iSCSI, RWO-only |
| 6 | same | `certificate.selfSigned` | `true` | **Mount CA trust bundle** into apps (`opendesk-certificates-ca-tls` / `truststore.jks`). Chart flag name is misleading — does **not** mint a self-signed CA under Option 1 BYO (`apps.certificates.enabled: false`) |
| 7 | same | `apps.*.enabled` | see [selection above](./openshift-deployment.md#current-app-set--hosts) | Minimal core-only footprint |
| 8 | OpenShift `SecurityContextConstraints` (cluster-scoped) | `oc apply -f opendesk-anyuid-seccomp-scc.yaml` | custom SCC `opendesk-anyuid-seccomp` (any UID/GID/fsGroup + `seccompProfiles: [runtime/default]` + `allowPrivilegeEscalation: true` + `allowedCapabilities: [CHOWN, DAC_OVERRIDE, FOWNER, KILL, NET_BIND_SERVICE, SETGID, SETUID, SYS_ADMIN, SYS_CHROOT]`), scoped to `groups: [system:serviceaccounts:opendesk]` | `restricted-v2` rejects openDesk's hardcoded non-namespace UIDs; plain `anyuid` then rejects `seccompProfile` — see [failures 1–2](#1-pods-rejected-by-scc-runasuserfsgroup-outside-namespaces-allocated-uid-range); `CHOWN`/`FOWNER`/`SYS_CHROOT` were added for Collabora ([failure 7](#7-collabora-needs-privilege-escalation--extra-capabilities-the-custom-scc-didnt-grant-yet)); `DAC_OVERRIDE`/`KILL`/`NET_BIND_SERVICE`/`SETGID`/`SETUID` were added for Dovecot/Postfix ([failure 10](#10-dovecotpostfix-need-more-capabilities-than-collaboras-scc-grant-covers)); `SYS_ADMIN` was added for Jitsi Jibri when recording is enabled ([failure 13](#13-jitsi-pods-crashloop-under-requireddropcapabilities-all--empty-capabilities--missing-sys_admin-for-jibri)) |
| 9 | ~~`ClusterIssuer/selfsigned-issuer`~~ | ~~`oc apply -f selfsigned-clusterissuer.yaml`~~ | — | **Superseded** (Option 2a only). Full row + YAML: [`openshift-legacy-selfsigned-ca/`](./openshift-legacy-selfsigned-ca/changes-rows-option-2a.md) |
| 10 | ~~`certificate.issuerRef` → `selfsigned-issuer`~~ | — | — | **Superseded** with row 9 — Option 2a only |
| 11 | `docs/openshift-manifests/opendesk-fix-univention-routes.yaml` (new) | `oc apply -f docs/openshift-manifests/` | 14 `Route` objects (namespace-scoped, `opendesk` ns): `portal.../` → `ums-portal-frontend:http`; the 6 `portal.../univention/{portal,selfservice}/{portal.json,navigation.json,api/v1/me}` JSON/XHR endpoints and the 7 `portal.../univention/{meta.json,languages.json,theme.css,login/main.js,login/dialog.js,login/LoginDialog.js,login/i18n/en/main.json}` UMC bootstrap assets → `ums-umc-gateway:http`/`ums-portal-server:http` (all edge termination, reusing the `opendesk-certificates-tls` leaf cert) | OpenShift's Ingress→Route converter drops every `pathType: Exact` Ingress rule, so these 14 paths across 3 charts (`ums-portal-frontend`, `ums-portal-server`, `ums-umc-gateway`) had zero Routes — see [failures 5](#5-openshifts-ingressroute-converter-silently-drops-pathtype-exact-rules) and [6](#6-same-ingressroute-exact-bug-second-instance-on-ums-umc-gateway) |
| 12 | `helmfile/environments/openshift/values.yaml.gotmpl` | `apps.collabora.enabled` | `true` | Restore openDesk's own upstream default (see [Minimal app selection](./openshift-deployment.md#current-app-set--hosts)) as an explicitly-added module |
| 13 | `helmfile/environments/openshift/values.yaml.gotmpl` | `apps.nextcloud.enabled` | `true` | Same as row 12, as an explicitly-added module — validated with its own full teardown+reconstruct cycle, **needed no other change** (see [Minimal app selection](./openshift-deployment.md#current-app-set--hosts)) |
| 14 | `helmfile/environments/openshift/values.yaml.gotmpl` | `apps.openproject.enabled` | `true` | Same as rows 12/13, as an explicitly-added module — validated with its own full teardown+reconstruct cycle |
| 15 | `helmfile/environments/openshift/values.yaml.gotmpl` + `helmfile/environments/openshift/customizations/openproject-design-seed-fix.yaml` (new) | `customization.release.openproject.ssrfSafeDesignSeed` | path to the new customization file, which sets all 7 `OPENPROJECT_SEED_DESIGN_*` env vars to a base64 `data:image/png` placeholder URI | Uses openDesk's own `customization.release.<name>` extension point to inject an extra Helm values file into just the `openproject` release, without touching its chart's `values.yaml.gotmpl` — see [failure 8](#8-openprojects-db-seed-job-blocks-itself-downloading-its-own-branding-assets-ssrf-guard) |
| 16 | `helmfile/environments/openshift/values.yaml.gotmpl` | `apps.clamavSimple.enabled` | `false` → `true` | Restores openDesk's own upstream default (per `docs/getting-started.md`'s apps table) — Nextcloud's `antivirus.enabled: true` is hardcoded with no toggle, and only gets a real ICAP host from `clamavSimple`/`clamavDistributed`; with both off, every file write 500s — see [failure 9](#9-nextclouds-hardcoded-antivirus-integration-has-no-scanner-behind-it) |
| 17 | `helmfile/environments/openshift/values.yaml.gotmpl` | `apps.oxAppSuite.enabled` / `apps.dovecot.enabled` / `apps.postfix.enabled` | `false` → `true` (all three) | Restores openDesk's own upstream default, as an explicitly-added module bundle (groupware + IMAP + SMTP are wired together, not independently useful) — see [Minimal app selection](./openshift-deployment.md#current-app-set--hosts) |
| 18 | OpenShift `SecurityContextConstraints` (cluster-scoped, same object as row 8) | `oc apply -f opendesk-anyuid-seccomp-scc.yaml` | extended `allowedCapabilities` with `DAC_OVERRIDE`, `KILL`, `NET_BIND_SERVICE`, `SETGID`, `SETUID` | Dovecot and both Postfix releases hardcode these capabilities (`docs/security-context.md`'s compliance table) — the SCC only had Collabora's 3 from row 8 — see [failure 10](#10-dovecotpostfix-need-more-capabilities-than-collaboras-scc-grant-covers) |
| 19 | `helmfile/environments/openshift/values.yaml.gotmpl` + `helmfile/environments/openshift/customizations/openxchange-core-ui-middleware-core-service-url-fix.yaml` (new) | `customization.release.openxchange.coreServiceUrlFix` → `appsuite.core-ui-middleware.coreServiceURL` | `"http://open-xchange-core-mw-http-api/appsuite"` | Points `core-ui-middleware`'s Node.js backend client at the internal Service over plain HTTP instead of self-referencing the public HTTPS Route (Node TLS verify fails when leaf CA is absent from Node's trust store) — see [failure 12](#12-core-ui-middleware-self-referencing-https-call-to-fetch-pwajson-fails-tls-verification-against-the-self-signed-ca) |
| 20 | `helmfile/environments/openshift/values.yaml.gotmpl` | Option 1 BYO: `apps.certificates.enabled: false`, `certificate.selfSigned: true` (mount trust only), remove `issuerRef`, `secrets.certificates.password` → `opendesk-certificates-keystore-jks` + `CERTIFICATES_JKS_PASSWORD` | (see Reconstruction) | Current TLS path: user-provided RH Internal CA leaf (`*.opendesk.apps...`); was Option 2a — archive [`openshift-legacy-selfsigned-ca/`](./openshift-legacy-selfsigned-ca/) |
| 21 | `docs/openshift-manifests/opendesk-fix-univention-routes.yaml` | `tls.externalCertificate.name` | `opendesk-certificates-tls` | Drop embedded ECME PEM/key (no private keys in git); Route ExternalCertificate feature (OCP 4.22, gate enabled) |
| 22 | `docs/openshift-manifests/opendesk-00-router-tls-secret-rbac.yaml` (new) | Role/RoleBinding | `openshift-ingress:router` → get/list/watch Secret `opendesk-certificates-tls` | Required for `externalCertificate` (filename `00-` sorts before fix-routes) |
| 23 | ~~`selfsigned-clusterissuer.yaml`~~ | ~~deleted from live manifests~~ | — | **Superseded** — YAML kept under [`openshift-legacy-selfsigned-ca/`](./openshift-legacy-selfsigned-ca/selfsigned-clusterissuer.yaml) |
| 24 | `helmfile/environments/openshift/values.yaml.gotmpl` | `apps.cryptpad` / `apps.element` / `apps.jitsi` / `apps.xwiki` | `false` → `true` | Restore upstream defaults; auto-wires Nextcloud↔CryptPad, Element↔Synapse/OX/Jitsi, XWiki↔newsfeed/Keycloak — see [Minimal app selection](./openshift-deployment.md#current-app-set--hosts) |
| 25 | `helmfile/environments/openshift/values.yaml.gotmpl` + `helmfile/environments/openshift/customizations/jitsi-capabilities-fix.yaml` (new) | `customization.release.jitsi.capabilitiesFix` → `jitsi.{web,prosody,jicofo,jvb}.securityContext.capabilities.add` | `CHOWN`/`SETGID`/`SETUID` (all four); plus `NET_BIND_SERVICE` on `web` | SCC `requiredDropCapabilities: [ALL]` leaves pods with `capabilities: {}` with zero caps — s6 needs SETGID, chown needs CHOWN, nginx `:80` needs NET_BIND_SERVICE — see [failure 13](#13-jitsi-pods-crashloop-under-requireddropcapabilities-all--empty-capabilities--missing-sys_admin-for-jibri) |
| 26 | OpenShift `SecurityContextConstraints` (cluster-scoped, same object as row 8) | `oc apply -f opendesk-anyuid-seccomp-scc.yaml` | extended `allowedCapabilities` with `SYS_ADMIN` | Chart hardcodes `SYS_ADMIN` on `jitsi.jibri` for Chromium/FFmpeg recording; jibri stays off by default (`jibri.enabled: false`) but SCC must allow the cap before anyone flips it on — see [failure 13](#13-jitsi-pods-crashloop-under-requireddropcapabilities-all--empty-capabilities--missing-sys_admin-for-jibri) |
| 27 | `helmfile/environments/openshift/customizations/jitsi-capabilities-fix.yaml` | `jitsi.prosody.securityContext.capabilities.add` | add `DAC_OVERRIDE` | Prosody cont-init `mv` of mode-0400 keys into `/config/certs` needs DAC_OVERRIDE under `requiredDropCapabilities: [ALL]` — empty certs → no c2s TLS → Jicofo/JVB XMPP auth fail — see [failure 14](#14-jitsi-prosody-tls-certs-missing-without-dac_override--xmpp-auth-fails-join-stuck) |
| 28 | `helmfile/environments/openshift/values.yaml.gotmpl` + `helmfile/environments/openshift/customizations/keycloak-xwiki-ics-redirect-fix.yaml.gotmpl` (new) | `customization.release.opendeskKeycloakBootstrap.xwikiIcsRedirectFix` → `config.opendesk.clients.opendesk-xwiki.redirectUris` | restates wiki+portal wildcards and adds `https://ics.<domain>/oidc/authenticator/callback` | Intercom proxies XWiki and presents that ICS callback as `redirect_uri` for client `opendesk-xwiki`; upstream bootstrap omit it → Keycloak `invalid_redirect_uri` — see [failure 15](#15-intercom--xwiki-oidc-invalid_redirect_uri-ics-callback-missing-from-opendesk-xwiki-allowlist) |
| 29 | `helmfile/environments/openshift/values.yaml.gotmpl` + `helmfile/environments/openshift/customizations/jitsi-media-nodeport-fix.yaml` (new) | `service.type.jitsiVideoBridge` → `NodePort`; `cluster.networking.ingressGatewayIP` → `10.32.105.193`; `jitsi.jvb.nodePort` → `31000` | Jitsi media ICE: browsers need reachable UDP to JVB; ClusterIP + TCP Routes + empty TURN leave ICE dead — see [failure 16](#16-jitsi-meet-audio--no-media-ice-unreachable-jvb-candidates) |
| 30 | `helmfile/environments/openshift/values.yaml.gotmpl` + `helmfile/environments/openshift/customizations/openxchange-openshift-rewrite-fix.yaml` (new) | `annotations.openxchangeAppsuiteIngress.*` + `appsuite.ingress.routes.*.annotations` → `haproxy.router.openshift.io/rewrite-target` | OpenShift router ignores nginx/haproxy-ingress rewrites; OX Guard and sibling path aliases 404'd externally — see [failure 17](#17-ox-app-suite-path-rewrites-ignored-on-openshift--guard-encryption-server-unreachable) |

_(Ingress↔Route audit Aug 2026: all Prefix OX Ingress rules have matching Routes. `pathType: Exact` / “direct” portal bootstrap paths are covered by row 11 fix-routes or by the portal `/` catch-all which 301s correctly. Remaining known gap: bare base-domain redirect under [Unsolved](#unsolved).)_

## Failures encountered and fixes

### 1. Pods rejected by SCC: `runAsUser`/`fsGroup` outside namespace's allocated UID range

**Symptom:** `helmfile apply -e openshift -n opendesk` hung on the very first release
(`opendesk-migrations-pre`); `oc get events -n opendesk` showed:

```
Error creating: pods "opendesk-migrations-pre-1-" is forbidden: unable to validate
against any security context constraint: [provider "anyuid": Forbidden: not usable
by user or serviceaccount, provider restricted-v2: .spec.securityContext.fsGroup:
Invalid value: [1000]: 1000 is not an allowed group, provider restricted-v2:
.containers[0].runAsUser: Invalid value: 1000: must be in the ranges:
[1000540000, 1000549999], ...]
```

**Root cause:** every openDesk component pins an explicit, fixed non-root
`runAsUser`/`fsGroup` (e.g. `1000`, `1001`, `999`, `101`/`102` — see
`docs/security-context.md`'s status-quo table). These are hardcoded in the charts
(not exposed as helmfile values — confirmed no `runAsUser`/`fsGroup` override key
exists anywhere under `helmfile/environments/default/`). OpenShift's default
`restricted-v2` SCC only allows UIDs from the namespace's pre-allocated range
(`1000540000-1000549999` for `opendesk`), so every fixed-UID pod is rejected.

**Doc used:** [OpenShift Container Platform 4.22 — Managing security context
constraints, Chapter 17](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/authentication_and_authorization/managing-pod-security-policies)
(fetched via web search after the `user-Red-Hat-documentation` MCP tool returned
"Not connected" for this session — the built-in `anyuid` SCC ("provides all
features of the `restricted` SCC, but allows users to run with any UID and any
GID") is exactly the documented mechanism for this scenario).

**Fix (priority 1, helm/deployment value): none available** — no helmfile value
exposes `runAsUser`/`fsGroup`, so per CURSOR.MD's priority order this drops to
priority 2.

**Fix (priority 2, OpenShift config):** grant the `anyuid` SCC to all service
accounts in the `opendesk` namespace (each openDesk sub-chart creates its own
dedicated ServiceAccount, so granting to the whole `system:serviceaccounts:opendesk`
group in one shot is the smallest fix instead of one grant per SA):

```shell
oc adm policy add-scc-to-group anyuid system:serviceaccounts:opendesk
```

### 2. `anyuid` SCC rejects pods that also set `securityContext.seccompProfile`

**Symptom:** after granting `anyuid`, pod creation still failed, now with:

```
Error creating: pods "opendesk-migrations-pre-1-" is forbidden: unable to validate
against any security context constraint: [metadata.annotations[container.seccomp.
security.alpha.kubernetes.io/opendesk-migrations]: Forbidden: seccomp may not be
set, provider restricted-v2: ...]
```

**Root cause:** every openDesk container also explicitly sets
`securityContext.seccompProfile.type: RuntimeDefault` (per
`docs/security-context.md`). OpenShift's built-in `anyuid` SCC does not declare a
`seccompProfiles` allow-list, so its admission path falls back to validating via
the deprecated `container.seccomp.security.alpha.kubernetes.io/*` annotation
mechanism, which is rejected outright — a known interaction, not specific to
openDesk.

**Doc used:** Red Hat Customer Portal solution
[7064000 — "The pod is not admitted due to the seccomp issue with anyuid scc"](https://access.redhat.com/solutions/7064000)
and [Bugzilla #2010564](https://bugzilla.redhat.com/show_bug.cgi?id=2010564), whose
documented workaround is to create a custom SCC (based on the built-in one you need)
that explicitly adds `seccompProfiles: ["runtime/default"]`, and grant that instead.

**Fix (priority 1, helm value): none** — `seccompProfile` is templated
unconditionally by every chart (also confirmed as intentional/required behaviour by
`docs/security-context.md`), not a value we're allowed/able to turn off.

**Fix (priority 2, OpenShift config):** replace the plain `anyuid` grant with a
custom SCC `opendesk-anyuid-seccomp` — identical to `anyuid` (any UID/GID/fsGroup,
priority 10, same volume types) plus `seccompProfiles: ["runtime/default"]` —
scoped via its own `groups: [system:serviceaccounts:opendesk]` field so it only
applies inside this namespace:

```shell
oc apply -f opendesk-anyuid-seccomp-scc.yaml   # see Changes table for full spec
oc adm policy remove-scc-from-group anyuid system:serviceaccounts:opendesk
```

### 3. Nubus hard-requires an object storage backend (not actually optional)

**Symptom:** `helmfile apply` failed while rendering the `ums` (Nubus) release:

```
failed to render [values-nubus.yaml.gotmpl], because of template:
stringTemplate:580:8: executing "stringTemplate" at
<fail "No objectstorage endpoint for nubus found!">: error calling fail:
No objectstorage endpoint for nubus found!
```

**Root cause:** `helmfile/apps/nubus/values-nubus.yaml.gotmpl` templates the Nubus
portal's S3 object-storage endpoint with `{{- if .Values.objectstores.nubus.endpoint
}} ... {{- else if .Values.apps.minio.enabled }} ... {{- else if
.Values.apps.seaweedfs.enabled }} ... {{- else }}{{- fail ... }}`. SeaweedFS was
initially disabled as part of the "true minimalism" cut suggested for this exercise,
but it turned out not to be optional: Nubus's portal server/consumer genuinely needs
an S3-compatible endpoint, and this cluster has no externally provided one to plug
into `objectstores.nubus.endpoint`.

**Fix (priority 1, helm value) — applied:** re-enabled `apps.seaweedfs` (openDesk's
default, lighter-weight object-storage backend, vs. MinIO) in the dev values. This
corrects the initial minimal-set assumption; see the updated
[Minimal app selection](./openshift-deployment.md#current-app-set--hosts) below.

### 4. `certificate.selfSigned: true` alone does not make the CA self-signed — cascading blocker for the whole Nubus chain

**Status: superseded.** This failure belonged to the **Option 2a in-cluster
self-signed CA** path (`apps.certificates.enabled: true` +
`ClusterIssuer/selfsigned-issuer`). Current reconstruct uses **Option 1 BYO**
(RH Internal CA) — Secrets from PEMs, certificates chart off — so this
issuance cascade no longer applies. Full historical writeup:
[`openshift-legacy-selfsigned-ca/failure-04-selfsigned-issuer.md`](./openshift-legacy-selfsigned-ca/failure-04-selfsigned-issuer.md).

**Still-relevant naming note:** `certificate.selfSigned: true` under BYO only
means “mount the CA trust bundle”; it does not mint certs. See
[TLS strategy](./openshift-deployment.md#tls-strategy-current).

### 5. OpenShift's Ingress→Route converter silently drops `pathType: Exact` rules

**Symptom:** Once every pod was `Running`, the deployment still looked broken from
the outside: `curl https://portal.opendesk.apps.../` returned a bare
`HTTP/1.0 503 Service Unavailable` (the router's own "no route matched" page, not
an application error), even though sub-paths like
`/univention/portal/` and Keycloak's `/realms/master` returned `200 OK` fine.

**Root cause:** openDesk's charts only support two Ingress "flavours" via
`ingress.controller` (`haproxy` = the [haproxy-ingress](https://haproxy-ingress.github.io)
project, or `nginx` = ingress-nginx) — neither is OpenShift's native router.
OpenShift exposes plain `Ingress` objects by auto-generating one `Route` per rule via
a built-in "ingress-to-route" shard controller, but **that controller only converts
rules with `pathType: Prefix` or `ImplementationSpecific` — it silently skips any
rule with `pathType: Exact`**, and produces zero Routes (and an empty
`status.loadBalancer`) for an Ingress whose rules are *all* Exact. Comparing the
`ums-portal-frontend-static` Ingress (`oc get ingress ... -o yaml`) to the Routes
OpenShift actually created for it showed exactly this gap:

```
# Ingress rule (never got a Route):
- path: /
  pathType: Exact
  backend: {service: {name: ums-portal-frontend, port: {name: http}}}
```

Two more openDesk-generated Ingresses hit the same wall:

- `ums-portal-server` — **all 6** of its rules are `Exact`
  (`/univention/portal/portal.json`, `/navigation.json`, `/api/v1/me`, and the
  `/univention/selfservice/...` equivalents — the JSON/XHR endpoints the portal
  frontend's JavaScript calls to render itself). None of them got a Route at all.
- `opendesk-home-basedomain` — its single rule (`/` → `opendesk-home-dummy`) is
  `Exact` too, so it never got a Route either (see [Unsolved](#unsolved)).

**Doc used:** Red Hat documentation
([Configuring ingress cluster traffic — creating a route](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/networking/configuring-ingress-cluster-traffic))
confirms Routes only support prefix-style path matching, and community/upstream
Kubernetes issue tracking for `ingress-to-route` (no override flag exists — it is a
hard behavioural limit of the converter, not a bug you can configure around).

**Fix (priority 1, helm value):** none available. `ingress.controller` only toggles
`haproxy` vs `nginx` *annotation* styles in the chart output — it does not change
`pathType`, and neither upstream ingress-controller flavour is what actually
processes these Ingresses on this cluster (OpenShift's shard controller does,
regardless of the annotations), so this knob cannot fix the gap.

**Fix (priority 2, OpenShift config) — applied:** create the missing Routes
directly, pointing at the exact same backend Service+port the dropped Ingress
rule already specified (so this is purely filling a gap left by OpenShift's own
converter, not inventing new routing logic), reusing the wildcard leaf cert/key
already in the `opendesk-certificates-tls` Secret (the same one every
auto-generated sibling Route already inlines) so TLS behaves identically. The
static, reconstructable form of this fix is
[`docs/openshift-manifests/opendesk-fix-univention-routes.yaml`](./openshift-manifests/opendesk-fix-univention-routes.yaml)
(7 of its 14 `Route` objects — the `opendesk-fix-portal-root` and
`opendesk-fix-univention-{portal,selfservice}-*` ones — are this failure's fix;
the other 7 belong to [failure 6](#6-same-ingressroute-exact-bug-second-instance-on-ums-umc-gateway)),
applied with `oc apply -f docs/openshift-manifests/` per the
[Reconstruction](./openshift-deployment.md#reconstruction) steps. It was first prototyped live with
`oc create route edge ...` (extracting the cert/key from the Secret via
`jsonpath`+`base64 -d`) while debugging, then captured into that manifest as the
actual documented fix — no ad-hoc commands are part of the reconstruction path.

**Verified:** `https://portal.opendesk.apps.../` now returns `301` to
`/univention/portal/` (an app-level redirect from `ums-portal-frontend`'s own
nginx, i.e. correct behaviour) which resolves to `200 OK`; all 6 portal-server
JSON/API endpoints return `200 OK`.

### 6. Same Ingress→Route `Exact` bug, second instance, on `ums-umc-gateway`

**Symptom:** after login, the portal itself worked, but clicking any portal icon that
opens the UMC app (e.g. `.../univention/management/?...#module=udm:portals/announcement`)
rendered a **fully white page**. Browser console showed `404`s for
`/univention/meta.json`, `/univention/theme.css`, `/univention/login/main.js`,
`/univention/login/dialog.js`, `/univention/login/LoginDialog.js`, and
`/univention/login/i18n/en/main.json`, plus a `dojo.js` `scriptError` from the failed
`main.js` load — the dojo/UMC bootstrap crashed before it could render anything.

**Root cause:** identical mechanism to [failure 5](#5-openshifts-ingressroute-converter-silently-drops-pathtype-exact-rules) —
`ums-umc-gateway`'s Ingress rules for those 7 exact filenames use `pathType: Exact`,
which OpenShift's Ingress→Route converter drops. The first pass (failure 5) only
covered `ums-portal-frontend`/`ums-portal-server`'s `Exact` rules and missed this
second chart. Confirmed via `oc get pods`/`oc logs` that `ums-umc-gateway` and
`ums-umc-server` themselves were healthy and answering `200`/`304` for everything
that *did* have a Route (e.g. `/univention/udm/portals/announcement` itself worked
fine) — this was purely a missing-Route gap, not an app bug.

**Fix (priority 2, same as failure 5 — no helm value controls Route generation):**
the other 7 `Route` objects in
[`docs/openshift-manifests/opendesk-fix-univention-routes.yaml`](./openshift-manifests/opendesk-fix-univention-routes.yaml)
(`opendesk-fix-univention-{meta,languages,theme,login-*}-*`), same edge
termination/leaf cert, pointed at `ums-umc-gateway:http` instead. While
debugging this was first prototyped by cloning an existing `opendesk-fix-*`
Route's JSON via `oc get route -o json | jq '...' | oc apply -f -` for each of
the 7 missing paths; the manifest is the actual documented, `oc apply -f
docs/openshift-manifests/`-reconstructable form. See [Changes row 11](#changes).

**Verified:** all 7 URLs now return `200 OK`; a full sweep of every remaining
`Exact` Ingress rule in the namespace against existing Routes found no other live
gaps (the handful of other "missing" ones already fall through to a broader
Prefix/catch-all Route on the same host and 301-redirect correctly).

**Lesson for reconstruction:** this bug class (`pathType: Exact` → dropped Route) can
recur per-chart on OpenShift; if a future openDesk version adds new `Exact` Ingress
rules anywhere, re-run the `oc get ingress -o json | jq` sweep described above and
add the missing Routes to
[`opendesk-fix-univention-routes.yaml`](./openshift-manifests/opendesk-fix-univention-routes.yaml)
rather than waiting for a fresh symptom report.

### 7. Collabora needs privilege escalation + extra capabilities the custom SCC didn't grant yet

**Symptom:** found during the [full teardown + redeploy validation](./openshift-deployment.md#reconstruction)
after adding `apps.collabora.enabled: true`. Every other release deployed and
went `Running` as before, but the `collabora` Deployment stayed `0/1` with
`ReplicaFailure: FailedCreate`:

```
Error creating: pods "collabora-66c95f7969-" is forbidden: unable to validate
against any security context constraint: [provider opendesk-anyuid-seccomp:
.containers[0].capabilities.add: Invalid value: "CHOWN": capability may not be
added, ... "FOWNER" ..., ... "SYS_CHROOT" ..., provider opendesk-anyuid-seccomp:
.containers[0].allowPrivilegeEscalation: Invalid value: true: Allowing privilege
escalation for containers is not allowed, provider "anyuid": Forbidden: not
usable by user or serviceaccount, ...]
```

**Root cause:** `collabora-online`'s container hardcodes
`securityContext.allowPrivilegeEscalation: true` plus `capabilities.add:
[CHOWN, FOWNER, SYS_CHROOT]` (LibreOffice-based document rendering needs to
`chroot`/`chown` inside its sandbox) — confirmed as intentional/documented
upstream behaviour by this repo's own
`docs/security-context.md` compliance table (`collabora`/collabora-online row:
`allowPrivilegeEscalation: yes`, `capabilities: ["CHOWN","FOWNER","SYS_CHROOT"]`,
marked `:x:` = doesn't meet the `restricted` profile). Our
`opendesk-anyuid-seccomp` SCC (added for [failures 1–2](#2-anyuid-scc-rejects-pods-that-also-set-securitycontextseccompprofile))
only granted any-UID/GID + the default seccomp profile — it never needed to
allow privilege escalation or extra capabilities before, because none of the
other 5 previously-enabled apps requested them.

**Doc used:** this repo's own `docs/security-context.md` (same doc used for
failures 1–2) already documents exactly which capabilities/flags each app
needs; no external lookup was required this time — the table is the "look up
the fix" step for this class of failure.

**Fix (priority 1, helm value): none** — same reasoning as failures 1–2:
`securityContext.allowPrivilegeEscalation`/`capabilities` are templated
unconditionally by the `collabora-online` chart, not exposed as a value.

**Fix (priority 2, OpenShift config) — applied:** extended the *existing*
`opendesk-anyuid-seccomp` SCC (same file, same object — not a new one) to also
set `allowPrivilegeEscalation: true` and `allowedCapabilities: [CHOWN, FOWNER,
SYS_CHROOT]`. It's still scoped to `groups: [system:serviceaccounts:opendesk]`
only (this namespace), consistent with the existing broad-but-namespace-scoped
grant style from failures 1–2 rather than introducing a second, Collabora-only
SCC. See [Changes row 8](#changes) and
[`docs/openshift-manifests/opendesk-anyuid-seccomp-scc.yaml`](./openshift-manifests/opendesk-anyuid-seccomp-scc.yaml).

**Verified:** after `oc apply`-ing the updated SCC, the existing `ReplicaSet`
retried on its own (no `helmfile`/`oc` re-trigger needed) and `collabora` came
up `1/1 Running`; `https://office.opendesk.apps.../` returns `200 OK`.

### 8. OpenProject's `db:seed` Job blocks itself downloading its own branding assets (SSRF guard)

**Symptom:** found during the [full teardown + redeploy validation](./openshift-deployment.md#reconstruction)
after adding `apps.openproject.enabled: true`. Every other release deployed
`Running` as before, but `helmfile apply` itself eventually failed with
`context deadline exceeded` after sitting at the `openproject` release for its
full wait timeout. `oc get pods` showed `openproject-seeder-1-...` stuck in
`CrashLoopBackOff`; its logs ended with:

```
Hostname 'projects.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com' has no public
ip addresses (SSRFFilter::Errors::InvalidAddress)
```

**Root cause:** `helmfile/apps/openproject/values.yaml.gotmpl` (an upstream
chart file, not something we edit) points 7 `OPENPROJECT_SEED_DESIGN_*` env
vars — `LOGO`, `LOGO_MOBILE`, `FAVICON`, `TOUCH_ICON`, `EXPORT_LOGO`,
`EXPORT_COVER`, `EXPORT_FOOTER` — at `https://<its-own-openproject-host>/opendesk-static-files/...`
URLs. OpenProject's one-shot `db:seed` Job (run as a post-install/upgrade Helm
hook) downloads each of these via CarrierWave, which uses the vendored
`ssrf_filter` Ruby gem to validate the target host before connecting. That gem
hardcodes a private-IP blacklist (`10.0.0.0/8`, `172.16.0.0/12`,
`192.168.0.0/16`, link-local, etc.) with **no allowlist or override hook**
exposed anywhere — confirmed by `oc exec`-ing into the running `openproject-web`
pod and reading the gem's source directly
(`bundle show ssrf_filter` → `lib/ssrf_filter.rb`'s `PRIVATE_IP_RANGES`
constant has no configuration point). This is a *different* SSRF guard than
`OPENPROJECT_SSRF__PROTECTION__IP__ALLOWLIST` (a real, documented Helm/env
value): that one only governs OpenProject's own outbound-integration guard
(SAML metadata fetch, Jira/GitHub webhooks, etc.), not this CarrierWave
download path — setting it changes nothing here, confirmed by testing it had
no effect before looking further. On this on-prem cluster the openDesk domain
always resolves to a private node/router IP (verified via `oc exec ... getent
hosts projects.<domain>` → `10.32.105.192`), so the download is
unconditionally rejected, the seeder Job never completes, and
`helm upgrade --install --wait-for-jobs` (hence `helmfile apply`) hangs until
its timeout.

**Doc used:** [OpenProject documentation — "Setting logos and icons through
environment variables"](https://www.openproject.org/docs/installation-and-operations/configuration/)
documents `OPENPROJECT_SEED_DESIGN_*` accepting an inline base64 `data:` URI
as an alternative to a URL — an officially supported input format, not a
workaround.

**Fix (priority 1, helm value) — applied:** rather than editing the
upstream `helmfile/apps/openproject/values.yaml.gotmpl` (forbidden by
CURSOR.MD), used openDesk's own `customization.release.<releaseName>`
extension point (`helmfile/environments/default/customization.yaml.gotmpl`) —
a first-class, chart-author-provided mechanism for merging an extra Helm
values file into one specific release without touching its template. Pointed
it at a new file,
[`helmfile/environments/openshift/customizations/openproject-design-seed-fix.yaml`](../helmfile/environments/openshift/customizations/openproject-design-seed-fix.yaml),
that overrides all 7 `OPENPROJECT_SEED_DESIGN_*` vars with a single shared
1×1 transparent PNG `data:image/png;base64,...` placeholder (purely cosmetic
branding for this evaluation deployment, so a placeholder is acceptable —
real deployments would inline actual logo assets the same way). This is
deep-merged on top of the chart's own values, so no HTTP download is ever
attempted and `ssrf_filter` is never invoked. See [Changes row 15](#changes).

**Verified:** on redeploy, `openproject-seeder-1-...` logged `Setting custom
logos` and completed successfully (`0/1 Completed`, not `CrashLoopBackOff`);
`helmfile apply` finished with all releases `deployed`; `https://projects.opendesk.apps.../`
redirects through Keycloak SSO (`/realms/opendesk/protocol/openid-connect/auth?client_id=opendesk-openproject...`)
to a final `200 OK`.

### 9. Nextcloud's hardcoded antivirus integration has no scanner behind it

**Symptom:** found via manual click-through testing (not the automated
teardown/rebuild sweep) — logging into Nextcloud through the portal's Keycloak
SSO completed the redirect, but the app then rendered a blank "Internal Server
Error" page. `oc logs` on the `opendesk-nextcloud-aio-...` pod for the request
in question (`reqId guEwlgwp58CQcDztAHJl`/`3oZE59fc2geArnBKtHpf`) showed the
first-login default-contact creation and the subsequent `GET /apps/files/`
both failing with the same underlying exception:

```
RuntimeException: Failed to initialize ICAP request: Cannot connect to
"tcp://clamav-icap:1344": php_network_getaddresses: getaddrinfo for
clamav-icap failed: Name or service not known (code 0)
  at apps/files_antivirus/lib/AvirWrapper.php:269 (initScanner)
  at apps/dav/lib/Listener/UserEventsListener.php:79 (firstLogin)
```

**Root cause:** `helmfile/apps/nextcloud/values-nextcloud-management.yaml.gotmpl`
(an upstream chart file) hardcodes `configuration.antivirus.enabled: true`
with **no toggle**, and only supplies a real ICAP `host` if
`apps.clamavDistributed.enabled` (→ `clamav-icap`) or
`apps.clamavSimple.enabled` (→ `clamav-simple`) — both of which the minimal
app set had switched off, since `clamavSimple` looked like an optional
standalone module rather than a Nextcloud dependency. With no `host` value
templated, Nextcloud's `files_antivirus` app fell back to its own
`av_host: clamav-icap` default (confirmed via
`occ config:list files_antivirus` inside the running pod, both before and
after the fix — see below), a Service that has never existed in this
deployment. Because `AvirWrapper` wraps **every** filesystem write (not just
uploads — first-login default-contact creation, JS/CSS template caching,
preview generation, etc.), this broke far more than "virus scanning didn't
run": any code path that writes a file 500s. This is the same class of hard-
dependency miss as [failure #3](#3-nubus-hard-requires-an-object-storage-backend-not-actually-optional)
(seaweedfs) — enabling a consumer app (Nextcloud) implicitly re-activated a
hard requirement (antivirus/ClamAV) that the minimal set had turned off,
except this one only surfaces once a real user actually logs in and writes a
file, not during `helmfile apply`/pod-readiness checks — nothing about the
Job/pod lifecycle flags it, which is why it wasn't caught by the earlier
automated teardown/rebuild + HTTP-`200`-on-`/` sweeps.

**Doc used:** `docs/getting-started.md`'s own apps table (confirms
`clamavSimple: enabled: true` is openDesk's upstream default, not a
custom add-on) plus direct inspection of
`helmfile/apps/nextcloud/values-nextcloud-management.yaml.gotmpl`'s
`configuration.antivirus` block (the same "read the actual chart, not just
the symptom" approach used for failures #3 and #8).

**Fix (priority 1, helm value) — applied:** flipped `apps.clamavSimple.enabled`
from `false` to `true` in the dev values — openDesk's own upstream default,
not a workaround. No new SCC/manifest was needed: `clamav-simple-0` scheduled
and reached `2/2 Running` under the already-existing `opendesk-anyuid-seccomp`
SCC on the first try. See [Changes row 16](#changes).

**Verified** (applied incrementally to the live namespace with
`helmfile apply -e openshift -n opendesk`, no teardown, per this round's scope):

- `clamav-simple-0` pod `2/2 Running`; `clamav-simple` Service listening on
  `3310/1344/7357`.
- `occ config:list files_antivirus` inside the Nextcloud pod now reports
  `"av_host": "clamav-simple"` (was implicitly `clamav-icap` before).
- `getent hosts clamav-icap` still fails inside the pod (that hostname never
  existed and still doesn't) but `getent hosts clamav-simple` now resolves;
  `curl telnet://clamav-simple:1344` from inside the Nextcloud pod completes a
  TCP connect (previously impossible — the old host didn't resolve at all).
- Zero `ICAP`/`antivirus`/`clamav` log lines and zero HTTP `500`s in the
  Nextcloud pod's logs across the ~20 minutes of cron/background-job activity
  (previews, housekeeping) since the fix landed, versus the reproducible 500
  before it — the same file-write code path that previously errored on every
  invocation is now silent.
- A credentialed WebDAV write to directly force the scan path was considered
  for extra certainty but intentionally not attempted from this session (it
  would require reading the Nextcloud admin password Secret to authenticate,
  crossing a credential-handling boundary for a fix that's already confirmed
  at the config/DNS/TCP layers) — the end-to-end confirmation is a real
  browser SSO login + file-list load by the user.

**Drift check:** this fix touched no `docs/openshift-manifests/` object;
`oc apply --dry-run=server -f docs/openshift-manifests/` still reports
everything `unchanged`.

### 10. Dovecot/Postfix need more capabilities than Collabora's SCC grant covers

**Symptom:** found while planning the OX App Suite/Dovecot/Postfix module
round, *before* the pods were even created — looked this one up proactively
from `docs/security-context.md` rather than waiting for a live
`FailedCreate` event, since the exact same class of failure (hardcoded
`capabilities.add` the existing SCC doesn't allow) was already diagnosed
once for Collabora in [failure #7](#7-collabora-needs-privilege-escalation--extra-capabilities-the-custom-scc-didnt-grant-yet).

**Root cause:** `docs/security-context.md`'s compliance table lists exact
`capabilities` for these charts:

- `open-xchange`/dovecot: `["CHOWN","DAC_OVERRIDE","KILL","NET_BIND_SERVICE","SETGID","SETUID","SYS_CHROOT"]`
- `open-xchange`/postfix-ox: `["CHOWN","DAC_OVERRIDE","FOWNER","SETGID","SETUID","KILL"]`
- `services-external`/postfix (the base SMTP relay release): identical to postfix-ox's list

Confirmed directly in the pulled chart values
(`helmfile/apps/open-xchange/values-dovecot.yaml.gotmpl`,
`helmfile/apps/open-xchange/values-postfix.yaml.gotmpl`,
`helmfile/apps/services-external/values-postfix.yaml.gotmpl`): all three
hardcode `containerSecurityContext.capabilities.add` with these lists (mail
delivery needs to bind port 25/143 as root — both also hardcode
`runAsUser: 0`/`runAsGroup: 0` — then `setuid`/`setgid` down, `chroot` into
the mail spool, and `chown`/`dac_override` maildir files). Our
`opendesk-anyuid-seccomp` SCC (last extended for Collabora in failure #7)
only allowed `[CHOWN, FOWNER, SYS_CHROOT]` — missing `DAC_OVERRIDE`, `KILL`,
`NET_BIND_SERVICE`, `SETGID`, `SETUID` for all three releases.

**Doc used:** this repo's own `docs/security-context.md` (same doc, same
"look up the fix" step as failure #7 — no external lookup needed since
openDesk documents its own hardcoded security contexts exhaustively).

**Fix (priority 1, helm value): none** — same reasoning as failures #2/#7:
these are unconditionally templated by the charts, not exposed as values.

**Fix (priority 2, OpenShift config) — applied:** extended the same
`opendesk-anyuid-seccomp` SCC object again (still one file, still scoped to
`groups: [system:serviceaccounts:opendesk]`) to add `DAC_OVERRIDE`, `KILL`,
`NET_BIND_SERVICE`, `SETGID`, `SETUID` to `allowedCapabilities`, applied
*before* running `helmfile apply` this time (since the exact requirement was
already known from the docs, unlike the reactive fixes in failures #1/#2/#7).
See [Changes row 18](#changes) and
[`docs/openshift-manifests/opendesk-anyuid-seccomp-scc.yaml`](./openshift-manifests/opendesk-anyuid-seccomp-scc.yaml).

**Verified:** all of `dovecot`, `postfix` (base), and `postfix-ox` scheduled
and reached `1/1 Running` on the first attempt — no `FailedCreate`/SCC
denial events for any of the three, confirming the proactive, docs-driven
capability list was complete and correct.

### 11. Cluster runs out of schedulable CPU once OX App Suite's heaviest containers are added

**Symptom:** `helmfile apply` itself finished successfully (all 6 new
releases showed `STATUS: deployed`, no Helm/chart-level error), but `oc get
pods` showed 4 of `open-xchange`'s containers stuck `Pending` with no node
assigned: `open-xchange-core-mw-groupware` (the actual middleware/business-
logic container), `open-xchange-core-imageconverter`,
`open-xchange-core-ui-middleware`, and `open-xchange-core-ui-middleware-updater`.
`oc describe pod` on each showed the same event:

```
Warning  FailedScheduling  default-scheduler  0/3 nodes are available: 3 Insufficient cpu.
no new claims to deallocate, preemption: 0/3 nodes are available: 3 No preemption
victims found for incoming pod.
```

**Root cause:** this is a real, cluster-level resource constraint, not a
Kubernetes config problem. `oc describe node` on all 3 nodes showed **CPU
requests already at 98–99% of allocatable** (`~11.4` of `11.5` cores
committed per node, only ~45–132m free each) from everything already running
on this shared cluster — before even counting the 4 new pods, which
together request `2.5` cores (`openxchangeCoreMW`: `1`, the other 3:
`0.5` each, per `helmfile/environments/default/resources.yaml.gotmpl`).
There was simply no node with enough free *requested* CPU headroom to place
any of them, regardless of `limits` (which stay at the chart-wide `99`/
unbounded convention).

**Considered and reverted:** as an interim mitigation, a `resources:`
override block was drafted in `helmfile/environments/openshift/values.yaml.gotmpl`
trimming just those 4 components' CPU **requests** (not limits) down to
match the sizing openDesk's own lightest UI-tier sidecars already use
(`openxchangeCoreUI`/`-Guidedtours`/`-GuardUI`: `0.01`). This would have
been a legitimate priority-1 helm-value fix (the `resources` map is a plain,
fully-overridable environment value, not chart-templated logic), and was
verified via `helmfile diff` to merge correctly. It was **not applied**: the
cluster was given more CPU capacity externally (nodes' allocatable CPU rose
from `11500m` to `15500m` each — a decision made by the cluster's own
operator, outside this task's scope) while this failure was still being
investigated, which resolved the scheduling problem at the source. The
drafted override was reverted in favor of running with openDesk's own
default, un-trimmed resource requests, since the actual constraint (not
enough real CPU) no longer applies.

**Fix actually applied: none needed.** Once nodes had `15500m` allocatable
CPU each (~8.9/0.76/0.5 cores free per node at that point), all 4 previously-
`Pending` pods scheduled and reached `1/1 Running` on their own — the
Kubernetes scheduler retries `Pending` pods automatically as cluster
capacity changes, no `helmfile`/`oc` re-trigger was needed.

**Related, separately-resolved disruption:** while nodes were still CPU-
constrained, node `ocp22-cp-1` was independently cordoned
(`Ready,SchedulingDisabled`) by something outside this session (not a
command run as part of this task), which evicted several already-`Running`
pods on it (`dovecot`, `ox-connector`, `postfix-ox`,
`open-xchange-core-documentconverter`, the `opendesk-open-xchange-bootstrap`
job pod). Per this task's live-systems-safety constraints, the node was
**not** uncordoned or otherwise touched by this session — it was later
uncordoned externally, at which point every evicted pod rescheduled and
recovered on its own, same as the CPU-capacity resolution above.

**Verified:** `oc get pods -n opendesk` shows 0 `Pending` pods; all of
`open-xchange-core-mw-groupware`/`-imageconverter`/`-ui-middleware`/
`-ui-middleware-updater` are `1/1 Running` (one had a single transient
restart — `exitCode 137` shortly after first scheduling, consistent with the
same "startup-race, self-heals" pattern as other first-boot races — stable
since). `https://webmail.opendesk.apps.../appsuite/` returns `200 OK` with a
real OX App Suite UI shell (correct security headers, session cookie,
gzip'd HTML), confirmed via the [Final state](#final-state) end-to-end sweep
below.

**Drift check:** this fix touched no `docs/openshift-manifests/` object, and
the drafted-then-reverted `resources:` override never reached
`helmfile/environments/openshift/values.yaml.gotmpl`'s committed state — `oc apply
--dry-run=server -f docs/openshift-manifests/` still reports everything
`unchanged`.

## Final state

This state was captured after **three consecutive full teardown + clean-slate
redeploy cycles**, each adding exactly one module and each rebuilt using
*only* the [documented reconstruction path](./openshift-deployment.md#reconstruction) (`oc delete
namespace opendesk`, then `oc create namespace`, `oc apply -f
docs/openshift-manifests/`, `helmfile apply -e openshift -n opendesk` — no ad-hoc
commands): first adding Collabora (surfaced
[failure #7](#7-collabora-needs-privilege-escalation--extra-capabilities-the-custom-scc-didnt-grant-yet)),
then Nextcloud on top of that (surfaced **nothing new**), then OpenProject on
top of both (surfaced
[failure #8](#8-openprojects-db-seed-job-blocks-itself-downloading-its-own-branding-assets-ssrf-guard)).
This is the state after the third cycle, with all three modules present. All
pods in the `opendesk` namespace that are part of the minimal app set (now
including Collabora, Nextcloud, and OpenProject) reached a healthy terminal
state:

| Status | Count | Notes |
| --- | --- | --- |
| `Running` | 33 | All long-lived Deployments/StatefulSets for nubus/UMS, mariadb, postgresql, redis, memcached, seaweedfs, static-files, intercom, collabora, nextcloud-aio/-exporter/-notifypush, and **openproject-web/-worker-default/-hocuspocus** |
| `Completed` | 7 | One-shot Helm hook/CronJob Jobs (keycloak bootstrap, provisioning register-consumers, UDM object-identifier migration, stack-data seed, nextcloud-aio cron, UDM license-cache cronjob run, and **openproject-seeder**) |
| `Error` | 1 | **Stale, superseded pod only** — see below, not a live problem |

The 1 `Error` pod (`ums-stack-data-ums-1-...`) is a first-attempt failure made
while LDAP/UDM were still coming up right after the fresh deploy — the same
transient-startup-race pattern seen on every from-scratch deployment so far
(historically amplified by Option 2a cert-issuance stalls; under BYO it is
just a short LDAP/UDM race). Its Job shows `Complete 1/1` overall once dependencies
were ready; Kubernetes doesn't retroactively delete old failed Pod objects
once a Job succeeds, so it lingers as harmless history — no fix needed, and
expected to recur (and self-heal) on every from-scratch redeploy. This cycle
also hit one more instance of the same class of transient flakiness at the
infra layer: on the first `helmfile apply` attempt, `seaweedfs`'s post-install
bucket-creation hook Job took longer than its `--timeout 300s` (slow
first-time NetApp Trident CSI volume provisioning), so Helm marked the
`seaweedfs` release `failed` even though the underlying Job's retry pod
completed fine seconds later. Re-running the exact same documented
`helmfile apply -e openshift -n opendesk` command (idempotent, not an ad-hoc
one-off) picked the release up as already-satisfied and continued cleanly
through to `openproject` — no manifest/values change was needed for this one,
just a plain retry of the documented command.

End-to-end HTTP checks (against the fresh redeploy, with OpenProject added):

| URL | Result |
| --- | --- |
| `https://portal.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` | `301` → `/univention/portal/` → `200 OK` |
| `https://id.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/realms/opendesk` | `200 OK` (Keycloak) |
| `https://office.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` | `200 OK` (Collabora) |
| `https://files.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` | `302` → Keycloak OIDC `/realms/opendesk/protocol/openid-connect/auth?client_id=opendesk-nextcloud...` → `200 OK` (Nextcloud, full SSO chain via Nubus) |
| `https://projects.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` | `302` → Keycloak OIDC `/realms/opendesk/protocol/openid-connect/auth?client_id=opendesk-openproject...` → `200 OK` (OpenProject, full SSO chain via Nubus) |
| `https://opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` (bare base domain) | `503` — see [Unsolved](#unsolved) |

**Drift check:** `oc apply --dry-run=server -f docs/openshift-manifests/`
reports every object (`opendesk-anyuid-seccomp`, router TLS RBAC, all 14
`opendesk-fix-*` Routes) as `unchanged` — the manifests remain a byte-accurate
snapshot of the live cluster's OpenShift-side config after this redeploy too.

**Conclusion: the two-command reconstruction path in [Reconstruction](./openshift-deployment.md#reconstruction)
is verified to work from a completely empty namespace, three times in a row,
across three independently-added modules** — Nubus/IAM (Keycloak + portal +
UMC), Collabora, Nextcloud, and now OpenProject (each with full Nubus SSO
login) are all up and reachable end-to-end through OpenShift Routes with zero
manual/ad-hoc intervention beyond the SCC capability grant from failure #7 and
the design-seed customization file from failure #8, both of which are
themselves captured as static files and applied/loaded idempotently every
time.

### Addendum: `clamavSimple` fix applied fix-forward (no teardown)

After the above cycle, manual click-through testing of a real user login
surfaced [failure #9](#9-nextclouds-hardcoded-antivirus-integration-has-no-scanner-behind-it)
(Nextcloud's antivirus integration pointing at a nonexistent scanner). Per
this round's scope, that fix (`apps.clamavSimple.enabled: true`) was applied
**incrementally** to the already-running namespace with a plain
`helmfile apply -e openshift -n opendesk` — no `oc delete namespace` this time, since
a full teardown/rebuild is reserved for whenever the next module gets added.
The live namespace picked up the new `clamav-simple` release and the upgraded
`opendesk-nextcloud-management` release cleanly:

| Status | Count | Notes |
| --- | --- | --- |
| `Running` | 34 | Same 33 as the OpenProject cycle above, **plus `clamav-simple-0`** |
| `Completed` | 7 | Unchanged one-shot Helm hook/CronJob Jobs |
| `Error` | 0 | The previously-noted stale `ums-stack-data-ums-1-...` pod has since aged out on its own |

This incremental path hasn't yet been re-validated by a full teardown/rebuild;
that validation will happen naturally the next time a module is added and the
full reconstruction cycle runs again (`apps.clamavSimple.enabled: true` is
already in the reproduced `values.yaml.gotmpl` above, so it's part of that
reconstruction by default going forward).

### Addendum 2: OX App Suite + Dovecot + Postfix, applied fix-forward (no teardown)

Fourth module round: `apps.oxAppSuite`, `apps.dovecot`, and `apps.postfix`
enabled together (see [Minimal app selection](./openshift-deployment.md#current-app-set--hosts)),
applied **incrementally** to the already-running namespace with a plain
`helmfile apply -e openshift -n opendesk`, per this round's explicit scope (same
"fix-forward, no teardown" pattern as the `clamavSimple` addendum above —
full teardown/rebuild validation is deferred to whenever the *next* module
gets added). This was openDesk's heaviest module yet: 6 new Helm releases
(`dovecot`, `postfix`, `postfix-ox`, `open-xchange`,
`opendesk-open-xchange-bootstrap`, `ox-connector`) and ~19 new pods.

Two issues surfaced, documented in full above:

- [Failure #10](#10-dovecotpostfix-need-more-capabilities-than-collaboras-scc-grant-covers) —
  Dovecot/Postfix's hardcoded capabilities weren't yet in the SCC's
  `allowedCapabilities`; looked up proactively from `docs/security-context.md`
  and fixed *before* deploying, so no pod ever actually failed to schedule for
  this reason.
- [Failure #11](#11-cluster-runs-out-of-schedulable-cpu-once-ox-app-suites-heaviest-containers-are-added) —
  the cluster ran out of schedulable CPU once OX App Suite's 4 heaviest
  containers were added on top of everything already running. Diagnosed down
  to exact node CPU-request numbers; a helm-value-only mitigation (trimming
  those 4 components' CPU requests) was drafted and verified viable, but
  turned out unnecessary once the cluster's own operator added real CPU
  capacity, so it was reverted rather than kept as a permanent workaround for
  a transient constraint. A separate, unrelated node cordon/uncordon during
  the same window (not caused by this session) caused some pod churn that
  self-recovered once the node came back — see failure #11 for the timeline.

No new object was added under `docs/openshift-manifests/` for this round —
only the already-existing `opendesk-anyuid-seccomp` SCC file was extended
(same file as failure #7's fix, `oc apply`-idempotent).

| Status | Count | Notes |
| --- | --- | --- |
| `Running` | 49 | Same 34 as the `clamavSimple` addendum, **plus** 11 `open-xchange` appsuite Deployments (core-mw-groupware, core-imageconverter, core-ui, core-ui-middleware, core-ui-middleware-updater, core-user-guide, core-documentconverter, gotenberg, guard-ui, nextcloud-integration-ui, public-sector-ui), plus `dovecot`, `postfix` (base), `postfix-ox`, `ox-connector` |
| `Completed` | 2 | One-shot Jobs mid-cycle at snapshot time (`opendesk-open-xchange-bootstrap`'s job pod and a cron run); count fluctuates run-to-run same as before, not a regression signal |
| `Pending` / `Error` | 0 | Both previously-`Pending` batches (the 4 CPU-starved OX pods, and the cordon-evicted pods) resolved on their own once cluster conditions changed — see failure #11 |

End-to-end HTTP checks (regression sweep of all previously-verified apps,
plus OX App Suite):

| URL | Result |
| --- | --- |
| `https://portal.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` | `200 OK` (direct to `/univention/portal/`) |
| `https://id.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/realms/opendesk` | `200 OK` (Keycloak) |
| `https://portal.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/univention/portal/portal.json` | `200 OK` (UMC) |
| `https://office.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` | `200 OK` (Collabora) |
| `https://files.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` | `302` → `/login` → `/apps/user_oidc/login/1` (Keycloak OIDC chain) → `200 OK` (Nextcloud) |
| `https://projects.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` | `302` → `/login` → `/auth/keycloak` (Keycloak OIDC chain) → `200 OK` (OpenProject) |
| `https://webmail.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/appsuite/` | `200 OK` — real OX App Suite UI shell (correct CSP/security headers, session cookie, gzip'd HTML) **new this round** |

Outbound mail delivery itself (Postfix actually relaying to the public
internet) was **not** tested — per this round's scope, confirming
Postfix/Dovecot pods are healthy and the OX App Suite UI loads is sufficient
for this evaluation deployment; there is no external SMTP relay configured
(`smtp.host` left empty, which is the chart's own supported "direct MX
delivery" mode, not a workaround), and this cluster has no verified path to
send real internet mail from.

**Drift check:** `oc apply --dry-run=server -f docs/openshift-manifests/`
reports every object (`opendesk-anyuid-seccomp` — now with the row-18
capability additions live — router TLS RBAC, all 14 `opendesk-fix-*`
Routes) as `unchanged` — the manifests remain a byte-accurate snapshot of
the live cluster's OpenShift-side config after this round too.

### 12. `core-ui-middleware` self-referencing HTTPS call to fetch `pwa.json` fails TLS verification against the self-signed CA

**Symptom:** reported by a real browser user, not `curl`: opening
`https://webmail.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/appsuite/`
logged, on every load/refresh:

```
Uncaught (in promise) SecurityError: Failed to register a ServiceWorker for scope
('https://webmail.opendesk.apps.…/appsuite/') with script
('https://webmail.opendesk.apps.…/appsuite/service-worker.js'): An SSL
certificate error occurred when fetching the script.
pwa.json:1  Failed to load resource: the server responded with a status of 500
appsuite/:1 Manifest fetch from https://webmail.opendesk.apps.…/appsuite/pwa.json
failed, code 500
```

Two independent symptoms bundled in one report — root-caused separately below.

#### 12a. `pwa.json` 500 — fixed

Reproduced outside the browser: `curl -sk .../appsuite/pwa.json` returned a real
`HTTP/1.1 500 Internal Server Error`, body `{"error": "Failed to load PWA
configuration"}` — not a cert-warning artifact of `-k`, an actual application
error. `oc logs` on the `open-xchange-core-ui-middleware` pod for a
timestamp-correlated request (`curl` immediately followed by
`oc logs --since=2m`) showed the real stack trace:

```
{"level":3,...,"err":{"type":"Error","message":"Backend request failed: unable
to verify the first certificate","stack":"Error: Backend request failed: unable
to verify the first certificate\n    at ClientRequest.<anonymous>
(file:///app/src/server-config.js:50:14)\n    ...",
"url":"https://webmail.opendesk.apps.…/appsuite/api/apps/manifests?action=config"},
"msg":"Failed to load PWA configuration"}
```

**Root cause:** `open-xchange-core-ui-middleware` is a small Node.js service
(a subchart of the vendored `appsuite-public-sector` chart, distinct from the
Java/Tomcat `core-mw-groupware` backend) that builds `pwa.json` by first
fetching `/api/apps/manifests?action=config` from the OX backend. Read
`src/server-config.js` directly out of the running pod (`oc exec ... node -e
"console.log(fs.readFileSync(...))"`) to find its `getBackendUrl()` logic has
an explicit two-step fallback chain: (1) use the `CORE_SERVICE_URL` env var
for a **direct, internal, plain-HTTP** connection if set, or (2) as a "last
resort", construct `https://<the incoming request's own Host header>` and
make a **real outbound HTTPS request back through the public route to
itself**. `values-openxchange.yaml.gotmpl` never sets `coreServiceURL` for
this subchart, so it always took path (2) — an HTTPS round-trip through the
OpenShift router back to its own external hostname, `webmail.opendesk.apps…`.
That connection fails Node.js's own TLS verification ("unable to verify the
first certificate") whenever the Route leaf's CA is **not** in Node's built-in
trust store — first observed under the Option 2a in-cluster CA (archived
[failure #4](#4-certificateselfsigned-true-alone-does-not-make-the-ca-self-signed--cascading-blocker-for-the-whole-nubus-chain)),
and still true under BYO RH Internal CA unless that root is imported into
Node. The Java/Tomcat `core-mw-groupware` container already gets a
`JAVA_OPTS_APPEND -Djavax.net.ssl.trustStore=...` mount of
`opendesk-certificates-ca-tls`; `core-ui-middleware` is a separate Node.js
runtime with no equivalent trust mount, and it doesn't need one once pointed
at the right internal URL (see fix below).
Confirmed the exact same GET (`.../appsuite/api/apps/manifests?action=config`)
succeeds and returns real JSON with `curl -sk` (which skips verification) —
proving the backend itself was healthy the whole time; this was purely an
outbound-TLS-trust bug in the middleware's own client, not a broken
downstream dependency.

**Doc used:** the vendored chart's own source
(`core-ui-middleware/templates/deployment.yaml`'s inline comment for
`CORE_SERVICE_URL`: `"Example: http://core-mw.svc.cluster.local/appsuite"`) —
directly documents the intended direct-connection value, no external lookup
needed once the fallback chain was read from the running pod's own code.

**Fix (priority 1, helm value) — applied:** set `coreServiceURL` to the
in-cluster Service the `/appsuite/api` Route already points at
(`open-xchange-core-mw-http-api`), with `/appsuite` as the base path (the
backend's own dispatcher prefix, confirmed via the `"prefix":"/appsuite/api"`
field already present in the `manifests?action=config` JSON response) so the
Node client never leaves the cluster network — no TLS, no custom-CA trust
store mount needed at all. Used the same `customization.release.
openxchange` extension point as [failure #8](#8-openprojects-db-seed-job-blocks-itself-downloading-its-own-branding-assets-ssrf-guard)
instead of editing the vendored `values-openxchange.yaml.gotmpl`: new file
[`helmfile/environments/openshift/customizations/openxchange-core-ui-middleware-core-service-url-fix.yaml`](../helmfile/environments/openshift/customizations/openxchange-core-ui-middleware-core-service-url-fix.yaml)
setting `appsuite.core-ui-middleware.coreServiceURL:
"http://open-xchange-core-mw-http-api/appsuite"` (the extra `appsuite:`
nesting is required — `core-ui-middleware` is itself a subchart of
`appsuite`, which is a dependency of the `open-xchange` release's actual
chart, `appsuite-public-sector`; a bare top-level `core-ui-middleware:` key
silently no-ops, confirmed empirically with `helm diff upgrade
--reuse-values` before rolling anything out live). See [Changes row
19](#changes).

**How it was rolled out (fix-forward, no teardown, this round):** applied via
`helm upgrade open-xchange ... --reuse-values -f
openxchange-core-ui-middleware-core-service-url-fix.yaml` instead of a plain
`helmfile apply -e openshift -n opendesk`, for one live-safety reason specific to
*this* round: the shell session's `MASTER_PASSWORD` had to be re-exported
after an unrelated mid-session credential expiry (see below), and re-deriving
it from scratch would not reproduce the original passphrase used for this
namespace's first install — `helmfile apply` with a *different*
`MASTER_PASSWORD` would have silently rewritten every `MASTER_PASSWORD`-derived
Secret (MariaDB/Redis/session passwords, etc.) to new values the *actual*
backing services (MariaDB users, etc.) were never told about, breaking
authentication cluster-wide. `helm upgrade --reuse-values` reuses every
already-deployed value and layers only the new customization file on top,
sidestepping that risk entirely. Confirmed via `helm diff upgrade
--reuse-values` first (read-only) that the only *substantive* changes were
the intended `CORE_SERVICE_URL` env var and two harmless, chart-inherent
side effects unrelated to this fix (see **Verified** below) — the same chart,
version, and post-renderer (`post-renderer-openxchange-HAPROXY.sh`) the
original `helmfile apply` would have used were passed explicitly, so the
result is byte-for-byte what a real `helmfile apply -e openshift -n opendesk` (run
with the *correct* original `MASTER_PASSWORD`) would also produce for this
release — this is a live-safety workaround for reapplying to an
already-running revision-1 release with the wrong seed in hand, not a
deviation from the documented reconstruction path itself: a **fresh**
`oc apply -f docs/openshift-manifests/` + `helmfile apply -e openshift -n opendesk`
from an empty namespace (a single consistent `MASTER_PASSWORD` throughout)
reproduces this exact same `appsuite.core-ui-middleware.coreServiceURL` value
correctly on the very first install, no `helm upgrade --reuse-values`
workaround needed.

**Verified:**

- `curl -sk .../appsuite/pwa.json` → `200 OK`, body `{}` (confirmed
  *correct*, not silently-broken, by reading `routes/webmanifest.js`:
  `if (!pwa || pwa.enabled !== 'true') return '{}'` — this evaluation
  deployment never configured the `pwa` capability, so an empty-but-valid
  manifest is the expected response once the backend fetch actually
  succeeds).
- `core-ui-middleware` pod logs show `"msg":"Using CORE_SERVICE_URL for
  backend","url":"http://open-xchange-core-mw-http-api/appsuite"` and zero
  `error`/`fail` log lines in the minutes after the fix landed (previously:
  one `Failed to load PWA configuration` error per request).
- Both `open-xchange-core-mw-groupware` and `open-xchange-core-ui-middleware`
  pods restarted cleanly (`1/1 Running`, triggered by the upgrade's changed
  pod template) with no new `Pending`/`Error`/`CrashLoopBackOff` anywhere in
  the namespace (`oc get pods -n opendesk` — 49 `Running` + 3 `Completed`,
  same shape as before this round).
- **Two incidental, chart-inherent side effects observed in the diff, not
  caused by this fix's actual value change, and not worth reverting:**
  `imagePullSecrets: null → []` on every Deployment in the release (a
  `--reuse-values` YAML-shape no-op — empty list vs. Helm's default null
  render the exact same functional podSpec) and a one-time rotation of the
  `open-xchange-core-mw-secret-envvars` Secret's `CREDSTORAGE_PASSCRYPT`
  field (the chart generates it with a bare, un-seeded `randAlphaNum 32` —
  it would rotate on **any** upgrade of this release, including a correctly
  reproduced `helmfile apply`, not something this fix introduced). All other
  `MASTER_PASSWORD`-derived secret fields (`MASTER_ADMIN_PW`,
  `OX_BASIC_AUTH_PASSWORD`, `JOLOKIA_PASSWORD`, the MariaDB/Redis
  credentials, etc.) were confirmed unchanged byte-for-byte in the
  `helm diff` output before applying anything.

**Drift check:** this fix touched no `docs/openshift-manifests/` object —
`oc apply --dry-run=server -f docs/openshift-manifests/` still reports every
object (`opendesk-anyuid-seccomp`, router TLS RBAC, all 14
`opendesk-fix-*` Routes) `unchanged`.

#### 12b. ServiceWorker registration `SecurityError` — unsolved, see [Unsolved](#unsolved)

The second half of the same browser report (`Failed to register a
ServiceWorker ... An SSL certificate error occurred`) is a *different* bug
class entirely — not an application error, a browser TLS-trust policy. See
the [`core-ui-middleware`'s ServiceWorker requires a browser-trusted TLS
certificate`](#core-ui-middlewares-serviceworker-requires-a-browser-trusted-tls-certificate)
entry under Unsolved for the full root cause and impact assessment.

### Addendum 3: `core-ui-middleware` `pwa.json` fix, applied fix-forward (no teardown)

Prompted by a real end-user browser bug report (not part of the earlier
automated/manual sweeps) against the already-running OX App Suite module
from Addendum 2: `pwa.json` 500ing and a ServiceWorker registration
`SecurityError` in the browser console. Root-caused and fixed as
[failure #12](#12-core-ui-middleware-self-referencing-https-call-to-fetch-pwajson-fails-tls-verification-against-the-self-signed-ca)
(the 500) and documented as [Unsolved](#unsolved) (the ServiceWorker cert
error) above. Applied **incrementally** to the already-running namespace
(`helm upgrade open-xchange ... --reuse-values`, see failure #12 for why
`--reuse-values` was used instead of a plain `helmfile apply` this one time)
— no `oc delete namespace` this round, same "fix-forward" pattern as the
`clamavSimple` and OX App Suite addenda above.

| Status | Count | Notes |
| --- | --- | --- |
| `Running` | 49 | Unchanged from the OX App Suite addendum — this fix only changed two Deployments' pod templates (`open-xchange-core-ui-middleware`, and `open-xchange-core-mw-groupware` picked up a `checksum/allConfig` restart from the incidental `CREDSTORAGE_PASSCRYPT` rotation, see failure #12), no pod count change |
| `Completed` | 3 | One-shot Jobs mid-cycle at snapshot time; count fluctuates run-to-run, not a regression signal (same caveat as every prior round) |
| `Pending` / `Error` | 0 | |

No new object was added under `docs/openshift-manifests/` for this round —
only a new `helmfile/environments/openshift/customizations/*.yaml` file plus its
`customization.release.openxchange` wiring in
`helmfile/environments/openshift/values.yaml.gotmpl` (see [Changes row
19](#changes)), same "Helm value only" category as the OpenProject SSRF fix
in failure #8.

**Drift check:** `oc apply --dry-run=server -f docs/openshift-manifests/`
still reports every object (`opendesk-anyuid-seccomp`, router TLS RBAC,
all 14 `opendesk-fix-*` Routes) `unchanged` — this round touched zero
OpenShift-native objects.


### Addendum 3: Option 1 BYO certs live redeploy (RHCSv2)

Full teardown + recreate with user-provided leaf (`CN=opendesk.apps.ocp22…`,
SANs apex + `*.opendesk.apps…`), Opaque CA secret + keytool-built JKS, router
`externalCertificate` + RBAC. `selfsigned-clusterissuer` removed.

| Check | Result |
| --- | --- |
| TLS issuer on portal/id/files/webmail/projects/office | `CN=2023 Certificate Authority RHCSv2` (not ECME) |
| `portal…/univention/portal/portal.json` | `200` |
| `id…/realms/opendesk` | `200` |
| `webmail…/appsuite/` + `pwa.json` | `200` |
| Helm releases | all `deployed` (~49 Running pods) |

New `MASTER_PASSWORD` / `CERTIFICATES_JKS_PASSWORD` for this rebuild live in
gitignored `helmfile/environments/openshift/.byo-redeploy-secrets` (not printed here).
Portal login user is still `Administrator`; password is in Secret
`ums-stack-data-ums-administrator` (derived from the new master).


### 13. Jitsi pods CrashLoop under `requiredDropCapabilities: [ALL]` + empty `capabilities` (+ missing `SYS_ADMIN` for Jibri)

**Symptom:** after enabling `apps.jitsi` (row 24), `jitsi-web` / `jitsi-prosody` /
`jitsi-jicofo` / `jitsi-jvb-*` entered `CrashLoopBackOff`. Logs:

```
s6-applyuidgid: fatal: unable to set supplementary group list: Operation not permitted
chown(...): Operation not permitted
# after CHOWN/SETGID/SETUID were requested, web still failed with:
nginx: bind() to 0.0.0.0:80 failed (13: Permission denied)
```

**Root cause:** custom SCC `opendesk-anyuid-seccomp` sets
`requiredDropCapabilities: [ALL]`. Under that policy a container only keeps
capabilities listed in both (a) the SCC's `allowedCapabilities` and (b) the
pod's `securityContext.capabilities.add`. openDesk's Jitsi chart values set
`capabilities: {}` (empty object) for web/prosody/jicofo/jvb — so every cap
is dropped. Same class of gap already fixed once for Collabora ([failure
#7](#7-collabora-needs-privilege-escalation--extra-capabilities-the-custom-scc-didnt-grant-yet))
and Dovecot/Postfix ([failure
#10](#10-dovecotpostfix-need-more-capabilities-than-collaboras-scc-grant-covers)),
except those charts already *requested* the caps in their pod templates; Jitsi
did not. The SCC already allowed `CHOWN`/`SETGID`/`SETUID`/`NET_BIND_SERVICE`
from those earlier rounds — pods just never asked for them.

Separately, the Jitsi chart hardcodes `capabilities.add: [SYS_ADMIN]` on
`jitsi.jibri` (Chromium/FFmpeg recording). Chart default is
`jibri.enabled: false` (openDesk only sets `replicaCount`; it never flips
`enabled`), so Jibri is not deployed today — but enabling recording later
would fail admission until `SYS_ADMIN` is on the SCC.

**Doc used:** prior failures #7/#10 in this file; live `oc logs` on CrashLoop
pods; `helm get values jitsi` confirming `jitsi.jibri.enabled: false` and
chart template `templates/jibri/deployment.yaml` gating on that flag.

**Fix (priority 1 + 2) — applied:**

1. Helm customization (no chart edit): new
   [`helmfile/environments/openshift/customizations/jitsi-capabilities-fix.yaml`](../helmfile/environments/openshift/customizations/jitsi-capabilities-fix.yaml)
   requesting `CHOWN`/`SETGID`/`SETUID` on web/prosody/jicofo/jvb and
   `NET_BIND_SERVICE` on web, wired via
   `customization.release.jitsi.capabilitiesFix` in
   `helmfile/environments/openshift/values.yaml.gotmpl`. See [Changes row 25](#changes).
2. SCC extension: add `SYS_ADMIN` to `allowedCapabilities` in
   [`docs/openshift-manifests/opendesk-anyuid-seccomp-scc.yaml`](openshift-manifests/opendesk-anyuid-seccomp-scc.yaml)
   and `oc apply -f` it. See [Changes row 26](#changes).

**Rollout notes:** `helmfile apply -l name=jitsi` hung for minutes on
`helm-diff` against large binary ConfigMaps in the Jitsi chart; the upgrade
still completed (revision 2 landed mid-diff). A follow-up
`helm upgrade --reuse-values -f jitsi-capabilities-fix.yaml` persisted
`NET_BIND_SERVICE` as revision 3. StatefulSet `jitsi-prosody` needed an
explicit `oc delete pod jitsi-prosody-0` to pick up the new pod template
(old CrashLoop pod kept `capabilities.drop: [ALL]` only).

**Verify:** web/prosody/jicofo/jvb/keycloak-adapter all `1/1 Running`;
`curl -sk https://meet.opendesk.apps…/` → `200` (was `503` while CrashLooping).
Jibri not deployed (`enabled: false`) — no further privileged /
`allowPrivilegeEscalation` change needed.


### 14. Jitsi Prosody TLS certs missing without `DAC_OVERRIDE` → XMPP auth fails (join stuck)

**Symptom:** after failure #13 (pods `1/1 Running`, meet UI loads), joining a
conference stalls after the start screen. Prosody logs
`No TLS context available for c2s` / cannot load private keys; Jicofo loops on
`No stream features to proceed with`; JVB never authenticates to the brewery.

**Root cause:** Prosody image cont-init does
`mv /config/data/*.{crt,key} /config/certs/ || true`. Generated keys are mode
`0400` owned by `prosody`. With SCC `requiredDropCapabilities: [ALL]`, the
container only keeps caps in `securityContext.capabilities.add`. Failure #13
requested `CHOWN`/`SETGID`/`SETUID` (enough for s6) but **not** `DAC_OVERRIDE`,
so root cannot read those keys → `mv` effectively leaves `/config/certs`
empty → no c2s TLS. SCC already allowed `DAC_OVERRIDE` from the Dovecot/Postfix
round ([failure #10](#10-dovecotpostfix-need-more-capabilities-than-collaboras-scc-grant-covers));
prosody just never asked for it.

**Doc used:** live `oc logs jitsi-prosody-0` / `jitsi-jicofo-*` / `jitsi-jvb-*`;
`oc exec` listing `/config/certs` before/after; prior failure #13 capability
pattern.

**Fix — applied:** add `DAC_OVERRIDE` to `jitsi.prosody.securityContext.capabilities.add`
in
[`helmfile/environments/openshift/customizations/jitsi-capabilities-fix.yaml`](../helmfile/environments/openshift/customizations/jitsi-capabilities-fix.yaml)
(same file as row 25). No SCC change. See [Changes row 27](#changes).

**Rollout notes:** prefer
`helm upgrade --reuse-values -f helmfile/environments/openshift/customizations/jitsi-capabilities-fix.yaml jitsi -n opendesk`
against the cached chart under `~/.cache/helmfile/jitsi-repo/...` (revision 4);
`helmfile apply -l name=jitsi` still risks hanging on huge helm-diff. Then
`oc delete pod jitsi-prosody-0` so cont-init re-runs; bounce jicofo/jvb if they
were stuck pre-TLS.

**Verify (live):** `/config/certs/` contains `meet.jitsi.{crt,key}` and
`auth.meet.jitsi.{crt,key}`; Prosody `Certificates loaded` / `Authenticated as
focus@auth.meet.jitsi` / `jvb@auth.meet.jitsi`; Jicofo
`Registered` + `Joined the room` (jvbbrewery); JVB `Authenticated` +
`Joined MUC: jvbbrewery@internal-muc.meet.jitsi`. No recent
`No TLS context available for c2s`.

**Remaining risk (media, not XMPP):** addressed in [failure 16](#16-jitsi-meet-audio--no-media-ice-unreachable-jvb-candidates)
(NodePort + advertise IP). This capability fix only covers XMPP/TLS join.

### 15. Intercom ↔ XWiki OIDC `invalid_redirect_uri` (ICS callback missing from `opendesk-xwiki` allowlist)

**Symptom:** Keycloak logs `LOGIN_ERROR` for `clientId="opendesk-xwiki"` with
`error="invalid_redirect_uri"` and
`redirect_uri="https://ics.<domain>/oidc/authenticator/callback"`. Intercom
then logs `Error fetching OIDC token for opendesk-xwiki` (and sometimes
follow-on token-refresh / missing `opendesk_username` noise while the silent
login path cannot complete).

**Root cause:** `opendesk-keycloak-bootstrap` registers `opendesk-xwiki` with
Valid Redirect URIs for `wiki.*` and `portal.*` only
(`helmfile/apps/nubus/values-opendesk-keycloak-bootstrap.yaml.gotmpl`). Portal
newsfeed / ICS talks to XWiki through the Intercom host (`ics.*`), so the OIDC
code flow presents the ICS-hosted XWiki callback path. That URI was never on
the client allowlist. Live `kcadm` before the fix:

```text
redirectUris: [ "https://wiki.<domain>/*", "https://portal.<domain>/*" ]
```

**Fix (durable, no chart edit):** openDesk `customization.release.opendeskKeycloakBootstrap`
extra values file that replaces `config.opendesk.clients.opendesk-xwiki.redirectUris`
with the upstream pair plus the ICS callback (Helm list merge replaces the whole
array). Wired from `helmfile/environments/openshift/values.yaml.gotmpl`. See
[Changes row 28](#changes).

**Apply (live):** `helmfile apply -e openshift -n opendesk -l name=opendesk-keycloak-bootstrap`
(revision 3; Job `opendesk-keycloak-bootstrap-bootstrap-3` Completed). Short-term
Admin API / `kcadm` patch of the same URIs was used to unblock before the Job
finished; bootstrap re-applied the same allowlist from the Secret.

**Verify:**

- Client allowlist includes
  `https://ics.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/oidc/authenticator/callback`
  (and matching `webOrigins` entry for `https://ics...`).
- Auth probe with that `redirect_uri` → HTTP 200 Keycloak login page; bogus
  `https://evil.example/callback` → HTTP 400.
- No further Keycloak `invalid_redirect_uri` for the ICS callback after the
  patch (only the deliberate evil probe).

**Remaining Intercom noise (out of scope for this allowlist fix):** expired ICS
access_token refresh / `No claim opendesk_username found in the id_token` /
occasional `Compact JWS must be a string` when a stale XWiki token is empty —
re-check after users re-login through ICS; not caused by missing redirect URI
once the allowlist is correct.

### 16. Jitsi Meet audio / no media (ICE unreachable JVB candidates)

**Symptom:** join/XMPP works (Prosody auth, Jicofo room, JVB brewery). After ~18s
clients ICE-restart / session-terminate; no audio/video. Room evidence:
`FinancialLeftsWasteFerociously`.

**Root cause:** JVB advertised unreachable ICE candidates
(`JVB_ADVERTISE_IPS=0.0.0.0`, pod IP, bad srflx). `jitsi-jvb` Service was
**ClusterIP UDP/10000 only**. OpenShift Routes are TCP-only (cannot carry RTP).
`TURN_HOST`/`TURNS_HOST` empty (no external TURN). `patchJVB` Job had empty
`ingressGatewayIP` / never patched advertise IP for NodePort. NetworkPolicy not
the blocker.

**Doc used:** `docs/getting-started.md` TURN section (external TURN only — no
in-cluster coturn wiring in openDesk helmfile); opendesk-jitsi `patchJVB` +
jitsi-meet chart NodePort option; live `oc`/`helm get values`.

**Fix strategy chosen: B** (JVB NodePort + advertise node IP). Skipped A
(chart coturn exists under jitsi-meet but openDesk does not enable it; coturn
still needs reachable UDP + relay port range — heavier than one JVB NodePort).
Skipped C (no existing external TURN on this network to wire).

**Fix — applied:**

1. `service.type.jitsiVideoBridge: NodePort` and
   `cluster.networking.ingressGatewayIP: "10.32.105.193"` in
   [`helmfile/environments/openshift/values.yaml.gotmpl`](../helmfile/environments/openshift/values.yaml.gotmpl).
2. Pin `jitsi.jvb.nodePort: 31000` via
   [`jitsi-media-nodeport-fix.yaml`](../helmfile/environments/openshift/customizations/jitsi-media-nodeport-fix.yaml)
   + `customization.release.jitsi.mediaNodePortFix`.
3. Live: targeted `helm upgrade` (revision 5) with those sets + existing
   capabilities fix file — avoid full `helmfile apply -l name=jitsi` helm-diff
   hang. Chart `patchJVB` post-upgrade hook set `JVB_ADVERTISE_IPS`, remapped
   `JVB_PORT`/Service `targetPort` to the NodePort, restarted JVB.

**Clients must reach:** `10.32.105.193:31000/UDP` (NodePort also on
`10.32.105.194` / `.195`). Firewall must allow that UDP path.

**Verify (live):**

- `svc/jitsi-jvb` type `NodePort`, `nodePort=31000`, `targetPort=31000`.
- Deploy env: `JVB_ADVERTISE_IPS=10.32.105.193`, `JVB_PORT=31000`.
- JVB logs: `StaticMapping(... publicAddress=10.32.105.193 ...)`,
  `SinglePortUdpHarvester ... :31000/udp`, XMPP `Authenticated` +
  `Joined MUC: jvbbrewery@...`.
- UDP send to `10.32.105.193:31000` from corp LAN host succeeds (datagram send).

**Residual risk:** advertise IP is private corp LAN (`10.32.105.0/24`). Browsers
off that network (no VPN) still cannot ICE to JVB without a public LoadBalancer
or real TURN (`turn.*` in getting-started). STUN may still publish an extra
public srflx that is not a working JVB path — on-LAN clients should use the
static `10.32.105.193:31000` candidate. No hostPort / SCC change (hostPorts
denied on `opendesk-anyuid-seccomp`).

### 17. OX App Suite path rewrites ignored on OpenShift → Guard “encryption server unreachable”

**Symptom:** Webmail shows *„Verschlüsselungsserver kann nicht kontaktiert
werden“* (OX Guard). External probe:

```text
curl -sk -o /dev/null -w '%{http_code}' \
  https://webmail.opendesk.apps.../appsuite/api/oxguard/login?action=status
→ 404
```

Sibling public paths that the chart rewrites the same way also 404'd:
`/appsuite/ui`, `/appsuite/help`, `/appsuite/rt2`, `/ajax`, `/api`, `/pks`,
`/appsuite/api/guardsupport`, `/appsuite/office`, and DAV root on `dav.*`.

**Root cause:** OX chart stamps `nginx.ingress.kubernetes.io/rewrite-target` and
`haproxy-ingress.github.io/config-backend: replace-path …` on each path Ingress.
OpenShift's Ingress→Route converter **does** create a Route per Prefix rule and
**does** copy those annotations onto the Route — but the OpenShift HAProxy router
**ignores** nginx/haproxy-ingress annotations. Without
`haproxy.router.openshift.io/rewrite-target`, the backend still sees the public
path (`/appsuite/api/oxguard/...`) while Guard listens on `/oxguard/...`.

In-cluster evidence: `http://open-xchange-core-mw-http-api/oxguard/login?action=status`
→ `500 unknown action` (reachable); same URL under `/appsuite/api/oxguard/...` →
`404`. Annotating only the Route is **not** durable — the Ingress controller
reconciles Route annotations from the Ingress and wipes manual Route edits.

**Doc used:** [OKD route rewrite-target](https://docs.okd.io/latest/networking/ingress_load_balancing/routes/nw-configuring-routes.html)
(path prefix replaced by annotation value; no regex captures); openDesk
`annotations.openxchangeAppsuiteIngress.*` hooks in
`helmfile/environments/default/annotations.yaml.gotmpl` /
`values-openxchange.yaml.gotmpl`.

**Fix (priority 1, helm values):**

1. Set OpenShift rewrite on each Ingress via
   `annotations.openxchangeAppsuiteIngress.{guardApiRoute,guardSupportApiRoute,guardPgpRoute,coreUiApiRoute,coreHelpRoute,rt2Route,httpApiRoutesApi,httpApiRoutesAjax,officeWebRoute,davRootRoute}`
   in [`values.yaml.gotmpl`](../helmfile/environments/openshift/values.yaml.gotmpl).
2. Same keys under chart path `appsuite.ingress.routes.*.annotations` in
   [`openxchange-openshift-rewrite-fix.yaml`](../helmfile/environments/openshift/customizations/openxchange-openshift-rewrite-fix.yaml)
   + `customization.release.openxchange.openshiftRewriteFix` (for targeted
   `helm upgrade --reuse-values -f` when helmfile/helm-diff hangs — same pattern
   as failure #16).
3. Live: Ingress annotated, then `helm upgrade open-xchange` rev 5 with the
   customization file **and**
   `--post-renderer helmfile/apps/open-xchange/post-renderer-openxchange-HAPROXY.sh`
   (strips chart `(.*)` regex suffixes to `pathType: Prefix` — required when
   bypassing helmfile; rev 4 without the post-renderer broke Route matching).
   Cleared prior failed rev 3 (`context canceled`).

**Note:** chart nginx rewrite for UI targets `/ui`, but this `core-ui` image
serves the SPA at `/` — OpenShift rewrite uses `/` (verified in-cluster).

**Verify:**

```text
curl -sk -o /dev/null -w '%{http_code}' \
  https://webmail.../appsuite/api/oxguard/login?action=status
→ 500 unknown action   # not 404; Guard reached (no session)
# also: /appsuite/ui → 200; /ajax/login?action=login → 200; /pks/ → 406 GRD-CORE-0002
```

**Ingress↔Route audit (esp. Exact / “direct”):** every OX Prefix Ingress has a
matching Route. Remaining Exact Ingresses without a same-path Route are either
already fixed by `opendesk-fix-univention-routes.yaml` (row 11) or fall through
to portal `/` (301 to `/univention/portal/` — curl-checked). No new static Routes
required for this failure. Bare `opendesk.apps.../` redirect stays [Unsolved](#unsolved).

## Unsolved

### `core-ui-middleware`'s ServiceWorker requires a browser-trusted TLS certificate

Every page load of `https://webmail.opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/appsuite/`
may still log a browser-console `SecurityError` failing to register
`.../appsuite/service-worker.js` **if** the client does not trust the serving
CA — there is no helm/OpenShift-config-only fix for untrusted clients.

**After Option 1 migration:** the leaf is issued by `CN=2023 Certificate Authority
RHCSv2` (Red Hat Internal PKI), not the old ECME self-signed CA. On machines
that already trust **Red Hat Internal Root CA**, ServiceWorker registration
should succeed without click-through. On clients without that root (personal
browsers, non-corp laptops), the same stricter ServiceWorker trust check
still fails until the Internal Root is imported — same category as before,
different CA.

- Chromium enforces a **stricter** TLS-trust requirement for `ServiceWorker`
  registration than for ordinary page loads: click-through does not add the
  CA to the real trust store.
- **Impact:** cosmetic/convenience only for OX App Suite mail/calendar (the
  ServiceWorker excludes `/appsuite/api/*`). Not a functional SSO blocker.
- **Workaround:** use a client that trusts RH Internal Root, or import
  `helmfile/environments/openshift/certs/ca.crt` into the OS/browser trust store.

### `opendesk-home`'s bare base-domain → portal redirect

`https://opendesk.apps.ocp22.stormshift.coe.muc.redhat.com/` (no `portal.` subdomain)
returns `503` and there is no helm/OpenShift-config-only fix.

- The `opendesk-home` chart's `opendesk-home-basedomain` Ingress rule points at a
  service named `opendesk-home-dummy`, but **that Service does not exist** —
  `oc get svc opendesk-home-dummy -n opendesk` → `NotFound`. It's a placeholder
  target: the chart relies entirely on ingress-controller-specific annotations
  (`haproxy-ingress.github.io/redirect-to`, `nginx.ingress.kubernetes.io/temporal-redirect`)
  to make the *ingress controller itself* issue the HTTP redirect before ever
  proxying to a backend. Real haproxy-ingress/ingress-nginx deployments never
  actually route traffic to the dummy service.
- OpenShift's router (HAProuter) understands neither annotation, and (per
  failure #5) this rule is also `pathType: Exact` so it never gets a Route in the
  first place — and even if it did, there's a nonexistent backend behind it.
- OpenShift Routes have no native "3xx-redirect-to-a-different-host" primitive
  per-Route (`insecureEdgeTerminationPolicy: Redirect` only handles HTTP→HTTPS on
  the *same* host). The only way to replicate this annotation-driven redirect
  behaviour is to customize the cluster's shared HAProxy router template
  (`oc edit configmaps/router-template -n openshift-ingress` or a custom
  `IngressController` with a custom template) — a cluster-wide change affecting
  every other tenant's routes on this shared multi-tenant cluster, explicitly out
  of bounds per the task's safety constraints.
- **Tried:** pointing a Route directly at a real backend was considered and
  rejected — it would silently serve portal/other content at the wrong hostname
  rather than actually redirecting, changing app behaviour rather than fixing
  infrastructure, which risks masking Origin/CSRF-sensitive redirects the app
  relies on.
- **Impact:** cosmetic only. `https://portal.opendesk.apps.../` (the real,
  documented entry point) works fully; only the convenience redirect from the
  bare apps domain is unavailable.
