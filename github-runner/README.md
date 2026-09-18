# GitHub Runner

This chart is a local wrapper for a GitHub self-hosted runner intended for a Rancher/k3s home-lab cluster.

It assumes the GitHub Actions Runner Controller (ARC) is already installed in the target cluster.

## What this chart deploys

This chart creates a `RunnerDeployment` custom resource that ARC reconciles into self-hosted GitHub runner pods.

## Install ARC first

```bash
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

kubectl create namespace actions-runner-system
helm install arc actions-runner-controller/actions-runner-controller \
  --namespace actions-runner-system \
  --create-namespace
```

## Create the GitHub token secret

Create a secret with a GitHub registration token or PAT depending on your ARC setup:

```bash
kubectl create secret generic github-runner-token \
  --namespace default \
  --from-literal=github_token='REPLACE_WITH_GITHUB_TOKEN'
```

## Install this chart

```bash
helm install github-runner ./github-runner \
  --namespace default \
  --set github.repository=YOUR_ORG/YOUR_REPO
```

## Update values

Edit `values.yaml` or pass overrides at install time:

```bash
helm upgrade github-runner ./github-runner \
  --install \
  --namespace default \
  --set github.repository=YOUR_ORG/YOUR_REPO \
  --set runner.replicaCount=1
```

## Notes

- This chart is maintained under the `helm-central` repository alongside the
  other home-lab charts.
- ARC is installed separately from its upstream Helm chart; update the ARC
  controller independently from this runner chart.
- If you want to use a different runner type (org-level, enterprise-level, or a custom runner image), edit the values and `RunnerDeployment` template accordingly.
