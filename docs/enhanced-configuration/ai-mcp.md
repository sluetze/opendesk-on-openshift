<!--
SPDX-FileCopyrightText: 2026 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
SPDX-License-Identifier: Apache-2.0
-->

# Connecting AI assistants via MCP

<!-- TOC -->
* [Connecting AI assistants via MCP](#connecting-ai-assistants-via-mcp)
  * [Overview](#overview)
  * [Available MCP servers](#available-mcp-servers)
  * [Authentication](#authentication)
    * [How authentication works](#how-authentication-works)
    * [Registering an MCP client in Keycloak](#registering-an-mcp-client-in-keycloak)
    * [Connecting an MCP client](#connecting-an-mcp-client)
    * [Revoking access](#revoking-access)
  * [OpenProject MCP server](#openproject-mcp-server)
  * [Limitations](#limitations)
<!-- TOC -->

## Overview

Components of openDesk can expose a [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server,
which lets any MCP-capable AI assistant act on the user's data (e.g. projects and work packages) on behalf of
that user.

This is the opposite direction to the central AI configuration described in
[Artificial Intelligence (AI) endpoint](../configuration-yamls/ai.md): There, openDesk components call an
external AI endpoint; here, an external AI assistant calls into openDesk. The MCP servers therefore do not use
the `ai.*` values. What openDesk provides is the authentication side: The MCP servers accept access tokens
issued by openDesk's Keycloak, and each AI assistant has to be registered there as an OIDC client.

## Available MCP servers

| Component   | Endpoint                                                                 | Prerequisite                                                  | Enabled and configured in                                                                   |
| ----------- | ------------------------------------------------------------------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| OpenProject | `https://<.Values.global.hosts.openproject>.<.Values.global.domain>/mcp` | Enterprise add-on, `enterprise.openproject.token` must be set | OpenProject: *Administration → Artificial Intelligence (AI) → Model Context Protocol (MCP)* |

No other component exposes an MCP server in openDesk today.

## Authentication

### How authentication works

MCP clients authenticate against the MCP server with OAuth 2.0. The MCP server advertises openDesk's Keycloak
realm as its authorization server, so the client sends the user through a regular Keycloak login and then calls
the MCP endpoint with the resulting access token. The MCP server accepts that token when:

* it carries the scope the MCP server requires,
* its `aud` claim contains the client id of the component's own OIDC client, so that the component trusts the
  token is meant for it, and
* it identifies the user so the component can map the token to an existing account.

Keycloak does not issue such tokens by default, hence additional client scopes and one client per AI assistant
are needed. Since the clients are registered statically, no dynamic client registration has to be enabled in
Keycloak. The component-specific requirements are listed in the section of the respective MCP server, e.g.
[OpenProject MCP server](#openproject-mcp-server).

### Registering an MCP client in Keycloak

Clients and client scopes are registered via `functional.authentication.oidc.clients` and
`functional.authentication.oidc.clientScopes` in
[`functional.yaml.gotmpl`](../../helmfile/environments/default/functional.yaml.gotmpl). The entries are YAML
representations of Keycloak's JSON client and client scope format (see the
[`opendesk-keycloak-bootstrap`](https://gitlab.opencode.de/bmi/opendesk/components/platform-development/charts/opendesk-keycloak-bootstrap)
chart), so any other attribute Keycloak supports can be added as well.

The example below uses a generic placeholder client (`mcp-client`) and connects it to the OpenProject MCP
server. Replace the client-specific parts, i.e. the client id/name, the client secret (`<client-secret>`) and
the `redirectUris`, with the values of the assistant you want to connect. The two client scopes are independent
of the MCP client and can be shared by all MCP clients you register:

* `mcp` is specific to the OpenProject MCP server: It provides the scope OpenProject requires and targets the
  token at openDesk's OpenProject client via an audience mapper.
* `mcp-client-scope` is generic and ensures the `sub` claim is part of the access token.

Add the following to your environment values file:

```yaml
functional:
  authentication:
    oidc:
      clientScopes:
        # Marks a token as MCP-capable and targets it at openDesk's OpenProject client.
        mcp:
          name: "mcp"
          protocol: "openid-connect"
          attributes:
            include.in.token.scope: "true"
            display.on.consent.screen: "true"
            include.in.openid.provider.metadata: "true"
          protocolMappers:
            - name: "opendesk-openproject"
              protocol: "openid-connect"
              protocolMapper: "oidc-audience-mapper"
              consentRequired: false
              config:
                included.client.audience: "opendesk-openproject"
                id.token.claim: "false"
                access.token.claim: "true"
                introspection.token.claim: "true"
                lightweight.claim: "false"
        # Ensures the `sub` claim is part of the access token, so the component can identify the user.
        mcp-client-scope:
          name: "mcp-client-scope"
          protocol: "openid-connect"
          attributes:
            include.in.token.scope: "false"
            display.on.consent.screen: "true"
            include.in.openid.provider.metadata: "true"
          protocolMappers:
            - name: "sub"
              protocol: "openid-connect"
              protocolMapper: "oidc-sub-mapper"
              consentRequired: false
              config:
                access.token.claim: "true"
                introspection.token.claim: "true"
      clients:
        mcp-client:
          name: "MCP client"
          clientId: "mcp-client"
          protocol: "openid-connect"
          enabled: true
          publicClient: false
          clientAuthenticatorType: "client-secret"
          secret: "<client-secret>"
          standardFlowEnabled: true
          implicitFlowEnabled: false
          directAccessGrantsEnabled: false
          serviceAccountsEnabled: false
          consentRequired: false
          frontchannelLogout: true
          redirectUris:
            # Callback URL of a hosted (web/desktop) MCP client; see the client's documentation.
            - "https://<mcp-client-host>/oauth/callback"
            # Local callback(s) of MCP clients running on a workstation; adapt the port(s) and path
            # to the clients you use.
            - "http://localhost:<port>/callback"
          attributes:
            use.refresh.tokens: "true"
          defaultClientScopes:
            - "mcp-client-scope"
            - "opendesk-openproject-scope"
            - "mcp"
            - "offline_access"
```

After applying the values, the `opendesk-keycloak-bootstrap` job creates the client and scopes in the
`opendesk` realm. Custom client scopes and clients are also listed in the Keycloak admin console (if enabled)
where you can verify them.

### Connecting an MCP client

With the client registered, configure the MCP client of your choice (how exactly depends on the client, e.g. a
"custom connector" or "remote MCP server" setting) with:

* the MCP server URL from [Available MCP servers](#available-mcp-servers) (HTTP transport),
* the OAuth client id (`mcp-client` above) and
* the client secret configured above.

The client then redirects the user to openDesk's login. After signing in, Keycloak redirects back to the
client's callback URL with the token, and the component's tools become available in the assistant. The
callback URL used by the client must be listed in the client's `redirectUris`; otherwise Keycloak rejects the
login with an "Invalid redirect URI" error.

### Revoking access

To revoke access for all users at once, remove (or disable) the client in the values file.

Ending a single user's sessions in the Keycloak admin console, including the offline session created through the
`offline_access` scope, only disconnects the assistant the user has currently connected. It does not prevent the
user from connecting again, as any user who can log in to openDesk can authorize the client. Restricting an MCP
client to selected users requires additional Keycloak configuration (e.g. a custom authentication flow) that is
not covered by openDesk.

In both cases, access tokens that have already been issued remain valid until they expire.

## OpenProject MCP server

OpenProject ships an [MCP server](https://www.openproject.org/docs/system-admin-guide/integrations/mcp-server/)
as an Enterprise add-on, so `enterprise.openproject.token` must be set. openDesk does not enable or configure
the MCP server itself: this is done within OpenProject under *Administration → Artificial Intelligence (AI) →
Model Context Protocol (MCP)*, where individual tools and resources can also be disabled or renamed.

In addition to the generic requirements described under [How authentication works](#how-authentication-works),
OpenProject accepts an access token only when:

* it carries the `mcp` scope, which OpenProject requires for all MCP endpoints,
* its `aud` claim contains `opendesk-openproject`, the client id of openDesk's OpenProject OIDC client, and
* it contains a `sub` claim and the claims of the existing `opendesk-openproject-scope` (in particular
  `opendesk_username`, which OpenProject uses as login attribute), so OpenProject can map the token to an
  existing OpenProject account.

The [example values](#registering-an-mcp-client-in-keycloak) above cover exactly these requirements.

## Limitations

* The OpenProject MCP server is an OpenProject Enterprise add-on and is enabled and administered within
  OpenProject, not via openDesk's values. openDesk only provides the Keycloak-side client registration.
* The `mcp` client scope in the example is bound to OpenProject through its audience mapper. Should further
  components expose MCP servers in the future, they will need their own scope or audience mapper.
* Whichever AI assistant is connected receives the data it queries from the MCP server. Operators are
  responsible for only registering assistants that meet their compliance and data protection requirements, see
  also the [limitations of the central AI configuration](../configuration-yamls/ai.md#limitations).
