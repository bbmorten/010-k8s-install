kubectl create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=bbmorten \
  --docker-password=XXXXXX \
  --docker-email=bbmorten@gmail.com

kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "dockerhub-creds"}]}'
kubectl patch serviceaccount default -p '{"imagePullSecrets": []}'
kubectl delete secret dockerhub-creds


# Download nerdctl (check latest version at: https://github.com/containerd/nerdctl/releases)
wget https://github.com/containerd/nerdctl/releases/download/v1.5.0/nerdctl-1.5.0-linux-amd64.tar.gz

# Extract it
tar -xvf nerdctl-1.5.0-linux-amd64.tar.gz

# Move to a directory in your PATH
sudo mv nerdctl /usr/local/bin/

sudo nerdctl login -u bbmorten
sudo nerdctl --namespace=k8s.io pull bitnami/kubectl:latest


sudo nerdctl run -d -p 5000:5000 --name registry registry:2

sudo nerdctl pull bitnami/kubectl:latest
sudo nerdctl tag bitnami/kubectl:latest 192.168.48.61:5000/kubectl:latest
sudo nerdctl push 192.168.48.61:5000/kubectl:latest # failed
sudo nerdctl push 192.168.48.61:5000/kubectl:latest --insecure-registry