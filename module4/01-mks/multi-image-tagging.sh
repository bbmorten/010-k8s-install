#!/bin/bash

export DOCKER_REPO=bbmorten

images=(
  "ubuntu:latest"
  "nginx:latest"
  "busybox:latest"
  "alpine:latest"
  "nicolaka/netshoot:latest"
)

for image in "${images[@]}"; do
  name="${image%%:*}"                     # full repo name
  tag="${image#*:}"                       # tag (e.g. latest)

  [[ "$name" == "$tag" ]] && tag="latest"

  short_name="${name##*/}"               # strip namespace if any
  target="${DOCKER_REPO}/${short_name}:${tag}" # target name

  echo "docker pull --platform=linux/x86_64 $image"
  echo "docker tag  $image $target"
  echo "docker push $target"
  echo "###############################################"
done
