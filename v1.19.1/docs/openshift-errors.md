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
| 1 | OpenShift | `opendesk-migrations-pre` Job: `restricted-v2` rejects `runAsUser`/`fsGroup` 1000; empty `seLinuxOptions.level`; stock `anyuid` would also reject explicit `seccompProfile` | fixed (thin SCC) | `opendesk-uid-seccomp` = anyuid + `seccompProfiles: [runtime/default]` + `seLinuxContext: RunAsAny`. No extra capabilities. |

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
