<!--
SPDX-FileCopyrightText: 2026 Zentrum für Digitale Souveränität der Öffentlichen Verwaltung (ZenDiS) GmbH
SPDX-License-Identifier: Apache-2.0
-->

# Artificial Intelligence (AI) endpoint

<!-- TOC -->
* [Artificial Intelligence (AI) endpoint](#artificial-intelligence-ai-endpoint)
  * [Overview](#overview)
  * [Coverage](#coverage)
  * [Configuration](#configuration)
    * [Enabling AI](#enabling-ai)
    * [Allowing users to configure their own AI backend](#allowing-users-to-configure-their-own-ai-backend)
    * [Disabling AI](#disabling-ai)
  * [Limitations](#limitations)
  * [See also](#see-also)
<!-- TOC -->

## Overview

openDesk provides a central configuration for wiring components up to an existing
OpenAI-API-compatible AI/LLM endpoint, rather than each application configuring its own.

openDesk does not ship a bundled AI backend of any kind: AI functionality is entirely opt-in and
requires operators to bring their own external endpoint, model, and API key.

All central AI wiring is configured in
[`ai.yaml.gotmpl`](../../helmfile/environments/default/ai.yaml.gotmpl). As with the other functional
configuration files described in [functional configuration](../functional.md), you override these values via your
own environment values file rather than editing the defaults in place.

## Coverage

| Component        | AI features                                                                                                                    | Config file                                                                             |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| Collabora Online | [AI-assisted writing inside documents, spreadsheets and presentations](https://sdk.collaboraonline.com/docs/ai_assistant.html) | [`apps/collabora/values.yaml.gotmpl`](../../helmfile/apps/collabora/values.yaml.gotmpl) |
| Notes            | AI text actions in the collaborative editor                                                                                    | [`apps/notes/values.yaml.gotmpl`](../../helmfile/apps/notes/values.yaml.gotmpl)         |

No other application (Nextcloud, OpenProject, XWiki, Element/Synapse, Jitsi, CryptPad, OX App
Suite) has AI functionality wired up in openDesk today, but more will be added in upcoming releases.

## Configuration

```yaml
ai:
  endpoint: ""
  apiKey:
    value: ""
  model: ""
  allowUserSettings: false
```

* `ai.endpoint`: Base URL of an external, OpenAI-API-compatible AI endpoint. Leaving this empty
  (the default) disables AI everywhere; setting it enables AI support in both Collabora Online and
  Notes at once — there is no separate per-component enable flag.
* `ai.apiKey.value`: API key for the configured endpoint. This is a value-only secret (it only
  takes the `value` field, not the `create`/`name`/`key` structure used by other managed secrets)
  since it is an operator-supplied override that is empty by default; see
  [migrations-manual.md](../migrations-manual.md) for background on this secret shape.
* `ai.model`: Name/id of the model to request at the endpoint.
* `ai.allowUserSettings`: Lets end users configure their own AI backend, overriding the
  operator-provided one. Currently only affects Collabora Online. Disabled by default, since it
  has privacy implications: users could point Collabora at an AI backend of their own choosing,
  which would then receive their document data.

### Enabling AI

Set `ai.endpoint`, `ai.model`, and `ai.apiKey.value` in your environment values file, pointing at
your external AI endpoint. Both Collabora Online and Notes pick this up automatically:

* Collabora Online translates these values into its native `--o:ai.*` CoolWSD options
  (`ai.enabled`, `ai.api_url`, `ai.model`, `ai.api_key`) and additionally allowlists the endpoint's
  hostname via `net.lok_allow.host`.
* Notes feeds the same values into its backend's `configuration.ai` block
  (`enabled`/`apiKey`/`baseUrl`/`model`), toggling its AI feature on whenever `ai.endpoint` is
  non-empty.

### Allowing users to configure their own AI backend

Set `ai.allowUserSettings: true` to let users override the operator-provided AI backend with one
of their own choosing, in Collabora Online. Consider the privacy implications noted above before
enabling this.

### Disabling AI

Leave `ai.endpoint` unset, or explicitly set it to `""` (the default), to keep AI functionality
disabled across all components.

## Limitations

* There is no bundled AI backend — unlike e.g. the bundled ClamAV for [malware
  scanning](antivir.md), AI functionality always requires an externally operated endpoint.
* Data sent for AI-assisted features (e.g. document or note content) is transmitted to whichever
  endpoint is configured. Operators are responsible for choosing an endpoint that meets their
  compliance and data protection requirements.
* When `ai.allowUserSettings` is enabled, individual users can widen this data-handling surface
  further by pointing Collabora at a backend of their own choosing.
* AI functionality is only wired up for Collabora Online and Notes, as described under
  [Coverage](#coverage).

## See also

* [Connecting AI assistants via MCP](../enhanced-configuration/ai-mcp.md): the opposite direction, i.e. letting
  external AI assistants access data in openDesk (currently OpenProject) via the Model Context Protocol. This is
  independent of the `ai.*` values described here.
