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
    litellm = {
      source  = "ncecere/litellm"
      version = "0.3.14"
    }
    random = {
      source = "hashicorp/random"
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

variable "gh_email" {
  type      = string
  sensitive = true
}

variable "litellm_base_url" {
  type      = string
  sensitive = true
}

variable "litellm_api_key" {
  type      = string
  sensitive = true
}

variable "litellm_user_id" {
  type      = string
  sensitive = true
}

variable "namespace" {
  type    = string
}

provider "litellm" {
  api_base = var.litellm_base_url
  api_key  = var.litellm_api_key
}

resource "random_uuid" "this" {}

locals {
  is_prebuild = data.coder_workspace_owner.me.name == "prebuilds" ? true : false
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
  order        = -1
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

data "coder_parameter" "select_ai" {
  name        = "Select an AI Companion"
  description = "Which AI companion would you like to assist you?"
  icon        = "/emojis/1f916.png"
  mutable     = true
  type        = "string"
  form_type   = "dropdown"
  default     = "claude-code"
  order       = 1

  option {
    name  = "Claude"
    icon  = "/icon/claude.svg"
    value = "claude-code"
  }

  option {
    name  = "Goose"
    icon  = "/icon/goose.svg"
    value = "goose-ai"
  }
}

data "coder_parameter" "ai_prompt" {
  name         = "AI Prompt"
  display_name = "AI Prompt (Optional)"
  description  = "Ask your AI companion to do something for you on startup! Otherwise, do nothing."
  icon         = "/emojis/1f916.png"
  mutable      = true
  default      = "Report 'agent started' to Coder!"
  form_type    = "textarea"
  order        = 2
}

data "coder_parameter" "system_prompt" {
  name        = "AI System Prompt (Optional)"
  description = "Configure your AI companion to adhere to certain rules!"
  icon        = "/emojis/1f916.png"
  mutable     = true
  default     = "You are a helpful coding assistant! You will be working on any projects in ${local.home_folder}."
  form_type   = "textarea"
  order       = 3
}

data "coder_workspace_tags" "location" {
  tags = {
    region = data.coder_parameter.location.value
  }
}

data "coder_parameter" "repo" {
  name        = "Git Repository"
  description = "Git project to clone and work on!"
  icon        = "/icon/git.svg"
  mutable     = false
  default     = ""
  type        = "string"
  form_type   = "input"
  order       = 4
}

data "coder_parameter" "key-duration" {
  name        = "LiteLLM Key Duration (Optional)"
  description = "How many hours do you want the key to last? (in hours)"
  icon        = "/emojis/23f0.png"
  mutable     = false
  type        = "number"
  form_type   = "slider"
  default     = 4
  order       = 5
  validation {
    min = 1
    max = 8
  }
}

data "coder_parameter" "ai_post_install_script" {
  name        = "AI's Post Install Script (Optional)"
  description = "Run a script after finalizing the AI installation!"
  icon        = "/emojis/1f4dd.png"
  mutable     = false
  type        = "string"
  form_type   = "textarea"
  default     = ""
  order       = 6
}

data "coder_parameter" "launch_script" {
  name        = "Workspace Launch Script (Optional)"
  description = "Script to run after workspace launch! (Runs outside of the AI context)"
  icon        = "/emojis/1f4dd.png"
  mutable     = false
  type        = "string"
  form_type   = "textarea"
  default     = ""
  order       = 7
}

data "coder_parameter" "enable_preview_app" {
  name        = "Enable Preview Coder App?"
  description = "This enables listen to a running application on some port (i.e. the app shoud already be running or started during workspace launch!)"
  type        = "bool"
  default     = true
  mutable     = true
  order       = 8
}

data "coder_parameter" "preview_port" {
  count       = tobool(data.coder_parameter.enable_preview_app.value) ? 1 : 0
  name        = "Preview Port"
  description = "The port the web app is running on to preview in Coder Tasks!"
  type        = "number"
  default     = 4200
  mutable     = true
  order       = 9
}

data "coder_external_auth" "github" {
  id       = "primary-github"
  optional = true
}

resource "coder_metadata" "pod_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = module.k8s_ws_deployment.agent_id
  item {
    key   = "UUID"
    value = local.workspace_name
  }
  item {
    key   = "Location"
    value = local.regions[data.coder_parameter.location.value].name
  }
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

locals {
  home_folder    = "/home/coder"
  work_folder    = join("/", [local.home_folder, element(split("/", data.coder_parameter.repo.value), -1)])
  workspace_name = random_uuid.this.result
  port           = try(data.coder_parameter.preview_port[0].value, 4200)
  domain         = element(split("/", data.coder_workspace.me.access_url), -1)
}

module "coder-login" {
  # source   = "registry.coder.com/coder/coder-login/coder"
  source   = "./modules/coder-login"
  agent_id = module.k8s_ws_deployment.agent_id
}

locals {
  vscode-web-settings = {
    "workbench.colorTheme" : "Default Dark Modern",
    "workbench.preferredDarkColorTheme" : "Default Dark Modern",
    "workbench.preferredHighContrastColorTheme" : "Default High Contrast",
    "roo-cline.autoImportSettingsPath" : "${local.home_folder}/.roo/roo-init.json",
    "git.useIntegratedAskPass" : false,
    "github.gitAuthentication" : false
  }
  vscode-web-extensions = [
    "esbenp.prettier-vscode",
    "RooVeterinaryInc.roo-cline"
  ]
}

module "git-clone" {
  count = data.coder_parameter.repo.value == "" ? 0 : 1
  # source   = "registry.coder.com/coder/git-clone/coder"
  source   = "./modules/git-clone"
  agent_id = module.k8s_ws_deployment.agent_id
  url      = data.coder_parameter.repo.value
  base_dir = local.home_folder
}

module "vscode-web" {
  # source                  = "registry.coder.com/coder/vscode-web/coder"
  source                  = "./modules/vscode-web"
  settings                = local.vscode-web-settings
  extensions              = local.vscode-web-extensions
  offline                 = false
  accept_license          = true
  auto_install_extensions = true
  use_cached              = true

  agent_id = module.k8s_ws_deployment.agent_id
  folder   = local.work_folder
  order    = 997
  group    = "Web Editors"
}

module "vscode-desktop" {
  # source   = "registry.coder.com/coder/vscode-desktop/coder"
  source   = "./modules/vscode-desktop"
  agent_id = module.k8s_ws_deployment.agent_id
  folder   = local.work_folder
  order    = 998
  group    = "Desktop IDEs"
}

module "filebrowser" {
  # source   = "registry.coder.com/coder/filebrowser/coder"
  source   = "./modules/filebrowser"
  agent_id = module.k8s_ws_deployment.agent_id
  order    = 999
}

locals {
  default_launch_script = <<-EOF
    echo "Creating settings file..."
    mkdir -p ~/.vscode-server/data/Machine
    echo "${replace(jsonencode(local.vscode-web-settings), "\"", "\\\"")}" > ~/.vscode-server/data/Machine/settings.json

    EXTENSIONS=("${join(",", local.vscode-web-extensions)}")
    IFS=',' read -r -a EXTENSIONLIST <<< "$${EXTENSIONS}"
    for extension in "$${EXTENSIONLIST[@]}"; do
      if [ -z "$extension" ]; then
        continue
      fi
      printf "Installing extension $${CODE}$extension$${RESET}...\n"
      output=$(/tmp/vscode-web/bin/code-server --install-extension "$extension" --force)
      if [ $? -ne 0 ]; then
        echo "Failed to install extension: $extension: $output"
      fi
    done

    ROO_INIT_FILE="$HOME/.roo/roo-init.json"
    mkdir -p "$(dirname "$ROO_INIT_FILE")"
    cat > "$ROO_INIT_FILE" <<EOT
    {
      "providerProfiles": {
        "currentApiConfigName": "default",
        "apiConfigs": {
          "default": {
              "litellmBaseUrl": "${var.litellm_base_url}",
              "litellmApiKey": "${try(litellm_key.this[0].key, "")}",
              "litellmModelId": "anthropic.claude.haiku",
              "apiProvider": "litellm",
              "id": "wbtoigff1bh"
          }
        }
      }
    }
    EOT
  EOF
}

resource "coder_script" "launch" {
  agent_id     = module.k8s_ws_deployment.agent_id
  display_name = "Launch Script"
  icon         = "/icon/dotfiles.svg"
  # icon         = "https://avatars.githubusercontent.com/u/211522643?s=200&v=4"
  run_on_start = true
  script       = data.coder_parameter.launch_script.value == "" ? local.default_launch_script : data.coder_parameter.launch_script.value
}

resource "litellm_key" "this" {
  count                  = data.coder_workspace.me.start_count
  user_id                = var.litellm_user_id
  key_alias              = "${data.coder_workspace_owner.me.email}-${data.coder_workspace.me.name}"
  metadata               = {}
  allowed_cache_controls = []
  duration               = "${data.coder_parameter.key-duration.value}h"
  guardrails             = []
  tags                   = []

  lifecycle {
    ignore_changes = [key_alias]
  }
}

locals {
  user_settings = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
    GIT_CONFIG_COUNT    = 1
    GIT_CONFIG_KEY_0    = "user.name"
    GIT_CONFIG_VALUE_0  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_CONFIG_KEY_1    = "user.email"
    GIT_CONFIG_VALUE_1  = data.coder_workspace_owner.me.email
    GH_USERNAME         = data.coder_workspace_owner.me.email
    GH_TOKEN            = data.coder_external_auth.github.access_token
  }
  claude_settings = {
    permisions = {
      allow = [
        "Bash(coder:*)",
        "Bash(gh:*)",
        "Bash(git:*)",
      ]
      deny = [
        "Bash(gh repo delete:*)",
        "Bash(gh repo create:*)",
        "Bash(gh repo edit:*)",

        "Bash(gh ssh-key:*)",
        "Bash(gh gpg-key:*)",
        "Bash(gh variable:*)",
        "Bash(gh token:*)",
        "Bash(gh agent-task:*)",
        "Bash(gh attestation:*)",
        "Bash(gh cache:*)",
        "Bash(gh codespace:*)",

        "Bash(gh gist delete:*)",

        "Bash(gh issue delete:*)",
        "Bash(gh issue transfer:*)",
        "Bash(gh issue reopen:*)",
        "Bash(gh issue close:*)",

        "Bash(coder server:*)",
        "Bash(coder reset-password:*)",

        "Bash(coder exp:*)",

        "Bash(coder templates archive:*)",
        "Bash(coder templates create:*)",
        "Bash(coder templates delete:*)",
        "Bash(coder templates edit:*)",
        "Bash(coder templates push:*)",
        "Bash(coder templates versions archive:*)",
        "Bash(coder templates versions unarchive:*)",
        "Bash(coder templates versions promote:*)",

        "Bash(coder users active:*)",
        "Bash(coder users create:*)",
        "Bash(coder users delete:*)",
        "Bash(coder users edit:*)",
        "Bash(coder users suspend:*)",

        "Bash(coder provisioner keys create:*)",
        "Bash(coder provisioner keys delete:*)",

        "Bash(coder groups create:*)",
        "Bash(coder groups delete:*)",
        "Bash(coder groups edit:*)",

        "Bash(coder organizations:*)",
        "Bash(coder organizations members:*)",
        "Bash(coder organizations roles:*)",
        "Bash(coder organizations settings:*)",
      ]
    }
    env = {
      CLAUDE_CODE_ENABLE_TELEMETRY             = "1",
      CLAUDE_CODE_MAX_OUTPUT_TOKENS            = "8192"
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
      DISABLE_PROMPT_CACHING                   = "1"
      ANTHROPIC_BASE_URL                       = var.litellm_base_url
      ANTHROPIC_MODEL                          = "anthropic.claude.sonnet"
      ANTHROPIC_SMALL_FAST_MODEL               = "anthropic.claude.haiku"
      ANTHROPIC_AUTH_TOKEN                     = try(litellm_key.this[0].key, "")
      NODE_OPTIONS                             = "--max-old-space-size=4096"

      GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
      GIT_COMMITTER_NAME  = var.gh_username
      GIT_COMMITTER_EMAIL = var.gh_email
      GIT_CONFIG_COUNT    = 1
      GIT_CONFIG_KEY_0    = "user.name"
      GIT_CONFIG_VALUE_0  = var.gh_username
      GIT_CONFIG_KEY_1    = "user.email"
      GIT_CONFIG_VALUE_1  = var.gh_email
      GH_TOKEN            = var.gh_token
      GH_USERNAME         = var.gh_username
    }
  }
  goose_settings = {
    OPENAI_API_KEY         = try(litellm_key.this[0].key, "")
    OPENAI_HOST            = var.litellm_base_url
    GOOSE_DISABLE_KEYRING  = "1"
    GOOSE_LEAD_MODEL       = "anthropic.claude.sonnet"
    GOOSE_SYSTEM_PROMPT    = data.coder_parameter.system_prompt.value
    GOOSE_TASK_PROMPT      = data.coder_parameter.ai_prompt.value
    DISABLE_PROMPT_CACHING = "1"
    NODE_OPTIONS           = "--max-old-space-size=4096"

    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
    GIT_CONFIG_COUNT    = 1
    GIT_CONFIG_KEY_0    = "user.name"
    GIT_CONFIG_VALUE_0  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_CONFIG_KEY_1    = "user.email"
    GIT_CONFIG_VALUE_1  = data.coder_workspace_owner.me.email
    GH_USERNAME         = data.coder_workspace_owner.me.email
    GH_TOKEN            = data.coder_external_auth.github.access_token
  }
}

locals {
  run_claude = data.coder_parameter.select_ai.value == "claude-code" ? 1 : 0
  run_goose  = data.coder_parameter.select_ai.value == "goose-ai" ? 1 : 0
}

module "claude-code" {
  count = local.run_claude
  # source   = "registry.coder.com/coder/claude-code/coder"
  source   = "./modules/claude-code"
  agent_id = module.k8s_ws_deployment.agent_id
  workdir  = local.work_folder

  install_agentapi    = false
  install_claude_code = false
  system_prompt       = data.coder_parameter.system_prompt.value
  ai_prompt           = data.coder_parameter.ai_prompt.value
  report_tasks        = true

  post_install_script = templatefile("scripts/claude.sh", {
    HOME_FOLDER   = local.home_folder
    SETTINGS      = jsonencode(local.claude_settings)
    PRESET_SCRIPT = data.coder_parameter.ai_post_install_script.value
  })

  order = 0
}

resource "coder_env" "goose" {
  for_each = local.run_goose != 0 ? local.goose_settings : {}
  agent_id = module.k8s_ws_deployment.agent_id
  name     = each.key
  value    = each.value
}

module "goose" {
  count = local.run_goose
  # source   = "registry.coder.com/coder/goose/coder"
  source   = "./modules/goose"
  agent_id = module.k8s_ws_deployment.agent_id
  folder   = local.work_folder

  install_goose    = false
  install_agentapi = false

  goose_provider = "openai"
  goose_model    = "anthropic.claude.haiku"

  post_install_script = templatefile("scripts/goose.sh", {
    HOME_FOLDER   = local.home_folder
    PRESET_SCRIPT = data.coder_parameter.ai_post_install_script.value
  })

  additional_extensions = yamlencode({
    desktop-command = {
      name    = "Desktop-commander"
      enabled = true
      args    = []
      cmd     = "desktop-commander"
      env     = {}
      type    = "stdio"
    },
    playwright = {
      name    = "Playwright"
      enabled = false
      args    = []
      cmd     = "npx -- @playwright/mcp@latest --headless --isolated --no-sandbox"
      env     = {}
      type    = "stdio"
    }
  })

  order = 0
}

resource "coder_app" "preview" {
  count        = tobool(data.coder_parameter.enable_preview_app.value) ? 1 : 0
  agent_id     = module.k8s_ws_deployment.agent_id
  slug         = "preview"
  display_name = "Web App Preview App"
  icon         = "${data.coder_workspace.me.access_url}/emojiss/1f50e.png"
  url          = "http://localhost:${local.port}"
  share        = "authenticated"
  subdomain    = true
  open_in      = "tab"
  order        = 1
  healthcheck {
    url       = "http://localhost:${local.port}/"
    interval  = 5
    threshold = 15
  }
}

module "k8s_ws_deployment" {
  source          = "./modules/k8s_ws_deployment"
  name            = local.workspace_name
  namespace       = var.namespace
  container_image = "750246862020.dkr.ecr.us-east-2.amazonaws.com/base-ws:test"
  labels = {
    "com.coder.workspace.uuid" = random_uuid.this.result
  }
  annotations = {
    "com.coder.user.email" = data.coder_workspace_owner.me.email
    "com.coder.workspace.id"   = data.coder_workspace.me.id
    "com.coder.workspace.name" = data.coder_workspace.me.name
    "com.coder.user.id"        = data.coder_workspace_owner.me.id
    "com.coder.user.username"  = data.coder_workspace_owner.me.name
  }
  node_selector = {
    "node.coder.io/used-for" = "coder-ws-all"
    "node.coder.io/name"     = "coder"
  }
  envs                       = local.user_settings
  cpu                        = 4000
  memory                     = 8
  ephemeral_storage          = 10
  attach_volume              = false
  pvc_storage_size           = 100
  privileged                 = false
  allow_privilege_escalation = true
  read_only_root_filesystem  = false
  add_dind_sidecar           = false
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