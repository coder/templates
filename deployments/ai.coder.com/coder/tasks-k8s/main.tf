# Managed in https://github.com/coder/templates
terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

variable "gh_token" {
    type = string
    sensitive = true
}

variable "gh_username" {
    type = string
    sensitive = true
}

# The Claude Code module does the automatic task reporting
# Other agent modules: https://registry.coder.com/modules?search=agent
# Or use a custom agent:  
module "claude-code" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/claude-code/coder"
  version             = "2.0.0"
  agent_id            = coder_agent.main.id
  folder              = "/home/coder/projects"
  install_claude_code = true
  claude_code_version = "latest"
  order               = 999

  experiment_post_install_script = data.coder_parameter.setup_script.value
  experiment_pre_install_script = <<-EOF
      # If user doesn't have a Github account or aren't 
      # part of the coder-contrib organization, then they can use the `coder-contrib-bot` account.
      if [ ! -z "$GH_USERNAME" ]; then
          unset -v GIT_ASKPASS
          unset -v GIT_SSH_COMMAND
      fi
  EOF

  # This enables Coder Tasks
  experiment_report_tasks = true
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
	    
      Remember this decision rule:
      - Stays running? → desktop-commander
      - Finishes immediately? → built-in tools
      
      -- Context --
      There is an existing app and tmux dev server running on port 8000. Be sure to read it's CLAUDE.md (./realworld-django-rest-framework-angular/CLAUDE.md) to learn more about it. 

      Since this app is for demo purposes and the user is previewing the homepage and subsequent pages, aim to make the first visual change/prototype very quickly so the user can preview it, then focus on backend or logic which can be a more involved, long-running architecture plan.

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
    "jetbrains_ide"   = "PY"
  }

  # Pre-builds is a Coder Premium
  # feature to speed up workspace creation
  # 
  # see https://coder.com/docs/admin/templates/extending-templates/prebuilt-workspaces
  prebuilds {
    instances = 0
    expiration_policy {
       ttl = 86400  # Time (in seconds) after which unclaimed prebuilds are expired (1 day)
   }
  }
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
    order = 1
    default      = "us-east-2"
    dynamic "option" {
        for_each = local.regions
        content {
            value = option.key
            name = option.value.name
            icon = option.value.icon
        }
    }
}

data "coder_workspace_tags" "location" {
    tags = {
        region = data.coder_parameter.location.value
    }
}

# Other variables for Claude Code
resource "coder_env" "claude_task_prompt" {
  agent_id = coder_agent.main.id
  name     = "CODER_MCP_CLAUDE_TASK_PROMPT"
  value    = data.coder_parameter.ai_prompt.value
}
resource "coder_env" "app_status_slug" {
  agent_id = coder_agent.main.id
  name     = "CODER_MCP_APP_STATUS_SLUG"
  value    = "claude-code"
}
resource "coder_env" "claude_system_prompt" {
  agent_id = coder_agent.main.id
  name     = "CODER_MCP_CLAUDE_SYSTEM_PROMPT"
  value    = data.coder_parameter.system_prompt.value
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  arch           = data.coder_provisioner.me.arch
  os             = "linux"
  startup_script = <<-EOT
    set -e
    # Prepare user home with default files on first start.
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~
      touch ~/.init_done
    fi
  EOT

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
      GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
      GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
  }

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  # For basic resources, you can use the `coder stat` command.
  # If you need more control, you can write your own script.
  metadata {
      display_name = "CPU Usage (Workspace)"
      key          = "0_cpu_usage"
      script       = "coder stat cpu"
      interval     = 10
      timeout      = 1
  }

  metadata {
      display_name = "RAM Usage (Workspace)"
      key          = "1_ram_usage"
      script       = "coder stat mem"
      interval     = 10
      timeout      = 1
  }

  metadata {
      display_name = "Disk Usage (Host)"
      key          = "3_home_disk"
      script       = "coder stat disk --path / --prefix Gi"
      interval     = 10
      timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }
}

# See https://registry.coder.com/modules/coder/code-server
module "code-server" {
    count  = data.coder_workspace.me.start_count
    folder = "/home/coder/projects"
    source = "registry.coder.com/coder/code-server/coder"

    settings = {
      "workbench.colorTheme" : "Default Dark Modern"
    }

    # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
    version = "~> 1.0"

    agent_id = coder_agent.main.id
    order    = 1
}

resource "coder_metadata" "pod_info" {
    count = data.coder_workspace.me.start_count
    resource_id = kubernetes_pod.dev[0].id
    daily_cost = local.cost
    item {
        key   = "UUID"
        value = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    }
    item {
        key = "Location"
        value = local.regions[data.coder_parameter.location.value].name
    }
}

module "vscode" {
    count    = data.coder_workspace.me.start_count
    source   = "registry.coder.com/coder/vscode-desktop/coder"
    version  = "1.1.0"
    agent_id = coder_agent.main.id
}

module "windsurf" {
    count    = data.coder_workspace.me.start_count
    source   = "registry.coder.com/coder/windsurf/coder"
    version  = "1.1.0"
    agent_id = coder_agent.main.id
}

module "cursor" {
    count    = data.coder_workspace.me.start_count
    source   = "registry.coder.com/coder/cursor/coder"
    version  = "1.2.0"
    agent_id = coder_agent.main.id
}

module "jetbrains_gateway" {
    count  = data.coder_workspace.me.start_count
    source = "registry.coder.com/coder/jetbrains-gateway/coder"

    # JetBrains IDEs to make available for the user to select
    jetbrains_ides = ["IU", "PS", "WS", "PY", "CL", "GO", "RM", "RD", "RR"]
    default        = "IU"

    # Default folder to open when starting a JetBrains IDE
    folder = "/home/coder/projects"

    # This ensures that the latest non-breaking version of the module gets downloaded, you can also pin the module version to prevent breaking changes in production.
    version = "~> 1.0"

    agent_id   = coder_agent.main.id
    agent_name = "main"
    order      = 2
}

resource "coder_app" "preview" {
    agent_id     = coder_agent.main.id
    slug         = "preview"
    display_name = "Preview your app"
    icon         = "${data.coder_workspace.me.access_url}/emojis/1f50e.png"
    url          = "http://localhost:${data.coder_parameter.preview_port.value}"
    share        = "authenticated"
    subdomain    = true
    open_in      = "tab"
    order        = 0
    healthcheck {
        url       = "http://localhost:${data.coder_parameter.preview_port.value}/"
        interval  = 5
        threshold = 25
    }
}

data "coder_external_auth" "github" {
    id = "primary-github"
    optional = true
}

locals {
    cost = 4
    logged_into_git = data.coder_external_auth.github.access_token != ""
    env = {
        CODER_AGENT_TOKEN = coder_agent.main.token
        ANTHROPIC_BASE_URL = "https://litellm.ai.demo.coder.com"
        ANTHROPIC_MODEL = "anthropic.claude.sonnet"
        ANTHROPIC_SMALL_FAST_MODEL = "anthropic.claude.haiku"
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
        DISABLE_PROMPT_CACHING = "1"
        GH_TOKEN = local.logged_into_git ? data.coder_external_auth.github.access_token : var.gh_token
        NODE_OPTIONS = "--max-old-space-size=${512*local.cost}"
        CLAUDE_CODE_MAX_OUTPUT_TOKENS = "8192"
    }
}

resource "kubernetes_pod" "dev" {

    count = data.coder_workspace.me.start_count

    metadata {
        name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
        namespace = "coder-ws"
    }

    spec {
        hostname = lower(data.coder_workspace.me.name)
        node_selector = {
            "node.coder.io/used-for" = "coder-ws-all"
            "node.coder.io/name" = "coder"
        }
        termination_grace_period_seconds = 0

        toleration {
            key = "dedicated"
            operator = "Equal"
            value = "coder-ws"
            effect = "NoSchedule"
        }

        container {
            name = "workspace"
            image = data.coder_parameter.container_image.value
            image_pull_policy = "IfNotPresent"
            command = [
                "/bin/bash", "-c", 
                join("\n", [
                    # "export PATH=$PATH:${local.home_folder}/bin",
                    local.logged_into_git ? "" : "git config --global credential.helper 'store --file=/tmp/.git-credentials'",
                    local.logged_into_git ? "" : "echo \"https://$GH_USERNAME:$GH_TOKEN@github.com\" > /tmp/.git-credentials",
                    coder_agent.main.init_script
                ])
            ]
            dynamic "env" {
                for_each = local.env
                content {
                    name = env.key
                    value = env.value
                }
            }
            env {
                name = "ANTHROPIC_AUTH_TOKEN"
                value_from {
                    secret_key_ref {
                        name = "litellm"
                        key = "token"
                    }
                }
            }
            dynamic "env" {
                for_each = local.logged_into_git ? {} : {
                    GH_USERNAME = var.gh_username
                }
                content {
                    name = env.key
                    value = env.value
                }
            }
            resources {
                limits = {
                    ephemeral-storage = "${local.cost*5}Gi"
                    cpu = "${ceil(local.cost/2)}"
                    memory = "${local.cost}Gi"
                }
            }
            security_context {
                allow_privilege_escalation = true
                privileged = false
                read_only_root_filesystem = false
            }
        }
    }

    lifecycle {
        ignore_changes = [ spec.0.container.0.env ]
    }
}