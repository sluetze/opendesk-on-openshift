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
| 2 | Environment | `clamav-simple-0` CrashLoop: freshclam SSL verify fail to gitlab.opencode.de CVD mirror | open | BYO CA mounted over `/etc/ssl/certs/ca-certificates.crt` — see below |
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

**Root cause:** with Option 1 BYO + `certificate.selfSigned: true`, the chart
mounts Secret `opendesk-certificates-ca-tls` key `ca.crt` onto
`/etc/ssl/certs/ca-certificates.crt` (subPath). That **replaces** the image's
system CA bundle with only the site RH Internal CA. freshclam then cannot verify
gitlab.opencode.de's public cert. Same CVD URL returns HTTP 200 from
`opendesk-static-files` (full system trust intact) — so not a network/DNS outage.

**Class:** Environment / BYO trust-mount side effect (not OpenShift SCC). Would
hit any cluster using the same private-CA-as-system-bundle pattern on a fresh
empty clamav PVC.

**Fix candidates (not applied yet):** ship a concatenated trust bundle
(public roots + RH CA) in `ca.crt`; or pre-seed the clamav PVC with CVD files;
or chart-level opt-out of trust mount for clamav if upstream adds one.

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
