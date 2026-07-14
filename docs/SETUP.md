# Setup Guide

## 1. What you can verify right now, with no cluster and no GitHub repo

```bash
# Install kustomize if you don't have it:
# https://kubectl.docs.kubernetes.io/installation/kustomize/

./scripts/validate-overlays.sh
```

This builds `k8s/base` and all three overlays with the real `kustomize`
binary and checks each one lands in the right namespace with the right
`ENVIRONMENT` value. It's the same check that runs in CI on every PR.

You can also just look at the generated output directly:

```bash
kustomize build k8s/overlays/prod
```

## 2. Run the app locally

```bash
cd app
pip install -r requirements.txt
ENVIRONMENT=local APP_VERSION=v1 uvicorn main:app --port 8000
```

In another terminal:

```bash
curl localhost:8000/
curl localhost:8000/healthz
curl localhost:8000/metrics
```

## 3. Push this repo to GitHub

```bash
git init
git add .
git commit -m "Initial commit: GitOps multi-environment promotion pipeline"
git branch -M main
git remote add origin https://github.com/shahzain-khan450/gitops-promotion-pipeline.git
git push -u origin main
```

## 4. Setting up the production approval gate (the real part)

This is a repo *setting*, not something in the YAML — `promote-prod.yml`
references `environment: production`, but you have to create that
environment and its protection rule:

1. On GitHub: your repo → **Settings** → **Environments** → **New
   environment** → name it exactly `production`.
2. Under **Deployment protection rules**, check **Required reviewers** and
   add yourself (or a teammate) as a reviewer.
3. Save.

Now when `promote-prod.yml` runs, it will sit in a "Waiting" state in the
Actions tab until a reviewer clicks **Approve and deploy** — this is a real
GitHub feature, the same one companies use for production gates.

## 5. Run it against a real Kubernetes cluster (kind, free, local)

```bash
kind create cluster --name gitops-demo

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd

kubectl apply -f argocd/projects/gitops-demo-project.yaml
kubectl apply -f argocd/root-app-of-apps.yaml
```

Port-forward and watch the three Applications appear:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080 — get the initial admin password with:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

You should see `dev-app` and `staging-app` sync automatically, and
`prod-app` sit as `OutOfSync` until you manually sync it:

```bash
argocd app sync prod-app
```

## 6. Build and push the real image

Before `ci.yml` can succeed against your own repo, the image it builds
needs somewhere to go — GHCR under your own GitHub username works with just
the built-in `GITHUB_TOKEN` (already wired into the workflow), no extra
secrets needed.

To test the same build locally first:

```bash
cd app
docker build -t ghcr.io/shahzain-khan450/gitops-demo-app:manual-test .
docker run -p 8000:8000 -e ENVIRONMENT=local -e APP_VERSION=manual-test \
  ghcr.io/shahzain-khan450/gitops-demo-app:manual-test
curl localhost:8000/
```

## 7. Try a full promotion end-to-end

1. Change something small in `app/main.py`, push to `main` → watch `ci.yml`
   build, push, and bump the dev overlay automatically.
2. Go to **Actions** → **Promote to Staging** → **Run workflow** → type
   `promote` → confirm.
3. Go to **Actions** → **Promote to Production** → **Run workflow** → type
   `promote` → the job will sit waiting for your approval (from step 4
   above) → approve it → watch the prod overlay get bumped and a Git tag
   created.
4. If you have ArgoCD running against this repo: `argocd app sync prod-app`
   to actually deploy it.

## What's a placeholder vs. what's real

| Item | Status |
|---|---|
| Kustomize overlays | Real — built and validated with the actual binary |
| The app | Real — built and run locally, all endpoints tested |
| GitHub Actions workflow YAML | Real syntax, uses real GitHub features (Environments) |
| ArgoCD Application/AppProject manifests | Real, valid syntax — not yet applied to a live cluster in this sandbox |
| `shahzain-khan450/gitops-promotion-pipeline` repo URL in the manifests | Placeholder — update if you rename the repo |
| GHCR image | Doesn't exist until you run `ci.yml` for the first time against your own repo |
