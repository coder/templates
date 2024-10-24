---
display_name: Docker (Code-Server)
description: Deploys Coder and Microsoft's code-server (VS Code Web) in a container
icon: ../../../site/static/icon/docker.svg
maintainer_github: coder
verified: true
tags: [docker, container]
---

# code-server (VS Code) template for a workspace in a container on a Docker host

### Apps included

1. A web-based terminal
1. Coder code-server IDE
1. Microsoft's code-server IDE aka VS Code Server

### Additional bash scripting

1. Prompt user and clone/install a dotfiles repository (for personalization settings)
2. Prompt user for container image to use
3. Prompt user for repo to clone
4. Prompt user for which VS Code extension to install
5. Clone repo
6. Download, install and start code-server (VS Code-in-a-browser)

### Extension Marketplaces

1. Coder's code-server installs from [Open VSX](https://open-vsx.org/)
1. Microsoft's code-server installs from [Microsoft](https://marketplace.visualstudio.com/)

### Resources

[Matifali template with Microsoft VS Code Server](https://github.com/matifali/coder-templates/tree/main/deeplearning)

[Matifali Dockerfile adding Microsoft VS Code Server](https://github.com/matifali/dockerdl/blob/main/base.Dockerfile)

[Microsoft VS Code Server home page](https://code.visualstudio.com/docs/remote/vscode-server)

[Coder's GoLang v2 repo](https://github.com/coder/coder)

[Coder's code-server TypeScript repo](https://github.com/coder/code-server)

[Docker Terraform provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
