# OpenShift manifests (v1.19.1)

Started on default `restricted-v2`. After proven UID/seccomp admission failure
(#1), ship thin SCC `opendesk-uid-seccomp` only — **not** fat
`opendesk-anyuid-seccomp` from prior overlays.

Also ships empty ConfigMap `opendesk-trusted-ca-bundle` labeled for CNO
`inject-trusted-cabundle` (cluster trust → `ca-bundle.crt`). ClamAV mounts it
via helm customization (see `openshift-errors.md` #2).

```bash
oc apply -k docs/openshift-manifests/overlays/example
```

BYO TLS: `create-byo-certificate-secrets.sh` (not applied via kustomize).
