# Overlay compatibility: v1.18.2 vs v1.19.0

Cheap delta from the two overlay trees. Apply each onto its **own** upstream tag.

| Area | v1.18.2 | v1.19.0 |
| --- | --- | --- |
| Upstream | `v1.18.2` `eab2ee77` | `v1.19.0` `1aacb0dd` |
| helmfile env `openshift` | yes (bases patch) | yes |
| migrations CA volume mounts | yes | yes |
| `migrations.objectStore.caBundle` in overlay values | yes | yes |
| default helm timeouts (element / seaweedfs) | unchanged | 2400s each (patch) |
| `trust.secret.mount` + name | not set | BYO CA Secret mount |
| Matrix `technical.matrix.migration` | (defaults) | `enabled: false`, `dryRun: true` |
| Synapse `persistence.storages.synapse.existingClaim` | unset | `media-opendesk-synapse-0` (site) |
| SCC `allowPrivilegeEscalation` | true (Collabora 1.18) | false |
| SCC extra caps | FOWNER, KILL, SYS_CHROOT | dropped; keep Jitsi set |
| SCC `seLinuxContext` | MustRunAs | RunAsAny (empty `seLinuxOptions`) |
| customizations/*.yaml | same set of files | same set |

`diff -ru v1.18.2 v1.19.0` for the rest (docs, example overlay values).
