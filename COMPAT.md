# Overlay compatibility: v1.18.2 / v1.19.0 / v1.19.1 / v1.20.4

Cheap delta across overlay trees. Apply each onto its **own** upstream tag.
Same area config → same cell text. Proven-without → `removed` (not `*not yet*`).

| Area | v1.18.2 | v1.19.0 | v1.19.1 | v1.20.4 |
| --- | --- | --- | --- | --- |
| Upstream | `v1.18.2` `eab2ee77` | `v1.19.0` `1aacb0dd` | `v1.19.1` `6c41d8e8` | `v1.20.4` `efe67d43` |
| helmfile env `openshift` | yes (bases patch) | yes (bases patch) | yes (bases patch) | yes (bases patch) |
| migrations CA volume mounts | yes | yes | removed | removed |
| default helm timeouts (element / seaweedfs) | unchanged | 2400s each | removed | removed |
| `trust.secret.mount` + name | not set | BYO CA Secret mount | yes (values) | yes (values) |
| Matrix `technical.matrix.migration` | (defaults) | `enabled: false` | removed | removed |
| Synapse `existingClaim` | unset | site PVC | removed | removed |
| SCC | anyuid+seccomp | tightened caps | thin `opendesk-uid-seccomp` (anyuid+seccomp+seLinux RunAsAny; **no** extra caps) | thin `opendesk-uid-seccomp` (anyuid+seccomp+seLinux RunAsAny; **no** extra caps) |
| Route / rewrite customizations | full set | full set | Exact fix Routes + router TLS RBAC | Exact fix Routes + router TLS RBAC |
| customizations/*.yaml | full set | full set | clamav CA, KC ICS, xwiki logout | clamav CA, KC ICS, xwiki logout |

`diff -ru v1.19.1 v1.20.4` for the rest.
