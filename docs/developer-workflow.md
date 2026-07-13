# Developer Workflow — feature development & back-promotion

How a developer starts a task, saves work, and — the focus of this doc — **pulls
a teammate's already-merged functionality into their own sandbox** ("back-promotion").

## The mental model (read this first)

**Git is the source of truth, not the org.** When a teammate ships a feature via a
PR, that feature lives in the **branch** (once merged to `dev`), not in "their org".
There is no magic org-to-org copy between sandboxes. To get their work you always:

> sync your branch with `dev` → deploy that source to **your** sandbox.

Normal promotion flows **up** (`dev → uat → main`). **Back-promotion flows down** —
from the shared integration branch back into your feature branch and sandbox — so
you stay in sync with what teammates have integrated.

Branch → org map: `dev` → dev sandbox · `uat` → uat sandbox · `main` → PROD.

## 1. Start a task

```bash
sf hardis work new
```
Creates a `feature/<task>` branch from the **latest** `origin/dev` and points your
CLI at your target sandbox. (It branches from `origin/dev`, so you always start
from current integration state.)

## 2. Develop and save

Build in your sandbox, then:
```bash
sf hardis work save
```
Computes the metadata delta from your changes, commits, pushes, and opens the PR
to `dev`. The PR Quality Gate (static analysis, check-only deploy, secret scan,
undeclared-deletion check) runs automatically on open.

## 3. Back-promote: bring a teammate's merged work into your sandbox

Once their PR is **merged to `dev`**:
```bash
sf hardis work backpromote \
  -o <your-sandbox-alias> \   # your org (defaults to your configured target-org)
  --parentbranch dev \        # where you pull from (the integration branch)
  --from <PR-number>          # optional: start point (a PR # or commit SHA)
```

What it does (verified against sfdx-hardis 7.x, Beta):
1. **Pre-flight** — requires a clean git working directory.
2. **Scope selection** — lists merged PRs on `dev` (grouped with commits); you pick
   up to which PR to back-promote. It tracks the last back-promoted commit for
   incremental runs.
3. **Delta** — uses `sfdx-git-delta` to compute the metadata difference between
   your last back-promoted state and the selected target.
4. **Conflict detection** — retrieves the same metadata from your org, diffs it
   against local, and produces Excel + PDF conflict reports.
5. **Interactive validation** — you review/deselect items; destructive changes
   need explicit confirmation.
6. **Deploy** — deploys the selected metadata to your sandbox (`NoTestRun`, or
   `RunSpecifiedTests` if the PRs configure test classes).

Add `--agent` to run non-interactively (automation); `--from` is then required
when there is no previous back-promote state.

### Manual equivalent (what it does under the hood)

```bash
git checkout feature/my-task
git merge origin/dev                              # bring merged changes into your branch
sf hardis project deploy smart -o <your-sandbox>  # deploy the updated source to your org
```

## Caveats

- **Metadata only — no data.** Seed/reference data is separate (SFDMU /
  `dataPackages` in `config/.sfdx-hardis.yml`).
- **Back-promote brings ALL merged parent-branch changes**, not just one teammate's
  feature. If you want *only* one specific change, that's a **cherry-pick**, not a
  back-promote.
- **Clean working directory required** — commit or stash your in-progress work first.
- **Don't build on unmerged work.** If a teammate's PR is still open, depending on
  it is fragile (their PR can change in review). Prefer back-promoting what is
  already integrated; if you truly must, branch off their branch and accept the risk.

## Pilot vs. production reality

- **This pilot** uses a single shared dev sandbox: every merge to `dev` triggers
  `Deploy to DEV`, which keeps that one org current for everyone — so back-promote
  is effectively a no-op here (nothing to pull; the org already matches `dev`).
- **With per-developer sandboxes** (the real multi-dev setup), back-promote is the
  daily tool to sync your personal sandbox with what the team has merged.

## Hotfix flow (urgent production fixes)

A hotfix skips the normal `dev → uat → main` release train to patch prod fast.
The half most teams get wrong is the **back-propagation**: a hotfix is not done
until it has flowed back **down** to `uat` and `dev`. Otherwise the next normal
promotion deploys `dev`'s version of the file — without the fix — and silently
overwrites it (drift → the bug regresses in prod).

### Steps

```bash
# 1. Branch from main (= what is actually live in prod), NOT from dev
git checkout -b hotfix/<issue> origin/main

# 2. Fix + test, then open a PR: hotfix/<issue> -> main
#    The PR gate check-only-validates against the PROD org before merge.

# 3. Merge -> "Deploy to PRODUCTION" ships the fix. Delete the hotfix branch.

# 4. BACK-PROPAGATE so uat and dev don't drift. Cherry-pick keeps it to the single
#    fix commit and avoids squash-scramble conflicts:
git checkout uat && git cherry-pick <hotfix-sha>   # -> push/PR to uat (deploy-uat applies it)
git checkout dev && git cherry-pick <hotfix-sha>   # -> push/PR to dev (deploy-dev applies it)
```

### Why branch from `main` (not `dev`)

- **Isolation:** `main` is the exact prod state, so the hotfix carries *only* the
  fix. Branching from `dev` would drag dev's unreleased work into prod.
- **Speed:** it goes straight to prod instead of waiting in the `dev → uat → main` queue.

### When to hotfix vs. normal flow

- **Hotfix:** an urgent prod defect that cannot wait for the normal release train.
- **Everything else:** the normal `dev → uat → main` flow.

### Regulated-org note

A hotfix still goes through the PR gate (check-only validation against prod) — it is
never merged blind. With required reviewers enabled (org cutover), a hotfix still
needs approval, typically via an expedited / on-call approver — never none.

> **Golden rule:** a hotfix is not finished until it is back on `uat` and `dev`.
