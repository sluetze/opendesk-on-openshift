<!--
SPDX-FileCopyrightText: 2026 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
SPDX-License-Identifier: Apache-2.0
-->

# Configuration YAML files

openDesk's default configuration is spread over several topic-specific YAML files in [`helmfile/environments/default/`](../../helmfile/environments/default/). Enterprise Edition (EE) deployments additionally load the files in [`helmfile/environments/default-enterprise-overrides/`](../../helmfile/environments/default-enterprise-overrides/), which replace selected CE defaults. To keep your deployment up to date, we recommend not editing these files, but overriding the values you need in your own environment (e.g. `dev`, `test` or `prod`). All files contain inline documentation. For some of them, this directory also has more detailed documentation, linked in the table below.

| File                                                                                                                     | Edition | Content with link to dedicated documentation where available                        |
| ------------------------------------------------------------------------------------------------------------------------ | ------- | ----------------------------------------------------------------------------------- |
| [`_helper.yaml.gotmpl`](../../helmfile/environments/default/_helper.yaml.gotmpl)                                         | CE/EE   | Internal shared values (LDAP, Keycloak realm), not meant to be changed              |
| [`ai.yaml.gotmpl`](../../helmfile/environments/default/ai.yaml.gotmpl)                                                   | CE/EE   | Optional AI endpoint for Collabora and Notes                                        |
| [`annotations.yaml.gotmpl`](../../helmfile/environments/default/annotations.yaml.gotmpl)                                 | CE/EE   | Custom annotations for ingresses, pods, services and service accounts per component |
| [`antivirus.yaml.gotmpl`](../../helmfile/environments/default/antivirus.yaml.gotmpl)                                     | CE/EE   | [ICAP and milter endpoints for malware scanning](antivir.md)                        |
| [`cache.yaml.gotmpl`](../../helmfile/environments/default/cache.yaml.gotmpl)                                             | CE/EE   | Redis/cache endpoints and credentials per component                                 |
| [`certificate.yaml.gotmpl`](../../helmfile/environments/default/certificate.yaml.gotmpl)                                 | CE/EE   | TLS certificate handling via cert-manager                                           |
| [`charts.yaml.gotmpl`](../../helmfile/environments/default/charts.yaml.gotmpl)                                           | CE/EE   | Helm chart sources and versions                                                     |
| [`cluster.yaml.gotmpl`](../../helmfile/environments/default/cluster.yaml.gotmpl)                                         | CE/EE   | Cluster capabilities: service type, RWX storage, networking                         |
| [`customization.yaml.gotmpl`](../../helmfile/environments/default/customization.yaml.gotmpl)                             | CE/EE   | Hooks to load additional custom values files per release                            |
| [`database.yaml.gotmpl`](../../helmfile/environments/default/database.yaml.gotmpl)                                       | CE/EE   | Database endpoints and credentials per component                                    |
| [`debug.yaml.gotmpl`](../../helmfile/environments/default/debug.yaml.gotmpl)                                             | CE/EE   | Debug output and cleanup behavior of jobs and resources                             |
| [`deployment.yaml.gotmpl`](../../helmfile/environments/default/deployment.yaml.gotmpl)                                   | CE/EE   | Helm release timeouts                                                               |
| [`enterprise_features.yaml.gotmpl`](../../helmfile/environments/default/enterprise_features.yaml.gotmpl)                 | EE      | Settings for enterprise-only features, such as Collabora autoscaling                |
| [`enterprise_keys.yaml.gotmpl`](../../helmfile/environments/default/enterprise_keys.yaml.gotmpl)                         | EE      | License keys and subscription tokens for enterprise components                      |
| [`functional.yaml.gotmpl`](../../helmfile/environments/default/functional.yaml.gotmpl)                                   | CE/EE   | Functional (user-facing) settings of the components                                 |
| [`global.generated.yaml.gotmpl`](../../helmfile/environments/default/global.generated.yaml.gotmpl)                       | CE/EE   | Generated release information, not meant to be changed                              |
| [`global.yaml.gotmpl`](../../helmfile/environments/default/global.yaml.gotmpl)                                           | CE/EE   | Global settings: domains, registries, image pull secrets                            |
| [`images.yaml.gotmpl`](../../helmfile/environments/default/images.yaml.gotmpl)                                           | CE/EE   | Container image sources and tags                                                    |
| [`ingress.yaml.gotmpl`](../../helmfile/environments/default/ingress.yaml.gotmpl)                                         | CE/EE   | Ingress controller, TLS, body size and timeout settings                             |
| [`migrations.yaml.gotmpl`](../../helmfile/environments/default/migrations.yaml.gotmpl)                                   | CE/EE   | Behavior of the automated migration jobs                                            |
| [`monitoring.yaml.gotmpl`](../../helmfile/environments/default/monitoring.yaml.gotmpl)                                   | CE/EE   | Prometheus monitors/rules and Grafana dashboards                                    |
| [`objectstores.yaml.gotmpl`](../../helmfile/environments/default/objectstores.yaml.gotmpl)                               | CE/EE   | S3 object storage buckets and credentials per component                             |
| [`opendesk_main.yaml.gotmpl`](../../helmfile/environments/default/opendesk_main.yaml.gotmpl)                             | CE/EE   | Enabling/disabling of components (apps)                                             |
| [`persistence.yaml.gotmpl`](../../helmfile/environments/default/persistence.yaml.gotmpl)                                 | CE/EE   | Storage classes and volume sizes                                                    |
| [`replicas.yaml.gotmpl`](../../helmfile/environments/default/replicas.yaml.gotmpl)                                       | CE/EE   | Replica counts per component                                                        |
| [`repositories.yaml.gotmpl`](../../helmfile/environments/default/repositories.yaml.gotmpl)                               | CE/EE   | Registry overrides and ClamAV signature mirrors                                     |
| [`resources.yaml.gotmpl`](../../helmfile/environments/default/resources.yaml.gotmpl)                                     | CE/EE   | CPU and memory requests/limits per component                                        |
| [`secrets.yaml.gotmpl`](../../helmfile/environments/default/secrets.yaml.gotmpl)                                         | CE/EE   | Passwords, keys and other secrets of the components                                 |
| [`security.yaml.gotmpl`](../../helmfile/environments/default/security.yaml.gotmpl)                                       | CE/EE   | Network policies and password reset rate limits                                     |
| [`selinux.yaml.gotmpl`](../../helmfile/environments/default/selinux.yaml.gotmpl)                                         | CE/EE   | SELinux options per component                                                       |
| [`service.yaml.gotmpl`](../../helmfile/environments/default/service.yaml.gotmpl)                                         | CE/EE   | Service type and load balancer IP overrides                                         |
| [`sip.yaml.gotmpl`](../../helmfile/environments/default/sip.yaml.gotmpl)                                                 | CE/EE   | SIP dial-in for Jitsi via Jigasi                                                    |
| [`smtp.yaml.gotmpl`](../../helmfile/environments/default/smtp.yaml.gotmpl)                                               | CE/EE   | SMTP relay, spam milter and DKIM                                                    |
| [`technical.yaml.gotmpl`](../../helmfile/environments/default/technical.yaml.gotmpl)                                     | CE/EE   | Technical tuning settings of the components                                         |
| [`theme.yaml.gotmpl`](../../helmfile/environments/default/theme.yaml.gotmpl)                                             | CE/EE   | [Branding: texts, colors, logos and other assets](./theming.md)                     |
| [`turn.yaml.gotmpl`](../../helmfile/environments/default/turn.yaml.gotmpl)                                               | CE/EE   | TURN server for audio and video calls                                               |
| [`charts.yaml.gotmpl`](../../helmfile/environments/default-enterprise-overrides/charts.yaml.gotmpl) (EE overrides)       | EE      | Helm charts of the enterprise component variants                                    |
| [`images.yaml.gotmpl`](../../helmfile/environments/default-enterprise-overrides/images.yaml.gotmpl) (EE overrides)       | EE      | Container images of the enterprise component variants                               |
| [`resources.yaml.gotmpl`](../../helmfile/environments/default-enterprise-overrides/resources.yaml.gotmpl) (EE overrides) | EE      | Resource settings that differ in EE                                                 |
