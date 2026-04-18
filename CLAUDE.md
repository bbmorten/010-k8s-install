# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Teaching/lab repo that provisions a 4-node Kubernetes 1.32 cluster (1 control plane + 3 workers) on Ubuntu 24.04 VMs created via Multipass, then layers on security labs (Cilium, kube-bench, AppArmor, Pod Security, kubesec, docker security, NFS storage, MetalLB).

## Core workflow

Driven from the host machine. The standard bring-up sequence (from [README.md](README.md)):

```
bash ./01-create-multipass-instances.sh         # launch 4 VMs with cloud-init.yaml
bash ./update-nodes-ini.sh inventory/nodes.ini  # sync Multipass-assigned IPs into inventory
bash ./run.sh apt-update-upgrade.yaml           # update all VMs
bash ./snapshot.sh k8s-pre-install              # stop VMs, snapshot, restart
bash ./run.sh ./consolidated-k8s-installer-3.yaml
bash ./snapshot.sh k8s-install-completed
```

Test deployment is three-phase (RBAC → main → node-viewer): apply `01-namespace-rbac.yaml`, `02-main-resources.yaml`, `03-node-viewer.yaml` with ~10s waits between.

Teardown: `multipass delete control-plane-01 worker-01 worker-02 worker-03 --purge`, or the `delete-cluster-v1.yaml` / `delete-cluster-v2.yaml` playbooks for `kubeadm reset`-style cleanup.

## Running playbooks

All Ansible invocation goes through [run.sh](run.sh) — it sets `ANSIBLE_CONFIG` to the repo's [ansible.cfg](ansible.cfg) and runs `ansible-playbook -b -K <playbook>`. Flags: `--debug=true` (-vvvv), `--syntax-check`, `--check` (dry-run). Do not call `ansible-playbook` directly; the config path wiring matters.

Inventory lives in [inventory/nodes.ini](inventory/nodes.ini) with groups `control_plane`, `workers`, and the combined `k8s_cluster`. SSH uses the repo-local `inventory/multipass-ssh-key` (mode 0600 required). Ansible user is `vm`.

## Installer structure

[consolidated-k8s-installer-3.yaml](consolidated-k8s-installer-3.yaml) is the single source of truth for cluster install. It builds `/etc/hosts` dynamically from the Ansible inventory (not static), then installs containerd, kubeadm/kubelet/kubectl, initializes the control plane, joins workers, and applies the CNI. When modifying install steps, edit this file rather than the legacy per-step playbooks in [archive/](archive/).

Shared container-runtime assets live in [common/](common/): `config-48-31.toml` (containerd config), `deploy-containerd-config.yaml`, `install-docker.sh`, etc.

## Snapshots

[snapshot.sh](snapshot.sh) stops all 4 VMs, snapshots each with the given name, then restarts (pass `--no-restart` to leave them stopped). The VM list is hardcoded — update the script if node names change. Use snapshots as rollback points between lab stages.

## IP-address management

Multipass assigns dynamic IPs. [update-nodes-ini.sh](update-nodes-ini.sh) reconciles `multipass list` output with `inventory/nodes.ini` and tolerates three hostname formats (with dashes, no dashes, underscores). Always run it after VM create/restart before running any playbook. It auto-backs up to `nodes.ini.bak.<timestamp>`.

Note: inventory hostnames (`st-10-01..04`) intentionally differ from Multipass VM names (`control-plane-01`, `worker-01..03`) — the reconcile script handles the mapping.

## Self-contained variants

Two sibling folders reimplement the install as self-contained Ansible projects (no paths leak outside the folder). Each has its own `ansible.cfg`, `run.sh`, `inventory/`, and `playbooks/`. **The root-level workflow above does not apply inside these folders.**

- [k8s-setup-w-calico/](k8s-setup-w-calico/) — Calico CNI (v3.29.2 via manifest apply), pod CIDR `192.168.0.0/16`.
- [k8s-setup-w-cilium/](k8s-setup-w-cilium/) — Cilium CNI (1.16.5 via the cilium CLI with `kubeProxyReplacement=true`), pod CIDR `10.244.0.0/16`. Built from the calico folder as a template; the two are **structural mirrors** — same `ansible.cfg`, `run.sh`, `inventory/` layout, same playbook names, same `scripts/fetch-kubeconfig.sh` and `tests/nginx-4-instances.yaml`. They diverge only in: (a) the CNI install block in `install-cluster.yaml`, (b) the CNI-specific interface/state cleanup in `delete-cluster.yaml` (`calico.1` vs `cilium_host`/`cilium_net`/`cilium_vxlan`/`lxc*` veths), (c) the `pod_network_cidr` default, (d) `fetch-kubeconfig.sh` default `CTX_NAME` (`calico-lab` vs `cilium-lab`). When editing shared logic (playbook scaffolding, logging, nginx test), apply the change to both folders.

Both assume 4 pre-existing Ubuntu 24.04 hosts at the IPs in `inventory/nodes.ini`; no VM provisioning. SSH key is `inventory/node-ssh-key`. The multipass-flavored variants will live in future `*-on-multipass/` folders with the VM lifecycle scripts.

Shared playbooks in each: `install-cluster.yaml`, `delete-cluster.yaml`, `apt-update-upgrade.yaml`, `refresh-apt-keys.yaml` (re-fetches rotated signing keys for third-party apt repos and patches legacy `.list` files to add `signed-by=`), `reboot-hosts.yaml`.

Shared helpers:

- `scripts/fetch-kubeconfig.sh` — copies `admin.conf` off the control plane and merges it into `~/.kube/config` with renamed cluster/user/context to avoid x509 errors from kubeadm's default names colliding with existing kubeconfigs. Supports `--standalone <path>` and env overrides `CP_IP`, `SSH_USER`, `SSH_KEY`, `CTX_NAME`.
- `tests/nginx-4-instances.yaml` — 4-replica nginx smoke test (NodePort 30080, Downward-API-rendered index showing pod name/IP/node/hostname). Uses `topologySpreadConstraints` to spread across the 4 nodes. CNI-agnostic.

Cilium-folder-only docs: [k8s-setup-w-cilium/README-HUBBLE.md](k8s-setup-w-cilium/README-HUBBLE.md) walks through installing the `cilium`/`hubble` CLIs on the host, enabling Hubble + Relay + UI, and `cilium hubble port-forward` for host-side `hubble observe`. [k8s-setup-w-cilium/README-TRAFFIC-GEN.md](k8s-setup-w-cilium/README-TRAFFIC-GEN.md) shows cross-namespace curl traffic against the `nginx-hello` service for Hubble flow demos.

Logging: both `run.sh` and `fetch-kubeconfig.sh` tee output to `logs/` (gitignored) with start/end banners and exit codes. `run.sh` also sets `ANSIBLE_LOG_PATH=logs/ansible-<playbook>-<timestamp>.log` for a structured Ansible log alongside the terminal transcript. When debugging failures inside these folders, check `logs/` first.

Note on `run.sh`: it invokes `ansible-playbook -b -K`, which prompts interactively for the BECOME (sudo) password. Passwordless sudo on the nodes is a documented prerequisite, but the `-K` prompt still appears — just hit Enter if sudo is passwordless, or supply the password otherwise. This makes the script unusable from non-TTY contexts (e.g., automated runners); invoke `ansible-playbook` directly in those cases.

## Lab modules

- [pod-security/](pod-security/) — Pod Security Admission, security contexts, capability drops, privilege escalation demos.
- [module4/](module4/) — `01-mks` and `02-icit` sub-labs.
- `02-module-*.{sh,yaml}` — MetalLB install, TLS secret creation, kube-bench job.
- `README-CILIUM-*`, `README-KUBESEC*`, `README-DOCKERSEC.md` — standalone lab guides (Cilium on Kind/Ubuntu VMs, kubesec on mac/linux, docker security).
- [nfs-subdir-external-provisioner.yaml](nfs-subdir-external-provisioner.yaml) + [scripts/nfs-*.sh](scripts/) — dynamic NFS storage class setup.
- [registry-playbook.yaml](registry-playbook.yaml) + [docker-registry.sh](docker-registry.sh) — private registry.

## Conventions

- Playbook filenames use numeric prefixes to indicate order (`01-`, `02-`, `03-`) but are executed individually via `run.sh`, not chained automatically.
- `any_errors_fatal: true` is used in the consolidated installer — a failure on one host aborts the whole run. Preserve this when editing.
- `.gitignore` is minimal; do not commit `inventory/nodes.ini.bak.*` backup files or Multipass-generated artifacts.
