---
display_name: RealWorld App with Django
description: Run a RealWorld Django application!
maintainer_github: jatcod3r
verified: false
tags: [kubernetes, container, ai, tasks]
---

# Run a RealWorld Django Application!

This is an example app cloned from [thanhdev/realworld-django-rest-framework-angular](https://github.com/thanhdev/realworld-django-rest-framework-angular), belonging to the [`RealWorld` suite](https://realworld-docs.netlify.app/). We include:

- [Anthropic - Claude Code](https://www.claude.com/product/claude-code)
- [Coder - AI Tasks](https://coder.com/docs/ai-coder/tasks)
- [Coder - AI Bridge](https://coder.com/docs/ai-coder/ai-bridge)
- [Coder - Agent Boundary](https://coder.com/docs/ai-coder/agent-boundary)

This is a starting point for working with AI agents in Coder Tasks and exploring AI governance. Try prompts such as:

- `Make the background color blue`
- `Add a dark mode`
- `Rewrite the entire backend in Go`

Or, check out any [existing project issues](https://github.com/coder-contrib/realworld-django-rest-framework-angular/issues) to have Claude work on:

- `Work on issue #1`
- `Look at "https://github.com/coder-contrib/realworld-django-rest-framework-angular/issues/30" and submit a fix.`

## Included in this template

This template is designed to be an example and a reference for building other templates with Coder Tasks. You can always run Coder Tasks on different infrastructure (e.g. as on Kubernetes, VMs) and with your own GitHub repositories, MCP servers, images, etc.

Additionally, this template uses our [Claude Code](https://registry.coder.com/modules/coder/claude-code) module, but [other agents](https://registry.coder.com/modules?search=tag%3Aagent) or even [custom agents](https://coder.com/docs/ai-coder/custom-agents) can be used in its place.

This template uses a [Workspace Preset](https://coder.com/docs/admin/templates/extending-templates/parameters#workspace-presets) that pre-defines:

- Universal Container Image (e.g. contains Node.js, Java, Python, Ruby, etc)
- MCP servers (playwright for previewing changes)
- System prompt and [repository](https://github.com/coder-contrib/realworld-django-rest-framework-angular) for the AI agent
- Startup script to initialize the repository and start the development server

### Prerequisites

Although this template runs on Kubernetes, alternatively, it can be installed onto a VM or Docker Container using our [tasks-docker](https://github.com/coder/registry/tree/main/registry/coder-labs/templates/tasks-docker) template. This is what it will require:

- Coder installed (see [our docs](https://coder.com/docs/install)), ideally a Linux VM with Docker
- Anthropic API Key (or access to Anthropic models via Bedrock or Vertex, see [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code/third-party-integrations))
- Access to a Docker socket
  - If on the local VM, ensure the `coder` user is added to the Docker group (docs)

    ```sh
    # Add coder user to Docker group
    sudo adduser coder docker
    
    # Restart Coder server
    sudo systemctl restart coder
    
    # Test Docker
    sudo -u coder docker ps
    ```

  - If on a remote VM, see the [Docker Terraform provider documentation](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs#remote-hosts) to configure a remote host

To import this template into Coder, first create a template from "Scratch" in the template editor.

Visit this URL for your Coder deployment:

```sh
https://coder.example.com/templates/new?exampleId=scratch
```

After creating the template, paste the contents from [main.tf](./main.tf) into the template editor and save.

Alternatively, you can use the Coder CLI to [push the template](https://coder.com/docs/reference/cli/templates_push)

```sh
# Download the CLI
curl -L https://coder.com/install.sh | sh

# Log in to your deployment
coder login https://coder.example.com

# Clone the registry
git clone https://github.com/coder/registry
cd registry

# Navigate to this template
cd registry/coder-labs/templates/tasks-docker
# OR
cd registry/coder-labs/templates/tasks-k8s

# Push the template
coder templates push
```
