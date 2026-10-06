# openDesk on OpenShift (overlay-only)

This branch is **not** a full openDesk tree. It holds OpenShift overlay files
versioned as `v1.18.2/` and `v1.19.0/`. Apply them onto a **vanilla** openDesk
checkout of the matching upstream tag.

Full charts, helmfile bases, and app source live upstream:

https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git

## Apply (v1.19.0)

```bash
git clone --branch v1.19.0 \
  git@gitlab.opencode.de:bmi/opendesk/deployment/opendesk.git opendesk
# Prefer the SHA in v1.19.0/UPSTREAM if your local v1.19.0 tag was moved.

OVERLAY=/path/to/this/overlay/v1.19.0
cd opendesk
cp -a "$OVERLAY/helmfile/environments/openshift" helmfile/environments/
git apply "$OVERLAY/helmfile/patches/"*.patch
cp -a "$OVERLAY/docs/"openshift-*.md "$OVERLAY/docs/openshift-legacy-selfsigned-ca" \
  "$OVERLAY/docs/openshift-manifests" docs/
# fill helmfile/environments/openshift/values.yaml.gotmpl + BYO certs (gitignored)
helmfile apply -e openshift
oc apply -k docs/openshift-manifests/overlays/example
```

Same recipe with `v1.18.2/` and `--branch v1.18.2`.

Fill site knobs (domain, StorageClass, IngressClass, JVB) before apply.
See `v1.19.0/docs/openshift-deployment.md`. Do not commit PEMs, keys, JKS,
`.kubeconfig`, or `.byo-redeploy-secrets`.

## Diff v1.18.2 vs v1.19.0

From this overlay repo:

```bash
diff -ru v1.18.2 v1.19.0
# or
git diff --no-index v1.18.2 v1.19.0
```

Short delta: `COMPAT.md`.
