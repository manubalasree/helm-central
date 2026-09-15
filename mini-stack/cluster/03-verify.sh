#!/usr/bin/env bash
# Run this on any of the 3 nodes once all 3 have joined.
set -euo pipefail
source ./00-vars.env

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== nodes (expect 3, all Ready) ==="
sudo k3s kubectl get nodes -o wide

echo "=== kube-vip pods (expect 1 per node, all Running) ==="
sudo k3s kubectl get pods -n kube-system -o wide | grep kube-vip

echo "=== VIP reachability from this node ==="
curl -sk "https://$VIP:6443/livez" && echo " -> VIP is answering the API server"
