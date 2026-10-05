<!--
SPDX-FileCopyrightText: 2024 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
SPDX-License-Identifier: Apache-2.0
-->

# Self-signed certificates and custom Certificate Authority (CA)

<!-- TOC -->
* [Self-signed certificates and custom Certificate Authority (CA)](#self-signed-certificates-and-custom-certificate-authority-ca)
  * [Certificates](#certificates)
    * [Option 0: ACME / `in-tree`](#option-0-acme--in-tree)
    * [Option 1: Bring Your Own Certificate](#option-1-bring-your-own-certificate)
    * [Option 2: Use cert-manager.io with auto-generated namespace root-certificate](#option-2-use-cert-managerio-with-auto-generated-namespace-root-certificate)
    * [Option 3: Use EJBCA with cert-manager.io](#option-3-use-ejbca-with-cert-managerio)
  * [Trust](#trust)
<!-- TOC -->

This document covers:
* Deploying openDesk into an environment with custom public key infrastructure (PKI) that is usually not part of
public certificate authority chains
* deploying openDesk into a local cluster

## Certificates

There are four options to address the certificate use case:

### Option 0: ACME / `in-tree`

To have a better overview of all certificate use-cases, we list the ACME option here as well. As this is the default
option and is widely used in conjunction with Let's Encrypt, you can configure an organization-provided ACME endpoint
here:

```yaml
certificate:
  create: true
  issuerRef:
    name: "my-company-issuer"
    kind: "ClusterIssuer"
    group: "cert-manager.io"
```

Detailed information on how to create an ACME issuer or use any other supported `in-tree` issuer can be found in the
[cert-manager documentation](https://cert-manager.io/docs/concepts/issuer/).

### Option 1: Bring Your Own Certificate

This option is useful when you have your own PKI in your environment which is also trusted by all clients that should
access openDesk.

1. Disable cert-manager.io certificate resource creation:

    ```yaml
    certificate:
      create: false
    ```

2. Create a Kubernetes secret named `opendesk-certificates-tls` of type `kubernetes.io/tls` containing either a valid
wildcard certificate or a certificate with [all required subdomains](../../helmfile/environments/default/global.yaml.gotmpl)
set as SANs (Subject Alternative Name).


> [!note]
> If your Certificate can not be validated against common ca-certificate bundles, you need to follow the [Trust](#trust)
> section.

### Option 2: Use cert-manager.io with auto-generated namespace root-certificate

This option is useful when you do not have a trusted certificate available and want to quickly deploy openDesk.
It will result in a cert-manager managed root certificate in the namespace you deploy openDesk into.

1. Configure certificates section:
    ```yaml
    certificate:
      selfSigned: true
      selfSignedOverrides:
        issuer:
          create: true
        caCertificate:
          create: true
    ```

2. The generated root CA is stored in the secret `opendesk-certificates-ca-tls`. As this root certificate is not
publicly trusted, you need to configure trust with that secret as the CA source:
    ```yaml
    trust:
      create: true
      certificateAuthorities:
        secret: "opendesk-certificates-ca-tls"
      secret:
        mount: true
        name: "opendesk-certificates-ca-bundle-tls"
    ```

> [!warning]
> Please note that `trust.certificateAuthorities.secret` and `trust.secret.name` have to be different - the first is
> the input the bundle is composed from, the second the output it is written to. The deployment refuses the same name
> for both at template time.

> [!note]
> Please note, that cert-manager will rotate the root-certificate. This option is more intended for testing instead of
> production usage.

### Option 3: Use EJBCA with cert-manager.io

In case you run an open-source [EJBCA](https://www.ejbca.org/) instance and have properly configured the
[Keyfactor cert-manager issuer](https://github.com/Keyfactor/ejbca-cert-manager-issuer) for it, you can point openDesk
at the resulting `ClusterIssuer`. The standalone `opendesk-ejbca` helper chart from the `opendesk-certificates`
repository can create that `ClusterIssuer` and its credential secrets for you; it is not part of the openDesk
deployment itself. Reference the issuer through `certificate.issuerRef`:

```yaml
certificate:
  selfSigned: true
  issuerRef:
    name: "my-ejbca"
    kind: "ClusterIssuer"
    group: "ejbca-issuer.keyfactor.com"
  selfSignedOverrides:
    organizations:
      - "MyOrg"
    privateKey:
      algorithm: "RSA"
      size: 4096
```

> [!note]
> If your Certificate can not be validated against common ca-certificate bundles, you need to follow the [Trust](#trust)
> section.

## Trust

One of the challenging parts of self-signed certificates is distributing trust to clients and applications.

For eval purposes, openDesk contains a simple Job which bundles the debian ca-certificates[^1] with custom provided
certificates and mounts them into all cluster components.

You can enable it via:

```yaml
trust:
  create: true
  secret:
    mount: true
    name: "opendesk-certificates-ca-bundle-tls"
```

> [!note]
> With `trust.create: true` the bundle needs a dedicated secret name: The default `trust.secret.name`
> (`opendesk-certificates-ca-tls`) exists for the `create: false` case and points at the CA secret of the
> `opendesk-certificates` chart, which the bundle Job would otherwise overwrite. The deployment refuses that
> combination at template time. Every component mounts whatever name is set here.

You benefit from `trust.create` when adding your root certificates to the default debian ca-bundle.
This can be achieved by either adding the root certificate as plain-text:

```yaml
trust:
  certificateAuthorities:
    # Additional certificate authorities which should be added to trust bundle.
    # Certificates have to end with ".crt" to be added to the bundle.
    values:
      corporate.crt: |
        -----BEGIN CERTIFICATE-----
        ...
```

or from an existing secret:

```yaml
trust:
  certificateAuthorities:
    secret: "my-ca-tls"
```

In case you want to use e.g. trust-manager, just create the certificate bundle with the name
`opendesk-certificates-ca-tls` or change the name via

```yaml
trust:
  create: false
  secret:
    mount: true
    name: "opendesk-certificates-ca-tls"
```

Please keep in mind that you have to provide a keystore and a truststore as well, so the certificates include:

- ca.crt
- keystore.jks
- truststore.jks

> [!note]
> XWiki does not support the use of an existing secret to access the keystore. Therefore, you have to set the
> password also as `secrets.certificates.password`.

[^1]: The bundled certificate authorities come from Debian's
[ca-certificates](https://salsa.debian.org/debian/ca-certificates) package, which is derived from Mozilla's
[Included CA Certificate List](https://wiki.mozilla.org/CA/Included_Certificates).
