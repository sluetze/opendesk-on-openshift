# Failure 4 (historical): `certificate.selfSigned: true` alone does not make the CA self-signed

**Status:** superseded. Current ocp22 path is Option 1 BYO — see
[`docs/openshift-deployment.md`](../openshift-deployment.md) /
[`docs/openshift-errors.md`](../openshift-errors.md). This writeup
documents the Option 2a in-cluster CA failure that blocked Nubus until a
`ClusterIssuer/selfsigned-issuer` existed.

**Symptom:** `helmfile apply` reported `ums` (Nubus) as successfully deployed, but
almost every Nubus pod stayed `Init:`/`ContainerCreating` for 45+ minutes. Root cause
traced (in dependency order) via `oc describe pod`:

```
Warning  FailedMount  ...  MountVolume.SetUp failed for volume "trusted-cert-crt-secret-volume":
                            secret "opendesk-certificates-ca-tls" not found
```

which traced further back to:

```
$ oc get certificate -n opendesk
NAME                       READY   SECRET
opendesk-certificates-ca   False   opendesk-certificates-ca-tls   (stuck)

Message: Issuing certificate as Secret does not exist   (cert-manager waiting forever)
Issuer Ref: Kind: ClusterIssuer, Name: letsencrypt-prod   <- doesn't exist on this cluster
```

**Root cause:** setting `certificate.selfSigned: true` only tells the
`opendesk-certificates` chart to mint its own **leaf** certificates from a
self-managed CA — it does **not** change how the **root CA certificate itself**
gets issued. That still goes through `certificate.issuerRef`, which we had left at
its chart default (`letsencrypt-prod`), a `ClusterIssuer` name that does not exist
on this cluster (ours are named `acme-letsencrypt`/`acme-letsencrypt-staging`, and
neither is usable anyway since ACME/Let's Encrypt cannot issue `isCA: true`
certificates). `cert-manager` therefore left the CA `Certificate` permanently
`Issuing`, so its secret (`opendesk-certificates-ca-tls`) never appeared, which
blocked every pod across the whole Nubus stack that mounts it (Keycloak, the
Keycloak bootstrap job, LDAP's OIDC JWKS fetch at startup, the portal, etc.) —
explaining the wide `Init:`/`ContainerCreating` pileup.

**Doc used:** this repo's own
[`docs/enhanced-configuration/self-signed-certificates.md`](../enhanced-configuration/self-signed-certificates.md),
"Option 2a: Use cert-manager.io with auto-generated namespace based root-certificate"
— which explicitly documents that `certificate.selfSigned: true` must be paired with
an `issuerRef` pointing at a self-signed `ClusterIssuer` that you create yourself.

**Fix (priority 1, helm value):** set `certificate.issuerRef.name:
"selfsigned-issuer"` / `.kind: "ClusterIssuer"` in the dev values.

**Fix (priority 2, OpenShift/cluster config):** create the `ClusterIssuer` the doc
prescribes (a cluster-scoped cert-manager object, not namespace-scoped SCC, but the
same "create the missing platform object" category CURSOR.MD pre-approves):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

Committed form was `docs/openshift-manifests/selfsigned-clusterissuer.yaml`
(now archived as [`selfsigned-clusterissuer.yaml`](./selfsigned-clusterissuer.yaml)).

**Later superseded by:** Option 1 BYO — disable the certificates chart, create
Secrets from PEMs + `truststore.jks`, drop `issuerRef` and the ClusterIssuer.
See [`option-2a-to-byo-migration.md`](./option-2a-to-byo-migration.md).
