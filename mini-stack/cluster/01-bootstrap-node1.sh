#!/usr/bin/env bash
# Run this on NODE1 ONLY — it bootstraps the cluster and the kube-vip VIP.
set -euo pipefail
source ./00-vars.env

MANIFEST_DIR=/var/lib/rancher/k3s/server/manifests
sudo mkdir -p "$MANIFEST_DIR"

# RBAC kube-vip needs to talk to the API server (it runs as a DaemonSet
# under k3s, not a static pod, so it needs real permissions).
curl -sfL https://kube-vip.io/manifests/rbac.yaml | sudo tee "$MANIFEST_DIR/kube-vip-rbac.yaml" >/dev/null

# Generate the kube-vip DaemonSet manifest using containerd directly
# (k3s bundles containerd, so no separate Docker install needed).
sudo ctr image pull ghcr.io/kube-vip/kube-vip:"$KVVERSION"
sudo ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:"$KVVERSION" vip \
  /kube-vip manifest daemonset \
    --interface "$INTERFACE" \
    --address "$VIP" \
    --inCluster \
    --taint \
    --controlplane \
    --services \
    --arp \
    --leaderElection \
  | sudo tee "$MANIFEST_DIR/kube-vip.yaml" >/dev/null

# k3s watches this manifests directory and applies whatever it finds as
# soon as its own API server comes up — that's what avoids the chicken-
# and-egg problem of needing a cluster to install the thing the cluster
# needs to bootstrap.
#
# --tls-san=$VIP: bakes the VIP into the API server's TLS certificate now,
# since it can't be added after the fact without regenerating certs.
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --tls-san="$VIP"

echo "Node token for joining node2/node3 (copy this):"
sudo cat /var/lib/rancher/k3s/server/node-token
