terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">=2.4.1"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "coder" {}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces). If the Coder host is itself running as a Pod on the same Kubernetes cluster as you are deploying workspaces to, set this to the same namespace."
}

variable "java_image" {
  type        = string
  description = "Docker image for Java 21 workspace"
  default     = "codercom/enterprise-java:ubuntu"
  # For Java 21, build and use a custom image:
  # default = "your-registry/java21-coder:latest"
}

# Prebuilt workspace configuration
variable "prebuild_instances" {
  type        = number
  description = "Number of prebuilt workspaces to maintain (0 to disable)"
  default     = 1
}

variable "prebuild_expiration_hours" {
  type        = number
  description = "Hours before unclaimed prebuilt workspaces expire (default 24)"
  default     = 24
}

data "coder_external_auth" "github" {
  id = "primary-github"
}

resource "random_uuid" "this" {}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

data "coder_workspace_tags" "location" {
  tags = {
    region = "us-east-2"
  }
}

data "coder_parameter" "enable_preview_app" {
  name        = "Enable Preview App?"
  description = "This enables listening to the running Java application (Spring Boot, Quarkus, etc.)"
  type        = "bool"
  default     = true
  mutable     = true
  order       = 8
}

data "coder_parameter" "preview_port" {
  count       = tobool(data.coder_parameter.enable_preview_app.value) ? 1 : 0
  name        = "Preview Port"
  description = "The port the Java app is running on (Spring Boot default: 8080)"
  type        = "number"
  default     = 8080
  mutable     = true
  order       = 9
}

data "coder_parameter" "build_tool" {
  name         = "build_tool"
  display_name = "Build Tool"
  type         = "string"
  description  = "Select the Java build tool for the project"
  icon         = "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/java/java-original.svg"
  default      = "maven"
  mutable      = false
  order        = 1
  option {
    name  = "Maven"
    value = "maven"
    icon  = "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/maven/maven-original.svg"
  }
  option {
    name  = "Gradle"
    value = "gradle"
    icon  = "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/gradle/gradle-original.svg"
  }
}

data "coder_parameter" "java_framework" {
  name         = "java_framework"
  display_name = "Java Framework"
  type         = "string"
  description  = "Select the primary Java framework (affects dev server startup)"
  icon         = "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/spring/spring-original.svg"
  default      = "spring-boot"
  mutable      = false
  order        = 2
  option {
    name  = "Spring Boot"
    value = "spring-boot"
    icon  = "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/spring/spring-original.svg"
  }
  option {
    name  = "Quarkus"
    value = "quarkus"
    icon  = "https://design.jboss.org/quarkus/logo/final/PNG/quarkus_icon_rgb_default.png"
  }
  option {
    name  = "Micronaut"
    value = "micronaut"
    icon  = "https://micronaut.io/wp-content/uploads/2021/02/Micronaut.svg"
  }
  option {
    name  = "Plain Java"
    value = "plain"
  }
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU cores"
  type         = "number"
  description  = "CPU cores for your individual workspace"
  icon         = "https://png.pngtree.com/png-clipart/20191122/original/pngtree-processor-icon-png-image_5165793.jpg"
  validation {
    min = 2
    max = 8
  }
  form_type = "input"
  mutable   = true
  default   = 4
  order     = 3
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (__ GB)"
  type         = "number"
  description  = "Memory (__ GB) for your individual workspace (Java apps typically need more memory)"
  icon         = "https://www.vhv.rs/dpng/d/33-338595_random-access-memory-logo-hd-png-download.png"
  validation {
    min = 4
    max = 16
  }
  form_type = "input"
  mutable   = true
  default   = 8
  order     = 4
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "The size of the home disk in GB"
  default      = "20"
  type         = "number"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 10
    max = 99999
  }
}

provider "kubernetes" {}

data "coder_parameter" "ai_prompt" {
  type        = "string"
  name        = "AI Prompt"
  icon        = "/emojis/1f4ac.png"
  description = "Write a task prompt for Claude. This will be the first action Claude follows."
  default     = file("./scripts/claude/TASK.md")
  mutable     = true
  form_type   = "textarea"
}

data "coder_parameter" "system_prompt" {
  type        = "string"
  name        = "AI System Prompt (Optional)"
  icon        = "/emojis/1f4ac.png"
  description = "Write a system prompt for Claude. This defines the context for Claude to follow."
  default     = file("./scripts/claude/SYSTEM.md")
  mutable     = true
  form_type   = "textarea"
  styling = jsonencode({
    disabled = true
  })
}

# =============================================================================
# PREBUILT WORKSPACE CONFIGURATION
# =============================================================================
# Prebuilt workspaces reduce startup time by maintaining a pool of ready-to-use
# workspaces. When a user creates a workspace matching a preset, they get an
# existing prebuilt workspace instead of waiting for provisioning.
#
# Prerequisites:
# - Coder Premium license required
# - Set prebuild_instances > 0 to enable
# =============================================================================

# Spring Boot + Maven preset (most common Java modernization scenario)
data "coder_workspace_preset" "spring_boot_maven" {
  name = "Spring Boot + Maven (Java 21)"
  parameters = {
    build_tool     = "maven"
    java_framework = "spring-boot"
    cpu            = 4
    memory         = 8
    home_disk_size = 20
  }
  default          = true
  prebuilds {
    instances = var.prebuild_instances
    expiration_policy {
      ttl = var.prebuild_expiration_hours * 3600
    }
  }
}

# # Spring Boot + Gradle preset
# data "coder_workspace_preset" "spring_boot_gradle" {
#   name = "Spring Boot + Gradle (Java 21)"
#   parameters = {
#     build_tool     = "gradle"
#     java_framework = "spring-boot"
#     cpu            = 4
#     memory         = 8
#     home_disk_size = 20
#   }
#   prebuilds {
#     instances = var.prebuild_instances
#     expiration_policy {
#       ttl = var.prebuild_expiration_hours * 3600
#     }
#   }
# }

# # Quarkus + Maven preset
# data "coder_workspace_preset" "quarkus_maven" {
#   name = "Quarkus + Maven (Java 21)"
#   parameters = {
#     build_tool     = "maven"
#     java_framework = "quarkus"
#     cpu            = 4
#     memory         = 8
#     home_disk_size = 20
#   }
#   prebuilds {
#     instances = var.prebuild_instances
#     expiration_policy {
#       ttl = var.prebuild_expiration_hours * 3600
#     }
#   }
# }

module "coder-login" {
  # Skip for prebuild workspaces - the prebuilds user can't create API keys
  count    = data.coder_workspace_owner.me.name != "prebuilds" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/coder-login/coder"
  version  = "1.0.15"
  agent_id = coder_agent.main.id
}

locals {
    env = {
    GH_TOKEN            = data.coder_external_auth.github.access_token
    GH_USERNAME         = data.coder_workspace_owner.me.name
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
    }
}

resource "coder_env" "this" {
    for_each = local.env
    agent_id = coder_agent.main.id
    name     = each.key
    value    = each.value
}

locals {
  vscode-web-settings = {
    "workbench.colorTheme" : "Default Dark Modern",
    "workbench.preferredDarkColorTheme" : "Default Dark Modern",
    "workbench.preferredHighContrastColorTheme" : "Default High Contrast",
    "git.useIntegratedAskPass" : false,
    "github.gitAuthentication" : false,
    "java.jdt.ls.java.home" : "/usr/lib/jvm/temurin-21-jdk-amd64",
    "java.configuration.runtimes" : [
      {
        "name" : "JavaSE-21",
        "path" : "/usr/lib/jvm/temurin-21-jdk-amd64",
        "default" : true
      },
      {
        "name" : "JavaSE-8",
        "path" : "/usr/lib/jvm/temurin-8-jdk-amd64"
      }
    ]
  }
  vscode-web-extensions = [
    "vscjava.vscode-java-pack",
    "vscjava.vscode-spring-initializr",
    "vmware.vscode-spring-boot",
    "vscjava.vscode-spring-boot-dashboard"
    # "redhat.vscode-xml",
    # "redhat.vscode-yaml"
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

locals {
  work_folder    = "/home/coder/repo"
  home_folder    = "/home/coder"
  workspace_name = random_uuid.this.result
  task_prompt    = data.coder_parameter.ai_prompt.value
  port           = try(data.coder_parameter.preview_port[0].value, 8080)
  domain         = element(split("/", data.coder_workspace.me.access_url), -1)
  build_tool     = data.coder_parameter.build_tool.value
  java_framework = data.coder_parameter.java_framework.value
  
  # Build tool specific commands
  build_cmd = local.build_tool == "maven" ? "mvn" : "gradle"
  
  # Framework-specific dev commands
  dev_cmd = {
    "spring-boot" = local.build_tool == "maven" ? "mvn spring-boot:run -Dspring-boot.run.arguments=--server.port=PREVIEW_PORT" : "gradle bootRun --args='--server.port=PREVIEW_PORT'"
    "quarkus"     = local.build_tool == "maven" ? "mvn quarkus:dev -Dquarkus.http.port=PREVIEW_PORT" : "gradle quarkusDev -Dquarkus.http.port=PREVIEW_PORT"
    "micronaut"   = local.build_tool == "maven" ? "mvn mn:run -Dmicronaut.server.port=PREVIEW_PORT" : "gradle run --args='-micronaut.server.port=PREVIEW_PORT'"
    "plain"       = local.build_tool == "maven" ? "mvn exec:java" : "gradle run"
  }
  
  system_prompt = replace(
    replace(
      replace(
        data.coder_parameter.system_prompt.value,
        "PREVIEW_PORT",
        tostring(local.port)
      ),
      "BUILD_TOOL",
      local.build_tool
    ),
    "DEV_CMD",
    local.dev_cmd[local.java_framework]
  )
  
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
        "Bash(mvn:*)",
        "Bash(gradle:*)",
        "Bash(java:*)",
        "Bash(javac:*)",
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
      CLAUDE_CODE_MAX_OUTPUT_TOKENS            = "64000"
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
      ANTHROPIC_MODEL                          = "claude-opus-4-5"
      ANTHROPIC_SMALL_FAST_MODEL               = "claude-haiku-4-5"
      ANTHROPIC_DEFAULT_HAIKU_MODEL            = "claude-haiku-4-5"
      ANTHROPIC_BASE_URL                       = "${data.coder_workspace.me.access_url}/api/v2/aibridge/anthropic"
      ANTHROPIC_AUTH_TOKEN                     = "${data.coder_workspace_owner.me.session_token}"
      NODE_OPTIONS                             = "--max-old-space-size=8192"
      JAVA_HOME                                = "/usr/lib/jvm/temurin-21-jdk-amd64"
      JAVA_TOOL_OPTIONS                        = "-Xmx4g -XX:+UseG1GC"

      GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_AUTHOR_EMAIL    = data.coder_workspace_owner.me.email
      GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
      GIT_COMMITTER_EMAIL = data.coder_workspace_owner.me.email
      GIT_CONFIG_COUNT    = 1
      GIT_CONFIG_KEY_0    = "user.name"
      GIT_CONFIG_VALUE_0  = data.coder_workspace_owner.me.email
      GIT_CONFIG_KEY_1    = "user.email"
      GIT_CONFIG_VALUE_1  = data.coder_workspace_owner.me.email
      GH_TOKEN            = data.coder_external_auth.github.access_token
      GH_USERNAME         = data.coder_workspace_owner.me.name
    }
    autoUpdaterStatus = "disabled"
    bypassPermissionsModeAccepted =  true
    hasAcknowledgedCostThreshold = true
    hasCompletedOnboarding = true
  }

  container_startup_script = <<-EOT
    set -e

    cd ~
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    \. "$HOME/.nvm/nvm.sh"
    nvm install 24
  EOT
}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"

  env = {
    PREVIEW_PORT        = local.port
    JAVA_HOME           = "/usr/lib/jvm/temurin-21-jdk-amd64"
    BUILD_TOOL          = local.build_tool
    JAVA_FRAMEWORK      = local.java_framework
  }

  display_apps {
    vscode          = false
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = false
  }

  startup_script = <<-EOT
    set -e
    
    echo "Setting up Coder Mux config..."
    mkdir -p ~/.mux
    echo "${replace(jsonencode(local.coder-mux-settings), "\"", "\\\"")}" > ~/.mux/providers.jsonc

    # Create the repo directory if it doesn't exist
    mkdir -p /home/coder/repo

    # Ensure .bashrc exists
    touch ~/.bashrc

    # Install required packages including zip
    sudo apt-get update -qq || true
    sudo apt-get install -y -qq gh zip unzip curl jq wget gnupg lsb-release ca-certificates || true

    # Install Eclipse Temurin Java 21 and Java 8
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /usr/share/keyrings/adoptium.gpg || true
    echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/adoptium.list || true
    sudo apt-get update -qq || true
    sudo apt-get install -y -qq temurin-21-jdk temurin-8-jdk || true

    # Set Java 21 as default
    sudo update-alternatives --set java /usr/lib/jvm/temurin-21-jdk-amd64/bin/java || true
    sudo update-alternatives --set javac /usr/lib/jvm/temurin-21-jdk-amd64/bin/javac || true

    # Set up JAVA_HOME in profile
    if ! grep -q "JAVA_HOME=/usr/lib/jvm/temurin-21" ~/.bashrc; then
      # Remove old JAVA_HOME entries
      sed -i '/JAVA_HOME/d' ~/.bashrc
      echo 'export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk-amd64' >> ~/.bashrc
      echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
    fi

    # Verify Java installation
    echo "Java version:"
    java -version
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "3_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
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

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    script       = <<EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "Java Version"
    key          = "7_java_version"
    script       = "java -version 2>&1 | head -1 | awk -F '\"' '{print $2}'"
    interval     = 300
    timeout      = 5
  }
}

module "claude-code" {
  count = data.coder_workspace.me.is_prebuild ? 0 : 1
  source              = "registry.coder.com/coder/claude-code/coder"
  agent_id            = coder_agent.main.id
  workdir             = local.work_folder
  version             = "4.2.9"

  install_agentapi    = true
  install_claude_code = true
  system_prompt       = local.system_prompt
  ai_prompt           = data.coder_parameter.ai_prompt.value
  report_tasks        = true

  post_install_script = templatefile("scripts/claude/install.sh", {
    HOME_FOLDER = local.home_folder
    SETTINGS    = jsonencode(local.claude_settings)
  })

  order = 0
}

module "code-server" {
  # # count = data.coder_workspace.me.is_prebuild ? 0 : 1
  # count        = data.coder_workspace.me.start_count
  source       = "registry.coder.com/coder/code-server/coder"
  display_name = "VS Code Web"
  version      = "1.3.1"
  agent_id     = coder_agent.main.id
  folder       = "/home/coder/repo"
  extensions   = local.vscode-web-extensions
  settings     = local.vscode-web-settings
  group        = "Web IDEs"
}

module "cmux" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/mux/coder"
  version  = "1.0.6"
  agent_id = coder_agent.main.id
  install_version = "latest"
  subdomain = true
  port     = 8081
}

resource "coder_ai_task" "this" {
  app_id = try(module.claude-code[0].task_app_id, "00000000-0000-0000-0000-000000000000")
}

resource "coder_app" "preview" {
  count        = tobool(data.coder_parameter.enable_preview_app.value) ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "preview"
  display_name = "Java Application Preview"
  icon         = "${data.coder_workspace.me.access_url}/emojis/2615.png"
  url          = "http://localhost:${local.port}"
  share        = "authenticated"
  subdomain    = true
  open_in      = "tab"
  order        = 1

    healthcheck {
    url       = "http://localhost:${local.port}/"
    interval  = 5
    threshold = 30
  }
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.3.2"
  agent_id = coder_agent.main.id
  folder   = "/home/coder/repo"
  group    = "Desktop IDEs"
  order    = 997
}

module "vscode-desktop" {
  source   = "registry.coder.com/coder/vscode-desktop/coder"
  version  = "1.1.1"
  agent_id = coder_agent.main.id
  folder   = "/home/coder/repo"
  order    = 998
  group    = "Desktop IDEs"
}

module "jetbrains_gateway" {
  source         = "registry.coder.com/coder/jetbrains-gateway/coder"
  version        = "1.2.6"
  agent_id       = coder_agent.main.id
  agent_name     = "main"
  folder         = "/home/coder/repo"
  jetbrains_ides = ["IU"]
  default        = "IU"
  latest         = true
  order          = 996
  group          = "Desktop IDEs"
}

module "kiro" {
  source   = "registry.coder.com/coder/kiro/coder"
  version  = "1.1.0"
  agent_id = coder_agent.main.id
  folder   = "/home/coder/repo"
  group    = "Desktop IDEs"
  order    = 999
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "coder-${data.coder_workspace.me.id}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim_v1.home
  ]
  wait_for_rollout = false
  
  metadata {
    name      = "coder-${data.coder_workspace.me.id}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${data.coder_workspace.me.id}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      # "com.coder.workspace.id"     = data.coder_workspace.me.id
      # "com.coder.workspace.name"   = data.coder_workspace.me.name
      # "com.coder.user.id"          = data.coder_workspace_owner.me.id
      # "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    # annotations = {
    #   "com.coder.user.email" = data.coder_workspace_owner.me.email
    # }
  
  }
  lifecycle {
    ignore_changes = [spec.0.template.0.spec.0.container.0.env.0]
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${coder_agent.main.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        # "com.coder.workspace.id"     = data.coder_workspace.me.id
        # "com.coder.workspace.name"   = data.coder_workspace.me.name
        # "com.coder.user.id"          = data.coder_workspace_owner.me.id
        # "com.coder.user.username"    = data.coder_workspace_owner.me.name
      }
    }
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = {
        "app.kubernetes.io/name"     = "coder-workspace"
        "app.kubernetes.io/instance" = "coder-workspace-${coder_agent.main.id}"
        "app.kubernetes.io/part-of"  = "coder"
        "com.coder.resource"         = "true"
        # "com.coder.workspace.id"     = data.coder_workspace.me.id
        # "com.coder.workspace.name"   = data.coder_workspace.me.name
        # "com.coder.user.id"          = data.coder_workspace_owner.me.id
        # "com.coder.user.username"    = data.coder_workspace_owner.me.name

        }
      }
      spec {
        security_context {
          run_as_user     = 1000
          fs_group        = 1000
          run_as_non_root = true
        }

        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = "coder-ws"
          effect   = "NoSchedule"
        }

        container {
          name              = "dev"
          image             = var.java_image
          image_pull_policy = "Always"
          command           = ["sh", "-c", join("\n", [local.container_startup_script, coder_agent.main.init_script])]
          security_context {
            run_as_user = "1000"
          }
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          env {
            name  = "JAVA_HOME"
            value = "/usr/lib/jvm/temurin-21-jdk-amd64"
          }
          resources {
            requests = {
              "cpu"    = "500m"
              "memory" = "1Gi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata.0.name
            read_only  = false
          }
        }

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              pod_affinity_term {
                topology_key = "kubernetes.io/hostname"
                label_selector {
                  match_expressions {
                    key      = "app.kubernetes.io/name"
                    operator = "In"
                    values   = ["coder-workspace"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
