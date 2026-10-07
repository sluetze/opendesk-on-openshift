# OpenShift manifests (v1.19.1)

Start with **default** OpenShift SCCs (`restricted-v2`). No custom SCC
shipped here. Add Route/RBAC/SCC YAMLs only when proven needed on this tag.

```bash
# optional once resources exist:
oc apply -k docs/openshift-manifests/overlays/example
```

BYO TLS: `create-byo-certificate-secrets.sh` (not applied via kustomize).
