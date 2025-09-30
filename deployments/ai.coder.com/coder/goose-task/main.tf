# Managed in https://github.com/coder/templates
terraform {
    required_providers {
        coder = {
            source  = "coder/coder"
            version = "2.11.0"
        }
        kubernetes = {
            source  = "hashicorp/kubernetes"
            version = "2.38.0"
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

variable "litellm_base_url" {
    type = string
    sensitive = true
}

variable "container_image" {
  type      = string
  sensitive = true
  default = "codercom/example-universal:ubuntu"
}

data "coder_parameter" "ai_prompt" {
    type        = "string"
    name        = "AI Prompt"
    icon        = "/emojis/1f4ac.png"
    description = "Write a task prompt for Claude. This will be the first action it will attempt to finish."
    default = "Do nothing but report a 'task completed' update to Coder"
    mutable     = false
}

data "coder_parameter" "cost" {
  type        = "number"
  name        = "Workspace Cost"
  icon        = "/emojis/1f4b8.png" # 💸
  description = "This adjusts the CPU & Memory of this workspace where it's calculated as: cpu = ceil(cost/2), memory = cost, ephemeral-storage = cost*5 "
  default     = 4
  mutable     = false
  validation {
    min       = 2
    max       = 8
    monotonic = "increasing"
  }
}

data "coder_parameter" "location" {
    name         = "location"
    display_name = "Location"
    description  = "Choose the location that's closest to you for the best connection!"
    mutable      = true
    order = 1
    default      = "us-east-2"
  form_type = "dropdown"
  dynamic "option" {
    for_each = local.regions
    content {
      value = option.key
      name  = option.value.name
      icon  = option.value.icon
    }
  }
}

data "coder_parameter" "git-repo" {
    name         = "git-repo"
    display_name = "Git Repository"
    description  = "Clone a Git repo over HTTPS (if public) or SSH (if private)."
    mutable      = false
    order = 0
    default      = ""
}

data "coder_workspace_tags" "location" {
    tags = {
        region = data.coder_parameter.location.value
    }
}

data "coder_external_auth" "github" {
    id = "primary-github"
    optional = true
}

locals {
    cost = data.coder_parameter.cost.value
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

resource "coder_metadata" "pod_info" {
    count = data.coder_workspace.me.start_count
    resource_id = module.k8s_ws_deployment.agent_id
    daily_cost = local.cost
    item {
        key   = "UUID"
        value = local.workspace_name
    }
    item {
        key = "Location"
        value = local.regions[data.coder_parameter.location.value].name
    }
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

locals {
    home_folder = "/home/coder"
    work_folder = data.coder_parameter.git-repo.value == "" ? local.home_folder : join("/", [
        local.home_folder, element(split(".", element(split("/", data.coder_parameter.git-repo.value), -1)), 0)
    ])
    workspace_name = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
}


module "coder-login" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/coder-login/coder"
  version = "1.1.0"

  agent_id = module.k8s_ws_deployment.agent_id
}

module "git-clone" {
  count    = data.coder_parameter.git-repo.value == "" ? 0 : 1
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.1.1"
  agent_id = module.k8s_ws_deployment.agent_id
  url      = data.coder_parameter.git-repo.value
  base_dir = local.home_folder
}

module "code-server" {
  count   = data.coder_workspace.me.start_count
  source  = "registry.coder.com/coder/code-server/coder"
  version = "1.3.1"

  settings = {
    "workbench.colorTheme" : "Default Dark Modern"
  }

  agent_id = module.k8s_ws_deployment.agent_id
  folder   = local.work_folder
  order    = 997
  group    = "Web Editors"
}

module "vscode-desktop" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/vscode-desktop/coder"
  version  = "1.1.1"
  agent_id = module.k8s_ws_deployment.agent_id
  folder   = local.work_folder
  order    = 998
  group    = "Desktop IDEs"
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.3.2"
  agent_id = module.k8s_ws_deployment.agent_id
  folder   = local.work_folder
  order    = 998
  group    = "Desktop IDEs"
}

module "kiro" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/kiro/coder"
  version  = "1.1.0"
  agent_id = module.k8s_ws_deployment.agent_id
  folder   = local.work_folder
  order    = 998
  group    = "Desktop IDEs"
}

module "goose" {
  source           = "registry.coder.com/coder/goose/coder"
  version          = "2.1.2"
  order = 0
  agent_id         = module.k8s_ws_deployment.agent_id
  folder           = local.work_folder
  install_goose    = false
  goose_version    = "1.9.0"
    goose_provider = "openai"
    goose_model = "anthropic.claude.haiku"
  agentapi_version = "latest"
    additional_extensions = yamlencode({
        desktop-command = {
            name = "Desktop-commander"
            enabled = true
            args = []
            cmd = "${local.home_folder}/bin/desktop-commander"
            env = {}
            type = "stdio"
        },
        playwright = {
            name = "Playwright"
            enabled = true
            args = []
            cmd = "${local.home_folder}/bin/playwright-mcp-server"
            env = {}
            type = "stdio"
        }
    })
}

locals {
    port = 3000
    domain = element(split("/", data.coder_workspace.me.access_url), -1)
}

module "preview" {
    source = "./modules/preview"
    agent_id = module.k8s_ws_deployment.agent_id
    port = local.port
    order    = 1
}

module "filebrowser" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/filebrowser/coder"
  version  = "1.1.2"
  agent_id = module.k8s_ws_deployment.agent_id
  order = 2
}

locals {
    task_prompt = join(" ", [
        "First, post a 'task started' update to Coder.",
        "Then, review all of your memory.",
        "Finally, ${data.coder_parameter.ai_prompt.value}.",
    ])
    system_prompt = <<-EOT
        First, report an initial task to Coder to show you have started. The user has provided you with a prompt of something to create. Create it the best you can, and keep it as short as possible.
        
        If you're being tasked to create a web application, then:
        - ALWAYS start the server using `python3` or `node` on localhost:${local.port}.
        - BEFORE starting the server, ALWAYS attempt to kill ANY process using port ${local.port}, and then run the dev server on port ${local.port}.
        - ALWAYS build the project using dev servers (and ALWAYS VIA desktop-commander)
        - When finished, you should use Playwright to review the HTML to ensure it is working as expected.

        ALWAYS run long-running commands (e.g. `pnpm dev` or `npm run dev`) using desktop-commander so it runs it in the background and users can prompt you. Other short-lived commands (build, test, cd, write, read, view, etc) can run normally.

        NEVER run the dev server without desktop-commander.

        For previewing, always use the dev server for fast feedback loops (never do a full Next.js build, for exmaple). A simple static HTML is preferred for web applications, but pick the best AND lightest framework for the job.
        
        The dev server will ALWAYS be on localhost:${local.port} and NEVER start on another port. If the dev server crashes for some reason, kill port ${local.port} (or the desktop-commander session) and restart the dev server.

        After large changes, use Playwright to ensure your changes work (preview localhost:${local.port}). Take a screenshot, look at the screenshot. Also look at the HTML output from Playwright. If there are errors or something looks "off," fix it.
        
        Aim to autonomously investigate and solve issues the user gives you and test your work, whenever possible.
        
        Avoid shortcuts like mocking tests. When you get stuck, you can ask the user but opt for autonomy.
        
        If you're making a git commit, always work on a different branch called "${data.coder_workspace.me.name}" and set the `user.name` to "Goose AI", and `user.email` to "${data.coder_workspace_owner.me.email}".

        If you're making a pull request, then do not ask anyone to review it.

        In your task reports to Coder:
        - Be specific about what you're doing
        - Clearly indicate what information you need from the user when in "failure" state
        - Keep it under 160 characters
        - Make it actionable

        If you're being tasked to create a Coder template, then,
        - You must ALWAYS ask the user for permission to push it. 
        - You are NOT allowed to push templates OR create workspaces from them without the users explicit approval.

        When reporting URLs to Coder, report to "https://preview--dev--${data.coder_workspace.me.name}--${data.coder_workspace_owner.me.name}.${local.domain}/" that proxies port ${local.port}

        When you need to access the GitHub API (e.g to query GitHub issues, or pull requests), use the GitHub CLI (`gh`).
        The GitHub CLI is already authenticated, use `gh api` for any REST API calls. The GitHub token is also available as `GH_TOKEN`.
    EOT
    logged_into_git = data.coder_external_auth.github.access_token != ""
}

module "k8s_ws_deployment" {
  source          = "./modules/k8s_ws_deployment"
  name            = local.workspace_name
  namespace       = "coder-ws"
  container_image = var.container_image
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
  envs = merge({
    OPENAI_HOST = var.litellm_base_url
    CODER_MCP_APP_STATUS_SLUG = "goose"
    GOOSE_DISABLE_KEYRING = "1"
    GOOSE_SYSTEM_PROMPT = local.system_prompt
    GOOSE_TASK_PROMPT = local.task_prompt
    GOOSE_LEAD_MODEL = "anthropic.claude.sonnet"
    DISABLE_PROMPT_CACHING = "1"
    NODE_OPTIONS                             = "--max-old-space-size=${512 * local.cost}"

    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
    GH_TOKEN            = local.logged_into_git ? data.coder_external_auth.github.access_token : var.gh_token
  })
  envs_secret = {
    OPENAI_API_KEY = {
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