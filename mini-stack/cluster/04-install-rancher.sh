#!/usr/bin/env bash
# Run this once, from a machine with kubectl/helm pointed at the cluster
# (kubectl config use-context pointing at $VIP, or run on any node with
# KUBECONFIG=/etc/rancher/k3s/k3s.yaml, edited to use $VIP instead of
# 127.0.0.1 as the server address).
set -euo pipefail
source ./00-vars.env

# cert-manager: Rancher's default TLS mode ("rancher" self-signed CA)
# needs this installed first to issue its certs.
helm repo add jetstack https://charts.jetstack.io --force-update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true

kubectl -n cert-manager rollout status deploy/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager-webhook

# Rancher itself. hostname uses nip.io against the VIP, same trick as
# values-homelab.yaml, so it resolves from your laptop with zero DNS setup.
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
kubectl create namespace cattle-system --dry-run=client -o yaml | kubectl apply -f -
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname="rancher.$VIP.nip.io" \
  --set bootstrapPassword=changeme \
  --set replicas=3
  # If Rancher doesn't create a working Ingress automatically (k3s's
  # Traefik should be auto-detected), add:
  #   --set ingressClassName=traefik

kubectl -n cattle-system rollout status deploy/rancher

echo "Rancher UI: https://rancher.$VIP.nip.io  (bootstrap password: changeme — change it on first login)"
