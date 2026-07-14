# Architecture

```mermaid
flowchart TD
    Push[Push to main] --> CI[CI: build, test, push image]
    CI --> BumpDev[kustomize edit set image - dev overlay]
    BumpDev --> CommitDev[git commit + push]
    CommitDev --> ArgoDev[ArgoCD dev-app: automated sync]
    ArgoDev --> Dev[dev namespace]

    Human1[Human: run 'Promote to Staging'] --> ReadDevTag[Read current dev image tag]
    ReadDevTag --> BumpStaging[kustomize edit set image - staging overlay]
    BumpStaging --> CommitStaging[git commit + push]
    CommitStaging --> ArgoStaging[ArgoCD staging-app: automated sync]
    ArgoStaging --> Staging[staging namespace]

    Human2[Human: run 'Promote to Production'] --> GateCheck{GitHub Environment 'production':<br/>required reviewer approval}
    GateCheck -->|approved| ReadStagingTag[Read current staging image tag]
    GateCheck -->|not approved| Blocked[Workflow blocked - no commit happens]
    ReadStagingTag --> BumpProd[kustomize edit set image - prod overlay]
    BumpProd --> CommitProd[git commit + push + git tag]
    CommitProd --> ArgoProdWait[ArgoCD prod-app: sync status = OutOfSync]
    ArgoProdWait --> Human3[Human: argocd app sync prod-app]
    Human3 --> Prod[prod namespace]
```

## Why two separate gates before prod

**Gate 1 — GitHub Environment required reviewer** (before the Git commit
happens): stops the *intent* to promote from even reaching version control
without sign-off. This is the "should we ship this" decision.

**Gate 2 — ArgoCD manual sync** (before the commit is actually applied to
the cluster): stops the *deployment* from happening automatically even after
it's been approved and committed. This is the "is now actually a safe
moment to deploy" decision — useful if, say, an approved promotion sits
overnight and someone wants to double check nothing else changed before
clicking Sync the next morning.

Two gates instead of one is a deliberate defense-in-depth choice, not
redundancy for its own sake — see `docs/INTERVIEW_TALKING_POINTS.md` for the
tradeoffs.

## Why dev has zero gates

Dev is meant to be disposable and fast — the whole point of having a dev
environment is to see your change running quickly. Adding any approval step
here just slows down the feedback loop without protecting anything
important; nothing depends on dev being stable.
