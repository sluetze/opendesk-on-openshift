# openDesk on OpenShift (overlay-only)

This branch is **not** a full openDesk tree. It holds OpenShift overlay files
versioned as `v1.18.2/`, `v1.19.0/`, and `v1.19.1/`. Apply them onto a
**vanilla** openDesk checkout of the matching upstream tag.

Full charts, helmfile bases, and app source live upstream:

https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git

## Apply (v1.19.1)

```bash
git clone --branch v1.19.1 \
  git@gitlab.opencode.de:bmi/opendesk/deployment/opendesk.git opendesk
# Prefer the SHA in v1.19.1/UPSTREAM.

OVERLAY=/path/to/this/overlay/v1.19.1
cd opendesk
cp -a "$OVERLAY/helmfile/environments/openshift" helmfile/environments/
git apply "$OVERLAY/helmfile/patches/"*.patch
cp -a "$OVERLAY/docs/"openshift-*.md "$OVERLAY/docs/openshift-manifests" docs/
# fill helmfile/environments/openshift/values.yaml.gotmpl + BYO certs (gitignored)
helmfile apply -e openshift -n opendesk
oc apply -k docs/openshift-manifests/overlays/example
```

Same recipe with `v1.19.0/` / `v1.18.2/` and matching `--branch`.

Fill site knobs (domain, StorageClass, IngressClass, JVB) before apply.
See `v1.19.1/docs/openshift-deployment.md`. Do not commit PEMs, keys, JKS,
`.kubeconfig`, or `.byo-redeploy-secrets`.

## Diff overlays

```bash
diff -ru v1.19.0 v1.19.1
# or
git diff --no-index v1.19.0 v1.19.1
```

Short delta: `COMPAT.md`.
