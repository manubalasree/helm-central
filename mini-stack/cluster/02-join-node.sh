#!/usr/bin/env bash
# Run this on NODE2 and NODE3 (each as its own server, joining the same
# embedded-etcd cluster node1 started). Do NOT run this on node1.
set -euo pipefail
source ./00-vars.env

if [ -z "${NODE_TOKEN:-}" ]; then
  echo "Set NODE_TOKEN to the value printed at the end of 01-bootstrap-node1.sh, e.g.:" >&2
  echo "  NODE_TOKEN=K10abc...:: ./02-join-node.sh" >&2
  exit 1
fi

# Joins via the VIP, not node1's IP directly — so node2/node3 (and any
# future node) never depend on node1 specifically being up.
curl -sfL https://get.k3s.io | sh -s - server \
  --server "https://$VIP:6443" \
  --token "$NODE_TOKEN" \
  --tls-san="$VIP"
