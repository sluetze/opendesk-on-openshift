# OpenShift overlay for openDesk v1.19.1

Upstream pin: `UPSTREAM` (GitLab tag `v1.19.1` /
`6c41d8e898490915ca4f11792170aa750a2c4877`).

Workarounds are added **only after proven** on a fresh 1.19.1 deploy.
v1.19.0 files are structural baselines, not assumed still required.

## Apply onto vanilla openDesk

```bash
git clone --branch v1.19.1 \
  git@gitlab.opencode.de:bmi/opendesk/deployment/opendesk.git opendesk
cd opendesk

OVERLAY=/path/to/overlay/v1.19.1
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

No custom SCC in this tree — OpenShift default `restricted-v2` only.
Site values: `helmfile/environments/openshift/values.yaml.gotmpl`.
