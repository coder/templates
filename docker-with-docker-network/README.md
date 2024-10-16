---
display_name: Docker (Docker Network)
description: Enable a Docker host within a Docker container
icon: ../../../site/static/icon/docker.svg
maintainer_github: coder
verified: true
tags: [container, docker]
---

# Docker host template for a workspace in a Docker container

### Apps included
1. A web-based terminal
1. code-server IDE (VS Code-in-a-browser)

### Additional bash scripting
1. Start Docker daemon using a privileged Docker container
1. Prompt user and clone/install a dotfiles repository (for personalization settings)
1. Clone coder/coder repo
1. Download, install and start code-server (VS Code-in-a-browser)

### Docker resource relevant snippet

> We create a docker_network and reference it in both containers (the one
> running a Docker daemon and the workspace container). Note the docker daemon
> container is privileged.

> You can `wget` or `curl` a process in inner containers by using the docker
> daemon name which is `docker_container.dind.name`:<the port>

```sh
resource "docker_network" "private_network" {
  name = "network-${data.coder_workspace.me.id}"
}

resource "docker_container" "dind" {
  image      = "docker:dind"
  privileged = true
  network_mode = "host"
  name       = "dind-${data.coder_workspace.me.id}"
  entrypoint = ["dockerd", "-H", "tcp://0.0.0.0:2375"]
  networks_advanced {
    name = docker_network.private_network.name
  }
}

resource "docker_container" "workspace" {
  count   = data.coder_workspace.me.start_count
  image   = "coderintegration.jfrog.io/docker/coder/coder-demo/coder-demo-golang:latest"
  name    = "dev-${data.coder_workspace.me.id}"
  command = ["sh", "-c", coder_agent.coder.init_script]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.coder.token}",
    "DOCKER_HOST=${docker_container.dind.name}:2375"
  ]
  volumes {
    container_path = "/home/coder/"
    volume_name    = docker_volume.coder_volume.name
    read_only      = false
  }    
  networks_advanced {
    name = docker_network.private_network.name
  }
}
```

### Resources

[Coder Docker in Docker docs](https://coder.com/docs/coder-oss/latest/templates/docker-in-docker)