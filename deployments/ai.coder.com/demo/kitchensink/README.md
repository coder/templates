---
display_name: Universal Workspace Template on K8s
description: Demonstrates "all things possible" in Coder Workspaces
icon: ../../../site/static/icon/code.png
maintainer_github: coder
verified: true
tags: [kubernetes, container]
---

# Kitchen Sink - Universal Workspace on K8s

> A comprehensive Coder workspace template demonstrating "all things possible" with Coder workspaces. This template is designed for demo purposes and showcases the full range of features available in Coder.

## Overview

This template provisions feature-rich Kubernetes-based development workspaces that include:
- Multiple IDE integrations (desktop and web-based)
- Configurable compute resources
- Persistent storage
- Git repository cloning
- External authentication
- Workspace presets
- Real-time resource monitoring
- Custom startup scripts

## Architecture

### Infrastructure Components

- **Kubernetes Deployment**: Ephemeral pod for the workspace container
- **Persistent Volume Claim**: Persistent storage mounted at `/home/coder` (10-50GB configurable)
- **Container Images**: Multiple pre-configured images for different programming languages
  - Node/React (`codercom/enterprise-node:latest`)
  - Golang (`codercom/enterprise-golang:latest`)
  - Java (`codercom/enterprise-java:latest`)
  - Base with Python (`codercom/enterprise-base:ubuntu`)

### Resource Configuration

The template provides configurable compute resources:
- **CPU**: 2-8 cores (default: 4)
- **Memory**: 4-16 GB (default: 8GB)
- **Storage**: 10-50 GB persistent disk (default: 10GB)

## Features

### 1. Desktop IDE Integrations

Access your workspace through popular desktop IDEs:

- **VS Code Desktop** - Full VS Code desktop experience
- **Cursor** - AI-powered code editor
- **Windsurf** - Modern development environment
- **Kiro** - Alternative IDE option
- **Zed** - High-performance code editor

### 2. Web-Based IDEs

Browser-based development environments:

- **code-server** - VS Code in the browser
- **VS Code Web** - Official VS Code web with extensions
  - Pre-configured extensions: GitHub Copilot, Python, Jupyter, YAML
- **JupyterLab** - Interactive notebook environment
- **Jupyter Notebook** - Classic notebook interface

### 3. JetBrains IDE Support

Full integration with JetBrains IDEs through two modes:

**JetBrains Gateway Mode**:
- GoLand (GO)
- WebStorm (WS)
- IntelliJ IDEA Ultimate (IU)
- PyCharm Professional (PY)

**JetBrains Toolbox Mode**:
- Full JetBrains Toolbox integration
- Requires JetBrains Toolbox 2.7+ and Coder 2.24+
- Toggle between Gateway and Toolbox via workspace parameter

### 4. Additional Tools

- **File Browser** - Web-based file management
- **Dotfiles** - Automatic dotfiles personalization
- **Git Clone** - Automatic repository cloning on workspace creation
- **Coder Login** - Seamless authentication integration

### 5. Workspace Monitoring

Real-time metrics displayed in the dashboard:
- CPU usage (workspace and host)
- Memory usage (workspace and host)
- Home directory disk usage
- Load average (host)

## Configurable Parameters

### Core Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| CPU cores | number | 4 | CPU cores for workspace (2-8) |
| Memory (GB) | number | 8 | Memory allocation (4-16 GB) |
| PVC storage size | number | 10 | Persistent storage in GB (10-50) |
| Container Image | dropdown | enterprise-base:ubuntu | Container image selection |
| Source Code Repository | dropdown | coder-contrib/coder | Git repository to clone |
| startup_script | textarea | "" | Custom startup script |

### Advanced Parameters (Admin-only)

| Parameter | Type | Description |
|-----------|------|-------------|
| namespace | dropdown | Kubernetes namespace selection |
| location | dropdown | Deployment region (Ohio, Oregon, London) |
| Jupyter IDE type | dropdown | Choose between JupyterLab, Notebook, or None |
| Use Jetbrains Toolbox? | checkbox | Toggle between Gateway and Toolbox |

## Pre-configured Repository Options

- **PAC-MAN** - Node.js game demo (`coder-contrib/pacman-nodejs`)
- **Coder v2 OSS** - Coder open-source project
- **code-server** - VS Code in the browser project

## Workspace Presets

### PAC-MAN Demo Preset

A pre-configured workspace for running the PAC-MAN Node.js demo:

- **Resources**: 4 CPU cores, 8GB RAM, 25GB storage
- **Image**: Node.js container
- **Repository**: pacman-nodejs
- **Startup Script**:
  - Installs MongoDB 8.0
  - Configures NPM
  - Starts MongoDB service
  - Installs dependencies and launches PAC-MAN

The PAC-MAN app is automatically exposed at `http://localhost:8080` with health checks.

## External Authentication

GitHub authentication is integrated via `coder_external_auth`:
- Optional GitHub OAuth
- Provides `GH_TOKEN` environment variable in workspace
- Enables seamless Git operations

## Security Features

- Runs as non-root user (UID 1000, GID 1000)
- Security context enforced at pod and container level
- Kubernetes RBAC integration
- Optional process logging with exectrace sidecar (commented out)

## Namespace Configuration

Multiple namespace options for workload isolation:
- `coder-ws-demo` - Demo environment (default)
- `coder-ws` - Standard workspaces
- `coder-ws-experiment` - Experimental workspaces

## Region Selection

Deploy workspaces in different regions:
- **us-east-2** (Ohio)
- **us-west-2** (Oregon)
- **eu-west-2** (London)

## Workspace Metadata

The following metadata is displayed in the Coder dashboard:
- Docker Image in use
- Repository cloned
- Region deployed to
- OS and Architecture
- Kubernetes Deployment name

## Prerequisites

### Required Infrastructure

1. **Kubernetes Cluster**: Existing cluster with appropriate capacity
2. **Coder Server**: Coder v2 installed and configured
3. **Container Registry Access**: Access to `codercom` images
4. **Storage Class**: Available storage class for PVCs
5. **Node Affinity**: Nodes with `dedicated=coder-ws` toleration

### Authentication

Template authenticates using:
- `~/.kube/config` on the Coder provisioner
- Built-in Kubernetes ServiceAccount authentication
- GitHub OAuth (optional external auth)

## Usage

### Creating a Workspace

1. Select the "Kitchen Sink" template in Coder
2. Configure your desired parameters:
   - Choose CPU, memory, and storage
   - Select container image for your language
   - Pick a repository to clone
   - Optionally add a startup script
3. Click "Create Workspace"

### Accessing IDEs

Once the workspace is running:
- Use the dashboard buttons to launch desktop IDEs
- Click web IDE links to open browser-based editors
- For JetBrains IDEs, ensure you have Gateway or Toolbox installed

### Using Presets

Select the "PAC-MAN" preset to instantly configure a demo workspace:
- Pre-configured resources and settings
- Automatic MongoDB setup
- PAC-MAN app ready to play

## Customization

This template is designed as a starting point. Common customizations include:

1. **Adding Tools**: Extend the container images with additional tools
2. **Custom Modules**: Add your own Terraform modules
3. **IDE Extensions**: Configure additional VS Code extensions
4. **Startup Scripts**: Pre-install tools via startup scripts
5. **Resource Limits**: Adjust CPU/memory ranges for your environment
6. **Network Policies**: Add Kubernetes network policies for security

## Technical Notes

### Persistence

- **Persistent**: `/home/coder` directory (backed by PVC)
- **Ephemeral**: Everything outside `/home/coder` (lost on workspace restart)

To persist additional tools, either:
- Install them in `/home/coder`
- Build custom container images
- Use dotfiles for configuration

### Startup Script Behavior

The template uses `startup_script_behavior = "blocking"`:
- Agent waits for startup script completion
- Workspace status shows as "starting" until script finishes
- Ensures dependencies are ready before IDE access

### Display Apps Configuration

The agent configuration shows:
- SSH helper enabled
- Port forwarding helper enabled
- Web terminal enabled
- Default VS Code integration disabled (using modules instead)

## Module Registry

This template uses official Coder registry modules:

| Module | Version | Purpose |
|--------|---------|---------|
| vscode-desktop | 1.1.1 | VS Code desktop integration |
| cursor | 1.2.1 | Cursor IDE integration |
| windsurf | 1.1.1 | Windsurf IDE integration |
| kiro | 1.0.0 | Kiro IDE integration |
| zed | 1.0.1 | Zed editor integration |
| code-server | 1.3.1 | VS Code web server |
| vscode-web | 1.3.1 | Official VS Code web |
| jupyterlab | 1.1.1 | JupyterLab environment |
| jupyter-notebook | 1.2.0 | Jupyter Notebook interface |
| filebrowser | 1.1.2 | Web file browser |
| dotfiles | 1.2.1 | Dotfiles support |
| git-clone | 1.1.1 | Repository cloning |
| coder-login | 1.0.31 | Authentication integration |

## Troubleshooting

### Workspace Won't Start

- Check resource availability in Kubernetes cluster
- Verify container image is accessible
- Review startup script logs in the workspace terminal

### IDE Connection Issues

- Ensure Coder agent is running (check workspace status)
- For desktop IDEs, verify client software is installed
- Check network connectivity and firewall rules

### Storage Issues

- Verify PVC was created successfully
- Check available storage in namespace
- Ensure storage class supports dynamic provisioning

## Maintenance

This template is centrally managed by CI/CD in the coder/templates repository.

Updates and changes should be made through the central repository and deployed via the CI/CD pipeline.

## Support

For issues or questions:
- Consult the [Coder documentation](https://coder.com/docs)
- Review the [Coder community forums](https://github.com/coder/coder/discussions)
- Contact your Coder administrator
