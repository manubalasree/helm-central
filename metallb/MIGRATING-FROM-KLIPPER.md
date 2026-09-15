# Migrating from Klipper (servicelb) to MetalLB

Your cluster is live and already using k3s's built-in Klipper servicelb
(confirmed via the `svclb-traefik-*` DaemonSet in `kube-system`) — so this
is a cutover, not a fresh install. Do these in order.

## Why

Klipper gives every `LoadBalancer` Service the same address: each node's
own IP, with the Service's port opened directly on the host. That's fine
for one Service (Traefik), but a second one on the same port — e.g. a
second MySQL instance also listening on 3306 — can't get its own IP from
Klipper; it would collide with the first on the same node ports. MetalLB
hands out real, distinct IPs from a pool instead, so each Service gets its
own address and can use whatever port it wants.

## 1. Disable Klipper on all 3 nodes

k3s was installed here without `--disable=servicelb`, so it has to be added
to the existing systemd unit rather than the install command. The k3s
installer writes `ExecStart` as a backslash-continued block, one flag per
line, e.g.:

```
ExecStart=/usr/local/bin/k3s \
    server \
        '--datastore-endpoint=mysql://k3s:...@tcp(192.168.2.204:3306)/k3s' \
        '--tls-san=rancher.home.arpa' \
        '--tls-san=192.168.2.204' \
        '--write-kubeconfig-mode=644' \
```

A one-line `sed` substitution can't safely target a specific line inside
that block, so edit it by hand instead. On **each** of the 3 nodes, one at
a time (this restarts k3s on that node — with the external MySQL
datastore, the other two keep serving while it does):

```bash
sudo $EDITOR /etc/systemd/system/k3s.service
```

Add a new line right after `server \`, matching the existing indentation
and quoting style:

```
        '--disable=servicelb' \
```

(order among the flag lines doesn't matter — putting it right after
`server \` just keeps it easy to spot later.)

```bash
grep -A1 'server \\' /etc/systemd/system/k3s.service   # confirm --disable=servicelb is there

sudo systemctl daemon-reload
sudo systemctl restart k3s
sudo systemctl status k3s --no-pager              # confirm it came back up
```

Then confirm Klipper is gone cluster-wide (run once, after all 3 nodes are done):

```bash
kubectl get daemonset -n kube-system | grep svclb   # expect: no output
```

If a `svclb-traefik-*` DaemonSet is still listed, Traefik's Service is still
`type: LoadBalancer` and k3s hasn't finished tearing it down — give it a
minute, or `kubectl delete pod -n kube-system -l app.kubernetes.io/name=traefik`
to force a reconcile.

## 2. Install MetalLB

From `helm-central/metallb`:

```bash
helm install metallb . -n metallb-system --create-namespace -f values-homelab.yaml
kubectl rollout status daemonset/metallb-speaker -n metallb-system
kubectl rollout status deployment/metallb-controller -n metallb-system
```

## 3. Apply the IP pool and advertisement mode

```bash
kubectl apply -f config/ipaddresspool.yaml -f config/l2advertisement.yaml
```

## 4. Confirm Traefik picks up a MetalLB IP

Traefik's Service is still `type: LoadBalancer` — it just has no backend
provisioning it anymore, so once MetalLB's controller is up it should claim
the next free IP from the pool (expect `.220`, the first address in the
range, since nothing else has claimed one yet):

```bash
kubectl get svc -n kube-system traefik
```

`EXTERNAL-IP` should now show a single `192.168.2.22x` address instead of a
node IP.

## 5. Point nginx-lb at the new address

`nginx-lb`'s `stream.conf` (in `k8s-rancher-homelab`) currently load-balances
ports 80/443 across all 3 node IPs, because that's what Klipper exposed.
Traefik now lives behind one stable MetalLB VIP instead, so replace the
`k8s_http`/`k8s_https` upstream blocks with the single address from step 4:

```nginx
upstream k8s_http {
    server 192.168.2.220:80;   # <-- the EXTERNAL-IP from `kubectl get svc -n kube-system traefik`
}
upstream k8s_https {
    server 192.168.2.220:443;
}
```

Leave `k8s_api` (port 6443) alone — that's still the 3 nodes' own control
plane, unrelated to Klipper/MetalLB.

Worth noting for later, not needed now: once Traefik has its own real,
ARP-announced LAN IP, `nginx-lb` is no longer doing anything for 80/443
that MetalLB doesn't already provide directly — clients could point straight
at `192.168.2.220`. Left as-is here since collapsing it is a separate
decision, not part of this migration.

## 6. New dedicated-IP Services (e.g. the 3 MySQL instances)

See `config/example-dedicated-ip-service.yaml` for the pattern: `type:
LoadBalancer` plus a `metallb.universe.tf/loadBalancerIPs` annotation to
pin a specific, stable address from the pool.
