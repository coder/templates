---
display_name: Kubernetes (RStudio Open Source)
description: Demonstrates an RStudio-Server Open Source container
icon: ../../../site/static/icon/rstudio.svg
maintainer_github: coder
verified: true
tags: [cloud, kubernetes]
---

# RStudio IDE template for a workspace in a Kubernetes pod

### Apps included
1. A web-based terminal
1. RStudio IDE
1. coder-server

### Additional Scripting
1. All R-related installation is handled by the "rstudio-server" submodule.

### Authentication

This template will use ~/.kube/config to authenticate to a Kubernetes cluster on GCP

Be sure to change the workspaces_namespace variable to the Kubernetes namespace the workspace will be deployed to

### Resources
[RStudio release notes](https://www.rstudio.com/products/rstudio/release-notes/)
[RStudio Management Guide](https://docs.posit.co/ide/server-pro/)
[RStudio rserver.conf](https://docs.posit.co/ide/server-pro/reference/rserver_conf.html)