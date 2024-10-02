---
display_name: Envbox with dockerd
description: Alternative to unprotected dockerd side-cars or sysbox on the host nodes
icon: ../../../site/static/icon/aws.svg
maintainer_github: coder
verified: true
tags: [envbox, kubernetes, cloud, docker-in-docker]
---

# Kubernetes pod with a privileged container running dockerd

### Apps included
1. A web-based terminal
1. VS Code Web (powered by code-server)

### Template Admin inputs
1. namespace
1. K8s permissions method (.kube/config or control plane service account)
1. Envbox inputs (e.g., inner and outer container CPU, Memory, mounts)

### Developer inputs
1. Dotfiles repo

> Future inputs may include CPU, memory and $HOME volume storage size

### Additional bash scripting
1. Start a python web server to show web-based port forwarding
1. Pull an NGINX image from DockerHub and `docker run` on port `8080` to show in web-based port forwarding

### Resources

[envbox docs](https://coder.com/docs/v2/latest/templates/docker-in-workspaces#envbox)

[envbox OSS project](https://github.com/coder/envbox)

[envbox starter template](https://github.com/coder/coder/tree/main/examples/templates/envbox)

[Nestybox (acquired by Docker, Inc.) - creators of sysbox container runtime](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/security.md)

[nginx docker image](https://hub.docker.com/_/nginx)

[docker cli run commands](https://docs.docker.com/engine/reference/commandline/run/)