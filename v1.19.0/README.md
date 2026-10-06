# OpenShift overlay for openDesk v1.19.0

Upstream pin: `UPSTREAM` (GitLab tag `v1.19.0` /
`1aacb0ddbfbcdc86f24ec9a847313016b8d95432`).

## Apply onto vanilla openDesk

```bash
git clone --branch v1.19.0 \
  git@gitlab.opencode.de:bmi/opendesk/deployment/opendesk.git opendesk
cd opendesk
# If the tag was moved locally: git checkout 1aacb0ddbfbcdc86f24ec9a847313016b8d95432

OVERLAY=/path/to/overlay/v1.19.0
cp -a "$OVERLAY/helmfile/environments/openshift" helmfile/environments/
git apply "$OVERLAY/helmfile/patches/"*.patch
cp -a "$OVERLAY/docs/"openshift-*.md "$OVERLAY/docs/openshift-legacy-selfsigned-ca" \
  "$OVERLAY/docs/openshift-manifests" docs/

# BYO TLS under helmfile/environments/openshift/certs/ (tls-fullchain.crt, tls.key, ca.crt)
helmfile apply -e openshift
oc apply -k docs/openshift-manifests/overlays/example
```

Patches vs upstream (OpenShift workarounds only):

| Patch | Why |
| --- | --- |
| `helmfile-bases-environments.yaml.gotmpl.patch` | register `openshift` helmfile env |
| `opendesk-migrations-*-values.yaml.gotmpl.patch` | mount BYO CA into migrations jobs |
| `helmfile-environments-default-deployment.yaml.gotmpl.patch` | Element + SeaweedFS helm timeouts (ocp22) |
| `gitignore.patch` | ignore overlay certs / kubeconfig / PEMs |

Site values: `helmfile/environments/openshift/values.yaml.gotmpl`.
Contract: `CURSOR.MD`. Failures: `docs/openshift-errors.md`.
