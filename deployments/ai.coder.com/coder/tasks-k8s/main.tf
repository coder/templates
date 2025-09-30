# Managed in https://github.com/coder/templates
terraform {
  required_providers {
    coder = {
      source = "coder/coder"
      version = "2.11.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

variable "gh_token" {
  type      = string
  sensitive = true
}

variable "gh_username" {
  type      = string
  sensitive = true
}

variable "litellm_base_url" {
  type      = string
  sensitive = true
}

# The Claude Code module does the automatic task reporting
# Other agent modules: https://registry.coder.com/modules?search=agent
# Or use a custom agent:  
module "claude-code" {
  count  = data.coder_workspace.me.start_count
  source = "./modules/claude-code"
  #   source              = "registry.coder.com/coder/claude-code/coder"
  #   version             = "3.0.0"
  agent_id            = module.k8s_ws_deployment.agent_id
  workdir             = "/home/coder/projects"
  install_claude_code = true
  claude_code_version = "latest"
  order               = 0
  ai_prompt           = data.coder_parameter.ai_prompt.value
  system_prompt       = data.coder_parameter.system_prompt.value
  report_tasks        = true
  source_script       = <<-EOF
    # If user doesn't have a Github account or aren't 
    # part of the coder-contrib organization, then they can use the `coder-contrib-bot` account.
    unset -v GIT_ASKPASS
    unset -v GIT_SSH_COMMAND
    export GH_TOKEN=${var.gh_token}
    export GH_USERNAME=${var.gh_username}
  EOF
  post_install_script = data.coder_parameter.setup_script.value
}

# We are using presets to set the prompts, image, and set up instructions
# See https://coder.com/docs/admin/templates/extending-templates/parameters#workspace-presets
data "coder_workspace_preset" "default" {
  name    = "Real World App: Angular + Django"
  default = true
  parameters = {
    "system_prompt" = <<-EOT
      -- Framing --
      You are a helpful assistant that can help with code. You are running inside a Coder Workspace and provide status updates to the user via Coder MCP. Stay on track, feel free to debug, but when the original plan fails, do not choose a different route/architecture without checking the user first.

      -- Tool Selection --
      - playwright: previewing your changes after you made them
        to confirm it worked as expected
	    -	desktop-commander - use only for commands that keep running
        (servers, dev watchers, GUI apps).
      -	Built-in tools - use for everything else:
       (file operations, git commands, builds & installs, one-off shell commands)
	
      When you need to access the GitHub API (e.g to query GitHub issues, or pull requests), use the GitHub CLI (`gh`).
      The GitHub CLI is already authenticated, use `gh api` for any REST API calls. The GitHub token is also available as `GH_TOKEN`.

      Remember this decision rule:
      - Stays running? → desktop-commander
      - Finishes immediately? → built-in tools
      
      -- Context --
      There is an existing app and tmux dev server running on port 8000. Be sure to read it's CLAUDE.md (./realworld-django-rest-framework-angular/CLAUDE.md) to learn more about it. 

      Since this app is for demo purposes and the user is previewing the homepage and subsequent pages, aim to make the first visual change/prototype very quickly so the user can preview it, then focus on backend or logic which can be a more involved, long-running architecture plan.

      The app is from the Github repository "https://github.com/coder-contrib/realworld-django-rest-framework-angular.git".

      If you are asked to work or list out issues, reference the Github repository.

      When working on issues, work on a separate branch. You cannot directly push or fork the repository. After you're finished, you must make a pull request. Don't assign anyone to review it. 

      When making a pull request, make sure to put in details about the GIT_AUTHOR_NAME and GIT_AUTHOR_EMAIL.

      Report all tasks back to Coder. In your task reports to Coder:
      - Be specific about what you're doing
      - Clearly indicate what information you need from the user when in "failure" state
      - Keep it under 160 characters
      - Make it actionable
    EOT

    "setup_script"    = <<-EOT
    # Set up projects dir
    mkdir -p /home/coder/projects
    cd $HOME/projects

    # Packages: Install additional packages
    sudo apt-get update && sudo apt-get install -y tmux
    if ! command -v google-chrome >/dev/null 2>&1; then
      yes | npx playwright install chrome
    fi

    # MCP: Install and configure MCP Servers
    npm install -g @wonderwhy-er/desktop-commander
    claude mcp add playwright npx -- @playwright/mcp@latest --headless --isolated --no-sandbox
    claude mcp add desktop-commander desktop-commander

    # Repo: Clone and pull changes from the git repository
    if [ ! -d "realworld-django-rest-framework-angular" ]; then
      git clone https://github.com/coder-contrib/realworld-django-rest-framework-angular.git
    else
      cd realworld-django-rest-framework-angular
      git fetch
      # Check for uncommitted changes
      if git diff-index --quiet HEAD -- && \
        [ -z "$(git status --porcelain --untracked-files=no)" ] && \
        [ -z "$(git log --branches --not --remotes)" ]; then
        echo "Repo is clean. Pulling latest changes..."
        git pull
      else
        echo "Repo has uncommitted or unpushed changes. Skipping pull."
      fi

      cd ..
    fi

    # Initialize: Start the development server
    cd realworld-django-rest-framework-angular && ./start-dev.sh
    EOT
    "preview_port"    = "4200"
    "container_image" = "codercom/example-universal:ubuntu"
  }

  # Pre-builds is a Coder Premium
  # feature to speed up workspace creation
  # 
  # see https://coder.com/docs/admin/templates/extending-templates/prebuilt-workspaces
  prebuilds {
    instances = 0
    expiration_policy {
      ttl = 86400 # Time (in seconds) after which unclaimed prebuilds are expired (1 day)
    }
  }
}

module "filebrowser" {
  count    = data.coder_workspace.me.start_count
  source   = "./modules/filebrowser"
  order    = 2
  agent_id = module.k8s_ws_deployment.agent_id
}

# Advanced parameters (these are all set via preset)
data "coder_parameter" "system_prompt" {
  name         = "system_prompt"
  display_name = "System Prompt"
  type         = "string"
  form_type    = "textarea"
  description  = "System prompt for the agent with generalized instructions"
  mutable      = false
}

data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "AI Prompt"
  default     = ""
  description = "Write a prompt for Claude Code"
  mutable     = true
}

data "coder_parameter" "setup_script" {
  name         = "setup_script"
  display_name = "Setup Script"
  type         = "string"
  form_type    = "textarea"
  description  = "Script to run before running the agent"
  mutable      = false
}

data "coder_parameter" "container_image" {
  name         = "container_image"
  display_name = "Container Image"
  type         = "string"
  default      = "codercom/example-universal:ubuntu"
  mutable      = false
}

data "coder_parameter" "preview_port" {
  name         = "preview_port"
  display_name = "Preview Port"
  description  = "The port the web app is running to preview in Tasks"
  type         = "number"
  default      = "3000"
  mutable      = false
}

locals {
  cost            = 4
  logged_into_git = data.coder_external_auth.github.access_token != ""
  regions = {
    "us-east-2" = {
      name = "Ohio"
      icon = "/emojis/1f1fa-1f1f8.png" # 🇺🇸
    }
    "us-west-2" = {
      name = "Oregon"
      icon = "/emojis/1f1fa-1f1f8.png" # 🇺🇸
    }
    "eu-west-2" = {
      name = "London"
      icon = "/emojis/1f1ec-1f1e7.png" # 🇬🇧
    }
  }
}

data "coder_parameter" "location" {
  name         = "location"
  display_name = "Location"
  description  = "Choose the location that's closest to you for the best connection!"
  mutable      = true
  order        = 1
  default      = "us-east-2"
  form_type    = "dropdown"
  dynamic "option" {
    for_each = local.regions
    content {
      value = option.key
      name  = option.value.name
      icon  = option.value.icon
    }
  }
}

data "coder_workspace_tags" "location" {
  tags = {
    region = data.coder_parameter.location.value
  }
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

# See https://registry.coder.com/modules/coder/code-server
module "code-server" {
  count  = data.coder_workspace.me.start_count
  folder = "/home/coder/projects"
  source = "registry.coder.com/coder/code-server/coder"

  extensions = ["RooVeterinaryInc.roo-cline"]
  settings = {
    "workbench.colorTheme" : "Default Dark Modern",
    "roo-cline.autoImportSettingsPath" : "/home/coder/.roo/roo-init.json"
  }

  agent_id = module.k8s_ws_deployment.agent_id
  order    = 997
  group    = "Web Editors"
}

data "coder_external_auth" "github" {
  id       = "primary-github"
  optional = true
}

resource "coder_script" "roocode_init" {
  display_name = "Roo Code Init"
  icon         = "https://avatars.githubusercontent.com/u/211522643?s=200&v=4"
  run_on_start = true
  agent_id     = module.k8s_ws_deployment.agent_id
  script       = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    ROO_INIT_FILE="$HOME/.roo/roo-init.json"

    if [ ! -f "$ROO_INIT_FILE" ]; then
    mkdir -p "$(dirname "$ROO_INIT_FILE")"

    cat > "$ROO_INIT_FILE" <<EOF
    {
    "providerProfiles": {
        "currentApiConfigName": "default",
        "apiConfigs": {
        "default": {
            "litellmBaseUrl": "${var.litellm_base_url}",
            "litellmApiKey": "$${ANTHROPIC_AUTH_TOKEN}",
            "litellmModelId": "anthropic.claude.haiku",
            "apiProvider": "litellm",
            "id": "wbtoigff1bh"
        }
        }
    }
    }
    EOF
    echo "Created $ROO_INIT_FILE with API key from ANTHROPIC_AUTH_TOKEN"
    else
    echo "$ROO_INIT_FILE already exists, skipping."
    fi
	EOT
}

resource "coder_metadata" "pod_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = module.k8s_ws_deployment.id
  daily_cost  = local.cost
  item {
    key   = "UUID"
    value = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  }
  item {
    key   = "Location"
    value = local.regions[data.coder_parameter.location.value].name
  }
}

module "vscode" {
  count    = data.coder_workspace.me.start_count
  source   = "./modules/vscode"
  agent_id = module.k8s_ws_deployment.agent_id
  order    = 998
  group    = "Desktop IDEs"
}

module "windsurf" {
  count    = data.coder_workspace.me.start_count
  source   = "./modules/windsurf"
  agent_id = module.k8s_ws_deployment.agent_id
  order    = 998
  group    = "Desktop IDEs"
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "./modules/cursor"
  agent_id = module.k8s_ws_deployment.agent_id
  order    = 998
  group    = "Desktop IDEs"
}

module "jetbrains_toolbox" {
  count  = data.coder_workspace.me.start_count
  source = "./modules/jetbrains_toolbox"

  # JetBrains IDEs to make available for the user to select
  options = ["IU", "PS", "WS", "PY", "CL", "GO", "RM", "RD", "RR"]
  default = ["IU", "PS", "WS", "PY", "CL", "GO", "RM", "RD", "RR"]

  # Default folder to open when starting a JetBrains IDE
  folder = "/home/coder/projects"

  agent_id        = module.k8s_ws_deployment.agent_id
  agent_name      = "main"
  coder_app_order = 999
  group           = "JetBrains Tools"
}

resource "coder_app" "preview" {
  agent_id     = module.k8s_ws_deployment.agent_id
  slug         = "preview"
  display_name = "Preview your app"
  icon         = "${data.coder_workspace.me.access_url}/emojis/1f50e.png"
  url          = "http://localhost:${data.coder_parameter.preview_port.value}"
  share        = "authenticated"
  subdomain    = true
  open_in      = "tab"
  order        = 1
  healthcheck {
    url       = "http://localhost:${data.coder_parameter.preview_port.value}/"
    interval  = 5
    threshold = 25
  }
}

module "k8s_ws_deployment" {
  source          = "./modules/k8s_ws_deployment"
  name            = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  namespace       = "coder-ws"
  container_image = data.coder_parameter.container_image.value
  labels = {
    "com.coder.workspace.id"   = data.coder_workspace.me.id
    "com.coder.workspace.name" = data.coder_workspace.me.name
    "com.coder.user.id"        = data.coder_workspace_owner.me.id
    "com.coder.user.username"  = data.coder_workspace_owner.me.name
  }
  annotations = {
    "com.coder.user.email" = data.coder_workspace_owner.me.email
  }
  node_selector = {
    "node.coder.io/used-for" = "coder-ws-all"
    "node.coder.io/name"     = "coder"
  }
  pre_command                = <<-EOF
        export PATH=$PATH:/home/coder/bin
    EOF
  coder_agent_startup_script = <<-EOF
        set -e
        # Prepare user home with default files on first start.
        if [ ! -f ~/.init_done ]; then
            cp -rT /etc/skel ~
            touch ~/.init_done
        fi
    EOF
  envs = merge({
    CLAUDE_CODE_MAX_OUTPUT_TOKENS            = "8192"
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
    DISABLE_PROMPT_CACHING                   = "1"
    ANTHROPIC_BASE_URL                       = var.litellm_base_url
    ANTHROPIC_MODEL                          = "anthropic.claude.sonnet"
    ANTHROPIC_SMALL_FAST_MODEL               = "anthropic.claude.haiku"
    NODE_OPTIONS                             = "--max-old-space-size=${512 * local.cost}"

    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
    GH_TOKEN            = local.logged_into_git ? data.coder_external_auth.github.access_token : var.gh_token
  })
  envs_secret = {
    ANTHROPIC_AUTH_TOKEN = {
      name = "litellm"
      key  = "token"
    }
  }
  cpu                        = ceil(local.cost / 2) * 1000
  memory                     = local.cost
  privileged                 = false
  allow_privilege_escalation = true
  read_only_root_filesystem  = false
  attach_volume              = true
  pvc_storage_size           = local.cost * 5
  metadata_blocks = [{
    display_name = "CPU Usage (Workspace)"
    key          = "cpu_usage"
    order        = 0
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
    }, {
    display_name = "RAM Usage (Workspace)"
    key          = "ram_usage"
    order        = 1
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
    }, {
    display_name = "CPU Usage (Host)"
    key          = "cpu_usage_host"
    order        = 2
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
    }, {
    display_name = "RAM Usage (Host)"
    key          = "ram_usage_host"
    order        = 3
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
    }, {
    display_name = "Disk Usage (Host)"
    key          = "disk_host"
    order        = 6
    script       = "coder stat disk --path / --prefix Gi"
    interval     = 600
    timeout      = 10
  }]
  tolerations = [{
    key      = "dedicated"
    operator = "Equal"
    value    = "coder-ws"
    effect   = "NoSchedule"
  }]
}