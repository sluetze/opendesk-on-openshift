<!--
SPDX-FileCopyrightText: 2026 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
SPDX-FileCopyrightText: 2023 Bundesministerium des Innern und für Heimat, PG ZenDiS "Projektgruppe für Aufbau ZenDiS"
SPDX-License-Identifier: Apache-2.0
-->

# Security

This document covers the current status of security measures.

<!-- TOC -->
* [Security](#security)
  * [Helm chart trust chain](#helm-chart-trust-chain)
  * [Container image trust chain](#container-image-trust-chain)
  * [Kubernetes security enforcements](#kubernetes-security-enforcements)
  * [Network policies](#network-policies)
<!-- TOC -->

## Helm chart trust chain

Helm charts are signed and validated against GPG keys in `helmfile/files/gpg-pubkeys`.

For more details on Chart validation, please visit: https://helm.sh/docs/topics/provenance/

All charts except the ones mentioned below are verified by Helmfile.

| Repository                | Verifiable |
| ------------------------- | :--------: |
| collabora-controller-repo |     no     |
| element                   |     no     |
| neoboard                  |     no     |
| open-xchange-repo         | cosign[^1] |

## Container image trust chain

Every container image used by openDesk is pinned by tag and digest in `helmfile/environments/default/images.yaml.gotmpl`
(and `helmfile/environments/default-enterprise-overrides/images.yaml.gotmpl` for the Enterprise Edition). The
`# providerResponsible: "openDesk"` annotation marks the images openDesk is responsible for. They fall into two groups:

| Image group                                                                                      | Signed by openDesk | Verifiable |
| ------------------------------------------------------------------------------------------------ | :----------------: | :--------: |
| Built by openDesk (`registry.opencode.de/bmi/opendesk/components/platform-development/images/*`) |        yes         |   cosign   |
| Mirrored or pulled from upstream (`.../images-mirror/*`, `registry-1.docker.io/*`)               |         no         |  upstream  |

Images built by openDesk are signed with [cosign](https://docs.sigstore.dev/cosign/) using a fixed key pair. The
corresponding public key is shipped in `helmfile/files/cosign-pubkeys/opendesk.pub`. Helmfile does not verify image
signatures itself, so verification is a manual step (or an admission-time policy, see below).

Mirrored images are unmodified copies of the upstream image and are not re-signed by openDesk; verify them against
the upstream project's signatures, if any. Images provided by suppliers (`providerResponsible` other than
`"openDesk"`) are the responsibility of the respective supplier.

### Verifying an image

Use the pinned image reference from `images.yaml.gotmpl` so that the signature is checked for exactly the digest
openDesk deploys. Example with `opendesk-migrations`:

```shell
cosign verify \
  --key helmfile/files/cosign-pubkeys/opendesk.pub \
  --insecure-ignore-tlog=true \
  registry.opencode.de/bmi/opendesk/components/platform-development/images/opendesk-migrations:1.12.6@sha256:92705e1fd5daef1a6bbf4af505a38ed3e244a51ee818d79ff531176ecd8a2cfd
```

A successful run prints the checks performed and a JSON payload whose `critical.image.docker-manifest-digest` matches
the pinned digest.

`--insecure-ignore-tlog=true` is required because openDesk signatures are not uploaded to the public Rekor
transparency log; without the flag cosign aborts with `not enough verified log entries from transparency log`. The
flag only skips the transparency log lookup, the signature is still verified against the openDesk public key.

### Enforcing verification in the cluster

To reject unsigned or tampered openDesk images at admission time, configure your policy engine with the same public
key, e.g. a Kyverno `verifyImages` rule or the sigstore
[policy-controller](https://docs.sigstore.dev/policy-controller/overview/), scoped to
`registry.opencode.de/bmi/opendesk/components/platform-development/images/*`. openDesk currently does not ship such
a policy.

## Kubernetes security enforcements

This list gives you an overview of default security settings and whether they comply with security standards:

⟶ Visit our generated detailed [Security Context](./security-context.md) overview.

## Network policies

Kubernetes network policies are an essential measure to secure your Kubernetes apps and clusters.
When applied, they restrict traffic to your services.
`NetworkPolicy` resources protect other deployments in your cluster or other services in your deployment from getting compromised when another
component is compromised.

We ship a default set of Otterize `ClientIntents` via
[Otterize intents operator](https://github.com/otterize/intents-operator) which translates intent-based access control
(IBAC) into Kubernetes native network policies.

This requires the Otterize intents operator to be installed.

```yaml
security:
  otterizeIntents:
    enabled: true
```

[^1]: Helmfile does not support cosign chart verification yet, though the chart can be [externally verified](https://docs.sigstore.dev/cosign/verifying/verify/) using the key(s) in `helmfile/files/cosign-pubkeys`
