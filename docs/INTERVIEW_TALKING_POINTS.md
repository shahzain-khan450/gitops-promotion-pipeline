# Interview Talking Points

## 30-second pitch

"I built a GitOps pipeline that promotes one app through dev, staging, and
production using ArgoCD's App-of-Apps pattern and Kustomize overlays —
same base manifests, environment-specific patches for replicas, resources,
and autoscaling. Dev deploys automatically on every push. Staging needs a
manual trigger. Production needs an actual GitHub-required-reviewer
approval before the promotion commit even happens, plus a second manual
ArgoCD sync before it's actually applied to the cluster."

## Why Kustomize overlays instead of copy-pasted YAML per environment

Three separate full YAML files per environment means every shared change
(a new probe, a label, a security context) has to be edited in three
places and will eventually drift. Kustomize's base + overlay pattern means
the shared definition lives once, and only the *differences* — replica
count, resource limits, environment variables — are declared per
environment. I can prove they don't drift because `scripts/validate-overlays.sh`
actually builds all three and checks each one lands in the right namespace
with the right values — that script runs on every PR, not just at review
time.

## Why two gates before prod, not one

- **A single gate is a single point of failure.** If the only protection is
  "someone has to approve the GitHub Action," an approved PR still
  auto-deploys instantly — there's no window to catch "wait, we just found
  an unrelated bug in staging" between approval and rollout.
- **The two gates check different things.** The GitHub reviewer approval is
  a human sign-off on *intent* ("yes, we should ship this"). The ArgoCD
  manual sync is a check on *timing* ("is right now actually a safe moment
  to apply it") — they're not redundant, they answer different questions.
- **This mirrors how real orgs actually gate prod**: a change-approval
  process (PR review, CAB, whatever) plus a separate deploy button, not one
  combined step.

## Why dev has zero gates and staging has a light one

Dev's whole purpose is fast feedback — gating it defeats the point. Staging
needs *some* deliberateness (you don't want every commit silently walking
into staging and confusing whoever's testing there), but doesn't need the
weight of a required-reviewer approval, because nothing user-facing depends
on staging being stable.

## Likely trap questions

- **"What if someone bypasses the pipeline and edits the prod overlay
  directly?"** ArgoCD's `selfHeal: true` on dev/staging (and even without
  it on prod, since it still diffs against Git on each poll) means any
  manual `kubectl edit` gets reported as drift and eventually reverted —
  Git stays the source of truth, not the cluster.
- **"Why store the image tag in Git instead of always deploying `:latest`
  and letting Kubernetes pull it?"** `:latest` isn't reproducible — you
  can't answer "what exactly is running in prod right now" or roll back to
  a specific known-good version. Pinning a specific tag per environment in
  Git means the deployed state is always an exact, auditable commit.
- **"How would you roll back a bad prod deploy?"** `git revert` the
  promotion commit (or manually re-run `promote-prod.yml` after
  cherry-picking an older tag) and re-sync — because the desired state
  lives in Git, rollback is a Git operation, not a manual kubectl scramble.
- **"Isn't the AppProject role binding a bit theoretical without real SSO
  groups?"** Yes — I noted that in the AppProject file itself. In a real
  deployment, `platform-team` would map to an actual OIDC/SSO group; here
  it demonstrates the RBAC *pattern* (scoping who can sync prod) rather
  than a fully wired identity provider.
- **"What's NOT production-ready here?"** No automated tests beyond an
  import smoke test, no image vulnerability scanning in CI (unlike my
  Secure Supply Chain project, deliberately kept out here to keep this
  project focused on the promotion pattern), and the AppProject's SSO
  group binding is illustrative, not wired to a real identity provider.

## Comparison to Argo Rollouts / progressive delivery

This project does *environment* promotion (dev → staging → prod), not
*progressive* delivery within a single environment (canary/blue-green
traffic shifting). Argo Rollouts solves a different problem — gradually
shifting traffic to a new version within prod itself, with automated
metric-based rollback. The two are complementary: you could put Argo
Rollouts inside the prod overlay's Deployment here without changing the
promotion pipeline around it.
