# OpenShift manifests (v1.19.1)

Start minimal: SCC only. Add Route/RBAC YAMLs only when proven needed on this tag.

```bash
oc apply -k docs/openshift-manifests/overlays/example
```

BYO TLS: `create-byo-certificate-secrets.sh` (not applied via kustomize).
