---
name: Use code-server with a private extension marketplace and internal CA
description: Use code-server with a private extension marketplace and internal CA
tags: [cloud, kubernetes, marketplace]
---

# code-server using a private extension marketplace and internal CA

## Apps included

1. A web-based terminal.
2. VS Code IDE in a browser (Coder's `code-server` project).

## User-configurable parameters

1. CPU cores
2. Memory
3. Disk size

## Terraform variables

Terraform variables are managed by the template author. Workspace users are not
able to modify template variables. This template has these Terraform variables:

1. `use_kubeconfig` (default false): set this to true if the Coder host is
  running outside the Kubernetes cluster for workspaces. A valid
  `~/.kube/config` must be present on the Coder host. Alternatively, you can
  edit the template to use a different form of authentication.
2. `namespace` (required): the Kubernetes namespace in which to create workspaces
3. `cert_name` (required): name for the marketplace's internal CA certificate.
4. `marketplace` (required): the full base URL of the private marketplace.

Managed Terraform variables are set in `coder templates create` and
`coder templates push`.

```
coder templates create --variable workspaces_namespace='my-namespace' --variable use_kubeconfig=true --default-ttl 2h -y
coder templates push --variable workspaces_namespace='my-namespace' --variable use_kubeconfig=true  -y
```

Alternatively, the Terraform variables can be specified in the template UI.

## Marketplace

For actually deploying the marketplace and adding extensions, see the
[code-marketplace repo](https://github.com/coder/code-marketplace).
