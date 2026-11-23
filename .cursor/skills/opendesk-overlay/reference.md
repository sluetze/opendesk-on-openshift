# Overlay layout + COMPAT reference

## Directory layout (per version)

```
vX.Y.Z/
├── UPSTREAM                 # tag, sha, remote, https
├── CURSOR.MD                # goal, fix pipeline, reconstruction contract
├── README.md                # how to apply this overlay onto vanilla upstream
├── docs/
│   ├── openshift-deployment.md
│   ├── openshift-errors.md  # living failure log for this version
│   └── openshift-manifests/
│       ├── create-byo-certificate-secrets.sh
│       ├── base/            # SCC, Routes, RBAC, CA bundle, kustomization
│       └── overlays/example/
└── helmfile/
    ├── environments/openshift/
    │   ├── values.yaml.gotmpl
    │   ├── certs/.gitkeep   # PEMs gitignored
    │   └── customizations/  # only proven fixes
    └── patches/             # git apply onto vanilla helmfile
```

This repo is **not** a full openDesk tree. Apply overlay onto a vanilla clone of
https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git at the matching tag.

## Apply recipe (from root README)

```bash
git clone --branch <TAG> \
  git@gitlab.opencode.de:bmi/opendesk/deployment/opendesk.git opendesk
# Prefer SHA in vTAG/UPSTREAM

OVERLAY=/path/to/this/overlay/<TAG>
cd opendesk
cp -a "$OVERLAY/helmfile/environments/openshift" helmfile/environments/
git apply "$OVERLAY/helmfile/patches/"*.patch
cp -a "$OVERLAY/docs/"openshift-*.md "$OVERLAY/docs/openshift-manifests" docs/
# fill values + BYO certs
helmfile apply -e openshift -n opendesk
oc apply -k docs/openshift-manifests/overlays/example
```

Ordered redeploy when debugging: destroy/create ns → BYO TLS → `oc apply -k` manifests → `helmfile apply`.

## UPSTREAM file

```
tag: vX.Y.Z
sha: <full commit sha>
remote: git@gitlab.opencode.de:bmi/opendesk/deployment/opendesk.git
https: https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git
```

Optional notes (deploy worktree path, extraction branch) allowed.

## Workaround inventory (what to review in Step 2)

Scan last overlay for:

- Helm values (`trust.secret.mount`, timeouts, Matrix migration flags, PVC claims, …)
- `customizations/*.yaml(.gotmpl)` (rewrites, redirects, capability patches, CA inject)
- `helmfile/patches/*.patch` (bases env, migrations CA mounts, gitignore, …)
- Manifests: SCC (thin vs fat), fix Routes, router TLS RBAC, trusted CA ConfigMap
- `openshift-errors.md` rows marked fixed — each is a candidate Keep / Obsolete / Unknown

## Path a vs b vs c (decision aid)

| Signal | Lean |
| --- | --- |
| Patch files still apply cleanly; few upstream helmfile moves | **a** |
| Release notes / commits explicitly fix an OpenShift gap you patched | **b** (drop that patch) |
| Bases/env layout renamed; most patches fail; SCC/Ingress model changed | **c** |

When unsure between **a** and **b**: ship **a**, list optional drops for user — do not delete workarounds without approval.

## COMPAT.md shape

Repo-root table; one column per overlay version.

```markdown
# Overlay compatibility: vA / vB / vNEW

Cheap delta across overlay trees. Apply each onto its **own** upstream tag.

| Area | vA | vB | vNEW |
| --- | --- | --- | --- |
| Upstream | `vA` `sha…` | `vB` `sha…` | `vNEW` `sha…` |
| … | … | … | … |

`diff -ru vB vNEW` for the rest.
```

Cell vocabulary already in use:

- `yes` — present
- concrete value (`2400s`, `enabled: false`, SCC name)
- `*not yet*` — intentionally not carried; add only if proven
- `deferred` / `empty until proven`
- short note for thin vs fat SCC policy

## Errors doc policy

Do **not** assume older version failures still apply. Classify each new failure OpenShift vs Environment. Only commit fixes proven on the deploy target. If a failure disappears without a durable overlay fix, remove it from the list.
