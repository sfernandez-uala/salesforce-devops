# Bringing this pipeline to a corporate Salesforce org

A step-by-step runbook to stand up this CI/CD pipeline (sfdx-hardis + GitHub
Actions) against a real corporate / production org and its sandboxes.

> Read the **Gotchas** section at the end first. It captures the hard-won
> lessons that cost the most time — you'll want them in mind before you start.

---

## 0. The model (what you're wiring)

**Two layers — don't conflate them:**

- **Build layer** — each developer works in their **own sandbox** and syncs
  with `sf hardis work backpromote`.
- **Promotion layer** — long-lived branches `dev → uat → main`, each mapped to a
  **shared org**: integration sandbox → staging/UAT sandbox → production.

Git is the source of truth. Nothing is deployed by hand — every change is a PR,
the pipeline deploys on merge. Deploys are **full** (`useDeltaDeployment: false`)
from `manifest/package.xml`; deletions require an explicit
`manifest/destructiveChanges.xml`.

---

## 1. Prerequisites

- **Salesforce**: a production org with sandbox capability (Enterprise/Unlimited),
  admin access, and enough sandbox licenses (per-dev + integration = Developer;
  UAT ideally Partial/Full Copy for realistic data).
- **Local tooling** (pin the same versions the CI uses):
  ```bash
  npm install --global @salesforce/cli@<pinned>
  sf plugins install sfdx-hardis@<pinned>
  sf plugins install sfdx-git-delta@<pinned>
  sf plugins install @salesforce/plugin-code-analyzer@<pinned>
  ```
- **GitHub**: an **org-owned** private repo, admin rights to configure
  Environments + secrets, and GitHub Advanced Security enabled (required for
  SARIF code-scanning on private repos).

---

## 2. Repo & branch model

1. Create the repo under the GitHub org.
2. Create the three long-lived branches: `dev`, `uat`, `main`.
3. `CODEOWNERS` → point at a **team** (e.g. `@<org>/salesforce-platform`), not an
   individual.
4. Branch protection on `dev`/`uat`/`main`: require the PR Quality Gate checks;
   add required reviewers at the org cutover (see Hardening).

---

## 3. Sandboxes

Create the orgs behind the promotion layer + the per-dev build sandboxes:

```bash
sf org create sandbox --name dev  --license-type Developer --alias <org>-dev  -o <prod-alias>
sf org create sandbox --name uat  --license-type <Developer|Partial> --alias <org>-uat -o <prod-alias>
# one per developer:
sf org create sandbox --name <devname> --license-type Developer --alias <org>-<devname> -o <prod-alias>
```

Sandbox creation is slow (minutes to ~1h). Authorize when done:
`sf org resume sandbox --name <name> -o <prod-alias>`.

---

## 4. JWT authentication (per org) — the critical part

The CI authenticates unattended via the **JWT Bearer Flow**: a private key signs
a token, the org validates it against an uploaded certificate. **No passwords, no
client secret.** Do this for **each** org (dev, uat, prod) — the consumer key is
**per-org**.

### 4a. Generate a certificate + private key (once; can be shared across orgs)
```bash
mkdir -p ~/sf-jwt && cd ~/sf-jwt
openssl req -x509 -sha256 -nodes -days 730 -newkey rsa:2048 \
  -keyout server.key -out server.crt -subj "/CN=<your>-devops-ci"
```
- `server.key` = **private key** (goes to CI as a secret; never commit).
- `server.crt` = **public certificate** (uploaded to the app in Salesforce).

> For production, prefer a **separate key pair for prod** so a leaked dev key
> can't reach production (see Hardening).

### 4b. Create the app in each org
New orgs use **External Client Apps** (older orgs: Connected Apps — same JWT
capability). In each org's Setup → **External Client App Manager → New**:
- **Enable OAuth**; Callback URL `http://localhost:1717/OauthRedirect` (placeholder).
- Scopes: **Manage user data via APIs (api)** + **Perform requests at any time
  (refresh_token, offline_access)**.
- **Enable JWT Bearer Flow** → upload `server.crt`.
- **Policies**: Permitted Users = **"Admin approved users are pre-authorized"**;
  assign the integration user's **profile/permission set**; IP Relaxation =
  **Relax IP restrictions**.
- Copy the **Consumer Key** (this org's `SFDX_CLIENT_ID`).

### 4c. Validate locally before touching CI
```bash
sf org login jwt --client-id <CONSUMER_KEY> --jwt-key-file ~/sf-jwt/server.key \
  --username <org-user> --instance-url <org-instance-url> --alias <org>
```
"Successfully authorized" means the cert → app → login chain is correct.

---

## 5. GitHub Environments & secrets

Use **GitHub Environments** (not repo-level secrets) as the single source of
truth — they support protection rules (required reviewers) for prod.

1. Create environments: `dev`, `uat`, `prod`.
2. Per environment, set two secrets:
   - `SFDX_CLIENT_ID_<ORG>` = that org's **Consumer Key**.
   - `SFDX_CLIENT_KEY_<ORG>` = the **raw `server.key` PEM** (whole file, incl.
     `-----BEGIN/END-----`).
3. The gate job (`delta-check-deploy`) **binds to the target branch's
   environment** (`main` maps to the `prod` environment). Deploy workflows bind to
   their own environment. So all JWT secrets live in Environments only.

**Two supported key models** — pick one:

| Model | How | When |
|---|---|---|
| **Raw PEM** (what this repo is wired for) | Workflows pass the PEM via `SFDX_CLIENT_CERT_<ORG>` (mapped from the `SFDX_CLIENT_KEY_<ORG>` secret). hardis detects the PEM header and uses it directly — no decryption. | Simple; app/cert created manually. |
| **Encrypted key** (hardis-native, recommended for prod) | Run `sf hardis project configure auth` per org. It creates the app, generates + **encrypts** the key into `config/branches/.jwt/<branch>.key` (committed), and prints `SFDX_CLIENT_ID_<ORG>` + `SFDX_CLIENT_KEY_<ORG>` (an AES **passphrase**). | Production — the private key never sits in a CI var in plaintext. |

---

## 6. Repo configuration

- `config/branches/.sfdx-hardis.<branch>.yml` — per branch:
  ```yaml
  instanceUrl: https://<org-domain>.my.salesforce.com   # sandbox: <domain>--<sbx>.sandbox...
  targetOrg: DEV|UAT|PROD
  targetUsername: <org-user>
  testLevel: NoTestRun            # dev
  # testLevel: RunLocalTests      # uat / main
  mergeTargets: [<next-branch>]
  ```
- `config/.sfdx-hardis.yml` — `useDeltaDeployment: false` (full, deterministic,
  PR-reviewable deploys).

---

## 7. Manifest

`manifest/package.xml` must list **every metadata type** you deploy — under the
full-deploy model, a type that isn't listed is silently skipped.

---

## 8. First deploy (reconstruct the org from Git)

Open a PR to `dev` → the gate runs (auth + check-only validate) → merge →
`Deploy to DEV` deploys the full manifest to the integration sandbox. On a fresh
org expect to resolve a few dependency gaps (missing features/objects the source
assumes). Then promote `dev → uat → main`.

---

## 9. Hardening for a regulated / corporate org

- **Code scanning**: enable GitHub Advanced Security so PMD findings publish as
  SARIF to Security → Code scanning (audit trail of accepted/dismissed findings).
- **Approvals**: enable branch protection + required reviewers; `CODEOWNERS` by
  team + require code-owner review. Add **required reviewers on the `prod`
  Environment** so production deploys pause for approval (expedited/on-call
  reviewer for hotfixes).
- **Credential isolation**: give **prod its own key pair** (dev/uat never see it).
  Prefer the **encrypted key model** so no raw private key sits in a CI var.
- **Reproducibility**: pin the CLI, plugins, and SHA-pin all GitHub Actions;
  enable Dependabot for `github-actions`.
- **Secrets**: gitleaks in the gate + GitHub push protection; JWT secrets scoped
  to Environments.

---

## Gotchas (read these — each one cost real time)

1. **Consumer key is per-org.** Reusing prod's key for dev fails with *"External
   client app is not installed in this org."* Each org's app has its own key.
2. **Secret scope: repo vs. Environment.** A job with no `environment:` reads
   **repo-level** secrets; a job bound to an environment reads that environment's.
   Keep JWT secrets in **Environments only** and bind every job (incl. the gate)
   to the right one, or you'll authenticate with stale/wrong keys.
3. **`SFDX_CLIENT_KEY` is not the raw key in hardis's default model** — it's the
   **AES passphrase** that decrypts `config/branches/.jwt/<branch>.key`. To use a
   raw PEM instead, pass it via **`SFDX_CLIENT_CERT_<ORG>`** (hardis detects the
   PEM header and skips decryption).
4. **Committed `.jwt/<branch>.key` files are org-specific** (encrypted). A file
   left over from a different org won't work — regenerate per org, or use the raw
   PEM path.
5. **Sandbox auth scope**: an org authorized via `sf org resume sandbox` may lack
   scope for `sf org open` (`Invalid_Scope`). Re-auth with `sf org login web
   --instance-url <sandbox-url>` for full scope.
6. **VS Code + Homebrew PATH**: the `sf` binary in `/opt/homebrew/bin` isn't on a
   GUI-launched VS Code's PATH → the extension errors `sf: command not found`.
   Launch VS Code from a terminal (`code .`), or the integrated terminal works.
7. **hardis routes prompts to the VS Code UI** (the "WS Client started / Look up
   in VS Code" behavior) when the extension is running. For plain terminal
   prompts, close VS Code and run the command in a standalone terminal.
8. **`main` branch ≠ `prod` environment name.** The gate maps `main → prod` when
   binding to the environment; keep that mapping if you rename anything.
9. **New orgs default to External Client Apps**, not Connected Apps — same JWT
   capability, but Settings (what the app can do) and Policies (who can use it)
   are separate sections.
