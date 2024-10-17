---
display_name: Kubernetes (Multi-Modules)
description: Demonstrates using multiple and reusable Coder-supported Terraform modules.
icon: ../../../site/static/icon/k8s.png
maintainer_github: coder
verified: true
tags: [container, kubernetes]
---

# Use Terraform modules to build a container workspace in a Kubernetes pod

### Apps included
1. A web-based terminal
1. Microsoft Visual Studio Code Server IDE
1. Coder's code-server IDE

### Additional input variables and bash scripting
1. Prompt user and clone/install a dotfiles repository (for personalization settings)
1. Prompt user for compute options (CPU core, memory, and disk)
1. Prompt user for container image to use
1. Prompt user for repo to clone
1. Clone source code repo
1. Download, install and start latest Microsoft Visual Studio Code Server

### Images/languages to choose from
1. NodeJS
1. Golang
1. Java
1. Base (for Python)

### Terraform modules

This template demonstrates how to re-use and pull Terraform snippets from https://registry.coder.com for common components like:
1. The `code-server` IDE (VS Code in a browser)
1. Microsoft Visual Studio Code Server (VS Code in a browser)
1. Automatically log into the Coder CLI in the workspace
1. Clone a code repository
1. Clone a dotfiles repository for personalization

### Managed Terraform variables
Managed Terraform variables can be freely managed by the template author to build templates. Workspace users are not able to modify template variables. This template has two managed Terraform variables:
1. `use_kubeconfig` which tells Coder which cluster and where to get the Kubernetes service account
2. `workspaces_namespace` which tells Coder which namespace to create the workspace pdo

Managed terraform variables are set in coder templates create & coder templates push.

`coder templates create --variable workspaces_namespace='my-namespace' --variable use_kubeconfig=true --default-ttl 2h -y`

`coder templates push --variable workspaces_namespace='my-namespace' --variable use_kubeconfig=true  -y`

Alternatively, the managed terraform variables can be specified in the template UI

### Authentication

This template will use ~/.kube/config or if the control plane's service account token to authenticate to a Kubernetes cluster

Be sure to specify the workspaces_namespace variable during workspace creation to the Kubernetes namespace the workspace will be deployed to

### Resources
[Coder's Terraform Provider - parameters](https://registry.terraform.io/providers/coder/coder/latest/docs/data-sources/parameter)

[NodeJS coder-react repo](https://github.com/coder/coder-react)

[Coder's GoLang v2 repo](https://github.com/coder/coder)

[Coder's code-server TypeScript repo](https://github.com/coder/code-server)

[Java Hello World repo](https://github.com/coder/java_helloworld)

[Python repo](https://github.com/coder/python_commissions)

