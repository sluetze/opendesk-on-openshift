# OpenShift overlay for openDesk v1.20.4

Upstream pin: `UPSTREAM` (GitLab tag `v1.20.4` /
`efe67d43d2bdb47a985ada4b4ae8c87bf66a57c8`).

Workarounds are added **only after proven** on a fresh 1.20.4 deploy.
Copied from v1.19.1 (path a); keep until re-proven or dropped.

## Apply onto vanilla openDesk

```bash
git clone --branch v1.20.4 \
  git@gitlab.opencode.de:bmi/opendesk/deployment/opendesk.git opendesk
cd opendesk

OVERLAY=/path/to/overlay/v1.20.4
cp -a "$OVERLAY/helmfile/environments/openshift" helmfile/environments/
git apply "$OVERLAY/helmfile/patches/"*.patch
cp -a "$OVERLAY/docs/"openshift-*.md \
  "$OVERLAY/docs/openshift-manifests" docs/

# BYO TLS under helmfile/environments/openshift/certs/
helmfile apply -e openshift -n opendesk
oc apply -k docs/openshift-manifests/overlays/example
```

Patches vs upstream (grow as proven):

| Patch | Why |
| --- | --- |
| `helmfile-bases-environments.yaml.gotmpl.patch` | register `openshift` helmfile env |
| `gitignore.patch` | ignore overlay certs / kubeconfig / PEMs |

Site values: `helmfile/environments/openshift/values.yaml.gotmpl`.
Thin SCC + fix Routes + CA inject: see `docs/openshift-manifests/` and
`docs/openshift-errors.md`.
