---
display_name: Docker (KasmVNC)
description: Runs KasmVNC virtual desktop on Docker
icon: ../../../site/static/icon/docker.svg
maintainer_github: coder
verified: true
tags: [docker, container]
---

# Run a virtual desktop to container workspace on a Docker host

### Apps included
1. A web-based terminal
1. code-server IDE (VS Code-in-a-browser)
3. Insomnia, a non-web API tool
4. KasmVNC Desktop

### Additional bash scripting
1. Prompt user and clone/install a dotfiles repository (for personalization settings)
1. Start Insomnia
1. Start KasmVNC
1. Download, install and start code-server (VS Code-in-a-browser)

### Known limitations
1. The image inherits from KasmVNC's Desktop image so is not an entirely custom image

### Authentication


### Resources
[Terraform Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)

[Image Resource](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/image)

