# Option 1 BYO migration (from Option 2a self-signed)

Historical was→now map when ocp22 left the `selfsigned-issuer` ClusterIssuer
path (failure #4 / Option 2a; see
[`openshift-errors.md`](../openshift-errors.md)). Current reconstruct steps:
[`docs/openshift-deployment.md`](../openshift-deployment.md#reconstruction).

| Was (Option 2a) | Now (Option 1 BYO) |
| --- | --- |
| `apps.certificates.enabled: true` + cert-manager `Certificate` CRs | `apps.certificates.enabled: false`; Secrets created from files |
| `certificate.issuerRef: selfsigned-issuer` | removed (unused) |
| `docs/openshift-manifests/selfsigned-clusterissuer.yaml` | moved here as archive; not applied |
| Routes embedded ECME leaf+key PEM | `externalCertificate.name: opendesk-certificates-tls` + router RBAC |
| Issuer ECME self-signed CA | Red Hat Internal Root / RHCSv2 intermediate |

`certificate.selfSigned: true` stayed across the migration — it only toggles
mounting of the CA/truststore into apps; it does not mint certs when the
certificates chart is disabled.
