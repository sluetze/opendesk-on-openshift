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
| 3 | Environment / app | `matrix-neodatefix-bot` CrashLoop: `M_UNKNOWN_TOKEN` / Token is not active | open | Matrix token/bootstrap; not SCC |
| 4 | Environment / app | `ums-stack-data-ums-1` pod Error (Job later Complete): UDM DELETE 500 on ox accessprofile | mitigated | Job completed on retry; stale Error pod left |

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
runs).

**Class:** Environment / app bootstrap (Matrix access token inactive or race with
MAS/Synapse). Not OpenShift-specific.

### 4. ums-stack-data-ums Job pod Error then Complete

**Evidence:** first pod failed with UDM REST `DELETE .../oxmail/accessprofile/...`
→ HTTP 500 (`super(type, obj): obj must be an instance or subtype of type`).
Job `ums-stack-data-ums-1` later `Complete 1/1`; stale Error pod remains.

**Class:** app/UDM (not OpenShift). No overlay fix required if Job Complete.
