terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
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

variable "namespace" {
  type    = string
  default = "coder-ws-experiment"
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

data "coder_parameter" "preview_port" {
  name        = "Preview Port"
  description = "The port the web app is running on to preview in Coder Tasks!"
  type        = "number"
  default     = 4200
  mutable     = true
  order       = 9
}

data "coder_parameter" "use_bots_git_creds" {
  name        = "Use Bot's Git Credentials?"
  description = "Use Coder Contrib's Git credentials to clone/pull from repos?"
  type        = "bool"
  default     = true
  mutable     = true
  order       = 11
}

data "coder_external_auth" "github" {
  id       = "primary-github"
  optional = true
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

locals {
  repo = "https://github.com/coder-contrib/realworld-django-rest-framework-angular.git"
  home_folder    = "/home/coder"
  work_folder    = join("/", [local.home_folder, "realworld-django-rest-framework-angular"])
  workspace_name = random_uuid.this.result # local.is_prebuild ? random_uuid.this.result : "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
  port           = data.coder_parameter.preview_port.value
  domain         = element(split("/", data.coder_workspace.me.access_url), -1)
  gh_token       = tobool(data.coder_parameter.use_bots_git_creds.value) ? var.gh_token : data.coder_external_auth.github.access_token
  gh_username    = tobool(data.coder_parameter.use_bots_git_creds.value) ? var.gh_username : data.coder_workspace_owner.me.name
}

module "coder-login" {
  count = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/coder-login/coder"
  # source   = "./modules/coder-login"
  agent_id = coder_agent.k8s-deployment.id
}

locals {
  vscode-web-settings = {
    "workbench.colorTheme" : "Default Dark Modern",
    "workbench.preferredDarkColorTheme" : "Default Dark Modern",
    "workbench.preferredHighContrastColorTheme" : "Default High Contrast",
    "git.useIntegratedAskPass" : false,
    "github.gitAuthentication" : false,
    "security.workspace.trust.enabled": false,
  }
  vscode-web-extensions = [
    "esbenp.prettier-vscode",
  ]
  coder-mux-settings = {
    "anthropic": {
      "serviceTier": "default",
      "models": [],
      "baseUrl": "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic",
      "apiKey": "${data.coder_workspace_owner.me.session_token}"
    }
  }
}

module "git-clone" {
  source   = "registry.coder.com/coder/git-clone/coder"
  # source   = "./modules/git-clone"
  agent_id = coder_agent.k8s-deployment.id
  url      = local.repo
  base_dir = local.home_folder
}

module "vscode-web" {
  count = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/vscode-web/coder"
  # source                  = "./modules/vscode-web"
  settings                = local.vscode-web-settings
  extensions              = local.vscode-web-extensions
  offline                 = false
  accept_license          = true
  auto_install_extensions = true
  use_cached              = true

  agent_id = coder_agent.k8s-deployment.id
  folder   = local.work_folder
  order    = 996
  group    = "Web Editors"
}

module "vscode-desktop" {
  count = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/vscode-desktop/coder"
  # source   = "./modules/vscode-desktop"
  agent_id = coder_agent.k8s-deployment.id
  folder   = local.work_folder
  order    = 997
  group    = "Desktop IDEs"
}

module "filebrowser" {
  count = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/filebrowser/coder"
  # source   = "./modules/filebrowser"
  agent_id = coder_agent.k8s-deployment.id
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

    echo "Setting up Coder Mux config..."
    mkdir -p ~/.mux
    echo "${replace(jsonencode(local.coder-mux-settings), "\"", "\\\"")}" > ~/.mux/providers.jsonc
  EOF
}

resource "coder_script" "launch" {
  agent_id     = coder_agent.k8s-deployment.id
  display_name = "Launch Script"
  icon         = "/icon/dotfiles.svg"
  # icon         = "https://avatars.githubusercontent.com/u/211522643?s=200&v=4"
  run_on_start = true
  script       = data.coder_parameter.launch_script.value == "" ? local.default_launch_script : data.coder_parameter.launch_script.value
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
      CLAUDE_CODE_MAX_OUTPUT_TOKENS            = "8192",
      ANTHROPIC_BASE_URL                       = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
      ANTHROPIC_MODEL                          = "claude-opus-4-5"
      ANTHROPIC_SMALL_FAST_MODEL               = "claude-haiku-4-5"
      NODE_OPTIONS                             = "--max-old-space-size=8192"

      GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
      GIT_COMMITTER_NAME  = var.gh_username
      GIT_COMMITTER_EMAIL = var.gh_email
      GIT_CONFIG_COUNT    = 1
      GIT_CONFIG_KEY_0    = "user.name"
      GIT_CONFIG_VALUE_0  = var.gh_username
      GIT_CONFIG_KEY_1    = "user.email"
      GIT_CONFIG_VALUE_1  = var.gh_email
      GH_TOKEN            = local.gh_token
      GH_USERNAME         = local.gh_username
    }
  }
}

locals {
  run_claude = data.coder_parameter.select_ai.value == "claude-code" ? 1 : 0
}

module "claude-code" {
  source   = "registry.coder.com/coder/claude-code/coder"
  version = "4.2.9"
  # source   = "./modules/claude-code"
  agent_id = coder_agent.k8s-deployment.id
  workdir  = local.work_folder

  install_agentapi    = false # AgentAPI already baked into image.
  install_claude_code = false # Claude Code already baked into image.
  system_prompt       = data.coder_parameter.system_prompt.value
  
  ai_prompt           = data.coder_parameter.ai_prompt.value
  report_tasks        = true
  claude_api_key      = data.coder_workspace_owner.me.session_token

  post_install_script = templatefile("scripts/claude/post.sh", {
    HOME_FOLDER   = local.home_folder
    SETTINGS      = jsonencode(local.claude_settings)
    PRESET_SCRIPT = data.coder_parameter.ai_post_install_script.value
    CODER_BOUNDARY_B64 = base64encode(file("${path.module}/scripts/claude/boundary-config.yaml"))
  })

  enable_boundary                  = true
  boundary_version                 = "v0.2.0"
  boundary_log_dir                 = "/tmp/boundary_logs"
  boundary_log_level               = "DEBUG"
  boundary_proxy_port              = "8087"

  order = 0
}

module "cmux" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/mux/coder"
  version  = "1.0.6"
  agent_id = coder_agent.k8s-deployment.id
  install_version = "latest"
  subdomain = true
  port     = 8081

  order    = 998
}

resource "coder_ai_task" "this" {
  app_id = module.claude-code.task_app_id
}

resource "coder_app" "preview" {
  agent_id     = coder_agent.k8s-deployment.id
  slug         = "preview"
  display_name = "Web App Preview App"
  icon         = "${data.coder_workspace.me.access_url}/emojis/1f50e.png"
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