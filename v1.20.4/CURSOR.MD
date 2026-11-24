# GOAL

get openDesk running on my OpenShift Cluster. Have documentation ready to reconstruct the result. have all needed changes in a human-readable, short and concise table.

# Method

1. Clone Opendesk deployment repository from https://gitlab.opencode.de/bmi/opendesk/deployment/opendesk.git utilizing the tag (version) specified by the User on an OpenShift Cluster.
2. inspect the deployed ressources and see where they fail (logs etc.)
3. document the fails and begin with a fix-pipeline


## fix pipeline

### Step 1. inspect failure and document it in a markdown doc (ISSUES.MD) in the project-root.
### Step 2. lookup the failure. prefer red hat documentation as source. Remember you are working against Red Hat openshift
### Step 3. solve the issue with configuration changes

use only this methods in this priority order
1. helm modifications / modifications to the deployment
2. openshift configuration modifications (e.g. SCC, special RoleBinding)

Remember. You are /ponytail

DO NOT: change sourcecode or the program itself. I want you to solve this with overlay only.

### Step 4. document the solution
IF NO SOLUTION IS FOUND, DOCUMENT THIS TOO.

If the failure is likely caused by the Demo-SetUp (e.g. Loadbalancer is not configured, so NodePort has to be used or Timeouts need to be changed, because of the slow storage), explicitly classify it as a environment issue and not as an general OpenShift incompatability.

## DONT
- dont access other clusters but ocp22
- dont utilize any authentication but the git credentials and the ocp22 credentials

## Reconstruction contract

The end result must be reconstructible with these steps (namespace + BYO TLS
secrets are the only imperative pieces; everything else is declarative).
Site-specific knobs (`global.domain`, StorageClass, IngressClass, JVB
advertise IP / NodePort, PEMs from a CA clients trust) are filled in
`helmfile/environments/openshift/` — see `docs/openshift-deployment.md`.

```shell
oc create namespace opendesk

# Option 1 BYO: PEMs under helmfile/environments/openshift/certs/
# (tls-fullchain.crt, tls.key, ca.crt; optional intermediate.crt).
# Charts require truststore.jks in the CA secret; the script builds it with a
# one-liner keytool via podman if missing. Reconstruct:
# docs/openshift-deployment.md. Failures/history: docs/openshift-errors.md.
# Note: certificate.selfSigned: true means "mount CA trust bundle", NOT
# "mint self-signed certs" (apps.certificates.enabled: false).
# Do NOT use the archived Option 2a ClusterIssuer path under
# docs/openshift-legacy-selfsigned-ca/.
export CERTIFICATES_JKS_PASSWORD='<jks password>'
bash docs/openshift-manifests/create-byo-certificate-secrets.sh

# Manifests are prefixed so RBAC applies before routes that use externalCertificate.
oc apply -f docs/openshift-manifests/

export MASTER_PASSWORD='<your passphrase>'
helmfile apply -e openshift -n opendesk
```

Rules that follow from this:

- Every OpenShift-config-priority-2 fix (SCC, RoleBinding, Route, ...)
  MUST be a static YAML file under `docs/openshift-manifests/`, applied with
  `oc apply -f`. No inline `oc create route ...` one-liners, no shell scripts that
  mutate the cluster as the "documented" form of a fix — those are fine as a scratchpad
  while debugging, but the committed fix is always the plain manifest.
  Exception: `create-byo-certificate-secrets.sh` (private TLS material; not YAML).
- Private keys / leaf certs are **not** committed: they stay under
  `helmfile/environments/openshift/certs/` (gitignored) or the repo-root PEM
  filenames listed in `.gitignore`. Routes reference Secret
  `opendesk-certificates-tls` via `spec.tls.externalCertificate` (no embedded PEM).
  Apply `opendesk-00-router-tls-secret-rbac.yaml` before fix-routes (filename sort).
- Authoritative helm values live in
  `helmfile/environments/openshift/values.yaml.gotmpl` (tracked) with inline
  comments explaining *why* each value is set. The deploy doc
  (`docs/openshift-deployment.md`) is cluster-agnostic: checklist + placeholders
  + pointer to that file (no requirement to paste a site-specific full dump).
- LATER (not now, just note the idea): consider upstreaming a first-class
  `openshift: true` toggle into the helm charts themselves so OpenShift support
  doesn't require any manifests/patches at all. Out of scope for this pass.
