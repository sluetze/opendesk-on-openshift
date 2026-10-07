# openDesk 1.19.1 on OpenShift — failures log

Do **not** assume 1.18.2 / 1.19.0 failures still apply. Classify each new failure:

| Class | Meaning |
| --- | --- |
| **OpenShift** | SCC, Ingress→Route Exact drop, rewrite-target, UID ranges, seccomp, … |
| **Environment** | LoadBalancer/NodePort/TURN/UDP, CPU, timeouts, storage class, DNS, client trust |

## Policy (1.19.1)

Do **not** reuse `opendesk-anyuid-seccomp` from 1.18.2/1.19.0. Start on
default `restricted-v2`. If pods fail SCC admission, classify as **OpenShift**,
gather evidence, prefer a minimal new fix — do not re-apply the old fat SCC.

## 1.19.1 deploy log

| # | Class | Symptom | Status | Fix (only if proven) |
| --- | --- | --- | --- | --- |
| — | — | (deploy started; custom SCC deleted) | in progress | — |

