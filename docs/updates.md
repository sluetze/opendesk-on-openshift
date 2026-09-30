<!--
SPDX-FileCopyrightText: 2026 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
SPDX-License-Identifier: Apache-2.0
-->

# Updates and features

While [migrations-manual.md](./migrations-manual.md) provides information about required actions when updating or upgrading openDesk this document provides an overview on new (non-breaking) options made available in the Helmfile deployment.

> [!note]
> We only list newly introduced plain YAML structures here. For documentation of the described features, please refer to the comments in the referenced `.yaml.gotmpl` files.

<!-- TOC -->
* [Updates and features](#updates-and-features)
  * [1.19.0](#1190)
    * [`certificate.yaml.gotmpl`](#certificateyamlgotmpl)
      * [Upgrade to `opendesk-certificates` v4](#upgrade-to-opendesk-certificates-v4)
      * [Template `group` in `issuerRef`](#template-group-in-issuerref)
      * [Allow overriding of `opendesk-certificates` chart options](#allow-overriding-of-opendesk-certificates-chart-options)
      * [Certificate Trust chain/build support](#certificate-trust-chainbuild-support)
    * [`customization.yaml.gotmpl`](#customizationyamlgotmpl)
      * [Additional release customization hooks](#additional-release-customization-hooks)
    * [`deployment.yaml.gotmpl`](#deploymentyamlgotmpl)
      * [Timeouts of the Helm releases](#timeouts-of-the-helm-releases)
    * [`functional.yaml.gotmpl`](#functionalyamlgotmpl)
      * [Enterprise Matrix client access policy](#enterprise-matrix-client-access-policy)
      * [Erasure of the Matrix account data of deleted users](#erasure-of-the-matrix-account-data-of-deleted-users)
      * [Load additional data files into the Nubus data loader](#load-additional-data-files-into-the-nubus-data-loader)
      * [Nubus password quality options](#nubus-password-quality-options)
    * [`opendesk_main.yaml.gotmpl`](#opendesk_mainyamlgotmpl)
      * [Standalone NeoBoard whiteboard](#standalone-neoboard-whiteboard)
    * [`technical.yaml.gotmpl`](#technicalyamlgotmpl)
      * [Autoscaling of the Matrix components](#autoscaling-of-the-matrix-components)
      * [Configure Nubus extensions](#configure-nubus-extensions)
      * [Configure LDAP indices](#configure-ldap-indices)
      * [Notes API rate limits](#notes-api-rate-limits)
  * [1.18.0](#1180)
    * [`functional.yaml.gotmpl`](#functionalyamlgotmpl-1)
      * [Options to configure the list views of the admin portal](#options-to-configure-the-list-views-of-the-admin-portal)
      * [Identity a user schedules under in a Shared Account's calendar](#identity-a-user-schedules-under-in-a-shared-accounts-calendar)
    * [`migrations.yaml.gotmpl`](#migrationsyamlgotmpl)
      * [Timeout and log retention of the migration jobs](#timeout-and-log-retention-of-the-migration-jobs)
    * [`technical.yaml.gotmpl`](#technicalyamlgotmpl-1)
      * [Allow overriding HTTP request rate limiting for the core-mw component of the OX App Suite](#allow-overriding-http-request-rate-limiting-for-the-core-mw-component-of-the-ox-app-suite)
    * [`theme.yaml.gotmpl`](#themeyamlgotmpl)
      * [Dedicated mobile logo and touch icon for OpenProject](#dedicated-mobile-logo-and-touch-icon-for-openproject)
      * [Custom fonts for OpenProject's PDF export](#custom-fonts-for-openprojects-pdf-export)
  * [1.17.0](#1170)
    * [`functional.yaml.gotmpl`](#functionalyamlgotmpl-2)
      * [Enable the "Send later" (scheduled mail) feature for OX App Suite](#enable-the-send-later-scheduled-mail-feature-for-ox-app-suite)
      * [Configurable "Remember Me" SSO session timeouts](#configurable-remember-me-sso-session-timeouts)
    * [`helmfile-defaults.yaml.gotmpl`](#helmfile-defaultsyamlgotmpl)
      * [Allow override of single application helmfiles](#allow-override-of-single-application-helmfiles)
    * [`migrations.yaml.gotmpl`](#migrationsyamlgotmpl-1)
      * [Skip single actions of the automated migrations](#skip-single-actions-of-the-automated-migrations)
    * [`secrets.yaml.gotmpl`, `objectstores.yaml.gotmpl`, `database.yaml.gotmpl`](#secretsyamlgotmpl-objectstoresyamlgotmpl-databaseyamlgotmpl)
      * [Provide selected secrets as pre-created Kubernetes Secrets](#provide-selected-secrets-as-pre-created-kubernetes-secrets)
    * [`smtp.yaml.gotmpl`](#smtpyamlgotmpl)
      * [Postfix HELO names](#postfix-helo-names)
    * [`technical.yaml.gotmpl`](#technicalyamlgotmpl-2)
      * [OX App Suite LDAP caching for contact picker](#ox-app-suite-ldap-caching-for-contact-picker)
      * [Postfix](#postfix)
        * [SPF validation for incoming mail](#spf-validation-for-incoming-mail)
        * [User namespaces for the Postfix pod](#user-namespaces-for-the-postfix-pod)
        * [Client, HELO, sender restrictions and rate limits](#client-helo-sender-restrictions-and-rate-limits)
  * [1.16.0](#1160)
    * [`theme.yaml.gotmpl`](#themeyamlgotmpl-1)
      * [OpenProject PDF export theming](#openproject-pdf-export-theming)
    * [`technical.yaml.gotmpl`](#technicalyamlgotmpl-3)
      * [Nextcloud worker and memory tuning](#nextcloud-worker-and-memory-tuning)
    * [`service.yaml.gotmpl`](#serviceyamlgotmpl)
      * [Option to set a `loadBalancerIp` for Dovecot and Postfix](#option-to-set-a-loadbalancerip-for-dovecot-and-postfix)
    * [`database.yaml.gotmpl`](#databaseyamlgotmpl)
      * [Option to enable SSL/TLS database connection for OX App Suite](#option-to-enable-ssltls-database-connection-for-ox-app-suite)
    * [`cache.yaml.gotmpl`](#cacheyamlgotmpl)
      * [Options to enable SSL/TLS Redis connection for the Intercom Service, Notes, and OX App Suite](#options-to-enable-ssltls-redis-connection-for-the-intercom-service-notes-and-ox-app-suite)
  * [1.15.0](#1150)
    * [`functional.yaml.gotmpl`](#functionalyamlgotmpl-3)
      * [Per user-quota for external sharing](#per-user-quota-for-external-sharing)
      * [Virtual alias limits](#virtual-alias-limits)
    * [`technical.yaml.gotmpl`](#technicalyamlgotmpl-4)
      * [Proxy protocol support for Postfix](#proxy-protocol-support-for-postfix)
      * [Set limitation on maximum number of objects (for tasks, contacts, attachments)](#set-limitation-on-maximum-number-of-objects-for-tasks-contacts-attachments)
<!-- TOC -->

## 1.19.0

### `certificate.yaml.gotmpl`

#### Upgrade to `opendesk-certificates` v4

Reworking the certificates helm chart to support most of the community requested TLS certificate use-cases.

Read more in [Certificates](./enhanced-configuration/self-signed-certificates.md#certificates) section of
[enhanced-configuration/self-signed-certificates.md](./enhanced-configuration/self-signed-certificates.md)

#### Template `group` in `issuerRef`

Supporting `cert-manager.io` extensions, the `group` can now be modified and defaults to `group: "cert-manager.io"`.

```yaml
certificate:
  issuerRef:
    name: "letsencrypt-prod"
    kind: "ClusterIssuer"
    group: "cert-manager.io"
```

#### Allow overriding of `opendesk-certificates` chart options

To support the most common TLS certificate use-cases, most options in the `opendesk-certificates` helm chart can now be
overridden.

```yaml
certificate:
  selfSignedOverrides:
    issuer:
      create: false
    caCertificate:
      create: false
      secret:
        value:
          certificate: ~
          key: ~
          truststore: ~
          keystore: ~
        name: ""
    organizations:
      - "European Company that Makes Everything (ECME) Inc."
    organizationalUnits:
      - "Datacenter Operations"
    privateKey:
      algorithm: "ECDSA"
      size: ~
```

#### Certificate Trust chain/build support

openDesk now has built-in eval support for generating a certificate trust bundle. It composes the public default CA
bundle with self-signed or organization-signed certificates, so that clients reach the applications through the
deployment's own certificate while the applications keep trusting endpoints protected by publicly signed
certificates.

```yaml
trust:
  create: false
  certificateAuthorities:
    values: {}
    secret: ""
  secret:
    mount: false
    name: "opendesk-certificates-ca-tls"
```

Read more in [Trust](./enhanced-configuration/self-signed-certificates.md#trust) section of
[enhanced-configuration/self-signed-certificates.md](./enhanced-configuration/self-signed-certificates.md)

### `customization.yaml.gotmpl`

#### Additional release customization hooks

Additional releases now accept custom values files through these keys:

```yaml
customization:
  release:
    opendeskElementCustomization: {}
    neoboard: {}
    provisioningSynapse: {}
    opendeskTrust: {}
```

These customize the Element configuration generation, standalone NeoBoard, Synapse provisioning connector, and
trust bundle releases, respectively. Each entry is a map of names to values-file paths, following the existing
customization convention; adding a customization does not enable the corresponding component.

Renamed and removed Matrix customization keys require action and are documented in
[the migration requirements](./migrations-manual.md#changed-helmfile-structure-matrix-release-customizations).

### `deployment.yaml.gotmpl`

The file is added with openDesk 1.19.0.

#### Timeouts of the Helm releases

The time Helm waits for a release to become ready is now configured centrally, instead of being hard-coded per
release in the application helmfiles:

```yaml
deployment:
  timeouts:
    # Seconds Helm waits for a release that has no timeout of its own.
    default: 300
    releases:
      # A release with a timeout of its own.
      openproject: 600
      # A release following `default`.
      cryptpad: ~
```

Every release has its own key below `releases`, named after the release in camelCase (e.g. `opendesk-nextcloud`
becomes `opendeskNextcloud`). The two migration releases are not listed; their timeout is set with
`migrations.job.timeoutSeconds`.

> [!note]
> `helmfile apply --timeout <seconds>` overrides all of these values for a single run.

### `functional.yaml.gotmpl`

#### Enterprise Matrix client access policy

Enterprise deployments can configure MAS client access through the following options:

```yaml
functional:
  chat:
    matrix:
      clients:
        restrictAllowedClients: true
        denyLegacyClients: true
        allowElementDesktopClients: true
        additionalAllowedClientUris: []
```

With `restrictAllowedClients: true`, the OIDC client URI allowlist includes enabled Element Web, Element Admin
and NeoBoard clients, the Element URI pattern when `allowElementDesktopClients` is enabled, and any entries in
`additionalAllowedClientUris`. Additional entries can use a trailing `*` wildcard. If no clients are configured,
the rendered allowlist is explicitly empty and no clients are allowed by that policy.

Set `restrictAllowedClients: false` to omit the allowlist and allow any client URI. Independently,
`denyLegacyClients: true` blocks legacy Matrix compatibility logins; set it to `false` to lift that policy block.
Disabling the allowlist does not enable legacy logins automatically.

Setting `allowElementDesktopClients: false` also disables the device code grant used for QR sign-in. This remains
in effect even when URI restrictions are disabled. These options configure Enterprise policy only; they do not
add a Pro policy to Community Edition.

#### Erasure of the Matrix account data of deleted users

Deleting a user in central identity management now also deactivates their Matrix account. The openDesk
Provisioning Connector does this through the Matrix Authentication Service, which deactivates the account in
Synapse as well. The following option controls whether deactivation also erases the account's data:

```yaml
functional:
  dataProtection:
    matrixAccountErasure:
      enabled: true
```

`true`, the default, erases the data (GDPR erasure): The profile is dropped and the user's events are marked for redaction, which cannot be undone. `false` only deactivates the account and keeps its data.

#### Load additional data files into the Nubus data loader

The content can now be customized beyond the existing options by loading additional data files into the
Nubus data loader (Nubus chart option `nubusStackDataUms.stackDataUms.extraDataFiles`). Additional portal
categories, folders, entries (tiles) or announcements are the typical use-cases, but any object type the data
loader supports can be managed this way.

```yaml
functional:
  portal:
    custom:
      extraDataFiles: {}
```

#### Nubus password quality options

The global password quality rules the Nubus IAM enforces whenever a password is set or changed (e.g. via the portal's
self-service or the admin portal) can now be configured. The options map 1:1 to the options from [the upstream documentation](https://docs.software-univention.de/ucs-operation/5.2/en/iam/password-management/policies.html#password-policy-settings).

The message shown in the login and self-service dialogues when a new password does not comply with the rules
can now be configured as well. The message is a static text that is not derived from the
rules, so keep the two in sync.

```yaml
functional:
  authentication:
    password:
      complexityMessage:
        en: "Password must be at least 14 characters long and must not contain insecure character sequences."
      quality:
        length:
          min: 14
        credit:
          digits: 0
          upper: 0
          lower: 0
          other: 0
        mspolicy: "false"
```

### `opendesk_main.yaml.gotmpl`

#### Standalone NeoBoard whiteboard

NeoBoard is now available as a standalone whiteboard application, deployed as a release of its own and served at
`https://whiteboard.<domain>`. The component is not enabled by default:

```yaml
apps:
  neoboard:
    enabled: false
```

Set `enabled: true` to deploy it. The standalone application is independent of the NeoBoard widget used inside
Element rooms: The widget continues to ship with the Element release (`apps.element`) and is not affected by this
toggle, and the standalone application does not require the widget, so it can also be enabled on deployments that
run without Element.

### `technical.yaml.gotmpl`

#### Autoscaling of the Matrix components

openDesk Enterprise only: The Element Pro HAProxy, the Matrix Authentication Service and the Synapse workers can be
scaled by a HorizontalPodAutoscaler instead of their static replica counts from `replicas.yaml.gotmpl`. All are
disabled by default; the Community Edition ignores the settings.

```yaml
technical:
  matrix:
    autoscaling:
      haproxy:
        enabled: false
        minReplicas: 2
        maxReplicas: 20
        targetCPUUtilizationPercentage: 200
      matrixAuthenticationService:
        enabled: false
        # ...
      synapse:
        # One entry per worker, e.g. `clientReader`, `eventCreator`, `federationInbound`, `synchrotron`.
        clientReader:
          enabled: false
          # ...
```

#### Configure Nubus extensions

Nubus extensions are container images that add plugins (e.g. LDAP schemas, UDM/UMC modules, portal extensions) to
Nubus (Nubus chart option `global.extensions`). The extensions openDesk ships can now be toggled and additional
custom extensions can be loaded:

```yaml
technical:
  nubus:
    extensions:
      toggle:
        a2gMapper: true
      custom:
        - name: "my-extension"
          image:
            registry: "registry.example.org"
            repository: "my-org/my-nubus-extension"
            tag: "1.0.0"
```

Extensions are extremely powerful and a faulty extension can easily break the deployment, so make sure to test
custom extensions on a non-production environment first.

#### Configure LDAP indices

The attributes indexed by the Nubus LDAP server can now be configured. The openDesk specific attributes that are
indexed in addition to the upstream Nubus defaults are shown in `opendesk` and additional attributes, e.g. added
through custom extensions, can be indexed via `custom`:

```yaml
technical:
  nubus:
    ldap:
      index:
        eq:
          opendesk:
            - "univentionFreeAttribute1"
            - "univentionFreeAttribute2"
          custom: []
```

#### Notes API rate limits

Notes throttles its API per user and answers `429 Too Many Requests` above the limit. The limits can now be
configured, for example raised for load tests or lowered to harden a deployment:

```yaml
technical:
  notes:
    rateLimit:
      document: "80/minute"
      documentAccess: "50/minute"
      invitation: "60/minute"
      documentAskForAccess: "30/minute"
      config: "30/minute"
      userListBurst: "30/minute"
      userListSustained: "180/hour"
```

Each value is a throttle rate in the form `<count>/<period>`, where the period is one of `second`, `minute`, `hour`
or `day`. Leaving an option unset (`~`) keeps the upstream default for that limit instead of passing an override.

`documentAskForAccess` is the only limit facing people who do not have access to the document yet, so raise it with
care.

## 1.18.0

### `functional.yaml.gotmpl`

#### Options to configure the list views of the admin portal

Two options are provided to configure the list views (e.g. showing users) of the IAM admin portal:

- Define if the list views should trigger their search automatically when opening the page (`autosearch`)
- Set the maximum number of entries to load for a result set (`sizelimit`)

When the limit is hit, the result set has to be narrowed down using the search function.

```yaml
functional:
  admin:
    portal:
      listViews:
        sizelimit: 500
        autosearch: true
```

#### Identity a user schedules under in a Shared Account's calendar

A Shared Account brings a calendar with it, and an appointment a user creates or answers there can name either
the user acting on behalf of the Shared Account, or the Shared Account alone. Which of the two applies can now be
configured:

```yaml
functional:
  groupware:
    sharedAccounts:
      calendar:
        # `sendOnBehalf` or `sendAs`
        sentByPreference: "sendOnBehalf"
```

`sendOnBehalf`, the default, keeps both visible to the recipients: The appointment is the Shared Account's, sent
by that user. `sendAs` shows only the Shared Account and does not reveal who acted.

The setting applies to users whose permission grants both "send as" and "send on behalf of" which is what openDesk default permission profiles do.

### `migrations.yaml.gotmpl`

#### Timeout and log retention of the migration jobs

The two migration jobs now have their own timeout and log retention, instead of following the `debug.cleanup.*`
settings that govern the jobs of all other components:

```yaml
migrations:
  job:
    # Seconds the deployment waits for a migration job to complete.
    timeoutSeconds: 3600
    # Seconds a completed migration job and its Pod are kept, so its log stays readable. `0` keeps
    # it without a time limit.
    keepOutputSeconds: 604800
```

Both defaults changed with this: A migration job used to be given 900 seconds and its Pod removed 60 seconds
after it completed. A migration is not a component that can simply be redeployed - it is a one-time change to
your data, and its log is the only record of what it did, per object and including the values it replaced.

Raise `timeoutSeconds` for a large IAM. A migration that is still working when it elapses keeps running, but the
deployment has already been reported as failed and no longer waits for its outcome.

> [!note]
> `keepOutputSeconds` is an upper bound, not a guarantee: the jobs are deployed as hooks that are replaced on the
> next deployment, so a job's log survives at most until you deploy again. Collect anything you need beyond that
> from the Pod, e.g. with your log aggregation.

### `technical.yaml.gotmpl`

#### Allow overriding HTTP request rate limiting for the core-mw component of the OX App Suite

The OX App Suite core-mw component enforces a rate limit on certain API components. It is now possible to override the
default values for the core-mw component:

```yaml
technical:
  oxAppSuite:
    rateLimit:
      coreMW:
        maxRateTimeWindow: "60000"
        maxRate: "3000"
```

This is usually not required but can be helpful to customize for example for load tests.
### `theme.yaml.gotmpl`

> [!note]
> The theming attributes `theme.imagery.logoHeaderSvgB64` and `theme.imagery.logoHeaderInvertedSvgB64`
> have been renamed with this release. See
> [`migrations-manual.md`](./migrations-manual.md#changed-helmfile-structure-streamlined-naming-of-the-theming-attributes)
> for the required action.

#### Dedicated mobile logo and touch icon for OpenProject

OpenProject's mobile logo and its touch icon can now be themed independently:

```yaml
theme:
  imagery:
    projects:
      logoMobileSvg: {{ readFile "./../../files/theme/_common/logoHeader.svg" | b64enc | quote }}
      touchiconSvg: {{ readFile "./../../files/theme/projects/favicon.svg" | b64enc | quote }}
```

Previously both were hardcoded to the favicon served for OpenProject, so the only way to change them
was to change `theme.imagery.projects.faviconSvg` - which changed the browser tab icon as well. The
defaults keep the visual result close to the previous one: The mobile logo now uses the common header
logo, the touch icon still uses the OpenProject favicon.

Both attributes take the Base64-encoded content of an SVG file. They are served through the
opendesk-static-files module and are therefore part of a ConfigMap, so keep them small.

#### Custom fonts for OpenProject's PDF export

The fonts used for OpenProject's PDF exports can now be set:

```yaml
theme:
  imagery:
    projects:
      pdfExportFontRegularUrl: ~
      pdfExportFontBoldUrl: ~
      pdfExportFontItalicUrl: ~
      pdfExportFontBoldItalicUrl: ~
```

> [!warning]
> As with the other OpenProject theming export settings, the fonts are written to OpenProject on every deployment.
> Changes made in OpenProject's admin UI are lost and must be set using the above options instead.

## 1.17.0

### `functional.yaml.gotmpl`

#### Enable the "Send later" (scheduled mail) feature for OX App Suite

The OX App Suite "Send later" feature for scheduling outgoing emails is now enabled by default.

```yaml
functional:
  groupware:
    mail:
      outbound:
        sendLater:
          enabled: true
```

Setting `enabled: false` turns the feature off, resulting in the same behaviour as in openDesk 1.16.x and earlier.

#### Configurable "Remember Me" SSO session timeouts

Keycloak's "Remember Me" login option can now be toggled, and the idle and maximum lifespan of SSO sessions created with it can be configured:

```yaml
functional:
  authentication:
    realmSettings:
      rememberMe: true
      ssoSessionIdleTimeoutRememberMe: 28800
      ssoSessionMaxLifespanRememberMe: 1209600
```

Set `rememberMe: false` to disable the "Remember Me" option entirely. The two lifespan values only take effect while `rememberMe` is enabled. All lifespan values are defined in seconds.

### `helmfile-defaults.yaml.gotmpl`

#### Allow override of single application helmfiles

It is now possible to override the helmfile definition with default values for
a single openDesk application from an external repository by referencing
the `helmfile-defaults.yaml.gotmpl` in the application directories.

Example `helmfile.yaml.gotmpl`:

```yaml
---
environments:
  ext-env:
    values:
      ...
---
helmfiles:
  - path: "git::https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git@helmfile/apps/collabora/helmfile-defaults.yaml.gotmpl?ref=main"
    values:
      - {{ toYaml .Values | nindent 6 }}
...
```

### `migrations.yaml.gotmpl`

#### Skip single actions of the automated migrations

The automated migrations are now described by a list of actions per stage, see
[Automated migrations overview](./migrations-automated.md#automated-migrations-overview) in
`migrations-automated.md`.

The new file `migrations.yaml.gotmpl` allows to opt out of single actions of these migrations via
`migrations.actionsSkip`, e.g. when a migration is considered too complex or too risky for your
environment.

`actionsSkip` mirrors the `actions` structure of the migration definition: An entry names the stage
(the list it is in), the `id` and the `tag` of the action it skips. Both have to match the declared
action exactly, including the absence of a tag, so that an opt-out can never silently suppress a
later, different piece of work that reuses the same action under another tag.

A skipped action is logged as a warning and is not recorded as executed, so an action that is
declared to run once stays eligible should you un-skip it later.

Example `migrations.yaml.gotmpl` for skipping the OX Connector restart post deployment:

```yaml
migrations:
  actionsSkip:
    pre: []
    post:
      - id: "ox_connector_restart"
        tag: "v1.17.0"
```

> [!warning]
> The automated migrations bring your deployment in line with the openDesk release you are
> deploying. Skipping an action means the migration it implements is not applied and the affected
> component may stay on the old state, so you take over the responsibility for its outcome - for
> example because you already performed the step manually or because you need to perform it in a
> maintenance window of your own. Only use this option if openDesk support asked you to do so or if
> you are certain about the consequences.

### `secrets.yaml.gotmpl`, `objectstores.yaml.gotmpl`, `database.yaml.gotmpl`

#### Provide selected secrets as pre-created Kubernetes Secrets

Secret-bearing entries now carry a `create`/`name`/`key` structure alongside their `value`, and openDesk
delivers them as real Kubernetes Secrets by default instead of inlining the value into the chart. This applies
across all three files:
- `secrets.*` in `secrets.yaml.gotmpl`
- `objectstores.<store>.secretKey` in `objectstores.yaml.gotmpl`
- `databases.<db>.password` in `database.yaml.gotmpl`

Example:

```yaml
secrets:
  cassandra:
    rootPassword:
      value: {{ ... }}
      create: true
      name: "cassandra-root-password"
      key: "cassandra-password"
```

- `create: true` (default): openDesk provisions that Secret from `value`. The `opendesk-secrets` release is
  deployed automatically whenever at least one secret is `create: true`.
- To bring your own: set `create: false` and pre-create the Secret named `name` with key `key` in the
  namespace beforehand, e.g. `kubectl -n <NAMESPACE> create secret generic cassandra-root-password
  --from-literal=cassandra-password='<your-password>'`.

Per-entry caveats are documented inline, e.g. some secrets need an extra key (MinIO also needs `root-user`,
Collabora `username`), some cannot yet use `create: false` (other components still read the literal value).

### `smtp.yaml.gotmpl`

#### Postfix HELO names

The HELO name announced by the OX App Suite facing Postfix (`postfix-ox`) and by the internal Postfix can now be
overridden. Both default to `~`, which keeps the previous behaviour of letting Postfix derive the name from its
hostname:

```yaml
smtp:
  heloName: ~
  internalHeloName: ~
```

### `technical.yaml.gotmpl`

#### OX App Suite LDAP caching for contact picker

The contact picker in OX App Suite can cache LDAP lookups. The cache lifetime is controlled by an expiry time in seconds:

```yaml
technical:
  oxAppSuite:
    contactPicker:
      cacheExpirySeconds: 0
```

A value of `0` disables caching and is the default. Any positive value keeps LDAP results cached for that many seconds before they are refreshed.

#### Postfix

##### SPF validation for incoming mail

Postfix can now validate the SPF record of incoming mail and reject mail that fails the check:

```yaml
technical:
  postfix:
    checkSpf: false
```

The check is disabled by default, which keeps the previous behaviour. Only enable it if Postfix actually sees the IP
of the originating mail server. If a load balancer or proxy in front of Postfix terminates the connection without
preserving the client IP, every incoming mail is evaluated against the proxy's IP and legitimate mail is rejected. In
such a setup, either configure `technical.postfix.smtpdUpstreamProxyProtocol` so that Postfix learns the real client
IP, or leave `checkSpf` disabled.

##### User namespaces for the Postfix pod

The Postfix pods (`postfix` and `postfix-ox`) can now run in their own user namespace, so that UID 0 inside the
container maps to an unprivileged UID on the host:

```yaml
technical:
  postfix:
    userNamespaces: false
```

The default `false` preserves the current behaviour. Set it to `true` if your cluster supports user namespaces
(Kubernetes >= v1.36 with the feature enabled on the nodes); see the
[Kubernetes documentation](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/). Enabling it on a
cluster without support prevents the Postfix pods from starting.

This complements the hardened container security contexts shipped with this release: the Postfix containers no longer
run privileged, no longer allow privilege escalation, and drop all capabilities except those Postfix requires
(`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETGID`, `SETUID`, `KILL`).

##### Client, HELO, sender restrictions and rate limits

A set of Postfix restrictions can now be toggled to harden the configuration. These only affect `postfix-ox`.
Boolean options default to Postfix's previous behaviour (`false`, i.e. not rejecting), except
`reject_non_fqdn_sender`, `reject_unknown_sender_domain`, `reject_unlisted_sender` which was mistakenly not set
but defaults now to `true`; the list options default to empty:

```yaml
technical:
  postfix:
    restrictions:
      unknownReverseClientHostname: false
      unknownClientHostname: false
      rblClient: []
      rhsblReverseClient: []
      invalidHeloHostname: false
      nonFQDNHeloHostname: false
      rhsblHelo: []
      unknownHeloHostname: false
      nonFQDNSender: true
      rhsblSender: []
      unknownSenderDomain: true
      unlistedSender: true
      nonFQDNRecipient: true
      unlistedRecipient: true
      unknownRecipientDomain: true
      unauthDestination: true
```

Additionally, several client connection limits can now be set for smtp (Port 25) and submission (Port 465/587):

```yaml
technical:
  postfix:
    anvilRateTimeUnit: 60
    smtpdUpstreamProxyProtocol: ~
    smtpLimits:
      clientConnectionCount: 15
      clientConnectionRate: 0
      clientMessageRate: 0
      clientRecipientRate: 0
      clientNewTLSSessionRate: 0
      clientAuthRate: 0
    submissionLimits:
      clientConnectionCount: 15
      clientConnectionRate: 0
      clientMessageRate: 0
      clientRecipientRate: 0
      clientNewTLSSessionRate: 0
      clientAuthRate: 0
```

All `*Rate` limits are counted per time interval, and `anvilRateTimeUnit` defines the length of that interval in
seconds. The default of `60` means the rate limits apply per minute; setting it to `3600`, for example, turns them
into hourly limits. It applies to both `smtpLimits` and `submissionLimits` and has no effect on
`clientConnectionCount`, which limits simultaneous connections rather than a rate.

## 1.16.0

### `theme.yaml.gotmpl`

#### OpenProject PDF export theming

It is possible to customize the theming for OpenProject's PDF exports now:

```yaml
theme:
  imagery:
    projects:
      pdfExportLogoPath: "./../../files/theme/logoHeader.jpg"
      pdfExportCoverPath: "./../../files/theme/login/background.jpg"
      pdfExportFooterPath: "./../../files/theme/login/favicon.png"
```

> [!warning]
> PDF theming is overwritten on every deployment. Changes made in OpenProject's admin UI are lost and must be set using the above options instead.

### `technical.yaml.gotmpl`

#### Nextcloud worker and memory tuning

The number of worker processes and the PHP memory limits of the Nextcloud components can now be tuned to size the
deployment for the expected load:

```yaml
technical:
  nextcloud:
    aio:
      php:
        memoryLimit: "768M"
        workers: 20
      nginx:
        workers: "auto"
    pushNotify:
      nginx:
        workers: 2
```

Previously, these values were hardcoded and could not be customized from the Helmfile deployment.

Pinning `nginx.workers` to a fixed number is especially relevant on nodes with many CPU cores: the `"auto"`
setting is not cgroup-aware and spawns one worker per host core regardless of the pod's CPU allocation, so setting an
explicit value bounds the number of workers.

### `service.yaml.gotmpl`

#### Option to set a `loadBalancerIp` for Dovecot and Postfix

It is now possible to configure a fixed `loadBalancerIp` for the external services exposed by Dovecot and/or Postfix when the service type is `LoadBalancer`:

```yaml
service:
  loadBalancerIp:
    dovecot: ~
    postfix: ~
```

### `database.yaml.gotmpl`

#### Option to enable SSL/TLS database connection for OX App Suite

SSL/TLS support for the database connection of OX App Suite is now available:

```yaml
databases:
  oxAppSuite:
    useSSL: false
    requireSSL: false
    verifyServerCertificate: false
    enabledTLSProtocols: "TLSv1.2,TLSv1.3"
    nullCatalogMeansCurrent: true
```

Previously no such option was provided.

### `cache.yaml.gotmpl`

#### Options to enable SSL/TLS Redis connection for the Intercom Service, Notes, and OX App Suite

SSL/TLS support for the Redis connection of the Intercom Service, Notes, and OX App Suite are now available:

```yaml
cache:
  intercomService:
    tls: true
  notes:
    tls: true
  oxAppSuite:
    tls: true
```

## 1.15.0

### `functional.yaml.gotmpl`

#### Per user-quota for external sharing

Configure the per-user quota for external share links and guest invitations (when features are enabled):

```yaml
functional:
  groupware:
    externalSharing:
      shareLinks:
        enabled: false
        quota: 100
      inviteGuests:
        enabled: false
        quota: 100
```

Previously, only toggling these features on or off was supported.

#### Virtual alias limits

Postfix applies limits to virtual alias expansion and recursion, these limits can be modified now:

```yaml
functional:
  groupware:
    mail:
      localLimits:
        expansion: 1000
        recursion: 25
```

### `technical.yaml.gotmpl`

#### Proxy protocol support for Postfix

**Target audience:** Deployments using values in `smtp.spamMilter.*` for spam protection.

**Context**

To facilitate spam detection openDesk can integrate Postfix with Rspamd via the Milter protocol using the Helmfile
settings below `smtp.spamMilter.*`.

When choosing this option, Rspamd needs the client IP address of incoming SMTP connections to perform DKIM, rDNS,
and SPF validation.

In Kubernetes environments, applications are typically not exposed directly to the internet but run behind a load
balancer or proxy, so Postfix does not receive the real client IP by default. It sees only the upstream load
balancer IP and passes that to Rspamd. As a result, Rspamd cannot distinguish actual client IPs, and spam detection
checks fail or lose reliability.

To address this, the real client IP must be preserved through the load balancer. A typical approach is to use a TCP
load balancer with proxy protocol enabled.

**Required action**

To enable the proxy protocol it must be configured for both the load balancer and Postfix.

> [!warning]
> In case of a configuration mismatch, Postfix will not function properly.

Make sure to address the following steps to enable Proxy Protocol:

1. Load balancer: To enable the proxy protocol on the load balancer, consult
   your cloud providers documentation on how to configure the load balancer. For
   example, this is the relevant section
  [in the STACKIT Kubernetes Engine documentation](https://docs.stackit.cloud/products/runtime/kubernetes-engine/basics/load-balancing/#tcp-proxy-protocol).
1. openDesk: Set the following Helmfile values and redeploy:

   ```yaml
   technical:
     postfix:
       smtpdUpstreamProxyProtocol: "haproxy"
   ```

#### Set limitation on maximum number of objects (for tasks, contacts, attachments)

Set OX context wide quota limits for tasks, contacts, and attachments:

```yaml
technical:
  oxAppSuite:
    quota:
      tasks: 250000
      contacts: 250000
      attachments: 250000
```

Previously, only the calendar quota could be configured.
