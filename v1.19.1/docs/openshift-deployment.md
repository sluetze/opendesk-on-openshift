# openDesk 1.19.1 on OpenShift — deploy checklist

Upstream: see `../UPSTREAM` (`v1.19.1` / `6c41d8e8`).

## Reconstruct

```shell
oc create namespace opendesk

# Option 1 BYO: PEMs under helmfile/environments/openshift/certs/
export CERTIFICATES_JKS_PASSWORD='<jks password>'
bash docs/openshift-manifests/create-byo-certificate-secrets.sh

# Manifests start empty (default SCCs only). Apply after resources exist:
# oc apply -k docs/openshift-manifests/overlays/example

export MASTER_PASSWORD='<your passphrase>'
helmfile apply -e openshift -n opendesk
```

Site knobs: `helmfile/environments/openshift/values.yaml.gotmpl`.
Failures: `docs/openshift-errors.md` (OpenShift vs Environment).
