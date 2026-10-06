# OpenShift overlay for openDesk v1.18.2

Upstream pin: `UPSTREAM` (GitLab tag `v1.18.2` /
`eab2ee774187308f82307f0daaf1471dfe560f34`).

## Apply onto vanilla openDesk

```bash
git clone --branch v1.18.2 \
  git@gitlab.opencode.de:bmi/opendesk/deployment/opendesk.git opendesk
cd opendesk

OVERLAY=/path/to/overlay/v1.18.2
cp -a "$OVERLAY/helmfile/environments/openshift" helmfile/environments/
git apply "$OVERLAY/helmfile/patches/"*.patch
cp -a "$OVERLAY/docs/"openshift-*.md "$OVERLAY/docs/openshift-legacy-selfsigned-ca" \
  "$OVERLAY/docs/openshift-manifests" docs/

helmfile apply -e openshift
oc apply -k docs/openshift-manifests/overlays/example
```

Patches vs upstream: register `openshift` env, migrations CA mounts, gitignore
for certs. No default `deployment.yaml.gotmpl` timeout bump on this tag
(that landed in v1.19.0).
