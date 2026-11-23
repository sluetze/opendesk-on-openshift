---
name: opendesk-overlay
description: >-
  Create a new OpenDesk OpenShift overlay version in this repo. Validates the
  target OpenDesk tag on opencode, diffs upstream + prior overlay workarounds,
  pauses for user choice (copy / prune / scratch), deploys on OpenShift until
  healthy, then updates COMPAT.md. Use when the user asks to create a new
  overlay, bump OpenDesk version, add vX.Y.Z overlay, or port OpenShift
  workarounds to a new openDesk release.
---

# Create OpenDesk Overlay

Workflow for adding a new versioned OpenShift overlay under this repo root
(`vX.Y.Z/`). Overlay-only: never patch application source. Follow `/ponytail`.

Hard stop after **Step 2**. Do not create or deploy until user picks path in Step 3.

## Inputs (required from user)

| Input | Meaning |
| --- | --- |
| **OpenDesk Version** | Upstream tag, e.g. `v1.20.0` |
| **Deployment target** | Cluster / context / namespace (must be allowed; default constraint: **ocp22** only) |

If either missing → ask. Do not invent a version or target.

## Progress checklist

Copy and track:

```
Overlay progress:
- [ ] Step 1: Validate version + target
- [ ] Step 2: Diff + workaround analysis → report to user
- [ ] Step 3: User chose a / b / c → create overlay tree
- [ ] Step 4: Deploy + iterate until healthy
- [ ] Step 5: Update COMPAT.md
```

---

## Step 1 — Validate inputs

1. Confirm **deployment target** is present and allowed (`CURSOR.MD`: only **ocp22**; only git + ocp22 credentials).
2. Confirm **OpenDesk Version** is a published tag on opencode:

```bash
# Prefer git ls-remote against the upstream remote
git ls-remote --tags \
  https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git \
  "refs/tags/<VERSION>" "refs/tags/<VERSION>^{}"
```

Also acceptable: browse/API the same project tags. Tag must resolve to a commit SHA.

3. Identify **last overlay** in this repo: highest existing `v*` directory that is not the new version (e.g. `v1.19.1`). Read its `UPSTREAM` for prior tag/SHA.

**Fail closed:** if tag missing or target unclear → stop and tell user. No Step 2.

---

## Step 2 — Diff + workaround impact (then STOP)

Goal: tell user whether prior overlay workarounds still make sense.

1. Fetch upstream release notes / changelog between last overlay tag and new tag (GitLab release notes, `CHANGELOG`, tag compare).
2. Diff upstream trees (or commit range) for areas that touch OpenShift workarounds:

```bash
# Example: compare upstream tags (clone or fetch as needed)
git diff <last-tag>..<new-tag> --stat
```

3. Diff overlay trees conceptually against last overlay contents:
   - `helmfile/environments/openshift/` (values, customizations)
   - `helmfile/patches/`
   - `docs/openshift-manifests/`
   - `docs/openshift-errors.md` (documented failures + fixes)
4. For **each** documented workaround in the last overlay, classify:

| Class | Meaning |
| --- | --- |
| **Keep** | Still needed; upstream did not fix the OpenShift gap |
| **Obsolete?** | Upstream change likely removes need — propose drop (user decides) |
| **Unknown** | Need deploy proof; keep until proven safe to remove |
| **Environment** | Demo/site specific (LB, timeouts, storage) — not OpenShift incompatibility |

5. Report findings to user in a short table: workaround → evidence → recommendation. Point at relevant commits/release-note lines.

**STOP.** Wait for Step 3 instructions. Do not create directories, copy overlays, or deploy yet.

---

## Step 3 — Create overlay (user chooses)

Wait for explicit choice:

| Path | When | Action |
| --- | --- | --- |
| **a** | Small upstream delta; workarounds still valid | Copy last overlay → `vNEWER/`; update only upstream refs (`UPSTREAM`, README clone branch/SHA, values comments if they pin version) |
| **b** | Some workarounds obsolete per Step 2 + user agree | Same as **a**, then **remove** only the workarounds user approved |
| **c** | Too many structural changes | Build overlay from scratch against vanilla upstream tag; reuse patterns from last overlay only where still proven; start thin (see 1.19.1 policy: no fat SCC by default) |

### Overlay creation rules

- Directory name = version tag without extras if possible (`v1.20.0/`).
- Write `UPSTREAM` with `tag`, `sha`, `remote`, `https`.
- Copy/adapt `CURSOR.MD` reconstruction contract; keep overlay-only + ocp22 constraints.
- Site secrets stay gitignored; never commit PEMs/keys/kubeconfig.
- Manifests under `docs/openshift-manifests/` stay declarative (`oc apply -k`); no “documented” imperative `oc create route` one-liners.
- Prefer thinning: do not carry fat SCC/caps/customizations forward without evidence.

Layout details: [reference.md](reference.md).

---

## Step 4 — Deploy until healthy

Follow repo root + version `CURSOR.MD` / `docs/openshift-deployment.md`.

1. Clone vanilla upstream at the new tag (prefer SHA from `UPSTREAM`).
2. Apply overlay (see root `README.md`): copy env, `git apply` patches, copy docs/manifests.
3. Fill site knobs in `helmfile/environments/openshift/` for the deployment target.
4. Create namespace + BYO TLS secrets (script) as documented.
5. Apply manifests, then `helmfile apply -e openshift -n <ns>`.

### Failure loop

On each failure:

1. Capture evidence (`oc get events`, pod logs, helmfile output). Classify **OpenShift** vs **Environment**.
2. Look up symptom in **previous** overlay docs first: `<last>/docs/openshift-errors.md` (and older if needed). Reuse proven fix only if still applicable.
3. Fix priority (only these):
   1. Helm / deployment values / customizations / patches
   2. OpenShift config as static YAML under `docs/openshift-manifests/`
4. Document in **new** `vNEWER/docs/openshift-errors.md` (symptom, class, status, fix). Remove entries that vanish without a durable fix.
5. Re-apply / redeploy. Iterate until pods healthy and routes usable; no open issues in the errors log that block “up and running”.

**Live systems:** gather evidence first. Ask before destructive ops (delete ns, force deletes, irreversible cluster config) unless user already approved the deploy loop on that target.

Do **not** change application source. Overlay only.

---

## Step 5 — Update COMPAT.md

Add a column for the new version. Keep the cheap-delta table style already used.

- Update title line to include the new version.
- Set **Upstream** row to new tag + short SHA.
- For each area row: `yes` / carried value / `*not yet*` / `deferred` / note — matching what the new overlay actually contains after Steps 3–4.
- Point readers at `diff -ru <prev> <new>` for the rest.

Do not invent rows; extend existing areas when possible. Add a row only when a new workaround class appears.

Template and examples: [reference.md](reference.md).

---

## Non-negotiables

- Overlay-only; no app source edits.
- Cluster: **ocp22** only (unless user explicitly expands `CURSOR.MD`).
- Auth: git credentials + ocp22 credentials only.
- Proven fixes only in the overlay; speculative carry-forward is debt — mark `*not yet*` / drop.
- Environment issues ≠ OpenShift incompatibilities — label them.
- Hard stop after Step 2 until user picks **a** / **b** / **c**.
