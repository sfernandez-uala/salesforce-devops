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

## Related: pipeline back-promotion (drift prevention)

Distinct from the per-developer flow: if an urgent fix ever lands directly on a
higher branch (e.g. a hotfix straight to `main`), back-promote it **down**
(`main → uat → dev`) so the lower branches don't drift. Same principle, branch level.
