# k8s-setup-w-cilium

Self-contained setup for a 4-node Kubernetes cluster (1 control plane + 3 workers) on Ubuntu 24.04 Multipass VMs, with **Cilium** as the CNI.

Sibling of [../k8s-setup-w-calico/](../k8s-setup-w-calico/) — same layout, same inventory contract; the only behavioural difference is that `playbooks/install-cluster.yaml` installs the Cilium CLI on the control plane and runs `cilium install` instead of applying a Calico manifest.

All cluster create/delete/maintenance operations are driven from `inventory/nodes.ini`. Everything needed lives inside this folder.

## Layout

```
k8s-setup-w-cilium/
├── ansible.cfg                 # points ansible at inventory/nodes.ini
├── run.sh                      # wrapper: ansible-playbook -b -K <file> [--check|--syntax-check|--debug=true]
├── cloud-init.yaml             # seeded into each VM at launch
├── inventory/
│   ├── nodes.ini               # single source of truth for hosts
│   ├── multipass-ssh-key       # 0600
│   └── multipass-ssh-key.pub
├── playbooks/
│   ├── install-cluster.yaml    # containerd + kubeadm + Cilium (via cilium CLI)
│   ├── delete-cluster.yaml     # kubeadm reset + package/config purge + Cilium state cleanup
│   ├── apt-update-upgrade.yaml
│   └── reboot-hosts.yaml
└── scripts/
    ├── create-vms.sh
    ├── update-inventory.sh
    └── snapshot.sh
```

## Versions

- Ubuntu 24.04 LTS on each VM
- Kubernetes **1.32.2** (repo `pkgs.k8s.io/core:/stable:/v1.32`)
- Cilium CLI: `latest` from `cilium/cilium-cli` stable channel (pin via `cilium_cli_version` in the playbook)
- containerd via Docker APT repo

Cilium is installed with `--set ipam.mode=kubernetes` so it honours the `podSubnet` kubeadm configures (`10.244.0.0/16` here — changed from the Calico variant's `192.168.0.0/16`).

## Bring up a fresh cluster

Run everything from inside this folder.

```shell
# 1. Launch 4 VMs (control-plane-01 + worker-01..03)
bash scripts/create-vms.sh

# 2. Sync Multipass-assigned IPs into inventory/nodes.ini
bash scripts/update-inventory.sh inventory/nodes.ini

# 3. Update/upgrade all nodes (safe to re-run anytime)
bash run.sh playbooks/apt-update-upgrade.yaml

# 4. (Optional) snapshot clean baseline
bash scripts/snapshot.sh k8s-pre-install

# 5. Install the cluster (kubeadm + Cilium)
bash run.sh playbooks/install-cluster.yaml

# 6. (Optional) snapshot post-install
bash scripts/snapshot.sh k8s-install-completed
```

Verify:

```shell
multipass shell control-plane-01
kubectl get nodes -w
kubectl get pods -n kube-system
cilium status
cilium connectivity test --request-timeout 30s --connect-timeout 10s
```

## Hubble (optional)

Once Cilium is healthy, from `control-plane-01`:

```shell
cilium hubble enable --ui
cilium hubble port-forward &
# then: hubble status / hubble observe
```

Full L4/L7 policy lab (xwing/tiefighter/deathstar + CiliumNetworkPolicy) in [../README-CILIUM-LABS-UBUNTU-VMs.md](../README-CILIUM-LABS-UBUNTU-VMs.md).

## Tear down the cluster (keep VMs)

```shell
bash run.sh playbooks/delete-cluster.yaml
```

Resets kubeadm, stops kubelet/containerd, purges packages + CNI config, removes Cilium interfaces (`cilium_host`/`cilium_net`/`cilium_vxlan`/`cilium_geneve` and `lxc*`) and the `cilium` CLI binary. VMs remain — re-run `install-cluster.yaml` to reinstall.

## Destroy VMs entirely

```shell
multipass delete control-plane-01 worker-01 worker-02 worker-03 --purge
```

## Maintenance

- **Patch nodes:** `bash run.sh playbooks/apt-update-upgrade.yaml`
- **Rolling reboot:** `bash run.sh playbooks/reboot-hosts.yaml`
- **Re-sync IPs after VMs restart:** `bash scripts/update-inventory.sh inventory/nodes.ini`

`run.sh` flags: `--check` (dry-run), `--syntax-check`, `--debug=true` (-vvvv).

## Inventory contract

Same as the Calico variant: [inventory/nodes.ini](inventory/nodes.ini) defines groups `control_plane`, `workers`, and `k8s_cluster`. Ansible user is `vm`; SSH key is `inventory/multipass-ssh-key`.

Inventory hostnames (`st-10-01..04`) differ from Multipass VM names (`control-plane-01`, `worker-01..03`); `scripts/update-inventory.sh` handles the mapping.

## Switching between Calico and Cilium

Don't run both installers against the same cluster without `delete-cluster.yaml` in between — the CNI state (interfaces, iptables/eBPF rules, `/etc/cni/net.d`) has to be wiped before the other installs cleanly.
