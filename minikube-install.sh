# This script installs Minikube, Cilium, and Hubble on a Linux system.
# It also sets up a Minikube cluster with Cilium as the CNI and enables Hubble for observability.
# It assumes that you have curl, wget, and tar installed on your system.
# It also assumes that you have sudo privileges to install packages and modify system files.
# The script performs the following steps:
# 1. Install Minikube and Cilium CLI
# 2. Start a Minikube cluster with 2 nodes
# 3. Install Cilium as the CNI
# 4. Enable Hubble for observability
# 5. Run a sample Nginx deployment and expose it
# 6. Test connectivity to the Nginx service
# 7. Install Hubble and run observability commands
# 8. Install Krew and Cyclonus for additional Kubernetes functionality
# 9. Create a NetworkPolicy to deny all ingress traffic to the Nginx deployment
# 10. Clean up resources and exit
#!/bin/bash
# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi
# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "curl could not be found. Installing curl..."
    apt update && apt install -y curl
fi
# Check if wget is installed
if ! command -v wget &> /dev/null; then
    echo "wget could not be found. Installing wget..."
    apt update && apt install -y wget
fi
# Check if tar is installed
if ! command -v tar &> /dev/null; then
    echo "tar could not be found. Installing tar..."
    apt update && apt install -y tar
fi
# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl could not be found. Installing kubectl..."
    snap install kubectl --classic
fi



curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo apt install --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system
adduser vm libvirt

minikube start --nodes 2

k get nodes
kubectl get nodes
minikube kubectl
minikube kubectl get nodes
cilium install

source <(minikube completion bash)

minikube addons  list

minikube addons enable dashboard
minikube addons enable ingress
minikube addons enable metrics-server


vm@ST-10-04:~$ minikube dashboard
🤔  Verifying dashboard health ...
🚀  Launching proxy ...
🤔  Verifying proxy health ...
🎉  Opening http://127.0.0.1:37097/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/ in your default browser...
👉  http://127.0.0.1:37097/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/
# minikube dashboard --url

ssh -L 12345:localhost:37097 vm@192.168.48.134


cd 010-k8s-install/

minikube addons enable ingress-dns

minikube ip

cilium status
cilium hubble enable
cilium connectivity test

kubectl get nodes
kubectl apply -f https://k8s.io/examples/application/deployment.yaml


kubectl get pods -A -o wide
cilium connectivity test stop
cilium connectivity test --help
cilium connectivity test --all-flows
kubectl get pods -A -o wide

kubectl expose deployment/nginx-deployment --port=80 --type=NodePort
kubectl get svc

curl -s http://10.103.122.240:31284



cilium hubble port-forward&

minikube service list
kubectl get svc
curl -s http://192.168.39.101:31284

minikube service nginx-deployment

minikube service nginx-deployment
minikube service nginx-deployment --url

sudo apt install w3m
minikube service nginx-deployment

minikube pause
minikube unpause


kubectl apply -f 01-namespace-rbac.yaml 
kubectl apply -f 02-main-resources.yaml 
kubectl apply -f 03-node-viewer.yaml 
kubectl apply -f k8s-cluster-test.yaml 

minikube ssh minikube

kubectl get nodes
minikube ssh -n m02

cilium hubble port-forward&
cilium hubble status

# Install Hubble

HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

hubble status
hubble observe

kubectl run web --image=nginx --labels="app=web" --expose --port=80
kubectl run --rm -i -t --image=alpine wget-test -- sh

hubble observe
hubble observe --pod=web
hubble observe --protocol=http
kubectl run --rm -i -t --image=alpine wget-test -- sh
hubble observe --protocol=http

hubble observe 
kubectl delete svc/web pod/web

kubectl krew install cyclonus
(   set -x; cd "$(mktemp -d)" &&   OS="$(uname | tr '[:upper:]' '[:lower:]')" &&   ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&   KREW="krew-${OS}_${ARCH}" &&   curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&   tar zxvf "${KREW}.tar.gz" &&   ./"${KREW}" install krew; )
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

kubectl krew install cyclonus
kubectl cyclonus
kubectl run web --image=nginx --labels="app=web" --expose --port=80
kubectl run --rm -i -t --image=alpine test-$RANDOM -- sh


kubectl apply -f - <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: web-deny-all
spec:
  podSelector:
    matchLabels:
      app: web
  ingress: []
EOF


kubectl cyclonus -A
kubectl run --rm -i -t --image=alpine test-$RANDOM -- sh
hubble observe 
cilium hubble port-forward &

kubectl run --rm -i -t --image=alpine test-$RANDOM -- sh

hubble observe -A
hubble observe -n default
kubectl delete pod web
kubectl delete service web
kubectl delete networkpolicy web-deny-all

