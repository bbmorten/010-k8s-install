#!/bin/bash

# On the HOST
# Create Multipass Instances
multipass launch --name control-plane-01 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml
multipass launch --name worker-01 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml 
multipass launch --name worker-02 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml
multipass launch --name worker-03 --cpus 2 --memory 4G --disk 20G 24.04 --cloud-init cloud-init.yaml

