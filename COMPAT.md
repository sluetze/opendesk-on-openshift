# Overlay compatibility: v1.18.2 / v1.19.0 / v1.19.1

Cheap delta across overlay trees. Apply each onto its **own** upstream tag.

| Area | v1.18.2 | v1.19.0 | v1.19.1 |
| --- | --- | --- | --- |
| Upstream | `v1.18.2` `eab2ee77` | `v1.19.0` `1aacb0dd` | `v1.19.1` `6c41d8e8` |
| helmfile env `openshift` | yes (bases patch) | yes | yes (structural) |
| migrations CA volume mounts | yes | yes | *not yet* — add only if proven |
| default helm timeouts (element / seaweedfs) | unchanged | 2400s each | *not yet* |
| `trust.secret.mount` + name | not set | BYO CA Secret mount | yes (values) |
| Matrix `technical.matrix.migration` | (defaults) | `enabled: false` | *not yet* |
| Synapse `existingClaim` | unset | site PVC | *not yet* |
| SCC | anyuid+seccomp | tightened caps | thin `opendesk-uid-seccomp` (anyuid+seccomp+seLinux RunAsAny; **no** extra caps) |
| Route / rewrite customizations | full set | full set | *deferred* until Exact/rewrite fails |
| customizations/*.yaml | full set | full set | empty until proven |

`diff -ru v1.19.0 v1.19.1` for the rest.
