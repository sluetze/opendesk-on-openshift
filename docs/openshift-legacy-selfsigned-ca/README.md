# Archive: self-signed in-cluster CA (Option 2a) — historical only

**Do not use for current ocp22 reconstruction.**

Current authoritative path is **Option 1 BYO** with user-provided PEMs under
OpenShift-wide trusted **Red Hat Internal CA (RHCSv2)**. See
[`docs/openshift-deployment.md`](../openshift-deployment.md) (reconstruct),
[`docs/openshift-errors.md`](../openshift-errors.md) (history), and
`CURSOR.MD`.

## Why this folder exists

Early ocp22 work used cert-manager Option 2a:

- `ClusterIssuer/selfsigned-issuer` (`spec.selfSigned: {}`)
- `apps.certificates.enabled: true` minting leafs from an in-cluster CA
- `certificate.issuerRef` → `selfsigned-issuer`
- Routes with embedded self-signed PEMs (ECME)

That path was superseded by BYO + RH Internal CA because clients and
ServiceWorkers need a CA already trusted on corp workstations, and private
keys must stay out of git (`externalCertificate` + router RBAC).

## What lives here

| File | Content |
| --- | --- |
| [`failure-04-selfsigned-issuer.md`](./failure-04-selfsigned-issuer.md) | Full writeup of the Option 2a cert-manager CA issuance failure |
| [`changes-rows-option-2a.md`](./changes-rows-option-2a.md) | Changes-table rows that only applied to Option 2a |
| [`option-2a-to-byo-migration.md`](./option-2a-to-byo-migration.md) | Was→Now map from Option 2a to Option 1 BYO |
| [`selfsigned-clusterissuer.yaml`](./selfsigned-clusterissuer.yaml) | Historical ClusterIssuer manifest (not under `openshift-manifests/`) |

## Still in the product docs (not moved)

Upstream Option 1 / 2a / 2b reference remains at
[`docs/enhanced-configuration/self-signed-certificates.md`](../enhanced-configuration/self-signed-certificates.md).
ocp22 uses **Option 1** from that doc; Option 2a/2b are general openDesk
options, not this cluster's reconstruct path.

## Naming trap (still true under BYO)

`certificate.selfSigned: true` does **not** mean “mint a self-signed CA”.
Under Option 1 it only toggles **mounting** `opendesk-certificates-ca-tls`
(`ca.crt` + `truststore.jks`) into apps. With `apps.certificates.enabled:
false`, cert-manager mints nothing.
